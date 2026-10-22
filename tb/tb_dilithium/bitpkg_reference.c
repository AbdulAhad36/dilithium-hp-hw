#include <stdint.h>
#include <stdio.h>
#include "poly.h"
#include "params.h"

/* Uses the unchanged software packers;input coefficients are canonical RTL residues. */
int main(void) {
  unsigned op,value;
  poly a;
  uint8_t output[POLYT0_PACKEDBYTES];
  while(scanf("%u",&op)==1) {
    for(unsigned i=0;i<N;i++) {
      if(scanf("%u",&value)!=1 || value>=Q) return 2;
      a.coeffs[i]=(op==0 || value<=(Q-1)/2)?(int32_t)value:(int32_t)value-Q;
    }
    unsigned length;
    if(op==0) { polyt1_pack(output,&a);length=POLYT1_PACKEDBYTES; }
    else if(op==1) { polyt0_pack(output,&a);length=POLYT0_PACKEDBYTES; }
    else if(op==2) { polyeta_pack(output,&a);length=POLYETA_PACKEDBYTES; }
    else return 3;
    for(unsigned i=0;i<length;i++)printf("%02x",output[i]);
    putchar('\n');
  }
  return 0;
}
