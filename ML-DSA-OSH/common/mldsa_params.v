// ML-DSA FIPS204 PARAMETER SETS (in BITS, unless specified otherwise)

// MIT License

// Copyright (c) 2025 KU Leuven - COSIC

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

`define N 256
`define Q 8380417
`define Q_WIDTH 23
`define D 13

`define K_2 4
`define L_2 4
`define eta_2 2
`define eta_WIDTH_2 3
`define lambda_2 128
`define omega_2 80
`define gamma1_range_2 17
`define gamma1_WIDTH_2 (`gamma1_range_2 + 1)

`define K_3 6
`define L_3 5
`define eta_3 4
`define eta_WIDTH_3 4
`define lambda_3 192
`define omega_3 55
`define gamma1_range_3 19
`define gamma1_WIDTH_3 (`gamma1_range_3 + 1)

`define K_5 8
`define L_5 7
`define eta_5 2
`define eta_WIDTH_5 3
`define lambda_5 256
`define omega_5 75
`define gamma1_range_5 19
`define gamma1_WIDTH_5 (`gamma1_range_5 + 1)

///// KeyGen() parameters

// INPUT
`define SEED_BYTES 32
`define SEED_WIDTH `SEED_BYTES*8

// OUTPUT
`define SKPK_RHO_BYTES 32
`define SKPK_RHO_WIDTH `SKPK_RHO_BYTES*8

`define SK_K_BYTES 32
`define SK_K_WIDTH `SK_K_BYTES*8

`define SK_tr_BYTES 64
`define SK_tr_WIDTH `SK_tr_BYTES*8

`define eta_PACKED_BYTES_2 (`eta_WIDTH_2 * `N / 8) //3 * 256 / 8 = 96
`define eta_PACKED_BYTES_3 (`eta_WIDTH_3 * `N / 8) //4 * 256 / 8 = 128
`define eta_PACKED_BYTES_5 (`eta_WIDTH_5 * `N / 8) //3 * 256 / 8 = 96

`define SK_s1_BYTES_2 (`eta_PACKED_BYTES_2 * `L_2) //96 * 4 = 384
`define SK_s1_WIDTH_2 `SK_s1_BYTES_2*8
`define SK_s1_BYTES_3 (`eta_PACKED_BYTES_3 * `L_3) //128 * 5 = 640
`define SK_s1_WIDTH_3 `SK_s1_BYTES_3*8
`define SK_s1_BYTES_5 (`eta_PACKED_BYTES_5 * `L_5) //96 * 7 = 672
`define SK_s1_WIDTH_5 `SK_s1_BYTES_5*8

`define SK_s2_BYTES_2 (`eta_PACKED_BYTES_2 * `K_2) //96 * 4 = 384
`define SK_s2_WIDTH_2 `SK_s2_BYTES_2*8
`define SK_s2_BYTES_3 (`eta_PACKED_BYTES_3 * `K_3) //128 * 6 = 768
`define SK_s2_WIDTH_3 `SK_s2_BYTES_3*8
`define SK_s2_BYTES_5 (`eta_PACKED_BYTES_5 * `K_5) //96 * 8 = 768
`define SK_s2_WIDTH_5 `SK_s2_BYTES_5*8

`define SK_t0_PACKED_BYTES (`N * `D / 8) // (256 * 13) / 8 = 416

`define SK_t0_BYTES_2 (`SK_t0_PACKED_BYTES * `K_2) //416 * 4 = 1664
`define SK_t0_WIDTH_2 `SK_t0_BYTES_2*8
`define SK_t0_BYTES_3 (`SK_t0_PACKED_BYTES * `K_3) //416 * 6 = 2496
`define SK_t0_WIDTH_3 `SK_t0_BYTES_3*8
`define SK_t0_BYTES_5 (`SK_t0_PACKED_BYTES * `K_5) //416 * 8 = 3328
`define SK_t0_WIDTH_5 `SK_t0_BYTES_5*8

`define PK_t1_PACKED_BYTES (`N * (`Q_WIDTH - `D) / 8) // (256 * (23 - 13)) / 8 = 320

`define PK_t1_BYTES_2 (`PK_t1_PACKED_BYTES * `K_2) //320 * 4 = 1280
`define PK_t1_WIDTH_2 `PK_t1_BYTES_2*8
`define PK_t1_BYTES_3 (`PK_t1_PACKED_BYTES * `K_3) //320 * 6 = 1920
`define PK_t1_WIDTH_3 `PK_t1_BYTES_3*8
`define PK_t1_BYTES_5 (`PK_t1_PACKED_BYTES * `K_5) //320 * 8 = 2560
`define PK_t1_WIDTH_5 `PK_t1_BYTES_5*8


`define PK_BYTES_2 (`SKPK_RHO_BYTES + `PK_t1_BYTES_2) //32 + 1280 = 1312
`define PK_WIDTH_2 `PK_BYTES_2*8
`define SK_BYTES_2 (`SKPK_RHO_BYTES + `SK_K_BYTES + `SK_tr_BYTES + `SK_s1_BYTES_2 + `SK_s2_BYTES_2 + `SK_t0_BYTES_2) //32 + 32 + 64 + 384 + 384 + 1664 = 2560
`define SK_WIDTH_2 `SK_BYTES_2*8

`define PK_BYTES_3 (`SKPK_RHO_BYTES + `PK_t1_BYTES_3) //32 + 1920 = 1952
`define PK_WIDTH_3 `PK_BYTES_3*8
`define SK_BYTES_3 (`SKPK_RHO_BYTES + `SK_K_BYTES + `SK_tr_BYTES + `SK_s1_BYTES_3 + `SK_s2_BYTES_3 + `SK_t0_BYTES_3) //32 + 32 + 64 + 640 + 768 + 2496 = 4032
`define SK_WIDTH_3 `SK_BYTES_3*8

`define PK_BYTES_5 (`SKPK_RHO_BYTES + `PK_t1_BYTES_5) //32 + 2560 = 2592
`define PK_WIDTH_5 `PK_BYTES_5*8
`define SK_BYTES_5 (`SKPK_RHO_BYTES + `SK_K_BYTES + `SK_tr_BYTES + `SK_s1_BYTES_5 + `SK_s2_BYTES_5 + `SK_t0_BYTES_5) // 32 + 32 + 64 + 672 + 768 + 3328 = 4896
`define SK_WIDTH_5 `SK_BYTES_5*8

///// Sign() parameters

`define CTX_BYTES 255
`define CTX_WIDTH `CTX_BYTES*8

`define RND_BYTES 32
`define RND_WIDTH `RND_BYTES*8

`define CTILDE_BYTES_2 (`lambda_2/4) //128/4 = 32
`define CTILDE_WIDTH_2 `CTILDE_BYTES_2*8
`define CTILDE_BYTES_3 (`lambda_3/4) //192/4 = 48
`define CTILDE_WIDTH_3 `CTILDE_BYTES_3*8
`define CTILDE_BYTES_5 (`lambda_5/4) //256/4 = 64
`define CTILDE_WIDTH_5 `CTILDE_BYTES_5*8

`define h_BYTES_2 (`K_2 + `omega_2) //4 + 80 = 84
`define h_BYTES_3 (`K_3 + `omega_3) //6 + 55 = 61
`define h_BYTES_5 (`K_5 + `omega_5) //8 + 75 = 83

`define z_PACKED_BYTES_2 (`gamma1_WIDTH_2 * `N / 8) //18* 256 / 8 = 576
`define z_BYTES_2 (`L_2 * `z_PACKED_BYTES_2) //4*576 = 2304
`define z_WIDTH_2 `z_BYTES_2*8
`define z_PACKED_BYTES_3 (`gamma1_WIDTH_3 * `N / 8) //20* 256 / 8 = 640
`define z_BYTES_3 (`L_3 * `z_PACKED_BYTES_3) //5*640 = 3200
`define z_WIDTH_3 `z_BYTES_3*8
`define z_PACKED_BYTES_5 (`gamma1_WIDTH_5 * `N / 8) //20* 256 / 8 = 640
`define z_BYTES_5 (`L_5 * `z_PACKED_BYTES_5) //7*640 = 4480
`define z_WIDTH_5 `z_BYTES_5*8

`define SIG_BYTES_2 (`CTILDE_BYTES_2 + `z_BYTES_2 + `h_BYTES_2) // 32 + 2304 + 84 = 2420
`define SIG_WIDTH_2 `SIG_BYTES_2*8

`define SIG_BYTES_3 (`CTILDE_BYTES_3 + `z_BYTES_3 + `h_BYTES_3) // 48 + 3200 + 61 = 3309
`define SIG_WIDTH_3 `SIG_BYTES_3*8

`define SIG_BYTES_5 (`CTILDE_BYTES_5 + `z_BYTES_5 + `h_BYTES_5) // 64 + 4480 + 83 = 4627
`define SIG_WIDTH_5 `SIG_BYTES_5*8
