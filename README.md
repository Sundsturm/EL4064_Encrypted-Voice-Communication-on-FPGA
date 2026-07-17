# AcakCakap: Encrypted Voice-Band DTMF Transceiver on FPGA

A high-performance, real-time 32-bit voice-band modem implemented on an Altera Cyclone V FPGA, designed to transmit and reconstruct secure digital keys over analog audio channels using Dual-Tone Multi-Frequency (DTMF) signaling.

---

## 1. Problem Statement and Motivation

Secure key exchange over analog voice-band channels (e.g., analog telephone lines, radio networks, or low-cost auxiliary cables) is subject to channel noise, attenuation, and phase distortion. Traditional digital modem architectures can be overly complex for simple key exchange tasks, while standard DTMF decoders suffer from high latency and poor sensitivity in low-gain environments.

**AcakCakap** solves this by implementing a hardware-accelerated transceiver on an FPGA. The system leverages:
- An **I/Q Correlator Preamble Detector** to achieve fast clock phase-alignment and frame synchronization.
- A parallel **Goertzel Filter Bank** to perform real-time frequency-domain demodulation of key payloads.
- An optimized **analog-to-digital front-end** using the Wolfson WM8731 codec at 0 dB unity gain, achieving 0% frame loss even in noisy and attenuated channels.

---

## 2. Key Features

- **Transceiver Architecture (TX/RX):** Separate, fully pipelined transmitter and receiver cores running synchronously with the audio sample clock.
- **NCO Sine Synthesizer:** A 32-bit phase accumulator Numerically Controlled Oscillator (NCO) with quadrant-mapping look-up tables (LUT) for low-distortion analog DTMF generation.
- **Quadratic I/Q Correlator:** Concurrently correlates audio samples with local sine/cos references to detect a custom `##3#` (`F, F, 3, F` hex) preamble sequence for sub-millisecond receiver triggering.
- **Parallel Goertzel DFT Bank:** Bank of 8 parallel Goertzel filters with optimized fixed-point coefficient arithmetic (Q2.14 for coefficients, Q13.3 for internal states) to prevent overflow while saving FPGA DSP blocks.
- **UART Interface:** Integrated 115200 bps UART receiver with clock-domain crossing (2-FF synchronizer) for dynamic 32-bit key injection from host PCs.
- **Codec & I2C Control:** Dedicated I2C master to boot and configure the Wolfson WM8731 codec at a 32 kHz sampling rate, 16-bit left-justified I2S data, and 0 dB unity gain.
- **Persistent Visualizer:** 6-digit Seven-Segment driver with bank-switching (MSB/LSB selection via slide switch) and state-retention to prevent display resetting.

---

## 3. Tech Stack and Dependencies

- **Hardware Platform:** Terasic DE10-Standard (Cyclone V `5CSXFC6D6F31C6N` FPGA)
- **Audio Codec:** Wolfson WM8731 (built-in on DE10-Standard)
- **HDL Language:** VHDL (compatible with IEEE 1164, Numeric_STD, and Fixed_Pkg)
- **Synthesis Tool:** Intel Quartus Prime (Lite/Standard Edition) v18.1 or newer
- **Simulation Tool:** QuestaSim / ModelSim
- **PC Test Scripting:** Python 3.8+ (with `pyserial` library)
- **Mathematical Modeling:** MATLAB (for bit-true simulation and coefficient extraction)

---

## 4. Project Structure

```
├── docs/                        # Project documentation and reports
│   ├── log/                     # Experimental logs and performance notes
│   └── report/                  # Technical reports (design, modeling, testing)
├── hdl/                         # VHDL source code files
│   ├── sender_hdl/              # Transmitter (TX) modules (NCO, DTMF generator)
│   ├── receiver_hdl/            # Preamble detector (I/Q correlator, dec_control)
│   ├── dtmf_detect_hdl/         # Demodulator (Goertzel bank, comparators, shift_add)
│   ├── util/                    # Helper VHDL files (UART, Seven-Segment)
│   ├── AcakCakap_Top.vhd        # Top-level integration file
│   └── run_tb_dtmf_integration.do # ModelSim simulation macro script
├── MATLAB/                      # MATLAB models and validation scripts
├── results/                     # Performance results (SW/UART testing logs)
├── util/                        # Host PC Python helper scripts (send_key.py)
└── README.md                    # This file
```

---

## 5. Installation and Setup

### Hardware Setup
1. Mount the **DE10-Standard** development board.
2. Connect a **3.5mm AUX Cable** from the **Line-Out** jack to the **Line-In** jack (direct loopback configuration).
3. Connect a USB-to-TTL serial adapter (e.g., CP2102) to the GPIO JP1 headers:
   - PC TX $\rightarrow$ GPIO PIN_W15 (`UART_RXD` on FPGA)
   - PC GND $\rightarrow$ GPIO GND
4. Connect the USB Blaster cable to compile and program the FPGA.

### FPGA Programming
1. Launch **Intel Quartus Prime** and open the project file (`quartus/AcakCakap.qpf`).
2. Run **Full Compilation** (`Ctrl + L`).
3. Open **Programmer**, select the SOF file, and download it to the Cyclone V device.

---

## 6. Configuration Options

### Audio Codec Gain (I2C)
The line-input gain of the WM8731 codec is configured in `hdl/i2c.vhd` using `Audio_init` commands.
- **Unity Gain (0 dB):** `x"0017"` (Left) and `x"0217"` (Right). *Highly recommended to prevent signal clipping.*
- **Boost Gain (+12 dB):** `x"001F"` (Left) and `x"021F"` (Right). *May cause Goertzel clipping under high input amplitude.*

### Demodulator Thresholds
- **Goertzel Decision Threshold:** Configured in `lowcomparator.vhd` and `highcomparator.vhd` as `THRESHOLD`. Currently optimized at `200` (`"00000000110010000"` in Q13.4 format) for low-gain detection.
- **I/Q Flagging Counter Threshold:** Configured in `flaggingv2.vhd` to trigger after `2` consecutive matches.

---

## 7. Usage Examples

### Skenario 1: Static Key (Slide Switches)
1. Set the input mode switch **SW[8] to `'0'`** (selects static switches).
2. Set the 8-bit key byte on **SW[7:0]** (e.g., `0x3A`). The system will duplicate this byte to form the 32-bit key `0x3A3A3A3A`.
3. Press **KEY[1]** to trigger the DTMF transmission.
4. Set **SW[0] to `'0'`** to view the lower 24-bit key on the Seven-Segments, or **SW[0] to `'1'`** to view the upper 8-bit key.

### Skenario 2: Dynamic Key (UART Python Injection)
1. Set the input mode switch **SW[8] to `'1'`** (selects UART register).
2. Run the Python testing utility to generate and transmit a random or specific 32-bit key:
   ```bash
   # Install dependencies
   pip install pyserial

   # Run injection script (adjust COM port and baudrate)
   python util/send_key.py --port COM3 --baud 115200 --key AF3C2B1D
   ```
3. The receiver will capture the DTMF transmission, reconstruct the key `AF3C2B1D`, and display it on the Seven-Segments.

---

## 8. Testing Instructions

### Simulation (RTL Verification)
You can verify the entire transceiver pipeline (looping the synthesized DTMF wave back to the receiver) using the provided ModelSim testbench:
1. Launch **ModelSim/QuestaSim**.
2. Change the directory to the project's VHDL root:
   ```tcl
   cd {d:/Users/Rafi Ananta Alden/Documents/Kuliah/Semester 8/EL4064/Enkripsi-Suara-FPGA/Demo/Top-Level/hdl}
   ```
3. Run the DO script:
   ```tcl
   do run_tb_dtmf_integration.do
   ```
4. Verify that the simulation runs, processes the wave, and displays `PASSED` in the transcript.

---

## 9. Performance Notes and Limitations

### Experimental Results (Direct Cable Loopback)
- **Frame Loss Rate:** 0.00% (The I/Q Correlator achieves 100% frame triggering).
- **Word Error Rate (WER):** 55.00% under dynamic UART injection, and 80.00% under manual switch triggering.
- **Symbol Error Rate (SER):** 33.75% under UART, 49.17% under SW.
- **Bit Error Rate (BER):** 18.59% under UART, 23.96% under SW.

### Known Limitation (Preamble Leakage)
The majority of character decoding failures (e.g., TX `18E99D3F` decoded as RX `F18E9D3F`) are caused by **symbol offset shift**, where the third `F` of the preamble sequence leaks into the payload due to early correlator triggering. This pushes the payload digits to the right and drops the last digit (LSB). The core Goertzel frequency selectivity remains intact (BER is low at ~18%).

---

## 10. Future Work / Roadmap

- [ ] **Digital Preamble Masking:** Implement a digital counter inside `shift_add.vhd` to explicitly discard the first decoded digit after receiver activation.
- [ ] **Preamble Trigger Delay:** Add a 20 ms delay buffer to the korelator `enable` signal to match the exact start boundary of the payload.
- [ ] **Physical Debouncer Tuning:** Enhance the filter coefficient for the hardware buttons to reduce transients during manual triggering.

---

## 11. Contributing

Contributions are welcome. Please open an issue or submit a pull request with details on your VHDL, MATLAB, or Python modifications.
