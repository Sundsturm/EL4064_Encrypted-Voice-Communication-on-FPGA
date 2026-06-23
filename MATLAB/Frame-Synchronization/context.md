Frame Synchronization (Fixed-Point Version)
1. Combination of (frame_size, batch_size) that can be choosen
- (16, 40)
- (20, 32)
- (32, 20)
- (40, 16)
Additional notes: Currently, the floating-point used (40, 16)
2. Simulation must use F_{s} or sampling frequency of 32kHz and the time/duration of 20ms
3. Sync point with DTMF symbols as a reference for plot checking: "#", "#", "3", "#"
- DTMF "3": 697 Hz and 1477 Hz and DTMF "#": 941 Hz and 1477 Hz
- The expected plot can be explained as follows: Initially (Sliding Window Index below 50), line of 941 Hz and line of 1477 Hz has higher correlation power values than line of 697 Hz. This condition represents "#" in DTMF. Then, line of 697 Hz rising up, crossing the line of 941 Hz, and has a higher correlation power value than line of 941 Hz because line of 941 Hz will go down. At the same time, line of 1477 Hz still has a high correlation power value. These conditions will happen between sliding window index of approximately 50 and 70 and it represents DTMF "3". In the end, line of 697 Hz will go down and line of 941 Hz will rise again so that both 941 Hz and 1477 Hz lines will have the highest correlation power and the condition represents DTMF "#".