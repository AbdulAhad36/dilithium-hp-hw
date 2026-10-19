# Sampler virtual pin configuration

Accepted Stage4.9r interface. Top-level: sampler.
These are RTL/Quartus virtual pins, **not physical board package assignments**.
The QSF explicitly assigns all 238 non-clock bits VIRTUAL_PIN=ON. clk is the one
physical clock input, automatically placed by the fitter; no board pin is chosen.

| Port | Direction | Width | Purpose |
|---|---|---:|---|
| clk | Input | 1 | Rising-edge clock;6.500 ns /153.85 MHz constraint;worst Fmax164.74 MHz,setup+0.430 ns/hold+0.141 ns;accepted 2026-10-19 |
| rst | Input | 1 | Active-high synchronous reset; abort both contexts |
| job_valid_i | Input | 1 | Descriptor valid |
| job_ready_o | Output | 1 | Selected context can accept descriptor |
| job_core_i | Input | 1 | Context/core slot 0 or 1 |
| job_id_i | Input | 16 | Polynomial identifier |
| job_mode_i | Input | 2 | 0=A, 1=secret, 2=mask, 3=challenge |
| job_param_i | Input | 2 | 0=ML-DSA-44, 1=65, 2=87; 3 invalid |
| input_data_i | Input | 128 | SHAKE bytes, earliest at bits 7:0 |
| input_bytes_i | Input | 5 | Valid contiguous low bytes, 1..16 |
| input_core_i | Input | 1 | Source context for the whole beat |
| input_last_i | Input | 1 | Optional finite-source exhaustion marker |
| input_valid_i | Input | 1 | Input beat valid |
| input_ready_o | Output | 1 | Input beat can be accepted |
| output_data_o | Output | 23 | Canonical coefficient modulo q |
| output_core_o | Output | 1 | Coefficient context |
| output_id_o | Output | 16 | Coefficient polynomial ID |
| output_index_o | Output | 8 | Coefficient index 0..255 |
| output_last_o | Output | 1 | Coefficient index255 |
| output_valid_o | Output | 1 | Coefficient valid |
| output_ready_i | Input | 1 | Destination accepts coefficient |
| status_valid_o | Output | 1 | Completion/error valid |
| status_core_o | Output | 1 | Completed context |
| status_id_o | Output | 16 | Completed polynomial ID |
| status_code_o | Output | 3 | 0=OK, 1=exhausted, 2=reserved unsupported, 3=parameter, 4=byte count |
| status_ready_i | Input | 1 | Controller accepts status |
| active_o | Output | 2 | Slot ownership until status acceptance |
| source_stop_o | Output | 2 | Stop/discard surplus source output for completed/failed slot |

Every transfer requires valid && ready. Tags/payload must remain stable during
stall. Reset cancels pending work. Slot reuse additionally requires the future
integration controller to stop/drain the old Keccak stream; no controller or
Keccak/NTT RTL is imported here.

See SPECIFICATION.md for the full protocol, ordering and routing contract.
QSF: quartus/sampler/sampler.qsf. SDC: quartus/sampler/sampler.sdc.
Data-input/output paths are intentionally excluded for standalone internal-core
timing. Physical integration needs a real pin map and I/O timing constraints.
