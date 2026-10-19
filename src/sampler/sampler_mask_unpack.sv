// Baseline mask expansion: up to one 64-bit chunk plus 19 saved bits.
// FIPS 204 BitUnpack consumes low-first 18/20-bit fields with no rejection.
// Four-field parallel extraction is our reconstruction, not disclosed authors' RTL.
module sampler_mask_unpack (
  input logic [63:0] word_i,
  input logic [63:0] word_lower_i,word_upper_i,
  input logic upper_i,
  input logic [3:0] bytes_i,
  input logic wide_i,
  input logic [18:0] residual_i,
  input logic [4:0] residual_bits_i,
  input logic [6:0] carry_shift_i,
  output logic [3:0] valid_o,
  output logic [3:0][19:0] field_o,
  output logic [18:0] residual_o,
  output logic [4:0] residual_bits_o
);
  logic [82:0] bits;
  wire [82:0] aligned_lower=83'(word_lower_i)<<residual_bits_i;
  wire [82:0] aligned_upper=83'(word_upper_i)<<residual_bits_i;
  logic [6:0] available,consumed;
  logic [2:0] fields;
  always_comb begin
    // Caller zeros bytes above bytes_i when accepting the original beat.
    // This moves byte-valid masking before the holding register, off the
    // carry feedback path. bytes_i still determines the field/carry counts.
    // One alignment shift replaces eight variable-index byte writes. Saved
    // carry is zero above its declared bit count, as is the masked input word.
    bits=83'(residual_i) | (upper_i ? aligned_upper:aligned_lower);
    valid_o='0;field_o='0;
    available=7'(residual_bits_i)+{bytes_i,3'b000};
    consumed=0;
    fields=wide_i ? (available>=80 ? 4:(available>=60 ? 3:(available>=40 ? 2:(available>=20 ? 1:0)))) :
      (available>=72 ? 4:(available>=54 ? 3:(available>=36 ? 2:(available>=18 ? 1:0))));
    for(int j=0;j<4;j++) begin
      // Consumers own validity;unused payload must not gate wide extraction.
      field_o[j]=wide_i ? bits[j*20+:20] : 20'(bits[j*18+:18]);
      if(j<fields)begin
        valid_o[j]=1;
      end
    end
    // Completed fields consume all the old carry. Extract the new carry
    // directly from the input word, avoiding alignment followed by a slice mux
    // on the carry feedback path. With no completed field, retain the combined
    // low bits (the old carry is still part of the unfinished field).
    if(wide_i)case(fields)
      0:consumed=0;
      1:consumed=20;
      2:consumed=40;
      3:consumed=60;
      default:consumed=80;
    endcase
    else case(fields)
      0:consumed=0;
      1:consumed=18;
      2:consumed=36;
      3:consumed=54;
      default:consumed=72;
    endcase
    // The caller prepares this shift at beat acceptance for both held halves.
    // Keep field-count/subtraction logic off the data extraction path.
    residual_o=(fields==0) ? bits[18:0] : 19'(word_i>>carry_shift_i);
    residual_bits_o=5'(available-consumed);
  end
endmodule
