# Agent onboarding — sampler_v1

User accepted Stage4.9r on2026-10-19. Main baseline:3537 actual placed ALMs,
164.74MHz worst Fmax,+0.430ns setup,+0.141ns hold at unchanged6.500ns.
3931 registers,4256 ALUTs,one M10K/1024bits,zero DSP. All4 corners0TNS.
Quartus seed1,HIGH PERFORMANCE EFFORT,physical register retiming OFF.
Original payload/sign/reservation structural guards pass. Area ALWAYS means
actual final-placement ALMs. Never use needed estimates for area claims.

Read README.md and docs/sampler_docs/post_midyear/SAMPLER_PLAN.md before work,
then SPECIFICATION.md,COVERAGE.md,THROUGHPUT.md,STAGE4_9R_RESULTS.json and the
user's docs/sampler_docs/LIGHTHD_SAMPLER.md and SAMPLER.md.
Main UVM621 complete/182 expected errors/51 aborts/159628 comparisons PASS;
functional1652/1721=95.99%,code15093/15799=95.53%. Python104/19456,C48/12288,
checker12,performance96 and five zero-credit fault gates PASS. Source checks
reuse byte-identical O after26 hashes;R has fresh fit/timing/structural evidence.
All96 performance rows match the preceding selected implementation.

Next is Stage5:verify DISTINCT accepted-build synthesis and fit netlists with
the MAIN UVM and independent Python captures. Current-build netlist results
are pending;old results must not be presented as current. CycloneV netlists
are functional only;TimeQuest is timing evidence. No board/I/O/security signoff.
Continue the user's cleanup first;do not launch new netlist simulations until
instructed. Integration,branch changes,module imports and commits require
explicit instruction. Do not advance automatically to Stage6.

RTL:src/sampler;UVM:tb_uvm/tb_uvm_sampler;common templates:tb_uvm/tb_uvm_reusable;
simulation:sim/sampler;Quartus:quartus/sampler;docs:docs/sampler_docs/post_midyear.
Keep exactly3 .do launchers:run_uvm.do,run_post_synthesis.do,run_post_fit.do.
Vectors/performance are modes of the main UVM. Independent models must not call
DUT functions. Coverage credits only scoreboard-accepted observations. Genuine
gaps stay visible;no artificial percentage ceiling or impossible bins.

Native128 remains inactive:tagged128-bit beats issue64-bit chunks. Current
pipeline:capture→staged prepare→extract→local compact→packed/admit→aligned
commit→32-entry/context collectors→per-context read→shared formatted output.
Mask conversion stays before packing;secret values remain4-bit encoded until
output formatting. Preserve complete state,credit/quota ownership and drain
before reuse. Do not relax6.500ns or waive original register guards.

Frozen Stage4.9r JSON/ZIP/SHA are immutable;never overwrite them. Its recorded
acceptance-pending field predates the explicit user acceptance. Mutable docs
record that acceptance. User-confirmed cleanup on2026-10-19 removed obsolete
checkpoint records/archives and leftover sim/ntt_LightHD and quartus/ntt_LightHD
folders. Only Stage4.9r result JSON/archive/checksum remain. All49 protected
source/model/settings/evidence files passed before/after hash checks. Two Python
analysis/checkpoint helpers remain after automatic review rejected their deletion.
