/* Component test adapter. Production reference routines are unchanged.
 * RTL stores ordinary residues;C's Montgomery PWM/inverse factors cancel in w.
 */
#include <stdint.h>
#include <stdio.h>
#include "params.h"
#include "polyvec.h"
static int read_bytes(uint8_t *v,unsigned n) {
  unsigned x;for(unsigned i=0;i<n;i++){if(scanf("%u",&x)!=1 || x>255)return 1;v[i]=(uint8_t)x;}return 0;
}
static void print_poly(const poly *p) {
  for(unsigned i=0;i<N;i++){int32_t x=p->coeffs[i]%Q;if(x<0)x+=Q;printf("%d ",x);}
}
int main(void) {
  unsigned nonce;uint8_t rho[32],seed[64];polyvecl y,hat,mat[K];polyveck w,lo,hi;
  while(scanf("%u",&nonce)==1) {
    if(nonce+L>65536 || read_bytes(rho,32) || read_bytes(seed,64))return 2;
    for(unsigned j=0;j<L;j++)poly_uniform_gamma1(&y.vec[j],seed,(uint16_t)(nonce+j));
    hat=y;polyvecl_ntt(&hat);polyvec_matrix_expand(mat,rho);
    polyvec_matrix_pointwise_montgomery(&w,mat,&hat);polyveck_reduce(&w);
    polyveck_invntt_tomont(&w);polyveck_caddq(&w);polyveck_decompose(&hi,&lo,&w);
    for(unsigned j=0;j<L;j++)print_poly(&y.vec[j]);
    for(unsigned j=0;j<L;j++)print_poly(&hat.vec[j]);
    for(unsigned r=0;r<K;r++)for(unsigned j=0;j<L;j++)print_poly(&mat[r].vec[j]);
    for(unsigned r=0;r<K;r++)print_poly(&w.vec[r]);
    for(unsigned r=0;r<K;r++)print_poly(&lo.vec[r]);
    for(unsigned r=0;r<K;r++)print_poly(&hi.vec[r]);
    putchar('\n');
  }
  return 0;
}
