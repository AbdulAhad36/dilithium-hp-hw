/* Test adapter only. Production C norm/MakeHint arithmetic is unchanged. */
#include <stdint.h>
#include <stdio.h>
#include "params.h"
#include "poly.h"
static int readpoly(poly *a){unsigned v;for(unsigned i=0;i<N;i++){if(scanf("%u",&v)!=1 || v>=Q)return 1;a->coeffs[i]=(int32_t)v;}return 0;}
static void printpoly(const poly *a){for(unsigned i=0;i<N;i++){int32_t v=a->coeffs[i]%Q;if(v<0)v+=Q;printf("%d ",v);}}
int main(void){
  unsigned marker;poly z[L],r[K],t[K],w[K],sum[K],h[K];
  while(scanf("%u",&marker)==1){
    if(marker!=1)return 2;
    for(unsigned i=0;i<L;i++)if(readpoly(&z[i]))return 3;
    for(unsigned i=0;i<K;i++)if(readpoly(&r[i]))return 3;
    for(unsigned i=0;i<K;i++)if(readpoly(&t[i]))return 3;
    for(unsigned i=0;i<K;i++)if(readpoly(&w[i]))return 3;
    for(unsigned i=0;i<L;i++){poly_reduce(&z[i]);printf("%d ",poly_chknorm(&z[i],GAMMA1-BETA));}
    for(unsigned i=0;i<K;i++){poly_reduce(&r[i]);printf("%d ",poly_chknorm(&r[i],GAMMA2-BETA));}
    for(unsigned i=0;i<K;i++){poly_reduce(&t[i]);printf("%d ",poly_chknorm(&t[i],GAMMA2));}
    for(unsigned i=0;i<K;i++){poly_add(&sum[i],&r[i],&t[i]);printf("%u ",poly_make_hint(&h[i],&sum[i],&w[i]));}
    for(unsigned i=0;i<K;i++)printpoly(&sum[i]);for(unsigned i=0;i<K;i++)printpoly(&h[i]);putchar('\n');
  }return 0;
}
