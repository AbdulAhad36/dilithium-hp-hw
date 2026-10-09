# Pre decoder trial - not selected

Four-bit lookup key for eligible [-4,4] inputs; exact simulation eligibility guard retained.
Main UVM 116/116, 14 checked covergroup types 100%; separate Python 18/18 cases and 4608/4608 coefficients.
Separate +8 invalid-input test reaches exact DUT eligibility fatal; no credit to passing coverage.
Fresh fit on 2026-10-09: 2392 ALMs, 2017 registers, 5 DSP, 20 M10K.
Slow 85 C Fmax 132.12 MHz; slow 0 C 129.70 MHz (worst).
Worst setup -2.710 ns, hold +0.163 ns, pulse width -0.555 ns at 5 ns.
Critical path at both slow corners: twiddle ROM -> bf_zi_q.
Not selected: worst Fmax regressed from 131.22 MHz despite 36 fewer ALMs.
Active core restored from lighthd_write_mux_checkpoint before the multiplier trial.
