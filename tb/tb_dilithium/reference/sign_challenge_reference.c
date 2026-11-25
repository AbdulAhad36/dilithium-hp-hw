/* Test adapter only;production pack/SHAKE/challenge routines are unchanged. */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "params.h"
#include "polyvec.h"
#include "fips202.h"
int main(void) {
  unsigned value;uint8_t message[64+K*POLYW1_PACKEDBYTES],digest[CTILDEBYTES];polyveck w1;poly c;
  while(scanf("%u",&value)==1) {
    if(value>255)return 2;message[0]=(uint8_t)value;
    for(unsigned i=1;i<64;i++){if(scanf("%u",&value)!=1 || value>255)return 2;message[i]=(uint8_t)value;}
    for(unsigned r=0;r<K;r++)for(unsigned i=0;i<N;i++){
      if(scanf("%u",&value)!=1 || value>(GAMMA2==(Q-1)/88?43:15))return 3;w1.vec[r].coeffs[i]=(int32_t)value;
    }
    polyveck_pack_w1(message+64,&w1);shake256(digest,CTILDEBYTES,message,sizeof(message));poly_challenge(&c,digest);
    for(unsigned i=64;i<sizeof(message);i++)printf("%02x",message[i]);putchar(' ');
    for(unsigned i=0;i<CTILDEBYTES;i++)printf("%02x",digest[i]);
    for(unsigned i=0;i<N;i++){int32_t x=c.coeffs[i];printf(" %d",x<0?x+Q:x);}putchar('\n');
  }
  return 0;
}
