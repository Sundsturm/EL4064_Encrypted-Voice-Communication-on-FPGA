# =============================================================================
# run_sim.do — ModelSim script untuk DecodeDTMF_v2
# Usage: Di ModelSim console, cd ke folder hdl/, lalu: do run_sim.do
#
# Pilih MODE dengan set variable di bawah:
#   set MODE "unit"   -> top_dtmfencode_tb_v2 (CEPAT, tanpa Goertzel)
#   set MODE "system" -> dtmf_system_tb (LENGKAP, dengan Goertzel)
# =============================================================================

set MODE "unit"
# set MODE "system"

# --- Bersihkan library lama ---
if {[file exists work]} { vdel -lib work -all }
vlib work
vmap work work

# =============================================================================
# MODE "unit" — Compile minimal untuk top_dtmfencode_tb_v2
# File yang DIBUTUHKAN: 5 RTL + 1 testbench
# Tidak perlu: Goertzel, Audio_interface, DecodeDTMF, audiopll
# =============================================================================
if {$MODE eq "unit"} {
    puts "\n*** MODE: unit test (top_dtmfencode_tb_v2) ***\n"

    vcom -work work lowcomparator.vhd
    vcom -work work highcomparator.vhd
    vcom -work work decision.vhd
    vcom -work work shift_add.vhd
    vcom -work work top_dtmfencode.vhd

    vcom -work work top_dtmfencode_tb_v2.vhd

    vsim -t 1ns work.top_dtmfencode_tb_v2

    add wave -divider "=== CONTROL ==="
    add wave -hex sim:/top_dtmfencode_tb_v2/clk
    add wave -hex sim:/top_dtmfencode_tb_v2/rst
    add wave -hex sim:/top_dtmfencode_tb_v2/in_valid
    add wave -hex sim:/top_dtmfencode_tb_v2/in_ready
    add wave -hex sim:/top_dtmfencode_tb_v2/out_valid

    add wave -divider "=== LOW GROUP ==="
    add wave -unsigned sim:/top_dtmfencode_tb_v2/corr_697
    add wave -unsigned sim:/top_dtmfencode_tb_v2/corr_770
    add wave -unsigned sim:/top_dtmfencode_tb_v2/corr_852
    add wave -unsigned sim:/top_dtmfencode_tb_v2/corr_941

    add wave -divider "=== HIGH GROUP ==="
    add wave -unsigned sim:/top_dtmfencode_tb_v2/corr_1209
    add wave -unsigned sim:/top_dtmfencode_tb_v2/corr_1336
    add wave -unsigned sim:/top_dtmfencode_tb_v2/corr_1477
    add wave -unsigned sim:/top_dtmfencode_tb_v2/corr_1633

    add wave -divider "=== OUTPUT ==="
    add wave -hex    sim:/top_dtmfencode_tb_v2/encode_out
    add wave -binary sim:/top_dtmfencode_tb_v2/sevseg

    run 5 us
    wave zoom full
}

# =============================================================================
# MODE "system" — Compile lengkap untuk dtmf_system_tb
# File yang DIBUTUHKAN: Goertzel(-2008) + 5 RTL + dtmf_system + testbench
# Tidak perlu: Audio_interface, DecodeDTMF, audiopll
# =============================================================================
if {$MODE eq "system"} {
    puts "\n*** MODE: system test (dtmf_system_tb) ***\n"

    vcom -2008 -work work Goertzel.vhd
    vcom -2008 -work work Goertzel_top.vhd

    vcom -work work lowcomparator.vhd
    vcom -work work highcomparator.vhd
    vcom -work work decision.vhd
    vcom -work work shift_add.vhd
    vcom -work work top_dtmfencode.vhd
    vcom -work work dtmf_system.vhd

    vcom -work work dtmf_system_tb.vhd

    vsim -t 1ns work.dtmf_system_tb

    add wave -divider "=== CONTROL ==="
    add wave -hex sim:/dtmf_system_tb/clk
    add wave -hex sim:/dtmf_system_tb/rst
    add wave -hex sim:/dtmf_system_tb/in_valid
    add wave -hex sim:/dtmf_system_tb/in_ready
    add wave -hex sim:/dtmf_system_tb/out_valid

    add wave -divider "=== OUTPUT ==="
    add wave -hex sim:/dtmf_system_tb/encode_out
    add wave -binary sim:/dtmf_system_tb/sevseg

    run 200 ms
    wave zoom full
}
