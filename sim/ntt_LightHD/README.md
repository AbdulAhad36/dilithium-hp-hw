# LightHD NTT simulation

Run these commands from the repository's `sim/` directory in PowerShell.
Each script compiles `../src/ntt_LightHD/` into its own library under this
folder. The existing shared UVM environment and SV golden model stay under
`../tb_uvm/tb_uvm_ntt/` so the four-bank regression still works.
If the input/expected files are missing, first run
`py -3 FIPS204_NTT/ntt_vectors.py prepare` from the repository root.

```powershell
& 'C:\questasim64_2024.1\win64\vsim.exe' -c -l ntt_LightHD/vector.log -do 'do ntt_LightHD/run_vectors.do; quit -f'
& 'C:\questasim64_2024.1\win64\vsim.exe' -c -l ntt_LightHD/core.log -do 'do ntt_LightHD/run_core_check.do; quit -f'
& 'C:\questasim64_2024.1\win64\vsim.exe' -c -l ntt_LightHD/engine.log -do 'do ntt_LightHD/run_engine_check.do; quit -f'
& 'C:\questasim64_2024.1\win64\vsim.exe' -c -l ntt_LightHD/uvm.log -do 'do ntt_LightHD/run_uvm.do; quit -f'
```

After the vector capture finishes, return to the repository root and compare
the observed coefficients with the independent FIPS 204-derived expected
file. `NTT VECTOR CAPTURE COMPLETE` alone is not a correctness result.

```powershell
py -3 FIPS204_NTT/ntt_vectors.py compare --observed sim/ntt_LightHD/ntt_dut_outputs.txt
py -3 sim/ntt_LightHD/fifo_schedule.py
```

The vector capture is separate from UVM. `run_uvm.do` enables `NTT_FIFO`
only for this candidate, adding 13 bounded-secret Pre-NTT cases to the
shared 53 standard-mode cases. Logs, work libraries, UCDB, and observed
outputs are generated here. The historical Stage 3 logs remain in
`experiments/ntt_stage3/lighthd_fifo/`.
