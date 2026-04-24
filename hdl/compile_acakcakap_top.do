###############################################################################
# compile_acakcakap_top.do
#
# Compile + elaboration check for AcakCakap_Top in Questa - Altera FPGA Starter
# Edition 2025.2 (Quartus Prime Pro 25.1std)
#
# Usage from hdl/ folder:
#   do compile_acakcakap_top.do
#
# Usage from Top-Level/ folder:
#   vsim -do hdl/compile_acakcakap_top.do
###############################################################################

onerror {abort all}
transcript on

puts ""
puts {=== [1/6] Setup libraries ===}
if {![file exists work]}     { vlib work     }
if {![file exists audiopll]} { vlib audiopll }
if {![file exists floatfixlib]} { vlib floatfixlib }
if {![file exists ieee_proposed]} { vlib ieee_proposed }
vmap work work
vmap audiopll audiopll
vmap floatfixlib floatfixlib
vmap ieee_proposed ieee_proposed

puts ""
puts {=== [2/6] Compile PLL / audio base ===}
vcom -2008 -work audiopll ../quartus/AudioPLL_sim/AudioPLL.vho
vcom -2008 -work work i2c.vhd
vcom -2008 -work work Audio_interface.vhd

puts ""
puts {=== [3/6] Compile DTMF sender ===}
vcom -2008 -work work sender_hdl/sine_gen_signed.vhd
vcom -2008 -work work sender_hdl/generate_dtmf_signed.vhd

puts ""
puts {=== [3.5/6] Compile fixed-point support libraries ===}
vcom -93 -work floatfixlib ../intelFPGA_lite/18.1/modelsim_ase/vhdl_src/floatfixlib/fixed_float_types_c.vhd
vcom -93 -work ieee_proposed ../intelFPGA_lite/18.1/modelsim_ase/vhdl_src/floatfixlib/fixed_pkg_c.vhd

puts ""
puts {=== [4/6] Compile DTMF detector and receiver ===}
vcom -2008 -work work receiver_hdl/lutcos_block.vhd
vcom -2008 -work work receiver_hdl/lutsin_block.vhd
vcom -2008 -work work receiver_hdl/multv6.vhd
vcom -2008 -work work receiver_hdl/powercalcv1.vhd
vcom -2008 -work work receiver_hdl/slidingv5.vhd
vcom -2008 -work work receiver_hdl/markingv1.vhd
vcom -2008 -work work receiver_hdl/Framingv2.vhd
vcom -2008 -work work receiver_hdl/flaggingv2.vhd
vcom -2008 -work work receiver_hdl/dec_control.vhd
vcom -2008 -work work receiver_hdl/toplevel_iq.vhd

vcom -2008 -work work dtmf_detect_hdl/shift_add.vhd
vcom -2008 -work work dtmf_detect_hdl/Goertzel.vhd
vcom -2008 -work work dtmf_detect_hdl/Goertzel_top.vhd
vcom -2008 -work work dtmf_detect_hdl/highcomparator.vhd
vcom -2008 -work work dtmf_detect_hdl/lowcomparator.vhd
vcom -2008 -work work dtmf_detect_hdl/decision.vhd
vcom -2008 -work work dtmf_detect_hdl/top_dtmfencode.vhd
vcom -2008 -work work dtmf_detect_hdl/dtmf_system.vhd
vcom -2008 -work work dtmf_detect_hdl/DecodeDTMF.vhd

puts ""
puts {=== [5/6] Compile scrambler/verilog blocks ===}
vlog -work work Butterfly.v
vlog -work work DelayBuffer.v
vlog -work work FFT.v
vlog -work work GenPermutationKey.v
vlog -work work Mult128.v
vlog -work work Multiply.v
vlog -work work ReorderXk.v
vlog -work work ReverseBitOrder.v
vlog -work work SdfUnit.v
vlog -work work SdfUnit2.v
vlog -work work Twiddle.v
vlog -work work Scrambler_TOP.v

puts ""
puts {=== [6/6] Compile and elaborate top-level ===}
vcom -2008 -work work AcakCakap_Top.vhd

# Elaboration check (no run required)
if {[catch {vsim -quiet -t 1ps -lib work work.AcakCakap_Top} sim_result]} {
	puts ""
	puts {=== ERROR: Elaboration failed for work.AcakCakap_Top ===}
	error $sim_result
}

quit -sim

puts ""
puts {=== SUCCESS: Compile and elaboration passed for work.AcakCakap_Top ===}
