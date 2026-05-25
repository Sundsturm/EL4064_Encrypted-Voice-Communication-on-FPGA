[BLOK 1] generate_full_sequence(0xABCDEF)
         → sinyal_tx: 7680 sampel (Preamble=2560 + Payload=5120)
                ↓
[BLOK 2] mock_frame_sync(sinyal_tx, N_PREAMBLE=2560)
         → goertzel_enable_start_idx = 2561  (1-based, tepat)
                ↓
[BLOK 3] receiver_pipeline(sinyal_tx, 2561, Fs, N_TONE)
         → 8 × {Goertzel → Comparator → Decision → Shift-Add}
         → reconstructed_key (uint32)
                ↓
[PASS/FAIL] Hex comparison + Hamming distance jika gagal
