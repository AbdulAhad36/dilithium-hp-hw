/* Test adapter:independent component assembly +unchanged C SHAKE/w1 packing/
 * mask sampling. This does not call or replace a complete signing function. */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "params.h"
#include "poly.h"
#include "polyvec.h"
#include "fips202.h"
static int bytes(uint8_t *out,unsigned n) {
  unsigned x;for(unsigned i=0;i<n;i++){if(scanf("%u",&x)!=1 || x>255)return 1;out[i]=(uint8_t)x;}return 0;
}
int main(void) {
  unsigned op,ctx,mlen,nonce,n,value;
  uint8_t tr[64],key[32],rnd[32],mu[64],seed[64],body[65536],message[66000],digest[64];
  polyveck w;poly mask;
  while(scanf("%u %u %u %u %u",&op,&ctx,&mlen,&nonce,&n)==5) {
    if(n>65535 || bytes(tr,64) || bytes(key,32) || bytes(rnd,32) || bytes(mu,64) || bytes(seed,64) || bytes(body,n))return 2;
    unsigned length=0,outlen=64;
    if(op==0){
      if(ctx>255 || n!=ctx+mlen)return 3;
      memcpy(message,tr,64);message[64]=0;message[65]=(uint8_t)ctx;
      memcpy(message+66,body,n);length=66+n;
    } else if(op==1){
      if(n)return 3;memcpy(message,key,32);memcpy(message+32,rnd,32);memcpy(message+64,mu,64);length=128;
    } else if(op==2){
      if(n!=K*POLYW1_PACKEDBYTES)return 3;
      for(unsigned j=0;j<K;j++)for(unsigned i=0;i<N;i++){
        if(scanf("%u",&value)!=1 || value>(GAMMA2==(Q-1)/88?43:15))return 4;
        w.vec[j].coeffs[i]=(int32_t)value;
      }
      polyveck_pack_w1(message+64,&w);
      if(memcmp(message+64,body,n))return 5;
      memcpy(message,mu,64);length=64+n;outlen=CTILDEBYTES;
    } else if(op==3){
      if(n || nonce>65535)return 3;
      memcpy(message,seed,64);message[64]=(uint8_t)nonce;message[65]=(uint8_t)(nonce>>8);length=66;
      poly_uniform_gamma1(&mask,seed,(uint16_t)nonce);
    } else return 3;
    for(unsigned i=0;i<length;i++)printf("%02x",message[i]);putchar(' ');
    shake256(digest,outlen,message,length);
    for(unsigned i=0;i<outlen;i++)printf("%02x",digest[i]);
    if(op==3)for(unsigned i=0;i<N;i++){int32_t x=mask.coeffs[i];printf(" %d",x<0?x+Q:x);}
    putchar('\n');
  }
  return 0;
}
