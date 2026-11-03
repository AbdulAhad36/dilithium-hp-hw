// Figure5 regrouping for16 signed4-bit samples/packet. Four earlier packets
// of the SAME context are retained;interleaved contexts never share a delay.
// Word0=[0..7,64..71],word8=[128..135,192..199]. Each word uses64/92 bits.
`default_nettype none
module secret_regroup (
  input wire logic clk,rst,
  input wire logic [1:0] job_start_i,
  input wire logic input_valid_i,output logic input_ready_o,
  input wire logic input_core_i,input_last_i,
  input wire logic [7:0] input_index_i,
  input wire logic [63:0] input_data_i,
  output logic output_valid_o,input wire logic output_ready_i,
  output logic output_core_o,output_last_o,
  output logic [3:0] output_word_o,
  output logic [91:0] output_data_o,
  output logic fault_o
);
  logic [63:0] delay_r[2][4];
  logic [4:0] packets_r[2];
  logic [1:0] pending_r;
  logic pending_core_r;
  logic [3:0] base_r;
  logic [63:0] first_r,second_r;
  logic pop,push,high_quarter,bad;
  assign high_quarter=input_index_i[6];
  assign output_valid_o=!rst && pending_r!=0 && !fault_o;
  assign pop=output_valid_o && output_ready_i;
  assign input_ready_o=!rst && !fault_o && (!high_quarter || pending_r==0 || (pending_r==1 && pop));
  assign push=input_valid_i && input_ready_o;
  assign output_core_o=pending_core_r;
  assign output_word_o=base_r+4'(pending_r==1);
  assign output_data_o={28'd0,(pending_r==2?first_r:second_r)};
  assign output_last_o=output_word_o==15;
  always_comb begin
    bad=input_index_i[3:0]!=0 || {1'b0,input_index_i[7:4]}!=packets_r[input_core_i] ||
      input_last_i!=(input_index_i==240);
    for(int lane=0;lane<16;lane++)bad|=input_data_i[4*lane+:4]>4 && input_data_i[4*lane+:4]<12;
  end
  always_ff @(posedge clk or posedge rst)begin
    if(rst)begin packets_r[0]<=0;packets_r[1]<=0;pending_r<=0;pending_core_r<=0;base_r<=0;fault_o<=0;end
    else begin
      if(pop)pending_r<=pending_r-1'b1;
      for(int c=0;c<2;c++)if(job_start_i[c])begin
        packets_r[c]<=0;
        if(pending_r!=0 && pending_core_r==c)fault_o<=1;
      end
      if(push)begin
        if(bad)fault_o<=1;
        else begin
          packets_r[input_core_i]<=packets_r[input_core_i]+1'b1;
          if(!high_quarter)delay_r[input_core_i][input_index_i[5:4]]<=input_data_i;
          else begin
            first_r<={input_data_i[31:0],delay_r[input_core_i][input_index_i[5:4]][31:0]};
            second_r<={input_data_i[63:32],delay_r[input_core_i][input_index_i[5:4]][63:32]};
            base_r<={input_index_i[7],input_index_i[5:4],1'b0};
            pending_core_r<=input_core_i;pending_r<=2;
          end
        end
      end
    end
  end
endmodule
`default_nettype wire
