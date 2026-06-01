onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider Control
add wave -noupdate /toplevel_tb2/clk
add wave -noupdate /toplevel_tb2/reset
add wave -noupdate /toplevel_tb2/enable
add wave -noupdate -divider {Batch Valid}
add wave -noupdate /toplevel_tb2/dbg_batch_valid
add wave -noupdate -divider {Batch Sums (Analog)}
add wave -noupdate -color Yellow -format Analog-Step -height 100 -max 13124.0 -min 317.0 -radix sfixed /toplevel_tb2/dbg_sum697
add wave -noupdate -color Cyan -format Analog-Step -height 100 -max 16501.0 -min 126.0 -radix sfixed /toplevel_tb2/dbg_sum941
add wave -noupdate -color Magenta -format Analog-Step -height 100 -max 14523.0 -min 44.0 -radix sfixed /toplevel_tb2/dbg_sum1477
add wave -noupdate -divider {Batch Sums (Digital)}
add wave -noupdate -radix sfixed /toplevel_tb2/dbg_sum697
add wave -noupdate -radix sfixed /toplevel_tb2/dbg_sum941
add wave -noupdate -radix sfixed /toplevel_tb2/dbg_sum1477
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 199
configure wave -valuecolwidth 71
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {323011500 ps}
