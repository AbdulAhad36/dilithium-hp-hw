// Stable lane-sized compaction. Prefix levels compute every destination
// independently; there is no per-candidate running job/collector counter.
module sampler_compact #(parameter int LANES=16,WIDTH=4) (
  input logic [LANES-1:0] valid_i,
  input logic [LANES-1:0][WIDTH-1:0] data_i,
  output wire [4:0] count_o,
  output logic [LANES-1:0][WIDTH-1:0] data_o
);
  localparam int LEVELS=$clog2(LANES),COUNT_WIDTH=$clog2(LANES+1);
  wire [COUNT_WIDTH-1:0] prefix [0:LEVELS][0:LANES-1];
  genvar lane,level;
  generate
    for(lane=0;lane<LANES;lane=lane+1)begin: g_initial
      assign prefix[0][lane]=COUNT_WIDTH'(valid_i[lane]);
    end
    for(level=0;level<LEVELS;level=level+1)begin: g_prefix
      for(lane=0;lane<LANES;lane=lane+1)begin: g_lane
        if(lane>=(1<<level))begin: g_add
          assign prefix[level+1][lane]=prefix[level][lane]+prefix[level][lane-(1<<level)];
        end else begin: g_copy
          assign prefix[level+1][lane]=prefix[level][lane];
        end
      end
    end
  endgenerate
  assign count_o=5'(prefix[LEVELS][LANES-1]);
  always_comb begin
    data_o='0;
    for(int dest=0;dest<LANES;dest++)
      for(int source=0;source<LANES;source++)
        // At most one source has this prefix rank. OR reduction is intentional.
        data_o[dest] |= data_i[source] & {WIDTH{valid_i[source] && prefix[LEVELS][source]==dest+1}};
  end
endmodule
