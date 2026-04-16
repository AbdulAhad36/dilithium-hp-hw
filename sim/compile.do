# Clean previous work
vdel -all

vlib work
vmap work work

        # Set UVM path (DO NOT rely on system env)
        #set env(UVM_HOME) "C:/questasim64_2024.1/verilog_src/uvm-1.2"

        # Compile UVM (must be FIRST)
        #vlog -sv +incdir+$env(UVM_HOME)/src \
        #    $env(UVM_HOME)/src/uvm_pkg.sv 

# Compile RTL

        #vlog -sv ../src/test/adder.sv
        #vlog -sv ../src/test/det_1011.sv


vlog -sv ../src/keccak_engine/keccak_pkg.sv
vlog -sv ../src/keccak_engine/*.sv
vlog -sv ../tb_uvm/tb_keccak_engine/keccak_core_tb.sv

        #vlog -sv ../tb_uvm/interface.sv

        #vlog -sv ../tb_uvm/interfacePackage.sv

        #vlog -sv ../tb_uvm/tb.sv

