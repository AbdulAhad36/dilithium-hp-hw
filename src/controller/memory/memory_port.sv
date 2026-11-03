// One bank-port scheduler. A and B instantiate independent copies of this FSM.
// Each selected bank advances independently:irregular packing writes do not
// stall reads on another bank. No polynomial IDs,leases or copied contexts.
`default_nettype none
module memory_port #(parameter bit COHERENT_ADMISSION=0) (
  input wire logic clk,rst,command_valid_i,
  output logic command_ready_o,
  output logic [3:0] busy_o,
  input wire logic [3:0] command_mask_i,command_write_i,
  input wire logic [3:0][9:0] command_base_i,
  input wire logic [3:0][10:0] command_words_i,
  // 0:sequential,1:even/odd transform words,2:Pre-NTT repeated
  // regrouped words,3:natural-order secret decode from compact storage.
  input wire logic [3:0][1:0] command_mode_i,
  input wire logic [3:0] write_valid_i,
  output logic [3:0] write_ready_o,
  input wire logic [3:0][91:0] write_data_i,
  // Write mode2 uses producer-tagged word addresses,allowing two sampled
  // polynomials to share one physical B-port burst without copied buffers.
  input wire logic [3:0][9:0] write_address_i,
  output logic [3:0] read_valid_o,
  input wire logic [3:0] read_ready_i,
  output logic [3:0][91:0] read_data_o,
  output logic [3:0][9:0] read_address_o,
  output logic [3:0] read_last_o,
  output logic [3:0] done_valid_o,
  input wire logic [3:0] done_ready_i,
  output logic [3:0] done_error_o,
  output logic [3:0] request_valid_o,request_write_o,
  output logic [3:0][9:0] request_address_o,
  output logic [3:0][91:0] request_data_o,
  input wire logic [3:0] request_ready_i,response_valid_i,response_write_i,
  input wire logic [3:0][9:0] response_address_i,
  input wire logic [3:0][91:0] response_data_i,
  output logic [3:0] response_ready_o
);
  typedef enum logic [1:0] {IDLE,RUN,REPORT,ADMIT} state_e;
  state_e state[4];
  logic [3:0] write_r,effective_mask;
  logic [3:0][1:0] mode_r;
  logic [3:0][9:0] base_r;
  logic [3:0][10:0] words_r,issued_r,retired_r;
  logic [3:0] issue_open_r;
  logic [3:0] admit_mask_r;
  logic mask_bad_r,admission_bad;
  function automatic logic [11:0] offset(input logic [10:0] index,input logic [1:0] mode);
    case(mode)
      1:return {index,1'b0};
      2:return {9'd0,index[3:1]};
      3:return {8'd0,index[5],index[3:1]};
      default:return {1'b0,index};
    endcase
  endfunction
  function automatic logic span_bad(input logic [9:0] base,
    input logic [10:0] words,input logic [1:0] mode,input logic write_command);
    // Compare the exclusive end without a subtract/add carry chain. For
    // stride two, base+2*(words-1)+1 <= 1024 is equivalent (for the
    // independently checked nonzero/in-range words) to words+floor(base/2)
    // <= 512. Tagged mode-two writes use the producer's checked addresses.
    case(mode)
      1:return ({1'b0,words}+{3'b0,base[9:1]})>12'd512;
      2:return !write_command && base>10'd1016;
      3:return base>10'd1008;
      default:return ({2'b0,base}+{1'b0,words})>12'd1024;
    endcase
  endfunction
  function automatic logic bank_bad(input logic [9:0] base,
    input logic [10:0] words,input logic [1:0] mode,input logic write_command);
    return words==0 || words>1024 ||
      (mode==2 && !write_command && words!=32) ||
      (mode==3 && words!=64) || span_bad(base,words,mode,write_command);
  endfunction
  always_comb begin
    effective_mask=command_mask_i==0?4'b0001:command_mask_i;
    command_ready_o=!rst;
    for(int b=0;b<4;b++)if(effective_mask[b] && state[b]!=IDLE &&
      !(state[b]==REPORT && done_ready_i[b]))command_ready_o=0;
    // The command descriptor was captured at the preceding edge. Validate
    // before issuing any RAM request,independent of arbitration/live inputs.
    admission_bad=mask_bad_r;
    for(int b=0;b<4;b++)if(admit_mask_r[b])
      admission_bad|=bank_bad(base_r[b],words_r[b],mode_r[b],write_r[b]);
  end
  always_comb begin
    request_valid_o=0;request_write_o=write_r;
    request_data_o=write_data_i;write_ready_o=0;
    read_valid_o=0;read_data_o=response_data_i;
    read_address_o=response_address_i;read_last_o=0;response_ready_o=0;
    for(int b=0;b<4;b++)begin
      busy_o[b]=state[b]!=IDLE;done_valid_o[b]=!rst && state[b]==REPORT;
      request_address_o[b]=base_r[b]+10'(offset(issued_r[b],mode_r[b]));
      if(write_r[b] && mode_r[b]==2)request_address_o[b]=write_address_i[b];
      if(!rst && state[b]==RUN)begin
        request_valid_o[b]=issue_open_r[b] && (!write_r[b] || write_valid_i[b]);
        write_ready_o[b]=write_r[b] && issue_open_r[b] && request_ready_i[b];
        read_valid_o[b]=!write_r[b] && response_valid_i[b];
        read_last_o[b]=retired_r[b]+11'd1==words_r[b];
        response_ready_o[b]=write_r[b] || read_ready_i[b];
      end
    end
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin
      for(int b=0;b<4;b++)state[b]<=IDLE;
      write_r<=0;mode_r<=0;base_r<=0;words_r<=0;
      issued_r<=0;retired_r<=0;done_error_o<=0;admit_mask_r<=0;mask_bad_r<=0;
      issue_open_r<=0;
    end else begin
      if(command_valid_i && (COHERENT_ADMISSION || command_ready_o))begin
        admit_mask_r<=effective_mask;
        mask_bad_r<=command_mask_i==0 || (command_write_i & ~command_mask_i)!=0;
      end
      for(int b=0;b<4;b++)begin
      // A retired read burst can turn directly into a write burst for the
      // SAME owner. There is no idle cycle in which another writer can steal
      // the lane before an in-place NTT's non-stallable result phase.
      if(command_valid_i && (COHERENT_ADMISSION || command_ready_o) && effective_mask[b])begin
        write_r[b]<=command_write_i[b];mode_r[b]<=command_mode_i[b];
        base_r[b]<=command_base_i[b];words_r[b]<=command_words_i[b];
        issued_r[b]<=0;retired_r[b]<=0;done_error_o[b]<=0;
        issue_open_r[b]<=command_words_i[b]!=0;
        state[b]<=ADMIT;
      end else case(state[b])
      ADMIT:begin
        done_error_o[b]<=admission_bad;
        state[b]<=admission_bad?REPORT:RUN;
      end
      RUN:begin
        if(request_valid_o[b] && request_ready_i[b])begin
          issued_r[b]<=issued_r[b]+1'b1;
          // Advance the capacity predicate at the issue edge. Downstream
          // write-ready no longer traverses an eleven-bit comparison.
          issue_open_r[b]<=issued_r[b]+11'd1<words_r[b];
        end
        if(response_valid_i[b] && response_ready_o[b])retired_r[b]<=retired_r[b]+1'b1;
        if(retired_r[b]==words_r[b])state[b]<=REPORT;
      end
      REPORT:if(done_ready_i[b])state[b]<=IDLE;
      default:state[b]<=IDLE;
      endcase
      end
    end
  end
`ifndef SYNTHESIS
  always @(posedge clk)if(!rst)for(int b=0;b<4;b++)if(state[b]==RUN)begin
    if(issue_open_r[b] !== (issued_r[b]<words_r[b]))
      $fatal(1,"LightHD bank-port cached issue capacity mismatch bank%0d",b);
    if(response_valid_i[b] && response_write_i[b]!==write_r[b])
      $fatal(1,"LightHD bank-port response kind mismatch bank%0d",b);
    if(response_valid_i[b] && retired_r[b]>=words_r[b])
      $fatal(1,"LightHD bank-port unexpected response bank%0d",b);
  end
`endif
// synthesis translate_off
  always @(posedge clk)if(!rst && COHERENT_ADMISSION && command_valid_i && !command_ready_o)
    $fatal(1,"Coherent scheduler received a non-admissible command");
  // synthesis translate_on
endmodule
`default_nettype wire
