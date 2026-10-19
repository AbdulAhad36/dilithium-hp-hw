// Stage4.9c: A/mask share the alignment payload for their owning accepted word.
// Fine/coarse alignment and carry extraction terminate at separate registers.
// Outputs remain owned by this accepted beat until the next accept_i.
module sampler_input_prepare(
  input logic clk,rst,accept_i,
  input logic [127:0] word_i,
  input logic [4:0] bytes_i,
  input logic [18:0] mask_carry_i,
  input logic [4:0] mask_bits_i,
  input logic wide_i,mode_a_i,
  input logic [15:0] a_carry_i,
  input logic [1:0] a_bytes_i,
  output logic ready_o,
  output logic [1:0][3:0][19:0] mask_fields_o,
  output logic [1:0][3:0] mask_valid_o,
  output logic [1:0][18:0] mask_carry_o,
  output logic [1:0][4:0] mask_bits_o,
  output logic [1:0][2:0][22:0] a_fields_o,
  output logic [1:0][1:0] a_lanes_o,
  output logic [1:0][15:0] a_carry_o,
  output logic [1:0][1:0] a_bytes_o
);
  logic [127:0] word_stage_r;
  logic [2:0] phase_r;
  logic [18:0] saved_mask_r;
  logic [4:0] saved_bits_r,bytes_r;
  logic [1:0] saved_a_bytes_r;
  logic wide_r;
  logic [130:0] mask_fine_r;
  logic [2:0] mask_coarse_r;
  logic [146:0] mask_stream_r;
  logic [5:0][22:0] a_values;
  logic [159:0] mask_padded;
  logic [178:0] carry_padded;
  logic [1:0][7:0] totals_r;
  logic [1:0][4:0] a_totals_r;
  logic [1:0][4:0] offsets_r,end_bits_r;
  logic [1:0][3:0] field_counts_r;
  logic [7:0] full_valid_r;
  logic [3:0] lower_valid_r;
  logic [1:0][18:0] carry_masks_r,carry_results;
  logic [1:0][1:0] a_ends_r;
  logic [1:0][2:0] a_counts_r;
  logic [1:0][15:0] a_carries;
  function automatic logic [4:0] offset_bits(input logic [4:0] bytes,input logic wide);
    if(wide)case(bytes)
      0,5,10,15:return 0;
      1,6,11,16:return 8;
      2,7,12:return 16;
      3,8,13:return 4;
      default:return 12;
    endcase
    else case(bytes)
      0,9:return 0;
      1,10:return 8;
      2,11:return 16;
      3,12:return 6;
      4,13:return 14;
      5,14:return 4;
      6,15:return 12;
      7,16:return 2;
      default:return 10;
    endcase
  endfunction
  function automatic logic [3:0] field_count(input logic [7:0] total,input logic wide);
    if(wide)begin
      if(total>=80)begin
        if(total>=120)return total>=140 ? 7:6;
        return total>=100 ? 5:4;
      end
      if(total>=40)return total>=60 ? 3:2;
      return total>=20 ? 1:0;
    end
    if(total>=72)begin
      if(total>=108)return total>=144 ? 8:(total>=126 ? 7:6);
      return total>=90 ? 5:4;
    end
    if(total>=36)return total>=54 ? 3:2;
    return total>=18 ? 1:0;
  endfunction
  function automatic logic [2:0] a_count(input logic [4:0] bytes);
    case(bytes)
      0,1,2:return 0;
      3,4,5:return 1;
      6,7,8:return 2;
      9,10,11:return 3;
      12,13,14:return 4;
      15,16,17:return 5;
      default:return 6;
    endcase
  endfunction
  function automatic logic [1:0] a_remainder(input logic [4:0] bytes);
    case(bytes)
      0,3,6,9,12,15,18:return 0;
      1,4,7,10,13,16:return 1;
      default:return 2;
    endcase
  endfunction
  function automatic logic [18:0] carry_window(input logic [178:0] stream,
      input logic [3:0] count,input logic wide);
    case(count)
      0:return stream[0+:19];
      1:return wide ? stream[20+:19]:stream[18+:19];
      2:return wide ? stream[40+:19]:stream[36+:19];
      3:return wide ? stream[60+:19]:stream[54+:19];
      4:return wide ? stream[80+:19]:stream[72+:19];
      5:return wide ? stream[100+:19]:stream[90+:19];
      6:return wide ? stream[120+:19]:stream[108+:19];
      7:return wide ? stream[140+:19]:stream[126+:19];
      8:return wide ? stream[160+:19]:stream[144+:19];
      default:return 0;
    endcase
  endfunction
  always_comb begin
    // For A,the shared shift is whole bytes and the carry is zero-extended.
    // For mask,it is the saved bit count. Only the owning mode consumes data.
    for(int j=0;j<6;j++)a_values[j]=mask_stream_r[24*j+:23];
    mask_padded={13'd0,mask_stream_r};carry_padded={32'd0,mask_stream_r};
    for(int half=0;half<2;half++)begin
      carry_results[half]=carry_window(carry_padded,field_counts_r[half],wide_r)&carry_masks_r[half];
      a_carries[half]=0;
      for(int j=0;j<6;j++)if(a_counts_r[half]==j)begin
        if(a_ends_r[half]==1)a_carries[half]={8'd0,a_values[j][7:0]};
        else if(a_ends_r[half]==2)a_carries[half]=a_values[j][15:0];
      end
    end
    for(int j=0;j<3;j++)begin
      a_fields_o[0][j]=a_values[j];
      a_fields_o[1][j]=a_counts_r[0]==3 ? a_values[j+3]:a_values[j+2];
    end
    a_lanes_o[0]=2'(a_counts_r[0]);a_lanes_o[1]=2'(a_counts_r[1]-a_counts_r[0]);
    for(int j=0;j<4;j++)begin
      mask_fields_o[0][j]=wide_r ? mask_padded[20*j+:20]:20'(mask_padded[18*j+:18]);
      if(lower_valid_r[3])
        mask_fields_o[1][j]=wide_r ? mask_padded[20*(j+4)+:20]:20'(mask_padded[18*(j+4)+:18]);
      else
        mask_fields_o[1][j]=wide_r ? mask_padded[20*(j+3)+:20]:20'(mask_padded[18*(j+3)+:18]);
    end
    mask_valid_o[0]=lower_valid_r;
    mask_valid_o[1]=lower_valid_r[3] ? full_valid_r[7:4]:full_valid_r[6:3];
    mask_bits_o=end_bits_r;a_bytes_o=a_ends_r;
  end
  always_ff @(posedge clk)begin
    // This I/O sampling register has no internally qualified wide enable.
    word_stage_r<=word_i;
    if(rst)begin phase_r<=0;ready_o<=0;end
    else if(accept_i)begin
      phase_r<=1;ready_o<=0;bytes_r<=bytes_i;wide_r<=wide_i;
      saved_mask_r<=mode_a_i ? 19'(a_carry_i):mask_carry_i;
      saved_bits_r<=mode_a_i ? {a_bytes_i,3'b000}:mask_bits_i;
      saved_a_bytes_r<=a_bytes_i;
      offsets_r[0]<=offset_bits(bytes_i>8 ? 5'd8:bytes_i,wide_i);
      offsets_r[1]<=offset_bits(bytes_i,wide_i);
    end else if(phase_r!=0 && phase_r<4)phase_r<=phase_r+1'b1;
    if(phase_r==1)begin
      logic [5:0] low_sum,all_sum;
      mask_fine_r<=131'(word_stage_r)<<saved_bits_r[1:0];
      mask_coarse_r<=saved_bits_r[4:2];
      totals_r[0]<=8'(saved_bits_r)+8'((bytes_r>8 ? 8:bytes_r)*8);
      totals_r[1]<=8'(saved_bits_r)+{bytes_r,3'b000};
      a_totals_r[0]<=5'(saved_a_bytes_r)+(bytes_r>8 ? 5'd8:bytes_r);
      a_totals_r[1]<=5'(saved_a_bytes_r)+bytes_r;
      low_sum={1'b0,saved_bits_r}+{1'b0,offsets_r[0]};
      all_sum={1'b0,saved_bits_r}+{1'b0,offsets_r[1]};
      end_bits_r[0]<=5'(low_sum>=(wide_r?20:18) ? low_sum-(wide_r?20:18):low_sum);
      end_bits_r[1]<=5'(all_sum>=(wide_r?20:18) ? all_sum-(wide_r?20:18):all_sum);
    end
    if(phase_r==2)begin
      mask_stream_r<=(147'(mask_fine_r)<<{mask_coarse_r,2'b00}) |147'(saved_mask_r);
      for(int half=0;half<2;half++)begin
        field_counts_r[half]<=field_count(totals_r[half],wide_r);
        for(int bit_index=0;bit_index<19;bit_index++)carry_masks_r[half][bit_index]<=bit_index<end_bits_r[half];
        a_counts_r[half]<=a_count(a_totals_r[half]);
        a_ends_r[half]<=a_remainder(a_totals_r[half]);
      end
      for(int j=0;j<4;j++)lower_valid_r[j]<=totals_r[0]>=(j+1)*(wide_r?20:18);
      for(int j=0;j<8;j++)full_valid_r[j]<=totals_r[1]>=(j+1)*(wide_r?20:18);
    end
    // Stage4.9f: carry payload can capture even if a short challenge word
    // restarts preparation. Old payload is then invalid until the new word
    // finishes. Ready MUST retain reset/acceptance priority;the payload banks
    // need neither enable. This removes input-ready/exhaustion from data enables.
    if(phase_r==3)begin
      mask_carry_o<=carry_results;a_carry_o<=a_carries;
    end
    if(phase_r==3 && !rst && !accept_i)ready_o<=1;
  end
  // synthesis translate_off
  logic accepted_previous_r;
  always @(posedge clk)begin
    if(rst)accepted_previous_r<=0;
    else begin
      if(accepted_previous_r)assert(!ready_o)
        else $fatal(1,"Preparation restart exposed stale ready");
      if(ready_o)assert(phase_r==4)
        else $fatal(1,"Preparation ready before completed phase4");
      accepted_previous_r<=accept_i;
    end
  end
  // synthesis translate_on
endmodule
