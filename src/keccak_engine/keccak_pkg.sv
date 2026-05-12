package keccak_pkg;
    // Misc. Bit Sizes
    parameter int BYTE_SIZE = 8;

    // State Array Dimension Bit Sizes
    parameter int LANE_SIZE = 64;
    parameter int ROW_SIZE  = 5;
    parameter int COL_SIZE  = 5;

    // Iota Step
    parameter int ROUND_INDEX_SIZE = 5;
    parameter int MAX_ROUNDS = 24;
    parameter int L_SIZE = 7;

    // Keccak Structure
    parameter int DWIDTH = 64; // Input data is 8 bytes (MAIN WHCIH DUT SUPPORTS)
    // parameter int DWIDTH = 256; // Input data is 32 bytes

    parameter int DATA_BYTE_NUM = DWIDTH/8;
    parameter int KEEP_WIDTH = DWIDTH/8; // 1 bit for every data byte
    parameter int X_WIDTH = $clog2(ROW_SIZE);
    parameter int Y_WIDTH = $clog2(COL_SIZE);

    // Different Keccak Modes (SHAKE-only for Dilithium)
    // - SHAKE128: rate 1344 bits (168 bytes) - used by ExpandA
    // - SHAKE256: rate 1088 bits (136 bytes) - used by ExpandS, ExpandMask, H
    // SHA3-256/512 support was removed (Dilithium does not need fixed-length SHA3).
    typedef enum {
        SHAKE128,
        SHAKE256
    } keccak_mode;
    parameter int MODE_NUM = 2;
    // Keep at 2 bits for legacy port widths; only LSB is meaningful.
    parameter int MODE_SEL_WIDTH = 2;

    // Setup Parameters
    parameter int CAPACITY_WIDTH = 11;
    parameter int RATE_WIDTH = 11;
    parameter int SUFFIX_WIDTH = BYTE_SIZE;
    parameter int SUFFIX_LEN_WIDTH = 3;

    parameter int BYTE_ABSORB_WIDTH = 8;
    parameter int XOF_LEN_WIDTH = 16;


endpackage : keccak_pkg
