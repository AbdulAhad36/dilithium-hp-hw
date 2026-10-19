package sampler_pkg;
  localparam int Q = 8380417;
  localparam int N = 256;
  typedef enum logic [1:0] {SAMPLE_A, SAMPLE_SECRET, SAMPLE_MASK, SAMPLE_BALL} mode_t;
  typedef enum logic [2:0] {
    STATUS_OK, STATUS_EXHAUSTED, STATUS_UNSUPPORTED, STATUS_PARAM, STATUS_BYTES
  } status_t;
endpackage
