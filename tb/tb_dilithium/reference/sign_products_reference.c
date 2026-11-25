/* Test-only adapter;production unpack/NTT/Montgomery/inverse unchanged. */
#include <stdint.h>
#include <stdio.h>
#include "params.h"
#include "packing.h"
#include "polyvec.h"
static int bytes(uint8_t *a,unsigned n){unsigned x;for(unsigned i=0;i<n;i++){if(scanf("%u",&x)!=1 || x>255)return 1;a[i]=(uint8_t)x;}return 0;}
static int polyin(poly *a){unsigned x;for(unsigned i=0;i<N;i++){if(scanf("%u",&x)!=1 || x>=Q)return 1;a->coeffs[i]=(int32_t)x;}return 0;}
static void printpoly(const poly *a){for(unsigned i=0;i<N;i++){int32_t x=a->coeffs[i]%Q;if(x<0)x+=Q;printf("%d ",x);}}
int main(void){
  unsigned first;uint8_t sk[CRYPTO_SECRETKEYBYTES],rho[32],key[32],tr[TRBYTES],seed[CTILDEBYTES];
  polyvecl s1,y;polyveck s2,t0,lo;poly c,cs1[L],cs2[K],ct0[K],z[L],r0[K];
  while(scanf("%u",&first)==1){
    if(first>255)return 2;sk[0]=(uint8_t)first;if(bytes(sk+1,CRYPTO_SECRETKEYBYTES-1) || bytes(seed,CTILDEBYTES))return 2;
    for(unsigned j=0;j<L;j++)if(polyin(&y.vec[j]))return 3;
    for(unsigned j=0;j<K;j++)if(polyin(&lo.vec[j]))return 3;
    unpack_sk(rho,tr,key,&t0,&s1,&s2,sk);poly_challenge(&c,seed);poly_ntt(&c);
    for(unsigned group=0;group<3;group++)for(unsigned j=0;j<(group==0?L:K);j++){
      poly a=group==0?s1.vec[j]:(group==1?s2.vec[j]:t0.vec[j]);poly *b=group==0?&cs1[j]:(group==1?&cs2[j]:&ct0[j]);
      poly_ntt(&a);poly_pointwise_montgomery(b,&c,&a);poly_invntt_tomont(b);poly_reduce(b);
    }
    for(unsigned j=0;j<L;j++)poly_add(&z[j],&y.vec[j],&cs1[j]);
    for(unsigned j=0;j<K;j++)poly_sub(&r0[j],&lo.vec[j],&cs2[j]);
    for(unsigned j=0;j<L;j++)printpoly(&cs1[j]);for(unsigned j=0;j<K;j++)printpoly(&cs2[j]);for(unsigned j=0;j<K;j++)printpoly(&ct0[j]);
    for(unsigned j=0;j<L;j++)printpoly(&z[j]);for(unsigned j=0;j<K;j++)printpoly(&r0[j]);putchar('\n');
  }return 0;
}
