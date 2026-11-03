// Independent registered A/B request queues,one per PHYSICAL bank port.
// A four-bit relation records the age of each live A/B slot pair. A younger
// conflicting request waits for every older opposite-port request;unrelated
// traffic bypasses a stalled opposite port. Same-edge acceptance orders A,B.
// Ready depends only on each port's registered occupancy,not RAM arbitration.
`default_nettype none
module bank_request_pipe (
 input wire logic clk,rst,
 input wire logic [1:0] input_valid_i,input_write_i,
 input wire logic [1:0][9:0] input_address_i,
 input wire logic [1:0][91:0] input_data_i,
 output logic [1:0] input_ready_o,
 output logic [1:0] output_valid_o,output_write_o,
 output logic [1:0][9:0] output_address_o,
 output logic [1:0][91:0] output_data_o,
 input wire logic [1:0] output_ready_i
);
 (* ramstyle="logic" *) logic [1:0][1:0][102:0] entries_r;
 logic [1:0][1:0] count_r,live;
 logic [1:0] read_r,write_r,push,pop,blocked;
 logic [1:0][1:0] a_older_r;
 genvar p,slot;
 generate
 for(p=0;p<2;p=p+1)begin:port_fields
  assign {output_write_o[p],output_address_o[p],output_data_o[p]}=entries_r[p][read_r[p]];
  assign input_ready_o[p]=!rst && count_r[p]<2;
  assign push[p]=input_valid_i[p] && input_ready_o[p];
  assign output_valid_o[p]=!rst && count_r[p]!=0 && !blocked[p];
  assign pop[p]=output_valid_o[p] && output_ready_i[p];
  for(slot=0;slot<2;slot=slot+1)begin:valid_slot
   assign live[p][slot]=count_r[p]==2 || (count_r[p]==1 && read_r[p]==1'(slot));
  end
  always_ff @(posedge clk)if(push[p])
   entries_r[p][write_r[p]]<={input_write_i[p],input_address_i[p],input_data_i[p]};
  always_ff @(posedge clk or posedge rst)begin
   if(rst)begin count_r[p]<=0;read_r[p]<=0;write_r[p]<=0;end
   else begin
    case({push[p],pop[p]})
     2'b10:count_r[p]<=count_r[p]+1'b1;
     2'b01:count_r[p]<=count_r[p]-1'b1;
     default:begin end
    endcase
    if(push[p])write_r[p]<=!write_r[p];
    if(pop[p])read_r[p]<=!read_r[p];
   end
  end
 end
 endgenerate
 always_comb begin
  blocked=0;
  for(int slot=0;slot<2;slot++)begin
   if(live[1][slot] && !a_older_r[read_r[0]][slot] &&
      output_address_o[0]==entries_r[1][slot][101:92] &&
      (output_write_o[0] || entries_r[1][slot][102]))blocked[0]=1;
   if(live[0][slot] && a_older_r[slot][read_r[1]] &&
      output_address_o[1]==entries_r[0][slot][101:92] &&
      (output_write_o[1] || entries_r[0][slot][102]))blocked[1]=1;
  end
 end
 always_ff @(posedge clk or posedge rst)begin
  if(rst)a_older_r<=0;
  else for(int a=0;a<2;a++)for(int b=0;b<2;b++)begin
   // New A is younger than all already-live B entries.
   if(push[0] && write_r[0]==1'(a))a_older_r[a][b]<=0;
   // New B is younger than all live A,including a simultaneous new A.
   if(push[1] && write_r[1]==1'(b))a_older_r[a][b]<=1;
  end
 end
 // synthesis translate_off
 always @(posedge clk)if(!rst)begin
  for(int p=0;p<2;p++)if(count_r[p]>2)$fatal(1,"Bank request queue overflow");
  if((output_valid_o==3) && output_address_o[0]==output_address_o[1] && (|output_write_o))
   $fatal(1,"Request ordering allowed a same-address write collision");
 end
 // synthesis translate_on
endmodule
`default_nettype wire
