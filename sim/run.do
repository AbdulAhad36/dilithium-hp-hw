# Compile everything
do compile.do

# Start simulation
vsim -voptargs=+acc work.tb

# Optional: open useful windows
#view wave
#view structure
#view signals

# Add all signals to waveform
#add wave -r *

# Run simulation
run -all

# Exit automatically
#quit -f