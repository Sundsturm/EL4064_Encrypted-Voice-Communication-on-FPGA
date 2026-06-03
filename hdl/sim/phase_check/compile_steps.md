# 1. Membuat library kerja simulator
vlib work

# 2. Kompilasi modul-modul VHDL (karena letaknya di ../sender_hdl/)
vcom ../sender_hdl/sine_gen_signed.vhd
vcom ../sender_hdl/generate_dtmf_signed.vhd

# 3. Kompilasi testbench Verilog Anda (berada di direktori aktif)
vlog tb_dtmf_tx_phase_check.v

# 4. Jalankan simulasi tanpa mode GUI (konsol saja)
vsim -c -do "run -all" tb_dtmf_tx_phase_check
