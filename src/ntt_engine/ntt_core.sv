// ============================================================================
// ntt_core.sv  --  Memory-based NTT/INTT core with a 2x2 butterfly tile
// ----------------------------------------------------------------------------
// Architecture (see docs/ntt-design-and-verification.md):
//   - 256 coefficients held in a BRAM array, organised 64 lines x 4 coeffs.
//   - A 2x2 butterfly TILE = 4 butterfly_unit instances arranged as two
//     stacked radix-2 stages. It consumes 4 coefficients per cycle and
//     advances TWO NTT stages per memory pass -> 8 radix-2 stages collapse
//     into N_PASSES = 4 passes.
//   - A conflict-free address generator (ntt_addr_gen, TODO) feeds read/write
//     addresses so the pipeline never stalls.
//   - Forward NTT uses BF_CT butterflies; inverse NTT uses BF_GS; the final
//     INTT pass scales every coefficient by N_INV.
//
// STATUS: leaf datapath (butterfly tile, twiddle ROM) is instantiated and
// complete. The control FSM and conflict-free address generator are scaffolded
// and marked TODO -- these are the next implementation step on branch 2_ntt.
// ============================================================================
import ntt_pkg::*;

module ntt_core (
    input  logic                 clk,
    input  logic                 rst,

    // ---- control ----------------------------------------------------------
    input  logic                 start_i,     // pulse: begin an operation
    input  ntt_op_e               op_i,        // OP_NTT / OP_INTT / OP_PWM
    output logic                  busy_o,
    output logic                  done_o,

    // ---- coefficient memory load / unload (one coeff per cycle) -----------
    input  logic                  wr_en_i,
    input  logic [LOGN-1:0]        wr_addr_i,
    input  logic [COEFF_W-1:0]     wr_data_i,
    input  logic                   rd_en_i,
    input  logic [LOGN-1:0]        rd_addr_i,
    output logic [COEFF_W-1:0]     rd_data_o
);

  // ==========================================================================
  // Coefficient memory : 256 x 23-bit. Implemented as 4 banks so the 2x2 tile
  // can read 4 / write 4 coefficients per cycle without a port conflict.
  // ==========================================================================
  localparam int unsigned BANK_DEPTH = N / COEFFS_PER_CYCLE;   // 64

  logic [COEFF_W-1:0] bank [COEFFS_PER_CYCLE][BANK_DEPTH];

  // ==========================================================================
  // Twiddle ROM
  // ==========================================================================
  logic [LOGN-1:0]    tw_addr;
  logic [COEFF_W-1:0] tw_data;

  twiddle_rom u_tw (
      .clk    (clk),
      .addr_i (tw_addr),
      .tw_o   (tw_data)
  );

  // ==========================================================================
  // 2x2 butterfly tile : 4 butterfly_unit instances.
  //   stage A : bf[0], bf[1]   (first of the two collapsed radix-2 stages)
  //   stage B : bf[2], bf[3]   (second collapsed stage)
  // ==========================================================================
  bf_mode_e            tile_mode;
  logic [COEFF_W-1:0]  bf_a_i [COEFFS_PER_CYCLE];
  logic [COEFF_W-1:0]  bf_b_i [COEFFS_PER_CYCLE];
  logic [COEFF_W-1:0]  bf_zeta[COEFFS_PER_CYCLE];
  logic [COEFF_W-1:0]  bf_a_o [COEFFS_PER_CYCLE];
  logic [COEFF_W-1:0]  bf_b_o [COEFFS_PER_CYCLE];

  genvar gi;
  generate
    for (gi = 0; gi < COEFFS_PER_CYCLE; gi++) begin : g_bf
      butterfly_unit u_bf (
          .clk    (clk),
          .rst    (rst),
          .mode_i (tile_mode),
          .a_i    (bf_a_i[gi]),
          .b_i    (bf_b_i[gi]),
          .zeta_i (bf_zeta[gi]),
          .a_o    (bf_a_o[gi]),
          .b_o    (bf_b_o[gi])
      );
    end
  endgenerate

  // ==========================================================================
  // Control FSM  --  TODO (next step on branch 2_ntt)
  // --------------------------------------------------------------------------
  // States: IDLE -> LOAD -> RUN(pass 0..3) -> SCALE(INTT only) -> UNLOAD -> IDLE
  // The RUN state streams 64 cycles per pass through the butterfly tile; the
  // conflict-free address generator (ntt_addr_gen) supplies bank read/write
  // addresses and twiddle indices. PWM mode reuses the 4 multipliers inside
  // the tile for 4-way point-wise multiplication.
  // ==========================================================================
  typedef enum logic [2:0] {
    S_IDLE, S_LOAD, S_RUN, S_SCALE, S_UNLOAD
  } state_e;

  state_e state;

  // Default datapath wiring so the scaffold elaborates cleanly. The real
  // address generation / pass sequencing replaces this in the next step.
  always_comb begin
    tile_mode = (op_i == OP_INTT) ? BF_GS : BF_CT;
    tw_addr   = '0;
    for (int i = 0; i < COEFFS_PER_CYCLE; i++) begin
      bf_a_i[i]  = '0;
      bf_b_i[i]  = '0;
      bf_zeta[i] = tw_data;
    end
  end

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      state  <= S_IDLE;
      busy_o <= 1'b0;
      done_o <= 1'b0;
    end else begin
      done_o <= 1'b0;
      case (state)
        S_IDLE  : if (start_i) begin state <= S_LOAD; busy_o <= 1'b1; end
        // TODO: LOAD / RUN / SCALE / UNLOAD sequencing
        default : begin state <= S_IDLE; busy_o <= 1'b0; done_o <= 1'b1; end
      endcase
    end
  end

  // ---- simple load / unload port (one coeff per cycle) --------------------
  always_ff @(posedge clk) begin
    if (wr_en_i)
      bank[wr_addr_i[1:0]][wr_addr_i[LOGN-1:2]] <= wr_data_i;
    if (rd_en_i)
      rd_data_o <= bank[rd_addr_i[1:0]][rd_addr_i[LOGN-1:2]];
  end

endmodule : ntt_core
