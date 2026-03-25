
do compile.do


# Simulate

vsim work.tb_keygen_top
vsim -voptargs=+acc work.tb_keygen_top

    # Add all signals to waveform
    #add wave -r *
    #radix -hex

    # Run simulation
    #run -all
    #wave zoom full