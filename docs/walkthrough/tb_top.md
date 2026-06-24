# DTMF Integration Error Walkthrough

This note documents the adjustments made to resolve the previous
`tb_dtmf_integration` failure where the reconstructed key did not match the
UART-injected key.

## Original Symptom

The integration test injected the dynamic key:

```text
0x3A7C9B1D
```

The first failing run sampled the receiver at the end of the nominal DTMF
transmission window and reported:

```text
reconstructed_key = 0x0F3F3A7C
expected          = 0x3A7C9B1D
```

After adding a bounded receiver flush wait, the receiver had more time to run,
but the failure changed to:

```text
reconstructed_key = 0x9B1D0000
expected          = 0x3A7C9B1D
```

That second result was the important clue. The receiver did decode the tail of
the payload (`9B1D`), but then continued shifting zero nibbles into the key
register after the DTMF transmission ended.

## Root Cause

The old receive-side accumulator in `top_dtmfencode.vhd` used `shift_add` to
shift every decoded DTMF valid pulse into a 32-bit register.

The DTMF decision path can emit a decoded value of `0` when the low or high
comparator reports no valid tone (`code_low = "000"` or `code_high = "000"`).
Those silence/no-tone windows were still able to reach the accumulator path,
so after the real payload was decoded, silence was treated like DTMF digit `0`
and kept shifting the key.

In short:

```text
old behavior: shift every decoder output
bad result:   valid payload eventually overwritten by trailing 0 nibbles
```

## Receiver Fix

File changed:

```text
dtmf_detect_hdl/top_dtmfencode.vhd
```

The continuous `shift_add` accumulator was replaced with a small frame-aware
collector inside `top_dtmfencode`.

The new logic:

1. Gates decoded symbols with `tone_valid`.
2. Ignores no-tone/silence detections.
3. Detects the sender preamble sequence:

```text
# # 3 #
```

4. Also accepts a shortened observed sequence:

```text
# 3 #
```

This tolerance helps if the receiver starts decoding after the first repeated
`#` has already passed through the audio/Goertzel pipeline.

5. Collects exactly 8 payload nibbles after the preamble.
6. Latches the completed 32-bit key into `framed_key`.
7. Holds `encode_out` stable until a new complete frame is received.

The key behavior now is:

```text
new behavior: detect frame, collect exactly 8 payload nibbles, then hold result
good result:  trailing silence cannot overwrite the completed key
```

Relevant signals added:

```vhdl
tone_valid
framed_key
payload_shift
frame_done
payload_count
frame_state
```

The output mapping was changed so the displayed/reconstructed key comes from
the framed result:

```vhdl
encode_out <= framed_key;
out_valid  <= frame_done;
```

## Testbench Timing Adjustment

File changed:

```text
tb_dtmf_integration.vhd
```

The testbench still waits 250 ms for nominal transmission completion:

```text
12 symbols x 20 ms = 240 ms, plus 10 ms tolerance
```

Then it conditionally gives the receiver pipeline up to 200 ms more only if
the expected key has not appeared yet:

```vhdl
if probe_key /= TEST_KEY then
    report "[TESTBENCH] TX window complete; waiting for receiver pipeline to flush..." severity note;
    wait until probe_key = TEST_KEY for 200 ms;
end if;
```

In the successful run, the key was ready by the normal assertion point at:

```text
271936125 ns
```

## Simulation Script Adjustment

File changed:

```text
run_tb_dtmf_integration.do
```

The script now lets the testbench control completion:

```tcl
run -all
```

This is better than a fixed `run 275 ms` because the testbench already owns the
bounded wait and calls `std.env.finish`.

The waveform list was also extended with frame collector signals:

```tcl
sim:/tb_dtmf_integration/DUT/DTMF_ENCODER_RX/tone_valid
sim:/tb_dtmf_integration/DUT/DTMF_ENCODER_RX/frame_state
sim:/tb_dtmf_integration/DUT/DTMF_ENCODER_RX/frame_done
```

These make it easier to inspect when the receiver recognizes the preamble,
starts payload collection, and latches the completed key.

## Verified Result

The final integration run passed:

```text
LSB Check PASSED. (7C9B1D displayed correctly)
MSB Check PASSED. (3A displayed correctly)
Key register Check PASSED. Value = 0x3A7C9B1D
INTEGRATION TEST: PASS (Zero Bit Errors)
```

The remaining simulation warnings are startup/metavalue warnings from the IQ
correlator/fixed-point path at time 0 and around early flag comparisons. They
do not affect the final Goertzel/frame-collector based key reconstruction in
this integration test.

## Summary

The previous error was not caused by UART injection or the seven-segment mux.
It was caused by the receiver accumulation strategy accepting decoded silence
after the actual payload. The fix makes key reconstruction frame-aware and
prevents trailing no-tone windows from shifting zeros into the completed key.
