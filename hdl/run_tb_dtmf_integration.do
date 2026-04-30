###############################################################################
# run_tb_dtmf_integration.do
#
# Compile + run dedicated integration testbench: tb_dtmf_integration
#
# Usage from hdl/ folder:
#   do run_tb_dtmf_integration.do
#
# Usage from Top-Level/ folder:
#   vsim -do hdl/run_tb_dtmf_integration.do
###############################################################################

onerror {abort all}
transcript on

puts ""
puts {=== [1/5] Setup libraries ===}
if {![file exists work]} { vlib work }
if {![file exists floatfixlib]} { vlib floatfixlib }
if {![file exists ieee_proposed]} { vlib ieee_proposed }
vmap work work
vmap floatfixlib floatfixlib
vmap ieee_proposed ieee_proposed

puts ""
puts {=== [2/5] Compile fixed-point support libraries ===}
vcom -93 -work floatfixlib ../intelFPGA_lite/18.1/modelsim_ase/vhdl_src/floatfixlib/fixed_float_types_c.vhd
vcom -93 -work ieee_proposed ../intelFPGA_lite/18.1/modelsim_ase/vhdl_src/floatfixlib/fixed_pkg_c.vhd

puts ""
puts {=== [3/5] Compile sender blocks ===}
vcom -2008 -work work sender_hdl/sine_gen_signed.vhd
vcom -2008 -work work sender_hdl/generate_dtmf_signed.vhd

puts ""
puts {=== [4/5] Compile receiver/detector blocks ===}
vcom -2008 -work work dtmf_detect_hdl/shift_add.vhd
vcom -2008 -work work dtmf_detect_hdl/Goertzel.vhd
vcom -2008 -work work dtmf_detect_hdl/Goertzel_top.vhd
vcom -2008 -work work dtmf_detect_hdl/highcomparator.vhd
vcom -2008 -work work dtmf_detect_hdl/lowcomparator.vhd
vcom -2008 -work work dtmf_detect_hdl/decision.vhd
vcom -2008 -work work dtmf_detect_hdl/top_dtmfencode.vhd

puts ""
puts {=== [5/5] Compile and run testbench ===}
vcom -2008 -work work tb_dtmf_integration.vhd

if {[catch {vsim -quiet -t 1ps -lib work work.tb_dtmf_integration} sim_result]} {
    puts ""
    puts {=== ERROR: Elaboration failed for work.tb_dtmf_integration ===}
    error $sim_result
}

# TB waits 520 ms before pass/fail assert. Run slightly longer.
run 550 ms
quit -sim

puts ""
puts {=== DONE: tb_dtmf_integration simulation finished ===}
quit
