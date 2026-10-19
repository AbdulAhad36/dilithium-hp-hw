// Shared sequential SampleInBall engine. The paper specifies distributed RAM,
// but not its cycle schedule. This single-port schedule is our reconstruction.
// Compact entries: 00=zero, 01=+1, 10=-1. RAM is cleared serially per new job;
// it has no bulk reset. Copy and sign writes are separate, including j==i.
module sampler_ball (
  input logic clk,rst,
  input logic start_i,start_core_i,
  input logic [1:0] start_param_i,
  input logic [1:0] abort_i,
  input logic byte_valid_i,byte_core_i,byte_last_i,
  input logic [7:0] byte_i,
  output logic byte_ready_o,
  output logic [1:0] done_o,exhausted_o,
  input logic read_valid_i,read_core_i,
  input logic [7:0] read_index_i,
  output logic read_ready_o,result_valid_o,result_core_o,
  output logic [22:0] result_o
);
  import sampler_pkg::*;
  typedef enum logic [2:0] {IDLE,CLEAR,COPY,SIGN,READ_OUT} state_t;
  state_t state;
  logic [1:0] memory [0:511];
  logic [1:0] read_value;
  logic [8:0] memory_address;
  logic [1:0] memory_write_data;
  logic memory_write;
  logic [1:0] pending,initialized;
  logic [63:0] signs [2];
  logic [3:0] sign_bytes [2];
  logic [7:0] position [2];
  logic selected,clear_core;
  logic [7:0] clear_index,saved_j;
  logic saved_last;
  wire idle = state==IDLE && pending==0;
  assign read_ready_o=!rst && idle && done_o[read_core_i] && !abort_i[read_core_i];
  assign byte_ready_o=!rst && idle && !read_valid_i && initialized[byte_core_i] &&
    !done_o[byte_core_i] && !exhausted_o[byte_core_i] && !abort_i[byte_core_i];
  assign result_valid_o=!rst && state==READ_OUT && !abort_i[selected];
  assign result_core_o=selected;
  assign result_o=read_value==2'b10 ? 23'(Q-1) : (read_value==2'b01 ? 23'd1 : 23'd0);

  // One synchronous RAM port, isolated from the resettable controller. The
  // serial CLEAR state initializes a context before any of its reads. Neither
  // the array nor its read register needs a reset. Read-during-write data is
  // unused: IDLE reads return in COPY or READ_OUT on the following cycle.
  always_comb begin
    memory_address=0;memory_write_data=0;memory_write=0;
    case(state)
      IDLE:begin
        // Stage4.9h: an unaccepted synchronous read has no consumer. Keep
        // handshake qualification in the FSM,off the RAM address payload.
        // read_valid excludes byte acceptance even when read_ready is low.
        if(read_valid_i)
          memory_address={read_core_i,read_index_i};
        else
          memory_address={byte_core_i,byte_i};
      end
      CLEAR:begin
        memory_address={clear_core,clear_index};
        memory_write=!rst && !abort_i[clear_core];
      end
      COPY:begin
        memory_address={selected,position[selected]};
        memory_write_data=read_value;
        memory_write=!rst && !abort_i[selected];
      end
      SIGN:begin
        memory_address={selected,saved_j};
        memory_write_data=signs[selected][0] ? 2'b10 : 2'b01;
        memory_write=!rst && !abort_i[selected];
      end
      default:;
    endcase
  end
  always_ff @(posedge clk) begin
    if(memory_write)memory[memory_address]<=memory_write_data;
    read_value<=memory[memory_address];
  end

  always_ff @(posedge clk) begin
    if(rst)begin
      state<=IDLE;pending<=0;initialized<=0;done_o<=0;exhausted_o<=0;
      selected<=0;clear_core<=0;clear_index<=0;saved_j<=0;saved_last<=0;
      for(int k=0;k<2;k++)begin signs[k]<=0;sign_bytes[k]<=0;position[k]<=0;end
    end else begin
      case(state)
        IDLE:begin
          // COPY/SIGN own this byte only after an accepted candidate. Capturing
          // during IDLE keeps the rejection comparator off its wide enable.
          saved_j<=byte_i;saved_last<=byte_last_i;
          if(|pending)begin
            clear_core<=pending[0] ? 1'b0 : 1'b1;
            clear_index<=0;state<=CLEAR;
          end else if(read_valid_i && read_ready_o)begin
            selected<=read_core_i;
            state<=READ_OUT;
          end else if(byte_valid_i && byte_ready_o)begin
            if(sign_bytes[byte_core_i]<8)begin
              if(byte_last_i)exhausted_o[byte_core_i]<=1;
            end else if(byte_i>position[byte_core_i])begin
              // Rejection consumes a byte but neither a sign nor a position.
              if(byte_last_i)exhausted_o[byte_core_i]<=1;
            end else begin
              selected<=byte_core_i;
              state<=COPY;
            end
          end
        end
        CLEAR:begin
          if(clear_index==255)begin
            pending[clear_core]<=0;initialized[clear_core]<=1;state<=IDLE;
          end else clear_index<=clear_index+1'b1;
        end
        COPY:begin
          state<=SIGN;
        end
        SIGN:begin
          signs[selected]<=signs[selected]>>1;
          if(position[selected]==255)done_o[selected]<=1;
          else begin
            position[selected]<=position[selected]+1'b1;
            if(saved_last)exhausted_o[selected]<=1;
          end
          state<=IDLE;
        end
        READ_OUT:state<=IDLE;
        default:state<=IDLE;
      endcase
      // Stage4.9b: preload only the NEXT,unowned sign byte while idle. Earlier
      // accepted bytes are untouched;after all8 bytes no preload is permitted.
      // Each actual byte handshake overwrites its own slot with the valid byte
      // on the same edge that advances sign_bytes. Read arbitration therefore
      // controls the count,not the128-bit payload enable. Start/reset override
      // these speculative writes;COPY/SIGN remain mutually exclusive with IDLE.
      for(int k=0;k<2;k++)if(state==IDLE && sign_bytes[k]<8)
        signs[k][sign_bytes[k]*8+:8]<=byte_i;
      for(int k=0;k<2;k++)if(state==IDLE && byte_valid_i && byte_ready_o && byte_core_i==k && sign_bytes[k]<8)begin
        sign_bytes[k]<=sign_bytes[k]+1'b1;
      end
      for(int k=0;k<2;k++)if(abort_i[k])begin
        pending[k]<=0;initialized[k]<=0;done_o[k]<=0;exhausted_o[k]<=0;
        if((state==CLEAR && clear_core==k) ||
           ((state==COPY || state==SIGN || state==READ_OUT) && selected==k))state<=IDLE;
      end
      if(start_i)begin
        pending[start_core_i]<=1;initialized[start_core_i]<=0;
        done_o[start_core_i]<=0;exhausted_o[start_core_i]<=0;
        signs[start_core_i]<=0;sign_bytes[start_core_i]<=0;
        case(start_param_i)
          0:position[start_core_i]<=217; // 256-39
          1:position[start_core_i]<=207; // 256-49
          default:position[start_core_i]<=196; // 256-60
        endcase
      end
    end
  end
  // synthesis translate_off
  always @(posedge clk)if(!rst)begin
    for(int k=0;k<2;k++)assert(sign_bytes[k]<=8)
      else $fatal(1,"Challenge sign-byte ownership count overflow");
    if((state==COPY || state==SIGN) && !abort_i[selected])
      assert(initialized[selected] && sign_bytes[selected]==8)
        else $fatal(1,"Challenge consumed speculative sign payload before8 accepted bytes");
  end
  // synthesis translate_on
endmodule
