/* Test adapter only:unchanged C unpack_sk and poly_ntt;canonical outputs. */
#include <stdint.h>
#include <stdio.h>
#include "params.h"
#include "packing.h"
#include "polyvec.h"
int main(void) {
  uint8_t sk[CRYPTO_SECRETKEYBYTES],rho[SEEDBYTES],key[SEEDBYTES],tr[TRBYTES];
  polyvecl s1;polyveck s2,t0;unsigned value;
  while(scanf("%u",&value)==1) {
    if(value>255)return 2;sk[0]=(uint8_t)value;
    for(unsigned i=1;i<CRYPTO_SECRETKEYBYTES;i++) {
      if(scanf("%u",&value)!=1 || value>255)return 2;sk[i]=(uint8_t)value;
    }
    unpack_sk(rho,tr,key,&t0,&s1,&s2,sk);
    for(unsigned section=0;section<3;section++)for(unsigned j=0;j<(section==0?L:K);j++) {
      poly *p=section==0?&s1.vec[j]:(section==1?&s2.vec[j]:&t0.vec[j]);
      poly_ntt(p);
      for(unsigned i=0;i<N;i++) {
        int32_t x=p->coeffs[i]%Q;if(x<0)x+=Q;printf("%d ",x);
      }
    }
    putchar('\n');
  }
  return 0;
}
