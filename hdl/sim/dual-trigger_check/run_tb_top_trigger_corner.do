###############################################################################
# run_tb_top_trigger_corner.do
#
# Compile + run dedicated corner-case trigger testbench: tb_top_trigger_corner
#
# Usage from hdl/sim/dual-trigger_check/ folder:
#   do run_tb_top_trigger_corner.do
#
# Usage from Top-Level/ folder:
#   vsim -do hdl/sim/dual-trigger_check/run_tb_top_trigger_corner.do
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
vcom -2008 -work audiopll ../../../quartus/AudioPLL_sim/AudioPLL.vho
vcom -2008 -work work ../../i2c.vhd
vcom -2008 -work work ../../Audio_interface.vhd

puts ""
puts {=== [3/6] Compile DTMF sender ===}
vcom -2008 -work work ../../sender_hdl/sine_gen_signed.vhd
vcom -2008 -work work ../../sender_hdl/generate_dtmf_signed.vhd

puts ""
puts {=== [3.5/6] Compile fixed-point support libraries ===}
vcom -93 -work floatfixlib ../../../intelFPGA_lite/18.1/modelsim_ase/vhdl_src/floatfixlib/fixed_float_types_c.vhd
vcom -93 -work ieee_proposed ../../../intelFPGA_lite/18.1/modelsim_ase/vhdl_src/floatfixlib/fixed_pkg_c.vhd

puts ""
puts {=== [4/6] Compile DTMF detector and receiver ===}
vcom -2008 -work work ../../receiver_hdl/lutcos_block.vhd
vcom -2008 -work work ../../receiver_hdl/lutsin_block.vhd
vcom -2008 -work work ../../receiver_hdl/multv6.vhd
vcom -2008 -work work ../../receiver_hdl/powercalcv1.vhd
vcom -2008 -work work ../../receiver_hdl/slidingv5.vhd
vcom -2008 -work work ../../receiver_hdl/markingv1.vhd
vcom -2008 -work work ../../receiver_hdl/Framingv2.vhd
vcom -2008 -work work ../../receiver_hdl/flaggingv2.vhd
vcom -2008 -work work ../../receiver_hdl/dec_control.vhd
vcom -2008 -work work ../../receiver_hdl/toplevel_iq.vhd

vcom -2008 -work work ../../dtmf_detect_hdl/shift_add.vhd
vcom -2008 -work work ../../dtmf_detect_hdl/Goertzel.vhd
vcom -2008 -work work ../../dtmf_detect_hdl/Goertzel_top.vhd
vcom -2008 -work work ../../dtmf_detect_hdl/highcomparator.vhd
vcom -2008 -work work ../../dtmf_detect_hdl/lowcomparator.vhd
vcom -2008 -work work ../../dtmf_detect_hdl/decision.vhd
vcom -2008 -work work ../../dtmf_detect_hdl/top_dtmfencode.vhd
vcom -2008 -work work ../../dtmf_detect_hdl/dtmf_system.vhd
vcom -2008 -work work ../../dtmf_detect_hdl/DecodeDTMF.vhd

puts ""
puts {=== [5/6] Compile scrambler/verilog blocks ===}
vlog -work work ../../Butterfly.v
vlog -work work ../../DelayBuffer.v
vlog -work work ../../FFT.v
vlog -work work ../../GenPermutationKey.v
vlog -work work ../../Mult128.v
vlog -work work ../../Multiply.v
vlog -work work ../../ReorderXk.v
vlog -work work ../../ReverseBitOrder.v
vlog -work work ../../SdfUnit.v
vlog -work work ../../SdfUnit2.v
vlog -work work ../../Twiddle.v
vlog -work work ../../Scrambler_TOP.v

puts ""
puts {=== [6/6] Compile and elaborate top-level & testbench ===}
vcom -2008 -work work ../../util/uart_rx.vhd
vcom -2008 -work work ../../AcakCakap_Top.vhd
vlog -work work tb_top_trigger_corner.v

if {[catch {vsim -quiet -voptargs="+acc" -t 1ps -lib work work.tb_top_trigger_corner} sim_result]} {
    puts ""
    puts {=== ERROR: Elaboration failed for work.tb_top_trigger_corner ===}
    error $sim_result
}

# --- Setup Waveform Window ---
view wave

add wave -noupdate -divider "System Clock & Reset"
add wave -noupdate -color Yellow sim:/tb_top_trigger_corner/CLOCK_50
add wave -noupdate -color Orange sim:/tb_top_trigger_corner/KEY[0]

add wave -noupdate -divider "Physical Inputs (Triggers)"
add wave -noupdate -color Cyan sim:/tb_top_trigger_corner/KEY[1]
add wave -noupdate -color Violet sim:/tb_top_trigger_corner/UART_RXD

add wave -noupdate -divider "FSM Internal State"
add wave -noupdate -color White sim:/tb_top_trigger_corner/dut/current_state
add wave -noupdate -color Green sim:/tb_top_trigger_corner/dut/dtmf_tone_enable

add wave -noupdate -divider "Outputs"
add wave -noupdate -radix hex sim:/tb_top_trigger_corner/HEX5
add wave -noupdate -radix hex sim:/tb_top_trigger_corner/HEX4
add wave -noupdate -radix hex sim:/tb_top_trigger_corner/HEX3
add wave -noupdate -radix hex sim:/tb_top_trigger_corner/HEX2
add wave -noupdate -radix hex sim:/tb_top_trigger_corner/HEX1
add wave -noupdate -radix hex sim:/tb_top_trigger_corner/HEX0
add wave -noupdate -color Red -format analog-step -radix decimal -height 60 -max 32767 -min -32768 sim:/tb_top_trigger_corner/AUD_DACDAT

# Run the simulation (covers all 3 scenarios: ~3.5 ms total sim time)
run 4 ms

wave zoom full

puts ""
puts {=== DONE: tb_top_trigger_corner simulation finished ===}
