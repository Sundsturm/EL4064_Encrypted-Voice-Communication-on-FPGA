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

# === KONFIGURASI WAVEFORM UNTUK ANALISIS THRESHOLD ===
# Buka jendela wave jika belum terbuka
view wave

# Masukkan sinyal-sinyal penting ke Waveform
add wave -noupdate -divider "Control & Input"
add wave -noupdate -color Yellow sim:/tb_dtmf_integration/clk
add wave -noupdate -color Yellow sim:/tb_dtmf_integration/rst
add wave -noupdate -color Cyan -format analog-step -radix decimal -height 60 -max 32767 -min -32768 sim:/tb_dtmf_integration/audio_loopback
add wave -noupdate sim:/tb_dtmf_integration/sample_tick

add wave -noupdate -divider "Goertzel Power Outputs (Unsigned)"
add wave -noupdate sim:/tb_dtmf_integration/goertzel_out_valid
add wave -noupdate -color Magenta -radix unsigned sim:/tb_dtmf_integration/power_697
add wave -noupdate -color Magenta -radix unsigned sim:/tb_dtmf_integration/power_770
add wave -noupdate -color Magenta -radix unsigned sim:/tb_dtmf_integration/power_852
add wave -noupdate -color Magenta -radix unsigned sim:/tb_dtmf_integration/power_941
add wave -noupdate -color Green -radix unsigned sim:/tb_dtmf_integration/power_1209
add wave -noupdate -color Green -radix unsigned sim:/tb_dtmf_integration/power_1336
add wave -noupdate -color Green -radix unsigned sim:/tb_dtmf_integration/power_1477

add wave -noupdate -divider "Decoder Outputs"
add wave -noupdate -radix binary sim:/tb_dtmf_integration/dtmf_code_4bit
add wave -noupdate sim:/tb_dtmf_integration/payload_symbol_count
add wave -noupdate -radix hex sim:/tb_dtmf_integration/reconstructed_key_out

# TB waits 520 ms before pass/fail assert. Run slightly longer.
run 550 ms

# Format tampilan agar seluruh sinyal muat di layar
wave zoom full

puts ""
puts {=== DONE: tb_dtmf_integration simulation finished ===}
puts {=== Silakan analisis nilai power_* pada Waveform untuk menentukan THRESHOLD ===}

# [PENTING] Comment-out perintah quit di bawah agar GUI ModelSim tidak tertutup otomatis!
# quit -sim
# quit
