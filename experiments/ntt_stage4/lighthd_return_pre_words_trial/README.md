# Registered compute and Pre-NTT FIFO words trial - 2026-10-10

Base: lighthd_return_words_trial, itself based on selected 148.46 MHz
lighthd_fold_pipeline_checkpoint. Only ntt_core.sv changes.

## Change

Keep the previous trial's per-FIFO registered compute words. Also register
Pre-NTT FIFO1's upper/lower word choice in its existing add/subtract stage,
using pre_upper_q0. The FIFO write stage now selects among three words
(registered compute, registered Pre, load) instead of four. FIFO push masks,
priority, operation sequence, interface and 5/7/10 pipeline are unchanged.
pre_upper_q1 still selects the required FIFO push mask.

The mathematical references, expected outputs and UVM models are unchanged.
No new pipeline clock or FIFO capacity. This is an implementation experiment,
not an accepted performance improvement until fresh fitting proves it.

## Fresh source verification

uvm_return_pre_words.log:118/118,zero UVM errors/fatals,fourteen checked
functional covergroup types at100%. Every observed operand, physical write,
final output and reset recovery remains checked through the main UVM.
vector_return_pre_words.log / compare_return_pre_words.log:18/18cases,
4608/4608coefficients. Core267/267/75/236 and no-stall wrapper781/781/845/750
(NTT/INTT/PWM/Pre) unchanged.

routing_writeback_return_pre_words.log: deliberately corrupts one observed
write word, real final outputs remain right; UVM ROUTING CHECKER PASS,
checked_jobs=0. Its failed UCDB is separate. Other unchanged negative-credit,
operand, GS and Pre-eligibility evidence remains retained, not freshly rerun.

Core raw coverage:308/320statements,232/245branches,53/84conditions,
51/52expressions,5/5states,9/9transitions,4509/4787toggles. Compared with the
selected baseline,13new statements and1104new toggle bins are hit
(552new signal bits x two directions); the same278constant misses remain.
Other DUT instance counts unchanged. No exclusions. New code changes the
coverage denominators; this does not establish blanket code closure.

## Fitted result: rejected

Fresh map/fit/STA and both slow-corner critical paths completed 2026-10-10.
Worst Fmax139.33MHz(slow0); slow85 142.19MHz. Resources:2681ALMs,
2668registers,5DSP,20M10K,37325RAMbits. At unchanged5ns: worst setup
-2.177ns,all-corner hold+0.170ns,pulse-0.555ns. Slow0 worst is lane3 kept
operand RAM -> b_o[11]; slow85 worst is inverse-tag RAM -> compute_word2_q[51].
The late Pre word mux is no longer the top path, but overall timing regresses.
Against selected148.46MHz/2490ALMs/-1.736ns, Fmax falls9.13MHz, ALMs rise191,
and setup worsens0.441ns. Do not select. Exact six RTL files are in rtl/;
complete source-verification and fitted evidence is in results/.
