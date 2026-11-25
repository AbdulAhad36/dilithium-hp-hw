/* Test-only attempt schedule using unchanged production arithmetic/SHAKE. */
#include <stdint.h>
#include <stdio.h>
#include "params.h"
#include "packing.h"
#include "polyvec.h"
#include "fips202.h"
#ifdef ENCODE_SIGNATURE
#include <stdlib.h>
#include <string.h>
#include "sign.h"
/* Explicit-rnd internal signing must never ask the platform for entropy. */
void randombytes(uint8_t *out,size_t n){(void)out;(void)n;abort();}
#endif
static int bytes(uint8_t *a,unsigned n){unsigned v;for(unsigned i=0;i<n;i++){if(scanf("%u",&v)!=1 || v>255)return 1;a[i]=(uint8_t)v;}return 0;}
static void hex(const uint8_t *a,unsigned n){for(unsigned i=0;i<n;i++)printf("%02x",a[i]);}
static void printpoly(const poly *a){for(unsigned i=0;i<N;i++){int32_t v=a->coeffs[i]%Q;if(v<0)v+=Q;printf("%d ",v);}}
int main(void){
  unsigned nonce;uint8_t sk[CRYPTO_SECRETKEYBYTES],body[176],rnd[32],rho[32],key[32],tr[TRBYTES],mu[64],seed[64],digest[CTILDEBYTES],packed[K*POLYW1_PACKEDBYTES];
  polyvecl mat[K],s1,y,z;polyveck s2,t0,w1,w0,h;poly cp;keccak_state st;
  while(scanf("%u",&nonce)==1){
#ifdef ENCODE_SIGNATURE
    unsigned initial_nonce=nonce;
#endif
    if(bytes(sk,sizeof(sk)) || bytes(body,176) || bytes(rnd,32))return 2;
    unpack_sk(rho,tr,key,&t0,&s1,&s2,sk);
    shake256_init(&st);shake256_absorb(&st,tr,TRBYTES);uint8_t domain[2]={0,7};shake256_absorb(&st,domain,2);shake256_absorb(&st,body,176);shake256_finalize(&st);shake256_squeeze(mu,64,&st);
    shake256_init(&st);shake256_absorb(&st,key,32);shake256_absorb(&st,rnd,32);shake256_absorb(&st,mu,64);shake256_finalize(&st);shake256_squeeze(seed,64,&st);
    printf("H ");hex(mu,64);putchar(' ');hex(seed,64);putchar('\n');
    polyvec_matrix_expand(mat,rho);polyvecl_ntt(&s1);polyveck_ntt(&s2);polyveck_ntt(&t0);
    while(nonce+L<=65536){
      unsigned base=nonce,reason=0,weight=0;nonce+=L;
      for(unsigned j=0;j<L;j++)poly_uniform_gamma1(&y.vec[j],seed,(uint16_t)(base+j));
      z=y;polyvecl_ntt(&z);polyvec_matrix_pointwise_montgomery(&w1,mat,&z);polyveck_reduce(&w1);polyveck_invntt_tomont(&w1);
      polyveck_caddq(&w1);polyveck_decompose(&w1,&w0,&w1);polyveck_pack_w1(packed,&w1);
      shake256_init(&st);shake256_absorb(&st,mu,64);shake256_absorb(&st,packed,sizeof(packed));shake256_finalize(&st);shake256_squeeze(digest,CTILDEBYTES,&st);
      poly_challenge(&cp,digest);poly_ntt(&cp);
      polyvecl_pointwise_poly_montgomery(&z,&cp,&s1);polyvecl_invntt_tomont(&z);polyvecl_add(&z,&z,&y);polyvecl_reduce(&z);
      if(polyvecl_chknorm(&z,GAMMA1-BETA))reason=1;
      if(!reason){polyveck_pointwise_poly_montgomery(&h,&cp,&s2);polyveck_invntt_tomont(&h);polyveck_sub(&w0,&w0,&h);polyveck_reduce(&w0);if(polyveck_chknorm(&w0,GAMMA2-BETA))reason=2;}
      if(!reason){polyveck_pointwise_poly_montgomery(&h,&cp,&t0);polyveck_invntt_tomont(&h);polyveck_reduce(&h);if(polyveck_chknorm(&h,GAMMA2))reason=3;}
      if(!reason){polyveck_add(&w0,&w0,&h);for(unsigned j=0;j<K;j++){weight+=poly_make_hint(&h.vec[j],&w0.vec[j],&w1.vec[j]);if(weight>OMEGA){reason=4;break;}}}
      printf("A %u %u %u\n",base,reason,weight);
      if(!reason){printf("S %u ",nonce);hex(digest,CTILDEBYTES);putchar(' ');for(unsigned j=0;j<L;j++)printpoly(&z.vec[j]);for(unsigned j=0;j<K;j++)printpoly(&h.vec[j]);putchar('\n');
#ifdef ENCODE_SIGNATURE
        uint8_t sig[CRYPTO_BYTES];pack_sig(sig,digest,&z,&h);
        if(initial_nonce==0){
          uint8_t full[CRYPTO_BYTES],pre[9]={0,7};size_t length=0;memcpy(pre+2,body,7);
          if(crypto_sign_signature_internal(full,&length,body+7,169,pre,9,rnd,sk) || length!=CRYPTO_BYTES || memcmp(full,sig,length))return 4;
        }
        printf("P ");hex(sig,sizeof(sig));putchar('\n');
#endif
        break;}
    }
    printf("E %u\n",nonce);
  }return 0;
}
