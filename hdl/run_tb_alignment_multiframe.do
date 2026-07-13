###############################################################################
# run_tb_alignment_multiframe.do
# Compile + run testbench verifikasi Goertzel Symbol Boundary Alignment
# Skenario: 3 frame berturut-turut tanpa silence
###############################################################################

onerror {abort all}
transcript on

puts ""
puts {=== [1/6] Setup libraries ===}
# Hapus dan buat ulang agar library terdaftar di project .mpf yang aktif.
# vlib bersifat idempotent jika direktori belum ada; jika sudah ada kita hapus dulu.
foreach lib_name {work audiopll local_floatfixlib local_ieee_proposed} {
    if {[file exists $lib_name]} {
        file delete -force $lib_name
    }
    vlib $lib_name
}

vmap floatfixlib   local_floatfixlib
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
vcom -93 -work floatfixlib   ../intelFPGA_lite/18.1/modelsim_ase/vhdl_src/floatfixlib/fixed_float_types_c.vhd
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
vcom -2008 -work work tb_alignment_multiframe.vhd

if {[catch {vsim -quiet -voptargs="+acc" -t 1ps -lib work work.tb_alignment_multiframe} sim_result]} {
    puts ""
    puts {=== ERROR: Elaboration failed ===}
    error $sim_result
}

# --- Setup Waveform Window ---
view wave

# --- Sinyal Alignment (fokus utama perbaikan) ---
add wave -noupdate -divider "=== Alignment FSM (Approach B) ==="
add wave -noupdate -color Yellow sim:/tb_alignment_multiframe/DUT/enable
add wave -noupdate -color Orange sim:/tb_alignment_multiframe/DUT/enable_d
add wave -noupdate -color Cyan   sim:/tb_alignment_multiframe/DUT/align_armed
add wave -noupdate -color Cyan   -radix unsigned sim:/tb_alignment_multiframe/DUT/align_counter
add wave -noupdate -color Green  sim:/tb_alignment_multiframe/DUT/goertzel_aligned
add wave -noupdate -color Red    sim:/tb_alignment_multiframe/DUT/goertzel_enable

# --- Frame Synchronization & DTMF decode ---
add wave -noupdate -divider "=== Frame Collector (DTMF Decoder) ==="
add wave -noupdate sim:/tb_alignment_multiframe/DUT/DTMF_ENCODER_RX/tone_valid
add wave -noupdate -radix hex sim:/tb_alignment_multiframe/DUT/DTMF_ENCODER_RX/code_dtmf
add wave -noupdate -radix hex sim:/tb_alignment_multiframe/DUT/reconstructed_key_32bit
add wave -noupdate -radix hex sim:/tb_alignment_multiframe/DUT/display_key

# --- HEX Output (verifikasi decode, menggantikan internal probes) ---
add wave -noupdate -divider "=== HEX Display (Output Verifikasi) ==="
add wave -noupdate -radix binary sim:/tb_alignment_multiframe/HEX5
add wave -noupdate -radix binary sim:/tb_alignment_multiframe/HEX4
add wave -noupdate -radix binary sim:/tb_alignment_multiframe/HEX3
add wave -noupdate -radix binary sim:/tb_alignment_multiframe/HEX2
add wave -noupdate -radix binary sim:/tb_alignment_multiframe/HEX1
add wave -noupdate -radix binary sim:/tb_alignment_multiframe/HEX0

# --- Transmitter ---
add wave -noupdate -divider "=== Transmitter ==="
add wave -noupdate sim:/tb_alignment_multiframe/DUT/dtmf_tone_enable
add wave -noupdate sim:/tb_alignment_multiframe/DUT/current_state
add wave -noupdate -radix unsigned sim:/tb_alignment_multiframe/DUT/segment_counter
add wave -noupdate -radix hex sim:/tb_alignment_multiframe/DUT/tone_digit

# --- Audio path ---
add wave -noupdate -divider "=== Audio Path ==="
add wave -noupdate -format analog-step -radix decimal -height 60 -max 32767 -min -32768 \
    sim:/tb_alignment_multiframe/DUT/dtmf_lout
add wave -noupdate -format analog-step -radix decimal -height 60 -max 32767 -min -32768 \
    sim:/tb_alignment_multiframe/DUT/Lin
add wave -noupdate sim:/tb_alignment_multiframe/DUT/Ldone

puts ""
puts {=== [6/6] Running simulation (3 frames x ~260ms each = ~800ms total) ===}
puts {    This may take a while. Watch the transcript for PASS/FAIL messages.}
puts ""

run -all

wave zoom full

puts ""
puts {=== DONE: tb_alignment_multiframe simulation finished ===}
