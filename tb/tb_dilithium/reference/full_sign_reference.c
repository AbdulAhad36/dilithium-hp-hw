/* Test adapter for unchanged production signing/verification. Inputs are the
 * original expanded SK,matching PK,ctx,message and explicit signing randomness.
 * No RTL intermediate or locally supplied expected signature is accepted. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "params.h"
#include "sign.h"

void randombytes(uint8_t *out,size_t length) {
  (void)out;(void)length;
  abort(); /* Internal signing must use the explicit rnd input. */
}
static int read_bytes(uint8_t *out,size_t length) {
  unsigned value;
  for(size_t i=0;i<length;i++) {
    if(scanf("%u",&value)!=1 || value>255)return 1;
    out[i]=(uint8_t)value;
  }
  return 0;
}
int main(int argc,char **argv) {
  /* Official sigGen prompts contain SK but no PK. This explicit test-only
   * mode signs original inputs without the local-fixture verification step. */
  int sign_only=argc==2 && strcmp(argv[1],"--sign-only")==0;
  if(argc!=1 && !sign_only)return 7;
  unsigned context_length,message_length;
  uint8_t sk[CRYPTO_SECRETKEYBYTES],pk[CRYPTO_PUBLICKEYBYTES],rnd[RNDBYTES];
  uint8_t prefix[257],signature[CRYPTO_BYTES];
  while(scanf("%u %u",&context_length,&message_length)==2) {
    if(context_length>255 || message_length>65535 ||
       context_length+message_length+66>65535)return 2;
    uint8_t *message=malloc(message_length?message_length:1);
    if(!message)return 3;
    prefix[0]=0;prefix[1]=(uint8_t)context_length;
    if(read_bytes(rnd,sizeof(rnd)) || (!sign_only && read_bytes(pk,sizeof(pk))) ||
       read_bytes(sk,sizeof(sk)) || read_bytes(prefix+2,context_length) ||
       read_bytes(message,message_length)) {free(message);return 4;}
    size_t signature_length=0;
    if(crypto_sign_signature_internal(signature,&signature_length,message,
         message_length,prefix,context_length+2,rnd,sk) ||
       signature_length!=CRYPTO_BYTES ||
       (!sign_only && crypto_sign_verify_internal(signature,signature_length,message,
         message_length,prefix,context_length+2,pk))) {free(message);return 5;}
    for(size_t i=0;i<signature_length;i++)printf("%02x",signature[i]);
    putchar('\n');free(message);
  }
  return ferror(stdin)?6:0;
}
