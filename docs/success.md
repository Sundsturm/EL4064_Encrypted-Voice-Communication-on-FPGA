do run_tb_dtmf_integration.do
# 
# puts ""
# 
# puts {=== [1/6] Setup libraries ===}
# === [1/6] Setup libraries ===
# if {![file exists work]}     { vlib work     }
# if {![file exists audiopll]} { vlib audiopll }
# 
# Create local directories for floatfixlib and ieee_proposed to prevent 
# modifying the read-only system installation libraries in modern Questa/ModelSim.
# if {![file exists local_floatfixlib]}     { vlib local_floatfixlib }
# vmap floatfixlib local_floatfixlib
# Questa Altera Starter FPGA Edition-64 vmap 2025.2 Lib Mapping Utility 2025.05 May 31 2025
# vmap floatfixlib local_floatfixlib 
# ** Note: (vmap-220) 'modelsim.ini' is used as the ini file.
# Modifying modelsim.ini
# 
# if {![file exists local_ieee_proposed]}   { vlib local_ieee_proposed }
# vmap ieee_proposed local_ieee_proposed
# Questa Altera Starter FPGA Edition-64 vmap 2025.2 Lib Mapping Utility 2025.05 May 31 2025
# vmap ieee_proposed local_ieee_proposed 
# ** Note: (vmap-220) 'modelsim.ini' is used as the ini file.
# Modifying modelsim.ini
# 
# puts ""
# 
# puts {=== [2/6] Compile PLL / audio base ===}
# === [2/6] Compile PLL / audio base ===
# vcom -2008 -work audiopll ../quartus/AudioPLL_sim/AudioPLL.vho
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:35 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work audiopll ../quartus/AudioPLL_sim/AudioPLL.vho 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Loading package altera_lnsim_components
# -- Compiling entity AudioPLL
# -- Compiling architecture RTL of AudioPLL
# End time: 11:54:35 on Jun 07,2026, Elapsed time: 0:00:00
# Errors: 0, Warnings: 0
# vcom -2008 -work work i2c.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:35 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work i2c.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Loading package NUMERIC_STD
# -- Compiling entity i2c
# -- Compiling architecture rtl of I2C
# End time: 11:54:36 on Jun 07,2026, Elapsed time: 0:00:01
# Errors: 0, Warnings: 0
# vcom -2008 -work work Audio_interface.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:36 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work Audio_interface.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Loading package NUMERIC_STD
# -- Loading package altera_lnsim_components
# -- Loading entity AudioPLL
# -- Compiling entity Audio_interface
# -- Compiling architecture WM8731 of Audio_interface
# -- Loading entity i2c
# End time: 11:54:36 on Jun 07,2026, Elapsed time: 0:00:00
# Errors: 0, Warnings: 0
# 
# puts ""
# 
# puts {=== [3/6] Compile DTMF sender ===}
# === [3/6] Compile DTMF sender ===
# vcom -2008 -work work sender_hdl/sine_gen_signed.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:36 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work sender_hdl/sine_gen_signed.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Loading package NUMERIC_STD
# -- Loading package MATH_REAL
# -- Compiling entity sine_gen_signed
# -- Compiling architecture rtl of sine_gen_signed
# End time: 11:54:36 on Jun 07,2026, Elapsed time: 0:00:00
# Errors: 0, Warnings: 0
# vcom -2008 -work work sender_hdl/generate_dtmf_signed.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:36 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work sender_hdl/generate_dtmf_signed.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Loading package NUMERIC_STD
# -- Loading package MATH_REAL
# -- Compiling entity generate_dtmf_signed
# -- Compiling architecture rtl of generate_dtmf_signed
# -- Loading entity sine_gen_signed
# End time: 11:54:36 on Jun 07,2026, Elapsed time: 0:00:00
# Errors: 0, Warnings: 0
# 
# puts ""
# 
# puts {=== [3.5/6] Compile fixed-point support libraries ===}
# === [3.5/6] Compile fixed-point support libraries ===
# vcom -93 -work floatfixlib ../intelFPGA_lite/18.1/modelsim_ase/vhdl_src/floatfixlib/fixed_float_types_c.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:37 on Jun 07,2026
# vcom -reportprogress 300 -93 -work floatfixlib ../intelFPGA_lite/18.1/modelsim_ase/vhdl_src/floatfixlib/fixed_float_types_c.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Compiling package fixed_float_types
# End time: 11:54:37 on Jun 07,2026, Elapsed time: 0:00:00
# Errors: 0, Warnings: 0
# vcom -93 -work ieee_proposed ../intelFPGA_lite/18.1/modelsim_ase/vhdl_src/floatfixlib/fixed_pkg_c.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:37 on Jun 07,2026
# vcom -reportprogress 300 -93 -work ieee_proposed ../intelFPGA_lite/18.1/modelsim_ase/vhdl_src/floatfixlib/fixed_pkg_c.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Loading package NUMERIC_STD
# -- Loading package fixed_float_types
# -- Compiling package fixed_pkg
# -- Loading package MATH_REAL
# -- Compiling package body fixed_pkg
# -- Loading package fixed_pkg
# ** Warning: ../intelFPGA_lite/18.1/modelsim_ase/vhdl_src/floatfixlib/fixed_pkg_c.vhd(1470): (vcom-1246) Range 0 downto 1 is null.
# ** Warning: ../intelFPGA_lite/18.1/modelsim_ase/vhdl_src/floatfixlib/fixed_pkg_c.vhd(1471): (vcom-1246) Range 0 downto 1 is null.
# ** Warning: ../intelFPGA_lite/18.1/modelsim_ase/vhdl_src/floatfixlib/fixed_pkg_c.vhd(1472): (vcom-1246) Range 0 downto 1 is null.
# ** Warning: ../intelFPGA_lite/18.1/modelsim_ase/vhdl_src/floatfixlib/fixed_pkg_c.vhd(6873): (vcom-1246) Range 2 to 1 is null.
# End time: 11:54:37 on Jun 07,2026, Elapsed time: 0:00:00
# Errors: 0, Warnings: 4
# 
# puts ""
# 
# puts {=== [4/6] Compile DTMF detector and receiver ===}
# === [4/6] Compile DTMF detector and receiver ===
# vcom -2008 -work work receiver_hdl/lutcos_block.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:37 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work receiver_hdl/lutcos_block.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Loading package NUMERIC_STD
# -- Compiling entity lutcos_block
# -- Compiling architecture Behavioral of lutcos_block
# End time: 11:54:37 on Jun 07,2026, Elapsed time: 0:00:00
# Errors: 0, Warnings: 0
# vcom -2008 -work work receiver_hdl/lutsin_block.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:38 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work receiver_hdl/lutsin_block.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Loading package NUMERIC_STD
# -- Compiling entity lutsin_block
# -- Compiling architecture Behavioral of lutsin_block
# End time: 11:54:38 on Jun 07,2026, Elapsed time: 0:00:00
# Errors: 0, Warnings: 0
# vcom -2008 -work work receiver_hdl/multv6.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:38 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work receiver_hdl/multv6.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Loading package NUMERIC_STD
# -- Loading package instance fixed_pkg
# -- Loading package fixed_float_types
# -- Loading package fixed_generic_pkg
# -- Loading package MATH_REAL
# -- Loading package body fixed_generic_pkg
# -- Compiling entity multv6
# -- Compiling architecture Behavioral of multv6
# End time: 11:54:38 on Jun 07,2026, Elapsed time: 0:00:00
# Errors: 0, Warnings: 0
# vcom -2008 -work work receiver_hdl/powercalcv1.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:38 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work receiver_hdl/powercalcv1.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Loading package NUMERIC_STD
# -- Loading package instance fixed_pkg
# -- Loading package fixed_float_types
# -- Loading package fixed_generic_pkg
# -- Loading package MATH_REAL
# -- Loading package body fixed_generic_pkg
# -- Compiling entity powercalcv1
# -- Compiling architecture Behavioral of powercalcv1
# End time: 11:54:38 on Jun 07,2026, Elapsed time: 0:00:00
# Errors: 0, Warnings: 0
# vcom -2008 -work work receiver_hdl/slidingv5.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:38 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work receiver_hdl/slidingv5.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Loading package NUMERIC_STD
# -- Loading package instance fixed_pkg
# -- Loading package fixed_float_types
# -- Loading package fixed_generic_pkg
# -- Loading package MATH_REAL
# -- Loading package body fixed_generic_pkg
# -- Compiling entity slidingv5
# -- Compiling architecture Behavioral of slidingv5
# End time: 11:54:39 on Jun 07,2026, Elapsed time: 0:00:01
# Errors: 0, Warnings: 0
# vcom -2008 -work work receiver_hdl/markingv1.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:39 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work receiver_hdl/markingv1.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Loading package NUMERIC_STD
# -- Loading package instance fixed_pkg
# -- Loading package fixed_float_types
# -- Loading package fixed_generic_pkg
# -- Loading package MATH_REAL
# -- Loading package body fixed_generic_pkg
# -- Compiling entity markingv1
# -- Compiling architecture Behavioral of markingv1
# End time: 11:54:39 on Jun 07,2026, Elapsed time: 0:00:00
# Errors: 0, Warnings: 0
# vcom -2008 -work work receiver_hdl/Framingv2.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:39 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work receiver_hdl/Framingv2.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Loading package NUMERIC_STD
# -- Loading package instance fixed_pkg
# -- Loading package fixed_float_types
# -- Loading package fixed_generic_pkg
# -- Loading package MATH_REAL
# -- Loading package body fixed_generic_pkg
# -- Compiling entity Framingv2
# -- Compiling architecture Behavioral of Framingv2
# End time: 11:54:39 on Jun 07,2026, Elapsed time: 0:00:00
# Errors: 0, Warnings: 0
# vcom -2008 -work work receiver_hdl/flaggingv2.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:39 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work receiver_hdl/flaggingv2.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Loading package NUMERIC_STD
# -- Loading package instance fixed_pkg
# -- Loading package fixed_float_types
# -- Loading package fixed_generic_pkg
# -- Loading package MATH_REAL
# -- Loading package body fixed_generic_pkg
# -- Compiling entity flaggingv2
# -- Compiling architecture Behavioral of flaggingv2
# End time: 11:54:40 on Jun 07,2026, Elapsed time: 0:00:01
# Errors: 0, Warnings: 0
# vcom -2008 -work work receiver_hdl/dec_control.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:40 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work receiver_hdl/dec_control.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Loading package NUMERIC_STD
# -- Compiling entity dec_control
# -- Compiling architecture Behavioral of dec_control
# End time: 11:54:40 on Jun 07,2026, Elapsed time: 0:00:00
# Errors: 0, Warnings: 0
# vcom -2008 -work work receiver_hdl/toplevel_iq.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:40 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work receiver_hdl/toplevel_iq.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Loading package NUMERIC_STD
# -- Loading package instance fixed_pkg
# -- Loading package fixed_float_types
# -- Loading package fixed_generic_pkg
# -- Loading package MATH_REAL
# -- Loading package body fixed_generic_pkg
# -- Compiling entity toplevel_iq
# -- Compiling architecture Behavioral of toplevel_iq
# End time: 11:54:40 on Jun 07,2026, Elapsed time: 0:00:00
# Errors: 0, Warnings: 0
# 
# vcom -2008 -work work dtmf_detect_hdl/shift_add.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:40 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work dtmf_detect_hdl/shift_add.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Loading package NUMERIC_STD
# -- Compiling entity shift_add
# -- Compiling architecture Behavioral of shift_add
# End time: 11:54:40 on Jun 07,2026, Elapsed time: 0:00:00
# Errors: 0, Warnings: 0
# vcom -2008 -work work dtmf_detect_hdl/Goertzel.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:41 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work dtmf_detect_hdl/Goertzel.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Loading package NUMERIC_STD
# -- Loading package MATH_REAL
# -- Loading package fixed_float_types
# -- Loading package fixed_pkg
# -- Compiling entity Goertzel
# -- Compiling architecture rtl of Goertzel
# End time: 11:54:41 on Jun 07,2026, Elapsed time: 0:00:00
# Errors: 0, Warnings: 0
# vcom -2008 -work work dtmf_detect_hdl/Goertzel_top.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:41 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work dtmf_detect_hdl/Goertzel_top.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Loading package NUMERIC_STD
# -- Loading package MATH_REAL
# -- Loading package fixed_float_types
# -- Loading package fixed_pkg
# -- Compiling entity Goertzel_top
# -- Compiling architecture rtl of Goertzel_top
# -- Loading entity Goertzel
# End time: 11:54:41 on Jun 07,2026, Elapsed time: 0:00:00
# Errors: 0, Warnings: 0
# vcom -2008 -work work dtmf_detect_hdl/highcomparator.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:41 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work dtmf_detect_hdl/highcomparator.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Compiling entity highcomparator
# -- Compiling architecture Behavioral of highcomparator
# End time: 11:54:41 on Jun 07,2026, Elapsed time: 0:00:00
# Errors: 0, Warnings: 0
# vcom -2008 -work work dtmf_detect_hdl/lowcomparator.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:42 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work dtmf_detect_hdl/lowcomparator.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Compiling entity lowcomparator
# -- Compiling architecture Behavioral of lowcomparator
# End time: 11:54:42 on Jun 07,2026, Elapsed time: 0:00:00
# Errors: 0, Warnings: 0
# vcom -2008 -work work dtmf_detect_hdl/decision.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:42 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work dtmf_detect_hdl/decision.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Compiling entity decision
# -- Compiling architecture Behavioral of decision
# End time: 11:54:42 on Jun 07,2026, Elapsed time: 0:00:00
# Errors: 0, Warnings: 0
# vcom -2008 -work work dtmf_detect_hdl/top_dtmfencode.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:42 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work dtmf_detect_hdl/top_dtmfencode.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Loading package std_logic_arith
# -- Loading package STD_LOGIC_UNSIGNED
# -- Compiling entity top_dtmfencode
# -- Compiling architecture Behavioral of top_dtmfencode
# End time: 11:54:43 on Jun 07,2026, Elapsed time: 0:00:01
# Errors: 0, Warnings: 0
# 
# puts ""
# 
# puts {=== [5/6] Compile top-level & testbench ===}
# === [5/6] Compile top-level & testbench ===
# vcom -2008 -work work util/uart_rx.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:43 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work util/uart_rx.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Loading package NUMERIC_STD
# -- Compiling entity uart_rx
# -- Compiling architecture rtl of uart_rx
# End time: 11:54:43 on Jun 07,2026, Elapsed time: 0:00:00
# Errors: 0, Warnings: 0
# vcom -2008 -work work AcakCakap_Top.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:43 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work AcakCakap_Top.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Loading package NUMERIC_STD
# -- Compiling entity AcakCakap_Top
# -- Compiling architecture rtl of AcakCakap_Top
# -- Loading package altera_lnsim_components
# -- Loading entity AudioPLL
# -- Loading entity Audio_interface
# -- Loading package MATH_REAL
# -- Loading entity generate_dtmf_signed
# -- Loading entity uart_rx
# -- Loading package instance fixed_pkg
# -- Loading package fixed_float_types
# -- Loading package fixed_generic_pkg
# -- Loading package body fixed_generic_pkg
# -- Loading entity toplevel_iq
# -- Loading package fixed_float_types
# -- Loading package fixed_pkg
# -- Loading entity Goertzel_top
# -- Loading package std_logic_arith
# -- Loading package STD_LOGIC_UNSIGNED
# -- Loading entity top_dtmfencode
# -- Loading entity shift_add
# End time: 11:54:43 on Jun 07,2026, Elapsed time: 0:00:00
# Errors: 0, Warnings: 0
# vcom -2008 -work work tb_dtmf_integration.vhd
# Questa Altera Starter FPGA Edition-64 vcom 2025.2 Compiler 2025.05 May 31 2025
# Start time: 11:54:43 on Jun 07,2026
# vcom -reportprogress 300 -2008 -work work tb_dtmf_integration.vhd 
# ** Note: (vcom-220) 'modelsim.ini' is used as the ini file.
# -- Loading package STANDARD
# -- Loading package TEXTIO
# -- Loading package std_logic_1164
# -- Loading package NUMERIC_STD
# -- Compiling entity tb_dtmf_integration
# -- Compiling architecture sim of tb_dtmf_integration
# -- Loading entity AcakCakap_Top
# -- Loading package ENV
# End time: 11:54:44 on Jun 07,2026, Elapsed time: 0:00:01
# Errors: 0, Warnings: 0
# 
# if {[catch {vsim -quiet -voptargs="+acc" -t 1ps -lib work work.tb_dtmf_integration} sim_result]} {
#     puts ""
#     puts {=== ERROR: Elaboration failed for work.tb_dtmf_integration ===}
#     error $sim_result
# }
# End time: 11:54:47 on Jun 07,2026, Elapsed time: 0:42:32
# Errors: 1, Warnings: 19
# ** Note: (vsim-220) 'modelsim.ini' is used as the ini file.
# vsim -quiet -voptargs=""+acc"" -t 1ps -lib work work.tb_dtmf_integration 
# Start time: 11:54:47 on Jun 07,2026
# ** Note: (vsim-3813) Design is being optimized due to module recompilation...
# ** Warning: (vopt-10908) Some optimizations are turned off because the +acc switch is in effect.
# ** Note: (vopt-220) 'modelsim.ini' is used as the ini file.
# ** Note: (vopt-143) Recognized 1 FSM in architecture body "top_dtmfencode(Behavioral)".
# ** Note: (vsim-12126) Error and warning message counts have been restored: Errors=0, Warnings=1.
# ** Warning: (vsim-8683) Uninitialized out port /tb_dtmf_integration/DUT/LEDR(9 downto 0) has no driver.
# This port will contribute value (10'hXXX) to the signal network.
# 
# --- Setup Waveform Window ---
# view wave
# .main_pane.wave.interior.cs.body.pw.wf
# 
# add wave -noupdate -divider "System Clock & Reset"
# add wave -noupdate -color Yellow sim:/tb_dtmf_integration/CLOCK_50
# add wave -noupdate -color Orange sim:/tb_dtmf_integration/KEY
# add wave -noupdate -color Violet sim:/tb_dtmf_integration/UART_RXD
# 
# add wave -noupdate -divider "FSM Internal State"
# add wave -noupdate -color White sim:/tb_dtmf_integration/DUT/current_state
# add wave -noupdate -color Green sim:/tb_dtmf_integration/DUT/dtmf_tone_enable
# add wave -noupdate -color Cyan sim:/tb_dtmf_integration/DUT/segment_counter
# 
# add wave -noupdate -divider "DTMF Transmitter Audio Path"
# add wave -noupdate -color Red   -format analog-step -radix decimal -height 60 -max 32767 -min -32768 sim:/tb_dtmf_integration/DUT/dtmf_lout
# add wave -noupdate -color Red   sim:/tb_dtmf_integration/AUD_DACDAT
# add wave -noupdate -color Blue  sim:/tb_dtmf_integration/AUD_ADCDAT
# add wave -noupdate -color Green -format analog-step -radix decimal -height 60 -max 32767 -min -32768 sim:/tb_dtmf_integration/DUT/Lin
# 
# add wave -noupdate -divider "Receiver Outputs"
# add wave -noupdate -radix binary sim:/tb_dtmf_integration/DUT/dtmf_code_4bit
# add wave -noupdate                sim:/tb_dtmf_integration/DUT/dtmf_code_valid
# add wave -noupdate                sim:/tb_dtmf_integration/DUT/DTMF_ENCODER_RX/tone_valid
# add wave -noupdate                sim:/tb_dtmf_integration/DUT/DTMF_ENCODER_RX/frame_state
# add wave -noupdate                sim:/tb_dtmf_integration/DUT/DTMF_ENCODER_RX/frame_done
# add wave -noupdate -radix hex     sim:/tb_dtmf_integration/DUT/reconstructed_key_32bit
# add wave -noupdate -radix hex     sim:/tb_dtmf_integration/probe_key
# 
# add wave -noupdate -divider "HEX Display Outputs"
# add wave -noupdate -radix hex sim:/tb_dtmf_integration/HEX5
# add wave -noupdate -radix hex sim:/tb_dtmf_integration/HEX4
# add wave -noupdate -radix hex sim:/tb_dtmf_integration/HEX3
# add wave -noupdate -radix hex sim:/tb_dtmf_integration/HEX2
# add wave -noupdate -radix hex sim:/tb_dtmf_integration/HEX1
# add wave -noupdate -radix hex sim:/tb_dtmf_integration/HEX0
# 
# Testbench owns the bounded wait and calls std.env.finish.
# run -all
# ** Warning: NUMERIC_STD.TO_INTEGER: metavalue detected, returning 0
#    Time: 0 ps  Iteration: 0  Instance: /tb_dtmf_integration/DUT/DTMF_corr/lutcos_unit
# ** Warning: NUMERIC_STD.TO_INTEGER: metavalue detected, returning 0
#    Time: 0 ps  Iteration: 0  Instance: /tb_dtmf_integration/DUT/DTMF_corr/lutcos_unit
# ** Warning: NUMERIC_STD.TO_INTEGER: metavalue detected, returning 0
#    Time: 0 ps  Iteration: 0  Instance: /tb_dtmf_integration/DUT/DTMF_corr/lutcos_unit
# ** Warning: NUMERIC_STD.TO_INTEGER: metavalue detected, returning 0
#    Time: 0 ps  Iteration: 0  Instance: /tb_dtmf_integration/DUT/DTMF_corr/lutsin_unit
# ** Warning: NUMERIC_STD.TO_INTEGER: metavalue detected, returning 0
#    Time: 0 ps  Iteration: 0  Instance: /tb_dtmf_integration/DUT/DTMF_corr/lutsin_unit
# ** Warning: NUMERIC_STD.TO_INTEGER: metavalue detected, returning 0
#    Time: 0 ps  Iteration: 0  Instance: /tb_dtmf_integration/DUT/DTMF_corr/lutsin_unit
# Info: hierarchical_name = tb_dtmf_integration.DUT.Audio_interface.Audio_PLL.audiopll_altera_pll_altera_pll_i_639.new_model.gpll.no_need_to_gen
# Adjusting output period from 54253.472222 to 53932.584270
# Info: =================================================
# Info:           Generic PLL Summary
# Info: =================================================
# Time scale of (tb_dtmf_integration.DUT.Audio_interface.Audio_PLL.audiopll_altera_pll_altera_pll_i_639.new_model.gpll.no_need_to_gen) is  1ps /  1ps
# Info: hierarchical_name = tb_dtmf_integration.DUT.Audio_interface.Audio_PLL.audiopll_altera_pll_altera_pll_i_639.new_model.gpll.no_need_to_gen
# Info: reference_clock_frequency = 50.0 MHz
# Info: output_clock_frequency = 18.432 MHZ
# Info: phase_shift = 0 ps
# Info: duty_cycle = 50
# Info: sim_additional_refclk_cycles_to_lock = 0
# Info: output_clock_high_period = 26966.292135
# Info: output_clock_low_period = 26966.292135
# ** Note: [TESTBENCH] Waiting for I2C and PLL to settle (20ms)...
#    Time: 100 ns  Iteration: 0  Instance: /tb_dtmf_integration
# ** Note: [TESTBENCH] Sending dynamic key: 0x3A7C9B1D via UART...
#    Time: 20000100 ns  Iteration: 0  Instance: /tb_dtmf_integration
# ** Note: [TESTBENCH] Pressing KEY(1) to trigger manual transmission...
#    Time: 21434125 ns  Iteration: 0  Instance: /tb_dtmf_integration
# ** Note: [TESTBENCH] Transmission started! Waiting 250ms for nominal TX completion...
#    Time: 21934125 ns  Iteration: 0  Instance: /tb_dtmf_integration
# ** Warning: :ieee:fixed_generic_pkg:">=": metavalue detected, returning FALSE
#    Time: 78136197638 ps  Iteration: 3  Instance: /tb_dtmf_integration/DUT/DTMF_corr/flag_unit
# ** Warning: :ieee:fixed_generic_pkg:">=": metavalue detected, returning FALSE
#    Time: 78136197638 ps  Iteration: 3  Instance: /tb_dtmf_integration/DUT/DTMF_corr/flag_unit
# ** Warning: :ieee:fixed_generic_pkg:">=": metavalue detected, returning FALSE
#    Time: 79378804378 ps  Iteration: 3  Instance: /tb_dtmf_integration/DUT/DTMF_corr/flag_unit
# ** Warning: :ieee:fixed_generic_pkg:">=": metavalue detected, returning FALSE
#    Time: 79378804378 ps  Iteration: 3  Instance: /tb_dtmf_integration/DUT/DTMF_corr/flag_unit
# ** Warning: :ieee:fixed_generic_pkg:">=": metavalue detected, returning FALSE
#    Time: 80621411122 ps  Iteration: 3  Instance: /tb_dtmf_integration/DUT/DTMF_corr/flag_unit
# ** Warning: :ieee:fixed_generic_pkg:">=": metavalue detected, returning FALSE
#    Time: 80621411122 ps  Iteration: 3  Instance: /tb_dtmf_integration/DUT/DTMF_corr/flag_unit
# ** Note: [TESTBENCH] === TUGAS 3: Checking macro assertions ===
#    Time: 271934125 ns  Iteration: 0  Instance: /tb_dtmf_integration
# ** Note: [TESTBENCH] Checking visualization for LSB (SW(0) = '0')...
#    Time: 271934125 ns  Iteration: 0  Instance: /tb_dtmf_integration
# ** Note: [TESTBENCH] LSB Check PASSED. (7C9B1D displayed correctly)
#    Time: 271935125 ns  Iteration: 0  Instance: /tb_dtmf_integration
# ** Note: [TESTBENCH] Checking visualization for MSB (SW(0) = '1')...
#    Time: 271935125 ns  Iteration: 0  Instance: /tb_dtmf_integration
# ** Note: [TESTBENCH] MSB Check PASSED. (3A displayed correctly)
#    Time: 271936125 ns  Iteration: 0  Instance: /tb_dtmf_integration
# ** Note: [TESTBENCH] Key register Check PASSED. Value = 0x3A7C9B1D
#    Time: 271936125 ns  Iteration: 0  Instance: /tb_dtmf_integration
# ** Note: ================== INTEGRATION TEST: PASS (Zero Bit Errors) ==================
#    Time: 271936125 ns  Iteration: 0  Instance: /tb_dtmf_integration
# 1
# Break in Process STIM_PROC at tb_dtmf_integration.vhd line 279
# 
# wave zoom full
# 0 ps
# 285532931250 ps
# 
# puts ""
# 
# puts {=== DONE: tb_dtmf_integration simulation finished ===}
# === DONE: tb_dtmf_integration simulation finished ===

