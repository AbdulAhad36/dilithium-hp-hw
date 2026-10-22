/* Standalone oracle adapter. Uses the unchanged repository power2round()
 * and ordinary modular arithmetic;no DUT code or generated SV is included. */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "rounding.h"

int main(int argc,char **argv) {
  if(argc==2 && strcmp(argv[1],"--selftest")==0) {
    uint32_t checksum=0;
    for(int32_t a=0;a<Q;a++) {
      int32_t low,high=power2round(&low,a);
      /* Reconstruction and the strict half-open interval uniquely define
       * the required pair,including the +4096 tie. */
      if(high<0 || high>1023 || low<=-4096 || low>4096 ||
         high*8192+low!=a || 4096-low<0 || 4096-low>8191)return 1;
      checksum=checksum*33u+(uint32_t)high+(uint32_t)low;
    }
    printf("C_PROCESS_REFERENCE_PASS:%d canonical Power2Round inputs;checksum=%08x\n",Q,checksum);
    return 0;
  }
  if(argc!=1)return 2;
  unsigned int op,a,b;
  while(scanf("%u %u %u",&op,&a,&b)==3) {
    int32_t low=0,high=0;unsigned int residue=0,packed=0;
    unsigned int error=op>2 || a>=Q || (op<2 && b>=Q);
    if(!error) {
      if(op==0)residue=(a+b)%Q;
      else if(op==1)residue=(a+Q-b)%Q;
      else {high=power2round(&low,(int32_t)a);packed=(unsigned int)(4096-low);}
    }
    printf("%u %u %d %d %u\n",error,residue,high,low,packed);
  }
  return ferror(stdin)?2:0;
}
