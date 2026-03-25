vlib work

# Compile

    #vlog -sv ../src_rtl/adder.sv
    #vlog -sv ../tb_rtl/adder_tb.sv


vlog -v ../ML-DSA-OSH/ref_combined/src/*.v
vcom -2008 ./ML-DSA-OSH/ref_combined/src/*.vhd
vlog -v ../ML-DSA-OSH/ref_combined/src_tb/*.v
