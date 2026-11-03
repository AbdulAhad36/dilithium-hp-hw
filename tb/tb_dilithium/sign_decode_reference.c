/* Test adapter only;unchanged software unpack_sk supplies the independent C
 * bit layout. C intentionally decodes unused eta patterns;the RTL's strict
 * range rejection is checked separately by Python. */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "params.h"
#include "packing.h"
#include "polyvec.h"
int main(void) {
  uint8_t sk[CRYPTO_SECRETKEYBYTES],roundtrip[CRYPTO_SECRETKEYBYTES];
  uint8_t rho[SEEDBYTES],key[SEEDBYTES],tr[TRBYTES];
  polyvecl s1;polyveck s2,t0;unsigned value;
  while(scanf("%u",&value)==1) {
    if(value>255)return 2;sk[0]=(uint8_t)value;
    for(unsigned i=1;i<CRYPTO_SECRETKEYBYTES;i++) {
      if(scanf("%u",&value)!=1 || value>255)return 2;sk[i]=(uint8_t)value;
    }
    unpack_sk(rho,tr,key,&t0,&s1,&s2,sk);
    pack_sk(roundtrip,rho,tr,key,&t0,&s1,&s2);
    if(memcmp(sk,roundtrip,sizeof(sk)))return 3;
    for(unsigned i=0;i<SEEDBYTES;i++)printf("%02x",rho[i]);putchar(' ');
    for(unsigned i=0;i<SEEDBYTES;i++)printf("%02x",key[i]);putchar(' ');
    for(unsigned i=0;i<TRBYTES;i++)printf("%02x",tr[i]);
    for(unsigned section=0;section<3;section++) {
      unsigned count=section==0?L:K;
      for(unsigned j=0;j<count;j++)for(unsigned i=0;i<N;i++) {
        int32_t x=section==0?s1.vec[j].coeffs[i]:(section==1?s2.vec[j].coeffs[i]:t0.vec[j].coeffs[i]);
        printf(" %d",x<0?x+Q:x);
      }
    }
    putchar('\n');
  }
  return 0;
}
