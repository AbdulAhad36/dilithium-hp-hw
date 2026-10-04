# Run from sim/ after: python nist_shake.py prepare
# Runs only the standalone UVM cores and captures DUT outputs quickly.
# Run python nist_shake.py compare afterward.
set ::keccak_nist_mode 1
do run.do
vmap work [file join $script_dir work]
unset ::keccak_nist_mode
