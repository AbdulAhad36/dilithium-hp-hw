#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "params.h"
#include "sign.h"

static uint8_t xi[SEEDBYTES];
static unsigned calls;
/* Test-only deterministic randomness injection;production reference is unchanged. */
void randombytes(uint8_t *out,size_t length) {
  if(length!=SEEDBYTES || calls++)exit(4);
  memcpy(out,xi,SEEDBYTES);
}
int main(void) {
  unsigned value;
  uint8_t pk[CRYPTO_PUBLICKEYBYTES],sk[CRYPTO_SECRETKEYBYTES];
  while(scanf("%u",&value)==1) {
    if(value>255)return 2;
    xi[0]=(uint8_t)value;
    for(unsigned i=1;i<SEEDBYTES;i++) {
      if(scanf("%u",&value)!=1 || value>255)return 2;
      xi[i]=(uint8_t)value;
    }
    calls=0;
    if(crypto_sign_keypair(pk,sk)!=0 || calls!=1)return 3;
    for(unsigned i=0;i<CRYPTO_PUBLICKEYBYTES;i++)printf("%02x",pk[i]);
    putchar(' ');
    for(unsigned i=0;i<CRYPTO_SECRETKEYBYTES;i++)printf("%02x",sk[i]);
    putchar('\n');
  }
  return 0;
}
