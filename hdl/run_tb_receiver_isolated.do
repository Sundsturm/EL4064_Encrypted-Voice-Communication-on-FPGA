###############################################################################
# run_tb_receiver_isolated.do
# Compile + run testbench verifikasi receiver terisolasi secara cepat
###############################################################################

onerror {abort all}
transcript on

puts ""
puts {=== [1/5] Setup libraries ===}
foreach lib_name {work local_floatfixlib local_ieee_proposed} {
    if {[file exists $lib_name]} {
        file delete -force $lib_name
    }
    vlib $lib_name
}

vmap floatfixlib   local_floatfixlib
vmap ieee_proposed local_ieee_proposed

puts ""
puts {=== [2/5] Compile fixed-point support libraries ===}
vcom -93 -work floatfixlib   ../intelFPGA_lite/18.1/modelsim_ase/vhdl_src/floatfixlib/fixed_float_types_c.vhd
vcom -93 -work ieee_proposed ../intelFPGA_lite/18.1/modelsim_ase/vhdl_src/floatfixlib/fixed_pkg_c.vhd

puts ""
puts {=== [3/5] Compile receiver & decoder HDL files ===}
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

puts ""
puts {=== [3.5/5] Compile transmitter files ===}
vcom -2008 -work work sender_hdl/sine_gen_signed.vhd
vcom -2008 -work work sender_hdl/generate_dtmf_signed.vhd

puts ""
puts {=== [4/5] Compile isolated testbench ===}
vcom -2008 -work work tb_receiver_isolated.vhd

if {[catch {vsim -quiet -voptargs="+acc" -t 1ps -lib work work.tb_receiver_isolated} sim_result]} {
    puts ""
    puts {=== ERROR: Elaboration failed ===}
    error $sim_result
}

# --- Setup Waveforms ---
view wave
add wave -noupdate -divider "=== Control ==="
add wave -noupdate sim:/tb_receiver_isolated/clk
add wave -noupdate sim:/tb_receiver_isolated/rst
add wave -noupdate sim:/tb_receiver_isolated/rx_rst
add wave -noupdate sim:/tb_receiver_isolated/Ldone
add wave -noupdate -format analog-step -radix decimal -height 50 sim:/tb_receiver_isolated/Lin

add wave -noupdate -divider "=== Frame Sync (toplevel_iq) ==="
add wave -noupdate sim:/tb_receiver_isolated/enable
add wave -noupdate sim:/tb_receiver_isolated/DTMF_corr/flag_unit/full

add wave -noupdate -divider "=== Alignment FSM ==="
add wave -noupdate sim:/tb_receiver_isolated/goertzel_aligned
add wave -noupdate sim:/tb_receiver_isolated/goertzel_enable

add wave -noupdate -divider "=== Goertzel & Decoder ==="
add wave -noupdate sim:/tb_receiver_isolated/goertzel_out_valid
add wave -noupdate sim:/tb_receiver_isolated/DTMF_ENCODER_RX/key_collector/state
add wave -noupdate sim:/tb_receiver_isolated/DTMF_ENCODER_RX/tone_valid
add wave -noupdate -radix hex sim:/tb_receiver_isolated/DTMF_ENCODER_RX/code_dtmf
add wave -noupdate sim:/tb_receiver_isolated/out_valid
add wave -noupdate -radix hex sim:/tb_receiver_isolated/reconstructed_key

puts ""
puts {=== [5/5] Running simulation ===}
run -all
wave zoom full

puts ""
puts {=== DONE: tb_receiver_isolated simulation finished ===}
