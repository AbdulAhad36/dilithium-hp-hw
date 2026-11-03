/* Test-only adapter: unchanged production PK/signature unpack,norm and Verify. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "params.h"
#include "packing.h"
#include "polyvec.h"
#include "sign.h"
#include "fips202.h"
#include "rounding.h"
void randombytes(uint8_t *out,size_t n) {(void)out;(void)n;abort();}
static int read_bytes(uint8_t *out,unsigned n) {
  unsigned x;for(unsigned i=0;i<n;i++){if(scanf("%u",&x)!=1 || x>255)return 1;out[i]=(uint8_t)x;}return 0;
}
int main(void) {
  unsigned op,n,pklen,siglen,ctxlen,mlen;
  uint8_t buf[8192],pk[CRYPTO_PUBLICKEYBYTES],sig[CRYPTO_BYTES],rho[32],c[CTILDEBYTES],ctx[255];
  polyveck t1,h;polyvecl z;
  while(scanf("%u",&op)==1) {
    if(op==6) {
      unsigned a,hint;if(scanf("%u %u",&a,&hint)!=2 || a>=Q || hint>1)return 12;
      printf("H %d\n",use_hint((int32_t)a,hint));continue;
    }
    if(op==4 || op==5) {
      uint8_t tr[64],mu[64],prefix[2];poly challenge;keccak_state state;
      if(scanf("%u %u %u %u",&pklen,&siglen,&ctxlen,&mlen)!=4 || pklen!=sizeof(pk) || siglen!=sizeof(sig) || ctxlen>255 || mlen>65535)return 9;
      uint8_t *message=malloc(mlen?mlen:1);if(!message)return 10;
      if(read_bytes(pk,pklen)||read_bytes(sig,siglen)||read_bytes(ctx,ctxlen)||read_bytes(message,mlen)){free(message);return 11;}
      unpack_pk(rho,&t1,pk);
      if(unpack_sig(c,&z,&h,sig)||polyvecl_chknorm(&z,GAMMA1-BETA)){free(message);puts("D 2");continue;}
      shake256(tr,sizeof(tr),pk,pklen);prefix[0]=0;prefix[1]=(uint8_t)ctxlen;
      shake256_init(&state);shake256_absorb(&state,tr,sizeof(tr));shake256_absorb(&state,prefix,sizeof(prefix));
      shake256_absorb(&state,ctx,ctxlen);shake256_absorb(&state,message,mlen);shake256_finalize(&state);shake256_squeeze(mu,sizeof(mu),&state);free(message);
      poly_challenge(&challenge,c);
      if(op==5) {
        polyvecl mat[K];polyveck w,high,product;
        polyvec_matrix_expand(mat,rho);polyvecl_ntt(&z);poly_ntt(&challenge);polyveck_shiftl(&t1);polyveck_ntt(&t1);
        polyvec_matrix_pointwise_montgomery(&w,mat,&z);polyveck_pointwise_poly_montgomery(&product,&challenge,&t1);
        polyveck_sub(&w,&w,&product);polyveck_reduce(&w);polyveck_invntt_tomont(&w);polyveck_caddq(&w);polyveck_use_hint(&high,&w,&h);
        polyveck_pack_w1(buf,&high);
        shake256_init(&state);shake256_absorb(&state,mu,sizeof(mu));shake256_absorb(&state,buf,K*POLYW1_PACKEDBYTES);shake256_finalize(&state);
        uint8_t digest[CTILDEBYTES];shake256_squeeze(digest,sizeof(digest),&state);unsigned match=1;
        for(unsigned i=0;i<CTILDEBYTES;i++)match&=digest[i]==c[i];
        printf("E ");for(unsigned i=0;i<sizeof(mu);i++)printf("%02x",mu[i]);printf(" ");for(unsigned i=0;i<sizeof(digest);i++)printf("%02x",digest[i]);printf(" %u",match);
        for(unsigned r=0;r<K;r++)for(unsigned j=0;j<L;j++)for(unsigned i=0;i<N;i++){int32_t x=mat[r].vec[j].coeffs[i]%Q;if(x<0)x+=Q;printf(" %d",x);}
        for(unsigned r=0;r<K;r++)for(unsigned i=0;i<N;i++)printf(" %d",w.vec[r].coeffs[i]);
        for(unsigned r=0;r<K;r++)for(unsigned i=0;i<N;i++)printf(" %d",high.vec[r].coeffs[i]);
        printf(" ");for(unsigned i=0;i<K*POLYW1_PACKEDBYTES;i++)printf("%02x",buf[i]);putchar('\n');continue;
      }
      printf("U ");for(unsigned i=0;i<sizeof(mu);i++)printf("%02x",mu[i]);
      for(unsigned i=0;i<N;i++){int32_t x=challenge.coeffs[i]%Q;if(x<0)x+=Q;printf(" %d",x);}
      for(unsigned section=0;section<3;section++)for(unsigned j=0;j<(section==0?K:section==1?L:1);j++){
        poly *a=section==0?&t1.vec[j]:section==1?&z.vec[j]:&challenge;
        if(section==0)poly_shiftl(a);poly_ntt(a);
        for(unsigned i=0;i<N;i++){int32_t x=a->coeffs[i]%Q;if(x<0)x+=Q;printf(" %d",x);}
      }
      putchar('\n');continue;
    }
    if(op==3) {
      uint8_t tr[64];
      if(scanf("%u",&n)!=1 || n!=CRYPTO_PUBLICKEYBYTES || read_bytes(buf,n))return 8;
      shake256(tr,sizeof(tr),buf,n);printf("T ");for(unsigned i=0;i<sizeof(tr);i++)printf("%02x",tr[i]);putchar('\n');continue;
    }
    if(op==2) {
      if(scanf("%u %u %u %u",&pklen,&siglen,&ctxlen,&mlen)!=4 || pklen!=sizeof(pk) || siglen!=sizeof(sig) || ctxlen>255 || mlen>65535)return 2;
      uint8_t *message=malloc(mlen?mlen:1);if(!message)return 3;
      if(read_bytes(pk,pklen)||read_bytes(sig,siglen)||read_bytes(ctx,ctxlen)||read_bytes(message,mlen)){free(message);return 4;}
      printf("V %d\n",crypto_sign_verify(sig,siglen,message,mlen,ctx,ctxlen,pk)==0);free(message);continue;
    }
    if(op>1 || scanf("%u",&n)!=1 || n>sizeof(buf) || read_bytes(buf,n))return 5;
    if(n!=(op?CRYPTO_BYTES:CRYPTO_PUBLICKEYBYTES)){puts("D 1");continue;}
    if(op==0) {
      unpack_pk(rho,&t1,buf);printf("P ");for(unsigned i=0;i<32;i++)printf("%02x",rho[i]);
      for(unsigned j=0;j<K;j++)for(unsigned i=0;i<N;i++)printf(" %d",t1.vec[j].coeffs[i]<<D);
    } else {
      int malformed=unpack_sig(c,&z,&h,buf),norm=polyvecl_chknorm(&z,GAMMA1-BETA);
      printf("S %d %d ",malformed,norm);for(unsigned i=0;i<CTILDEBYTES;i++)printf("%02x",c[i]);
      for(unsigned j=0;j<L;j++)for(unsigned i=0;i<N;i++){int32_t x=z.vec[j].coeffs[i];printf(" %d",x<0?x+Q:x);}
      if(!malformed)for(unsigned j=0;j<K;j++)for(unsigned i=0;i<N;i++)printf(" %d",h.vec[j].coeffs[i]);
    }
    putchar('\n');
  }
  return ferror(stdin)?6:0;
}
