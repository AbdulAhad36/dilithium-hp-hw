/* Thin executable wrapper around the unchanged repository C reference.
 * Python invokes one build for each DILITHIUM_MODE=2/3/5. No RTL is used.
 * Arguments: sampler-mode(0..3) nonce seed-hex. Prints 256 canonical values.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "poly.h"

int main(int argc, char **argv) {
  uint8_t seed[64];
  unsigned int byte;
  int mode, length;
  unsigned long nonce;
  poly result;
  if(argc != 4) return 2;
  mode = atoi(argv[1]);
  nonce = strtoul(argv[2], NULL, 10);
  length = mode == 0 ? SEEDBYTES : (mode == 3 ? CTILDEBYTES : CRHBYTES);
  if(mode < 0 || mode > 3 || nonce > 65535 || strlen(argv[3]) != (size_t)(2*length)) return 2;
  for(int i=0;i<length;i++) {
    if(sscanf(argv[3]+2*i, "%2x", &byte) != 1) return 2;
    seed[i] = (uint8_t)byte;
  }
  switch(mode) {
    case 0: poly_uniform(&result, seed, (uint16_t)nonce); break;
    case 1: poly_uniform_eta(&result, seed, (uint16_t)nonce); break;
    case 2: poly_uniform_gamma1(&result, seed, (uint16_t)nonce); break;
    default: poly_challenge(&result, seed); break;
  }
  for(int i=0;i<N;i++) {
    int value = result.coeffs[i] % Q;
    if(value < 0) value += Q;
    printf("%d\n", value);
  }
  return 0;
}
