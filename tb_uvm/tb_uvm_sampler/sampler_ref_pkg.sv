// Scalar byte-stream reference: no RTL extractor, collector or schedule reuse.
package sampler_ref_pkg;
  function automatic int unsigned matrix_candidate(byte unsigned b0,b1,b2);
    return int'(b0) + 256*int'(b1) + 65536*int'(b2 & 8'h7f);
  endfunction
  // Return signed mathematical coefficient, -99 denotes a rejected nibble.
  // Independent scalar FIPS formula; no compare/subtract lane implementation.
  function automatic int secret_candidate(input int nibble, input bit eta4);
    if(eta4)return nibble<9 ? 4-nibble : -99;
    return nibble<15 ? 2-(nibble%5) : -99;
  endfunction
  // Known teaching byte stream from SAMPLER.md, not an official NIST vector.
  function automatic int mask_example_signed(input int index);
    case(index)
      0:return -3; 1:return 0; 2:return 2; 3:return 131072;
      4:return -131071; 5:return 1; 6:return -68928; 7:return 31072;
      default:return 0;
    endcase
  endfunction
endpackage
