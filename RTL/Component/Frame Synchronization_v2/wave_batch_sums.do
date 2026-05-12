# ==================================================
# ModelSim TCL Script: Visualize Frame Sync Batch Sums
# Run this in ModelSim console after compiling
# Usage: do wave_batch_sums.do
# ==================================================

# Restart simulation
restart -force

# Add clock and control signals
add wave -divider "Control"
add wave /toplevel_tb2/clk
add wave /toplevel_tb2/reset
add wave /toplevel_tb2/enable

# Add batch valid indicator
add wave -divider "Batch Valid"
add wave /toplevel_tb2/dbg_batch_valid

# Add batch sums as analog waveforms
add wave -divider "Batch Sums (Analog)"

add wave -format Analog-Step -height 100 -max 10000 -min 0 \
    -color Yellow \
    /toplevel_tb2/dbg_sum697

add wave -format Analog-Step -height 100 -max 10000 -min 0 \
    -color Cyan \
    /toplevel_tb2/dbg_sum941

add wave -format Analog-Step -height 100 -max 10000 -min 0 \
    -color Magenta \
    /toplevel_tb2/dbg_sum1477

# Also add as digital for exact values
add wave -divider "Batch Sums (Digital)"
add wave -radix decimal /toplevel_tb2/dbg_sum697
add wave -radix decimal /toplevel_tb2/dbg_sum941
add wave -radix decimal /toplevel_tb2/dbg_sum1477

# Run simulation
run -all

# Zoom to fit
wave zoom full
