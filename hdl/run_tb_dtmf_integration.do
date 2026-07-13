###############################################################################
# run_tb_dtmf_integration.do
# Compile + run dedicated integration testbench: tb_dtmf_integration
###############################################################################

onerror {abort all}
transcript on

puts ""
puts {=== [1/6] Setup libraries ===}
if {![file exists work]}     { vlib work     }
if {![file exists audiopll]} { vlib audiopll }

# Create local directories for floatfixlib and ieee_proposed to prevent 
# modifying the read-only system installation libraries in modern Questa/ModelSim.
if {![file exists local_floatfixlib]}     { vlib local_floatfixlib }
vmap floatfixlib local_floatfixlib

if {![file exists local_ieee_proposed]}   { vlib local_ieee_proposed }
vmap ieee_proposed local_ieee_proposed

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
vcom -2008 -work work receiver_hdl/toplevel_iq_fpga.vhd

vcom -2008 -work work dtmf_detect_hdl/shift_add.vhd
vcom -2008 -work work dtmf_detect_hdl/Goertzel.vhd
vcom -2008 -work work dtmf_detect_hdl/Goertzel_top.vhd
vcom -2008 -work work dtmf_detect_hdl/highcomparator.vhd
vcom -2008 -work work dtmf_detect_hdl/lowcomparator.vhd
vcom -2008 -work work dtmf_detect_hdl/decision.vhd
vcom -2008 -work work dtmf_detect_hdl/top_dtmfencode.vhd

puts ""
puts {=== [5/6] Compile top-level & testbench ===}
vcom -2008 -work work util/uart_rx.vhd
vcom -2008 -work work AcakCakap_Top.vhd
vcom -2008 -work work tb_dtmf_integration.vhd

if {[catch {vsim -quiet -voptargs="+acc" -t 1ps -lib work work.tb_dtmf_integration} sim_result]} {
    puts ""
    puts {=== ERROR: Elaboration failed for work.tb_dtmf_integration ===}
    error $sim_result
}

# --- Setup Waveform Window ---
view wave

add wave -noupdate -divider "System Clock & Reset"
add wave -noupdate -color Yellow sim:/tb_dtmf_integration/CLOCK_50
add wave -noupdate -color Orange sim:/tb_dtmf_integration/KEY
add wave -noupdate -color Violet sim:/tb_dtmf_integration/UART_RXD

add wave -noupdate -divider "FSM Internal State"
add wave -noupdate -color White sim:/tb_dtmf_integration/DUT/current_state
add wave -noupdate -color Green sim:/tb_dtmf_integration/DUT/dtmf_tone_enable
add wave -noupdate -color Cyan sim:/tb_dtmf_integration/DUT/segment_counter

add wave -noupdate -divider "DTMF Transmitter Audio Path"
add wave -noupdate -color Red   -format analog-step -radix decimal -height 60 -max 32767 -min -32768 sim:/tb_dtmf_integration/DUT/dtmf_lout
add wave -noupdate -color Red   sim:/tb_dtmf_integration/AUD_DACDAT
add wave -noupdate -color Blue  sim:/tb_dtmf_integration/AUD_ADCDAT
add wave -noupdate -color Green -format analog-step -radix decimal -height 60 -max 32767 -min -32768 sim:/tb_dtmf_integration/DUT/Lin

add wave -noupdate -divider "Receiver Outputs"
add wave -noupdate                sim:/tb_dtmf_integration/DUT/DTMF_ENCODER_RX/tone_valid
add wave -noupdate -radix hex     sim:/tb_dtmf_integration/DUT/reconstructed_key_32bit
add wave -noupdate -radix hex     sim:/tb_dtmf_integration/probe_key

add wave -noupdate -divider "HEX Display Outputs"
add wave -noupdate -radix hex sim:/tb_dtmf_integration/HEX5
add wave -noupdate -radix hex sim:/tb_dtmf_integration/HEX4
add wave -noupdate -radix hex sim:/tb_dtmf_integration/HEX3
add wave -noupdate -radix hex sim:/tb_dtmf_integration/HEX2
add wave -noupdate -radix hex sim:/tb_dtmf_integration/HEX1
add wave -noupdate -radix hex sim:/tb_dtmf_integration/HEX0

# Testbench owns the bounded wait and calls std.env.finish.
run -all

wave zoom full

puts ""
puts {=== DONE: tb_dtmf_integration simulation finished ===}
