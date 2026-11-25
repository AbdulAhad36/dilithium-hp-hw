// Shared x4 Process bit packer:four canonical coefficients per memory word.
// op0:t1,1:t0,2:eta secret,3:w1,4:z. Low output byte is first on the wire.
// One144-bit reservoir;no full polynomial/key buffer. Four coefficients need
// at most80 bits,so output bandwidth can apply backpressure for z packing.
`default_nettype none
module bitpkg_c22_reference (
  input wire logic clk,rst,command_valid_i,
  output logic command_ready_o,
  input wire logic [2:0] command_op_i,
  input wire logic [1:0] command_param_i,
  input wire logic [15:0] command_id_i,
  input wire logic input_valid_i,output logic input_ready_o,
  input wire logic [3:0][22:0] input_data_i,
  input wire logic [5:0] input_index_i,input wire logic input_last_i,
  output logic output_valid_o,input wire logic output_ready_i,
  output logic [63:0] output_data_o,
  output logic [3:0] output_bytes_o,
  output logic [6:0] output_index_o,
  output logic output_last_o,
  output logic [15:0] output_id_o,
  output logic done_valid_o,input wire logic done_ready_i,
  output logic [2:0] done_code_o,
  output logic [15:0] done_id_o
);
  typedef enum logic [1:0] {IDLE,FEED,REPORT} state_e;
  state_e state;
  logic [143:0] bits_r,bits_next;
  logic [7:0] count_r,count_after_pop,count_next;
  logic [6:0] group_r;
  logic [2:0] op_r;
  logic [4:0] width_r;
  logic [2:0] eta_r;
  logic [23:0] gamma_r;
  logic ended_r,pop,push,bad_value,bad_frame;
  logic [3:0][23:0] encoded;
  logic [79:0] group_bits;
  logic [6:0] group_width;
  function automatic logic [12:0] encode_t0(input logic [22:0] value);
    return (value<=4096?13'd4096:13'd4097)-value[12:0];
  endfunction
  function automatic logic [3:0] encode_secret(input logic [22:0] value,input logic [2:0] eta);
    return (value<=23'(eta)?4'(eta):4'(eta)+4'd1)-value[3:0];
  endfunction
  function automatic logic [19:0] encode_z(input logic [22:0] value,input logic [19:0] gamma);
    logic [19:0] base;
    base=value<=23'(gamma)?gamma:gamma==131072?20'h1e001:20'h7e001;
    return base-value[19:0];
  endfunction
  assign command_ready_o=!rst && state==IDLE;
  assign output_valid_o=!rst && state==FEED && count_r>=64;
  assign output_data_o=bits_r[63:0];assign output_bytes_o=8;
  assign output_last_o=ended_r && count_r==64;
  assign output_id_o=done_id_o;
  assign done_valid_o=!rst && state==REPORT;
  assign pop=output_valid_o && output_ready_i;
  assign count_after_pop=pop?count_r-8'd64:count_r;
  assign group_width={width_r,2'b0};
  assign input_ready_o=!rst && state==FEED && !ended_r && (!output_valid_o || output_ready_i) &&
    ({1'b0,count_after_pop}+{2'b0,group_width})<=9'd144;
  assign push=input_valid_i && input_ready_o;
  always_comb begin
    bad_value=0;encoded=0;
    for(int i=0;i<4;i++)begin
      bad_value|=input_data_i[i]>=23'd8380417;
      case(op_r)
        0:begin encoded[i]={1'b0,input_data_i[i]};bad_value|=input_data_i[i]>1023;end
        1:begin
          bad_value|=input_data_i[i]>4096 && input_data_i[i]<23'd8376322;
          encoded[i]=24'(encode_t0(input_data_i[i]));
        end
        2:begin
          bad_value|=input_data_i[i]>23'(eta_r) && input_data_i[i]<23'd8380417-23'(eta_r);
          encoded[i]=24'(encode_secret(input_data_i[i],eta_r));
        end
        3:begin encoded[i]={1'b0,input_data_i[i]};bad_value|=input_data_i[i]>(width_r==6?43:15);end
        4:begin
          bad_value|=input_data_i[i]>gamma_r && input_data_i[i]<23'(24'd8380418-gamma_r);
          encoded[i]=24'(encode_z(input_data_i[i],gamma_r[19:0]));
        end
        default:bad_value=1;
      endcase
    end
    // Fixed slices select encodings;no lane-index times variable-width mux.
    case(op_r)
      0:group_bits=80'({encoded[3][9:0],encoded[2][9:0],encoded[1][9:0],encoded[0][9:0]});
      1:group_bits=80'({encoded[3][12:0],encoded[2][12:0],encoded[1][12:0],encoded[0][12:0]});
      2:group_bits=eta_r==4?80'({encoded[3][3:0],encoded[2][3:0],encoded[1][3:0],encoded[0][3:0]}):
        80'({encoded[3][2:0],encoded[2][2:0],encoded[1][2:0],encoded[0][2:0]});
      3:group_bits=gamma_r==131072?80'({encoded[3][5:0],encoded[2][5:0],encoded[1][5:0],encoded[0][5:0]}):
        80'({encoded[3][3:0],encoded[2][3:0],encoded[1][3:0],encoded[0][3:0]});
      4:group_bits=gamma_r==131072?80'({encoded[3][17:0],encoded[2][17:0],encoded[1][17:0],encoded[0][17:0]}):
        {encoded[3][19:0],encoded[2][19:0],encoded[1][19:0],encoded[0][19:0]};
      default:group_bits=0;
    endcase
    bad_frame=group_r>63 || input_index_i!=group_r[5:0] || input_last_i!=(group_r==63);
    bits_next=pop?(bits_r>>64):bits_r;count_next=count_after_pop;
    if(push && !bad_value && !bad_frame)begin
      bits_next=bits_next | (144'(group_bits)<<count_after_pop);
      count_next=count_after_pop+{1'b0,group_width};
    end
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      state<=IDLE;bits_r<=0;count_r<=0;group_r<=0;op_r<=0;width_r<=0;eta_r<=0;
      gamma_r<=0;ended_r<=0;output_index_o<=0;done_code_o<=0;done_id_o<=0;
    end else case(state)
      IDLE:if(command_valid_i)begin
        op_r<=command_op_i;done_id_o<=command_id_i;done_code_o<=0;
        bits_r<=0;count_r<=0;group_r<=0;ended_r<=0;output_index_o<=0;
        eta_r<=command_param_i==1?4:2;
        gamma_r<=command_param_i==0?24'd131072:24'd524288;
        width_r<=command_op_i==0?10:command_op_i==1?13:command_op_i==2?
          (command_param_i==1?4:3):command_op_i==3?(command_param_i==0?6:4):
          (command_param_i==0?18:20);
        if(command_param_i==3 || command_op_i>4)begin done_code_o<=1;state<=REPORT;end
        else state<=FEED;
      end
      FEED:begin
        if(pop || push)begin bits_r<=bits_next;count_r<=count_next;end
        if(pop)begin output_index_o<=output_index_o+1'b1;if(output_last_o)state<=REPORT;end
        if(push)begin
          if(bad_value || bad_frame)begin
            done_code_o<=bad_frame?3'd3:3'd2;bits_r<=0;count_r<=0;state<=REPORT;
          end else begin group_r<=group_r+1'b1;if(input_last_i)ended_r<=1;end
        end
      end
      REPORT:if(done_ready_i)state<=IDLE;
      default:state<=IDLE;
    endcase
  end
endmodule
`default_nettype wire
