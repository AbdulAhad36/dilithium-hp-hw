/* Independent adapter to unchanged C decompose/make_hint/poly_chknorm. */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "params.h"
#include "rounding.h"
#include "poly.h"
int main(int argc,char **argv) {
  if(argc==2 && !strcmp(argv[1],"--selftest")) {
    uint32_t sum=0;
    for(int32_t a=0;a<Q;a++) {
      int32_t low,high=decompose(&low,a),alpha=2*GAMMA2;
      int32_t expected=(a+GAMMA2-1)/alpha;
      int32_t remainder=a-expected*alpha;
      if(expected==(Q-1)/alpha){expected=0;remainder=a-Q;}
      if(high!=expected || low!=remainder)return 3;
      sum=sum*33u+(uint32_t)high+(uint32_t)low;
    }
    printf("C_DECOMPOSE_EXHAUSTIVE_PASS:%d coefficients,level%d,checksum=%08x\n",Q,DILITHIUM_MODE,sum);return 0;
  }
  unsigned op,kind,a,h;
  while(scanf("%u %u %u %u",&op,&kind,&a,&h)==4) {
    int32_t low=0,high=0,center=(int32_t)a;unsigned hint=0,reject=0;
    unsigned error=op>2 || a>=Q || (op==1 && kind>2) || (op==2 && h>(Q-1)/(2*GAMMA2)-1);
    if(!error) {
      if(center>(Q-1)/2)center-=Q;
      if(op==0)high=decompose(&low,(int32_t)a);
      if(op==1){poly p={{0}};p.coeffs[0]=center;reject=poly_chknorm(&p,kind==0?GAMMA1-BETA:(kind==1?GAMMA2-BETA:GAMMA2));}
      if(op==2)hint=make_hint(center,(int32_t)h);
    }
    printf("%u %d %d %u %u\n",error,high,low,hint,reject);
  }
  return ferror(stdin)?2:0;
}
