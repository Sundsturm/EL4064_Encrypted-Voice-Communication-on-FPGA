###############################################################################
# run_tb_receiver_v6.do
# Compile + run testbench verifikasi receiver dengan sinyal input v6
################################################################################

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
puts {=== [3/5] Compile receiver HDL files ===}
vcom -2008 -work work receiver_hdl/lutcos_block.vhd
vcom -2008 -work work receiver_hdl/lutsin_block.vhd
vcom -2008 -work work receiver_hdl/multv6.vhd
vcom -2008 -work work receiver_hdl/powercalcv1.vhd
vcom -2008 -work work receiver_hdl/slidingv5.vhd
vcom -2008 -work work receiver_hdl/markingv1.vhd
vcom -2008 -work work receiver_hdl/Framingv2.vhd
vcom -2008 -work work receiver_hdl/flaggingv2.vhd
vcom -2008 -work work receiver_hdl/dec_control.vhd
vcom -2008 -work work receiver_hdl/toplevel_iq_text.vhd

puts ""
puts {=== [4/5] Compile v6-style testbench ===}
vcom -2008 -work work tb_receiver_v6_signal.vhd

if {[catch {vsim -quiet -voptargs="+acc" -t 1ps -lib work work.tb_receiver_v6_signal} sim_result]} {
    puts ""
    puts {=== ERROR: Elaboration failed ===}
    error $sim_result
}

# --- Setup Waveforms (Matching wave_delay14batch.do & wave_batch_sums.do) ---
view wave
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider Control
add wave -noupdate /tb_receiver_v6_signal/clk
add wave -noupdate /tb_receiver_v6_signal/rst
add wave -noupdate /tb_receiver_v6_signal/enable

add wave -noupdate -divider {Batch Valid}
add wave -noupdate /tb_receiver_v6_signal/dbg_batch_valid

add wave -noupdate -divider {Batch Sums (Analog)}
add wave -noupdate -color Yellow -format Analog-Step -height 100 -max 13124.0 -min 0.0 -radix sfixed /tb_receiver_v6_signal/dbg_sum697
add wave -noupdate -color Cyan -format Analog-Step -height 100 -max 16501.0 -min 0.0 -radix sfixed /tb_receiver_v6_signal/dbg_sum941
add wave -noupdate -color Magenta -format Analog-Step -height 100 -max 14523.0 -min 0.0 -radix sfixed /tb_receiver_v6_signal/dbg_sum1477

add wave -noupdate -divider {Batch Sums (Digital)}
add wave -noupdate -radix sfixed /tb_receiver_v6_signal/dbg_sum697
add wave -noupdate -radix sfixed /tb_receiver_v6_signal/dbg_sum941
add wave -noupdate -radix sfixed /tb_receiver_v6_signal/dbg_sum1477

TreeUpdate [SetDefaultTree]
configure wave -namecolwidth 220
configure wave -valuecolwidth 75
configure wave -justifyvalue left
configure wave -signalnamewidth 0
update

puts ""
puts {=== [5/5] Running simulation ===}
run -all
wave zoom full

puts ""
puts {=== DONE: tb_receiver_v6_signal simulation finished ===}
