/* File adapter for the existing reference implementation. No RNG/crypto replacement.
 * The only randombytes caller allowed here is seeded KeyGen (exactly 32 bytes).
 * Python owns file formats, case selection, provenance and comparisons. */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include "params.h"
#include "sign.h"
#include "randombytes.h"

static FILE *trace_file;
static unsigned attempt;
static uint8_t keygen_seed[SEEDBYTES];
static unsigned seed_calls;

static void trace_bytes(const char *name, const uint8_t *p, size_t n) {
  if(!trace_file) return;
  fprintf(trace_file, "%s = ", name);
  for(size_t i=0;i<n;i++) fprintf(trace_file,"%02x",p[i]);
  fputc('\n',trace_file);
}
static void trace_poly(const char *name, const poly *p) {
  if(!trace_file) return;
  fprintf(trace_file,"%s =\n",name);
  for(size_t i=0;i<N;i++) {
    if(i%16==0) fprintf(trace_file,"  coeff[%03u..%03u]:",(unsigned)i,(unsigned)(i+15));
    fprintf(trace_file," %ld",(long)p->coeffs[i]);
    if(i%16==15) fputc('\n',trace_file);
  }
}
static void trace_polys(const char *name, const poly *p, size_t n) {
  if(!trace_file) return;
  for(size_t j=0;j<n;j++) {
    char label[80];
    snprintf(label,sizeof(label),"%s[%u]",name,(unsigned)j);
    trace_poly(label,&p[j]);
  }
}
static void trace_matrix(const polyvecl mat[K]) {
  if(!trace_file) return;
  fprintf(trace_file,"A_hat: %u rows x %u columns; 256 coefficients/poly; reference NTT order\n",K,L);
  for(unsigned i=0;i<K;i++) for(unsigned j=0;j<L;j++) {
    char label[40];
    snprintf(label,sizeof(label),"A_hat[%u][%u]",i,j);
    trace_poly(label,&mat[i].vec[j]);
  }
}
static void trace_attempt(void) {
  ++attempt;
  if(trace_file) fprintf(trace_file,"\nSIGN ATTEMPT %u (nonce %u)\n",attempt,attempt-1);
}
static void trace_reject(const char *reason) {
  if(trace_file) fprintf(trace_file,"REJECT: %s\n",reason);
}
void randombytes(uint8_t *out, size_t n) {
  if(n!=SEEDBYTES || seed_calls++) {
    fputs("Unexpected reference RNG call\n",stderr); exit(3);
  }
  memcpy(out,keygen_seed,n);
}
#ifdef GOLDEN_TRACE
#include "sign_trace.inc"
#else
#include "sign.c"
#endif

/* One hex line per field. '-' represents empty. Limit each field to 16 MiB. */
static uint8_t *read_hex(size_t *length) {
  size_t cap=128,n=0; int c;
  char *s=malloc(cap);
  if(!s) exit(3);
  while((c=getchar())!=EOF && c!='\n') {
    if(c=='\r') continue;
    if(n>=33554432) { fputs("Input field too large\n",stderr); exit(3); }
    if(n+1>=cap) { cap*=2; char *next=realloc(s,cap); if(!next) exit(3); s=next; }
    s[n++]=(char)c;
  }
  if(c==EOF && n==0) { fputs("Missing input field\n",stderr); exit(3); }
  if(n==1 && s[0]=='-') n=0;
  if(n%2) { fputs("Odd hex length\n",stderr); exit(3); }
  *length=n/2;
  uint8_t *p=malloc(*length ? *length : 1);
  if(!p) exit(3);
  for(size_t i=0;i<*length;i++) {
    unsigned v=0;
    for(unsigned j=0;j<2;j++) {
      char h=s[2*i+j];
      if(h>='0' && h<='9') v=v*16+(unsigned)(h-'0');
      else if(h>='a' && h<='f') v=v*16+(unsigned)(h-'a'+10);
      else if(h>='A' && h<='F') v=v*16+(unsigned)(h-'A'+10);
      else { fputs("Invalid hex\n",stderr); exit(3); }
    }
    p[i]=(uint8_t)v;
  }
  free(s); return p;
}
static void output(const char *name,const uint8_t *p,size_t n) {
  printf("%s = ",name);
  for(size_t i=0;i<n;i++) printf("%02x",p[i]);
  putchar('\n');
}
int main(int argc,char **argv) {
  if(argc!=3) return 2;
  size_t len[7]; uint8_t *in[7];
  for(unsigned i=0;i<7;i++) in[i]=read_hex(&len[i]);
  /* fields: seed, rnd, sk, pk, signature, message, prefix */
  if(strcmp(argv[2],"-")) {
    trace_file=fopen(argv[2],"wb"); if(!trace_file) return 2;
    fprintf(trace_file,"Level %d; K=%u L=%u N=%u Q=%u; operation=%s\n",DILITHIUM_MODE,K,L,N,Q,argv[1]);
    fputs("Signed decimal reference coefficients; stages/domains are labeled.\n",trace_file);
  }
  uint8_t pk[CRYPTO_PUBLICKEYBYTES],sk[CRYPTO_SECRETKEYBYTES],sig[CRYPTO_BYTES];
  int rc=0; size_t siglen=0;
  if(!strcmp(argv[1],"keygen")) {
    if(len[0]!=SEEDBYTES) return 2;
    memcpy(keygen_seed,in[0],SEEDBYTES);
    rc=crypto_sign_keypair(pk,sk);
    if(rc || seed_calls!=1) return 3;
    output("pk",pk,sizeof(pk)); output("sk",sk,sizeof(sk));
  } else if(!strcmp(argv[1],"sign")) {
    if(len[1]!=RNDBYTES || len[2]!=CRYPTO_SECRETKEYBYTES || len[6]>257) return 2;
    rc=crypto_sign_signature_internal(sig,&siglen,in[5],len[5],in[6],len[6],in[1],in[2]);
    if(rc || siglen!=CRYPTO_BYTES) return 3;
    output("signature",sig,siglen);
  } else if(!strcmp(argv[1],"verify")) {
    if(len[3]!=CRYPTO_PUBLICKEYBYTES || len[6]>257) return 2;
    rc=crypto_sign_verify_internal(in[4],len[4],in[5],len[5],in[6],len[6],in[3]);
    printf("valid = %s\n",rc==0 ? "true" : "false");
  } else return 2;
  for(unsigned i=0;i<7;i++) free(in[i]);
  if(trace_file && fclose(trace_file)) return 3;
  return ferror(stdout) ? 3 : 0;
}
