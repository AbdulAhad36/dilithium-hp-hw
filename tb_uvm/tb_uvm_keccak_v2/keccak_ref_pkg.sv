// =========================================================================
// keccak_ref_pkg.sv  -  Pure-SystemVerilog SHAKE reference model
//
// Untimed reference implementation of Keccak-f[1600] + sponge construction
// + SHAKE128/SHAKE256. Used by the UVM scoreboard to golden-compare every
// transaction, including random stress + coverage-closure items that have
// no NIST vector. No DPI, no external dependencies, no toolchain.
//
// Algorithm matches FIPS 202 verbatim. Bytes within a lane use little-
// endian ordering (byte 0 = bits[7:0]). Sponge absorbs full rate blocks,
// then injects SHAKE suffix 0x1F at the first padding byte and 0x80 at
// the last byte of the rate block, then permutes, then squeezes.
//
// Public API:
//   shake_hex(mode, msg_hex, out_bytes) -> lowercase hex string
//
// Self-test: shake_self_test() runs 4 NIST vectors and $displays pass/fail.
// =========================================================================
`timescale 1ns/1ps

package keccak_ref_pkg;
    import keccak_pkg::*;

    // ---------------------------------------------------------------------
    // 64-bit left rotate
    // ---------------------------------------------------------------------
    function automatic logic [63:0] rotl64(input logic [63:0] x, input int n);
        int s = n % 64;
        if (s == 0) return x;
        return (x << s) | (x >> (64 - s));
    endfunction

    // ---------------------------------------------------------------------
    // Keccak-f[1600] permutation. 24 rounds in place on a 5x5 array of u64.
    // ---------------------------------------------------------------------
    function automatic void keccak_f1600(ref logic [63:0] S [5][5]);
        // Round constants (FIPS 202 Table 1)
        static logic [63:0] RC [24] = '{
            64'h0000000000000001, 64'h0000000000008082, 64'h800000000000808a, 64'h8000000080008000,
            64'h000000000000808b, 64'h0000000080000001, 64'h8000000080008081, 64'h8000000000008009,
            64'h000000000000008a, 64'h0000000000000088, 64'h0000000080008009, 64'h000000008000000a,
            64'h000000008000808b, 64'h800000000000008b, 64'h8000000000008089, 64'h8000000000008003,
            64'h8000000000008002, 64'h8000000000000080, 64'h000000000000800a, 64'h800000008000000a,
            64'h8000000080008081, 64'h8000000000008080, 64'h0000000080000001, 64'h8000000080008008
        };
        // Rho rotation offsets, indexed [x][y] (FIPS 202 Table 2)
        static int RHO [5][5] = '{
            '{ 0, 36,  3, 41, 18},
            '{ 1, 44, 10, 45,  2},
            '{62,  6, 43, 15, 61},
            '{28, 55, 25, 21, 56},
            '{27, 20, 39,  8, 14}
        };

        logic [63:0] C [5];
        logic [63:0] D [5];
        logic [63:0] B [5][5];

        for (int r = 0; r < 24; r++) begin
            // Theta
            for (int x = 0; x < 5; x++)
                C[x] = S[x][0] ^ S[x][1] ^ S[x][2] ^ S[x][3] ^ S[x][4];
            for (int x = 0; x < 5; x++)
                D[x] = C[(x + 4) % 5] ^ rotl64(C[(x + 1) % 5], 1);
            for (int x = 0; x < 5; x++)
                for (int y = 0; y < 5; y++)
                    S[x][y] = S[x][y] ^ D[x];

            // Rho + Pi (combined): B[y][(2x+3y)%5] = rotl(S[x][y], RHO[x][y])
            for (int x = 0; x < 5; x++)
                for (int y = 0; y < 5; y++)
                    B[y][(2*x + 3*y) % 5] = rotl64(S[x][y], RHO[x][y]);

            // Chi: S[x][y] = B[x][y] ^ ((~B[(x+1)%5][y]) & B[(x+2)%5][y])
            for (int x = 0; x < 5; x++)
                for (int y = 0; y < 5; y++)
                    S[x][y] = B[x][y] ^ ((~B[(x + 1) % 5][y]) & B[(x + 2) % 5][y]);

            // Iota
            S[0][0] = S[0][0] ^ RC[r];
        end
    endfunction

    // ---------------------------------------------------------------------
    // Map byte index within rate block -> (x, y, byte_offset)
    // The Keccak state's lane (x,y) lives at linear lane index 5*y + x;
    // within a lane, byte 0 is bits[7:0] (little-endian).
    // ---------------------------------------------------------------------
    function automatic void byte_idx_to_xy(
        input  int byte_idx,
        output int x,
        output int y,
        output int boff
    );
        int lane_idx;
        lane_idx = byte_idx / 8;
        boff     = byte_idx % 8;
        x        = lane_idx % 5;
        y        = lane_idx / 5;
    endfunction

    // ---------------------------------------------------------------------
    // SHAKE sponge: absorb msg, then squeeze out_bytes bytes
    // ---------------------------------------------------------------------
    function automatic void shake_compute(
        input  keccak_mode    mode,
        input  byte unsigned  msg [],
        input  int            out_bytes,
        output byte unsigned  out [$]
    );
        logic [63:0] S [5][5];
        int rate_bytes;
        int msg_len;
        int block_start;
        int rem;
        int x, y, boff;
        int produced;
        int to_take;

        msg_len = msg.size();
        case (mode)
            SHAKE128: rate_bytes = 168;  // 1344 / 8
            SHAKE256: rate_bytes = 136;  // 1088 / 8
            default:  rate_bytes = 168;
        endcase

        // Init state to zero
        for (int xx = 0; xx < 5; xx++)
            for (int yy = 0; yy < 5; yy++)
                S[xx][yy] = '0;

        // Absorb full rate blocks
        block_start = 0;
        while (msg_len - block_start >= rate_bytes) begin
            for (int i = 0; i < rate_bytes; i++) begin
                byte_idx_to_xy(i, x, y, boff);
                S[x][y] = S[x][y] ^ (64'(msg[block_start + i]) << (boff * 8));
            end
            keccak_f1600(S);
            block_start += rate_bytes;
        end

        // Last (possibly empty) block: absorb tail + padding
        rem = msg_len - block_start;
        for (int i = 0; i < rem; i++) begin
            byte_idx_to_xy(i, x, y, boff);
            S[x][y] = S[x][y] ^ (64'(msg[block_start + i]) << (boff * 8));
        end
        // SHAKE suffix 0x1F at first padding byte
        byte_idx_to_xy(rem, x, y, boff);
        S[x][y] = S[x][y] ^ (64'h1F << (boff * 8));
        // 0x80 at last byte of the rate block
        byte_idx_to_xy(rate_bytes - 1, x, y, boff);
        S[x][y] = S[x][y] ^ (64'h80 << (boff * 8));
        // Permute
        keccak_f1600(S);

        // Squeeze
        out.delete();
        produced = 0;
        while (produced < out_bytes) begin
            to_take = (out_bytes - produced < rate_bytes) ? (out_bytes - produced) : rate_bytes;
            for (int i = 0; i < to_take; i++) begin
                byte unsigned b;
                byte_idx_to_xy(i, x, y, boff);
                b = (S[x][y] >> (boff * 8)) & 8'hFF;
                out.push_back(b);
            end
            produced += to_take;
            if (produced < out_bytes) keccak_f1600(S);
        end
    endfunction

    // ---------------------------------------------------------------------
    // Hex string <-> byte helpers
    // ---------------------------------------------------------------------
    function automatic void hex_to_bytes(input string s, output byte unsigned arr []);
        int n = s.len() / 2;
        arr = new[n];
        for (int i = 0; i < n; i++) begin
            int v = 0;
            for (int k = 0; k < 2; k++) begin
                byte c;
                int d;
                c = s[i*2 + k];
                if      (c >= "0" && c <= "9") d = c - "0";
                else if (c >= "a" && c <= "f") d = 10 + (c - "a");
                else if (c >= "A" && c <= "F") d = 10 + (c - "A");
                else                            d = 0;
                v = (v << 4) | d;
            end
            arr[i] = v[7:0];
        end
    endfunction

    function automatic string bytes_to_hex(input byte unsigned arr [$], input int n);
        string s = "";
        for (int i = 0; i < n; i++) s = {s, $sformatf("%02x", arr[i])};
        return s;
    endfunction

    // ---------------------------------------------------------------------
    // Top-level: hex msg in, hex output out
    // ---------------------------------------------------------------------
    function automatic string shake_hex(
        input keccak_mode mode,
        input string      msg_hex,
        input int         out_bytes
    );
        byte unsigned msg [];
        byte unsigned obs [$];
        hex_to_bytes(msg_hex, msg);
        shake_compute(mode, msg, out_bytes, obs);
        return bytes_to_hex(obs, out_bytes);
    endfunction

    // ---------------------------------------------------------------------
    // Self-test: 4 NIST vectors. Returns 1 if all pass, 0 otherwise.
    // ---------------------------------------------------------------------
    function automatic bit shake_self_test();
        bit    ok = 1;
        string got;
        string exp;

        // SHAKE128 Empty -> 16B
        got = shake_hex(SHAKE128, "", 16);
        exp = "7f9c2ba4e88f827d616045507605853e";
        if (got != exp) begin
            $display("[shake_self_test] FAIL SHAKE128 Empty\n  exp=%s\n  got=%s", exp, got);
            ok = 0;
        end

        // SHAKE128 "84f6cb3dc77b9bf856caf54e" -> 16B
        got = shake_hex(SHAKE128, "84f6cb3dc77b9bf856caf54e", 16);
        exp = "56538d52b26f967bb9405e0f54fdf6e2";
        if (got != exp) begin
            $display("[shake_self_test] FAIL SHAKE128 Short\n  exp=%s\n  got=%s", exp, got);
            ok = 0;
        end

        // SHAKE256 Empty -> 32B
        got = shake_hex(SHAKE256, "", 32);
        exp = "46b9dd2b0ba88d13233b3feb743eeb243fcd52ea62b81b82b50c27646ed5762f";
        if (got != exp) begin
            $display("[shake_self_test] FAIL SHAKE256 Empty\n  exp=%s\n  got=%s", exp, got);
            ok = 0;
        end

        // SHAKE256 "765db6ab3af389b8c775c8eb99fe72" -> 32B
        got = shake_hex(SHAKE256, "765db6ab3af389b8c775c8eb99fe72", 32);
        exp = "ccb6564a655c94d714f80b9f8de9e2610c4478778eac1b9256237dbf90e50581";
        if (got != exp) begin
            $display("[shake_self_test] FAIL SHAKE256 Short\n  exp=%s\n  got=%s", exp, got);
            ok = 0;
        end

        if (ok) $display("[shake_self_test] PASS (4/4 NIST vectors)");
        return ok;
    endfunction

endpackage
