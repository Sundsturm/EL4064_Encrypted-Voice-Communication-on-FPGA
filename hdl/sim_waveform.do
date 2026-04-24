###############################################################################
# sim_waveform.do
#
# ModelSim/Questa do-script — Audio_interface Bypass Waveform Simulation
#
# Cara pakai:
#   1. Buka Questa/ModelSim
#   2. Di konsol TCL: cd ke folder hdl/, lalu:
#        do sim_waveform.do
#
# Atau dari direktori Top-Level/:
#        vsim -do hdl/sim_waveform.do
#
# Waveform yang dihasilkan memperlihatkan:
#   - Sinyal clock (XCK, BCLK, LRCK)
#   - Data serial masuk (AUD_ADCDAT)
#   - Data paralel keluar (Lin, Rin)
#   - Pulsa selesai (Ldone, Rdone)
###############################################################################

# ---------------------------------------------------------------------------
# 0. Bersihkan library lama (opsional, keluarkan komentar jika perlu rebuild)
# ---------------------------------------------------------------------------
# if {[file exists work]}    { vdel -lib work    -all }
# if {[file exists audiopll]} { vdel -lib audiopll -all }

# ---------------------------------------------------------------------------
# 1. Buat / verifikasi library
# ---------------------------------------------------------------------------
if {![file exists work]}     { vlib work     ; vmap work work }
if {![file exists audiopll]} { vlib audiopll ; vmap audiopll audiopll }

# ---------------------------------------------------------------------------
# 2. Kompilasi
# ---------------------------------------------------------------------------
vcom -93 -work audiopll ../quartus/AudioPLL_sim/AudioPLL.vho
vcom -93 -work work     i2c.vhd
vcom -93 -work work     Audio_interface.vhd
vlog -work work         tb_audio_bypass.v

# ---------------------------------------------------------------------------
# 3. Mulai simulasi
# ---------------------------------------------------------------------------
vsim -t 1ns -lib work work.tb_audio_bypass

# ---------------------------------------------------------------------------
# 4. Konfigurasi waveform
# ---------------------------------------------------------------------------
quietly WaveActivateNextPane {} 0

# Resolver sederhana untuk hierarchy yang bisa berubah akibat optimisasi.
proc add_wave_any {label color path_list args} {
    foreach p $path_list {
        if {[llength [find signals $p]] > 0} {
            if {[llength $args] > 0} {
                eval add wave -label "$label" -color $color $args $p
            } else {
                add wave -label "$label" -color $color $p
            }
            return
        }
    }
    puts "WARNING: signal '$label' tidak ditemukan pada path kandidat: $path_list"
}

# --- Clocking ---
add wave -divider "=== CLOCKING ==="
add_wave_any "AUD_XCK"     cyan   [list /tb_audio_bypass/AUD_XCK /tb_audio_bypass/dut/AUD_XCK]
add_wave_any "AUD_BCLK"    yellow [list /tb_audio_bypass/AUD_BCLK /tb_audio_bypass/dut/AUD_BCLK]
add_wave_any "AUD_ADCLRCK" orange [list /tb_audio_bypass/AUD_ADCLRCK /tb_audio_bypass/dut/AUD_ADCLRCK]

# --- I2S Serial Data ---
add wave -divider "=== I2S SERIAL ==="
add_wave_any "AUD_ADCDAT"  magenta [list /tb_audio_bypass/AUD_ADCDAT /tb_audio_bypass/dut/AUD_ADCDAT]

# --- Parallel Output (deserialized) ---
add wave -divider "=== OUTPUT PARALEL ==="
add_wave_any "Lin" green [list /tb_audio_bypass/Lin /tb_audio_bypass/dut/Lin] -format analog-step -height 60 -radix decimal
add_wave_any "Rin" lime  [list /tb_audio_bypass/Rin /tb_audio_bypass/dut/Rin] -format analog-step -height 60 -radix decimal

# --- Done pulses ---
add wave -divider "=== DONE PULSES ==="
add_wave_any "Ldone" white [list /tb_audio_bypass/Ldone /tb_audio_bypass/dut/Ldone]
add_wave_any "Rdone" white [list /tb_audio_bypass/Rdone /tb_audio_bypass/dut/Rdone]

# --- DUT Internal (FSM & counter) ---
add wave -divider "=== DUT INTERNAL ==="
add_wave_any "RCV state" pink [list /tb_audio_bypass/dut/RCV]

# ---------------------------------------------------------------------------
# 5. Konfigurasi tampilan
# ---------------------------------------------------------------------------
configure wave -namecolwidth  160
configure wave -valuecolwidth 100
configure wave -justifyvalue  left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns

# ---------------------------------------------------------------------------
# 6. Jalankan simulasi
# ---------------------------------------------------------------------------
run -all

# ---------------------------------------------------------------------------
# 7. Zoom ke area data aktif (lewati ~18 ms inisialisasi I2C)
# ---------------------------------------------------------------------------
wave zoom range 18500000ns 22000000ns

# Simpan waveform ke file (opsional, bisa dibuka ulang dengan:  dataset open sim_waveform.wlf)
# wave write sim_waveform.wlf

echo ""
echo "=== Waveform siap. Gunakan scroll/zoom untuk navigasi. ==="
