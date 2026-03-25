# ML-DSA-OSH
This repository contains the verilog/vhdl sources of an efficient HW implementation of ML-DSA ([FIPS 204](https://doi.org/10.6028/NIST.FIPS.204)). The current design is largely based on the design by [Beckwith et al.](https://eprint.iacr.org/2021/1451), and their [open-source implementation](https://github.com/GMUCERG/Dilithium) of CRYSTALS-Dilithium v3.1.
The design supports all three NIST security levels (II, III and V) and operations (KeyGen, SigGen, SigVer), at runtime: one can perform operations of any configuration on the same hardware instantiation.

## :file_folder: Contents

* [src](ref_combined/src/): verilog/vhdl (design) source files.
* [common](common): definition of ML-DSA parameter sets and twiddle factors.
* [testbench](ref_combined/src_tb/): testbenches for all modes of operation.
* [NIST KAT's](KAT): testvectors for ML-DSA-44, ML-DSA-67 and ML-DSA-87 (KeyGen, SigGen, SigVer).

## :book: Bibliography

If you use or build upon the code in this repository, please cite our paper using our [citation key](CITATION).

## Licensing

See our [license](LICENSE) and further details of original sources in the accompanying [notice](NOTICE).

