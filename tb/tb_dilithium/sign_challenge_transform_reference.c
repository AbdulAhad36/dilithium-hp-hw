#include <stdio.h>
#include <stdint.h>
#include "poly.h"
#include "params.h"
int main(void) {
  unsigned n,v;uint8_t seed[64];poly c;
  while(scanf("%u",&n)==1) {
    if(n!=CTILDEBYTES)return 2;
    for(unsigned i=0;i<n;i++){if(scanf("%2x",&v)!=1)return 3;seed[i]=(uint8_t)v;}
    poly_challenge(&c,seed);
    for(unsigned i=0;i<N;i++)printf("%u ",(unsigned)((c.coeffs[i]%Q+Q)%Q));
    poly_ntt(&c);
    for(unsigned i=0;i<N;i++)printf("%u%c",(unsigned)((c.coeffs[i]%Q+Q)%Q),i==N-1?'\n':' ');
  }
  return 0;
}
