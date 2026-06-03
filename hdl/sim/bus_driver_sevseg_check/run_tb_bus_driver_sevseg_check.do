###############################################################################
# run_tb_bus_driver_sevseg_check.do
#
# Compile + run dedicated SEVSEG display bus driver testbench
#
# Usage from hdl/sim/bus_driver_sevseg_check/ folder:
#   do run_tb_bus_driver_sevseg_check.do
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
vlog -work work tb_bus_driver_sevseg_check.v

# Tambahkan +acc untuk memastikan sinyal tidak di-optimisasi
if {[catch {vsim -quiet -voptargs="+acc" -t 1ps -lib work work.tb_bus_driver_sevseg_check} sim_result]} {
    puts ""
    puts {=== ERROR: Elaboration failed for work.tb_bus_driver_sevseg_check ===}
    error $sim_result
}

# --- Setup Waveform Window ---
view wave

add wave -noupdate -divider "Control Signals"
add wave -noupdate -color Yellow sim:/tb_bus_driver_sevseg_check/CLOCK_50
add wave -noupdate -color Orange sim:/tb_bus_driver_sevseg_check/SW[0]

add wave -noupdate -divider "Internal Registers"
add wave -noupdate -color White -radix hex sim:/tb_bus_driver_sevseg_check/dut/reconstructed_key_32bit

add wave -noupdate -divider "7-Segment Physical Displays (Active-Low)"
add wave -noupdate -color Cyan -radix hex sim:/tb_bus_driver_sevseg_check/HEX5
add wave -noupdate -color Cyan -radix hex sim:/tb_bus_driver_sevseg_check/HEX4
add wave -noupdate -color Cyan -radix hex sim:/tb_bus_driver_sevseg_check/HEX3
add wave -noupdate -color Cyan -radix hex sim:/tb_bus_driver_sevseg_check/HEX2
add wave -noupdate -color Cyan -radix hex sim:/tb_bus_driver_sevseg_check/HEX1
add wave -noupdate -color Cyan -radix hex sim:/tb_bus_driver_sevseg_check/HEX0

# Run the simulation (20 us total untuk 2 skenario)
run 25 us

wave zoom full

puts ""
puts {=== DONE: tb_bus_driver_sevseg_check simulation finished ===}
