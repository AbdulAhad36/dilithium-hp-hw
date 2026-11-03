# Dilithium throughput and implementation measurements

Latest saved full-design result: 31923 actual placed ALMs, 72.36 MHz worst-corner Fmax, -7.32 ns setup and +0.088 ns hold. The 6.500 ns target is not closed;150+ MHz remains the goal. Area reduction is currently deferred.

Source measurements: sim/dilithium/reference_build/stage7c26_metrics.json and stage7c26_throughput.json. Timing comes from the same Cyclone V full fit and all four TimeQuest corners;hold TNS is zero. Count only final placed ALMs [A].

|Operation|Level|Mean clocks|Estimated latency (us)|Estimated operations/s|
|---|---:|---:|---:|---:|
|KeyGen|2|8778.68|121.32|8242.7|
|KeyGen|3|15234.72|210.54|4749.7|
|KeyGen|5|24535.92|339.08|2949.1|
|Sign mean|2|70276.13|971.20|1029.7|
|Sign mean|3|83119.07|1148.69|870.6|
|Sign mean|5|133422.20|1843.87|542.3|
|Verify valid|2|11244.33|155.39|6435.2|
|Verify valid|3|16724.33|231.13|4326.6|
|Verify valid|5|25777.00|356.23|2807.2|

Latency = clocks / Fmax(MHz). Rate = Fmax(Hz) / clocks. These are sequential estimates,not initiation intervals or FPGA board measurements. Sign uses the measured mean across official cases;Verify uses valid cases. RTL outputs were compared independently with the official vectors.

Full functional qualification is distinct from timing closure. No target acceptance,post-fit functional signoff or physical FPGA testing is implied. Old trial measurements remain in the retained evidence checkpoints. Update this manual only for significant verified improvements or accepted milestones.
