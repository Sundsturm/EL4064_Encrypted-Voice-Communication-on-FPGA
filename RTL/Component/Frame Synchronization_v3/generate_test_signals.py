import os
import numpy as np

# DTMF Frequencies (Hz)
DTMF_FREQ = {
    '1': (697, 1209), '2': (697, 1336), '3': (697, 1477), 'A': (697, 1633),
    '4': (770, 1209), '5': (770, 1336), '6': (770, 1477), 'B': (770, 1633),
    '7': (852, 1209), '8': (852, 1336), '9': (852, 1477), 'C': (852, 1633),
    '*': (941, 1209), '0': (941, 1336), '#': (941, 1477), 'D': (941, 1633)
}

def generate_symbol(char, num_samples=640, fs=32000, freq_offset_percent=0.0):
    if char == ' ':
        return np.zeros(num_samples)
    if char not in DTMF_FREQ:
        raise ValueError(f"Unknown DTMF char: {char}")
    
    f1, f2 = DTMF_FREQ[char]
    f1 *= (1.0 + freq_offset_percent / 100.0)
    f2 *= (1.0 + freq_offset_percent / 100.0)
    
    t = np.arange(num_samples) / fs
    # Sum of two sines (peak is 2.0)
    s = np.sin(2 * np.pi * f1 * t) + np.sin(2 * np.pi * f2 * t)
    return s

def add_awgn(signal, snr_db):
    sig_power = np.mean(signal**2)
    if sig_power == 0:
        # If signal is pure zero (silence), assume signal power was 1.0 for noise reference
        sig_power = 0.5  # Standard DTMF signal power is around 0.5 to 1.0
    snr_linear = 10**(snr_db / 10.0)
    noise_power = sig_power / snr_linear
    noise = np.random.normal(0, np.sqrt(noise_power), len(signal))
    return signal + noise

def add_impulsive_noise(signal, probability=0.005, amplitude=1.8):
    noisy_signal = signal.copy()
    num_spikes = int(len(signal) * probability)
    spike_indices = np.random.choice(len(signal), num_spikes, replace=False)
    for idx in spike_indices:
        noisy_signal[idx] = np.random.choice([amplitude, -amplitude])
    return noisy_signal

def save_signal(filename, signal):
    # Save as float values, one per line
    with open(filename, 'w') as f:
        for val in signal:
            f.write(f"{val:.10f}\n")
    print(f"Saved {filename} ({len(signal)} samples)")

def main():
    np.random.seed(42)  # For reproducible noise generation
    output_dir = os.path.dirname(os.path.abspath(__file__))
    
    preamble = ['#', '#', '3', '#']
    std_payload = ['0', '1', '2', '4', '5', '6', '7', '8']
    worst_payload = ['#', '#', '3', '#', '3', '3', '#', '3']
    
    # Prefix silence of 1280 samples (32 batches) for circular buffer lookback fill
    prefix_silence = list(generate_symbol(' ', num_samples=1280))
    
    # ----------------------------------------------------
    # Case 1: Standard (Ideal)
    # ----------------------------------------------------
    sig1 = list(prefix_silence)
    for char in preamble + std_payload:
        sig1.extend(generate_symbol(char))
    save_signal(os.path.join(output_dir, "test_1key_standard.txt"), np.array(sig1))
    
    # ----------------------------------------------------
    # Case 2: Worst-Case Payload
    # ----------------------------------------------------
    sig2 = list(prefix_silence)
    for char in preamble + worst_payload:
        sig2.extend(generate_symbol(char))
    save_signal(os.path.join(output_dir, "test_worst_case_payload.txt"), np.array(sig2))
    
    # ----------------------------------------------------
    # Case 3: Silence Gaps
    # ----------------------------------------------------
    sig3 = list(prefix_silence)
    full_seq = preamble + std_payload
    for i, char in enumerate(full_seq):
        sig3.extend(generate_symbol(char))
        if i < len(full_seq) - 1:
            # 64 samples of silence between symbols
            sig3.extend(generate_symbol(' ', num_samples=64))
    save_signal(os.path.join(output_dir, "test_silence_gaps.txt"), np.array(sig3))
    
    # ----------------------------------------------------
    # Case 4: Low SNR (5 dB AWGN, 30% Scale)
    # ----------------------------------------------------
    sig4_clean = list(prefix_silence)
    for char in preamble + std_payload:
        sig4_clean.extend(generate_symbol(char))
    # Scale both silence and preamble/payload to 30%
    sig4_clean = np.array(sig4_clean) * 0.3
    # Add noise to the entire signal (including silence prefix)
    sig4_noisy = add_awgn(sig4_clean, snr_db=5.0)
    save_signal(os.path.join(output_dir, "test_low_snr.txt"), sig4_noisy)
    
    # ----------------------------------------------------
    # Case 5: Frequency Offset (+1.5%)
    # ----------------------------------------------------
    sig5 = list(prefix_silence)
    for char in preamble + std_payload:
        sig5.extend(generate_symbol(char, freq_offset_percent=1.5))
    save_signal(os.path.join(output_dir, "test_freq_offset.txt"), np.array(sig5))
    
    # ----------------------------------------------------
    # Case 6: Impulsive Noise
    # ----------------------------------------------------
    sig6_clean = []
    # Pre-applied noise (silence with spikes) for 2 symbols (1280 samples)
    sig6_clean.extend(generate_symbol(' ', num_samples=1280))
    # Preamble + Payload
    for char in preamble + std_payload:
        sig6_clean.extend(generate_symbol(char))
    # Post-applied noise (silence with spikes) for 2 symbols (1280 samples)
    sig6_clean.extend(generate_symbol(' ', num_samples=1280))
    
    sig6_noisy = add_impulsive_noise(np.array(sig6_clean), probability=0.005, amplitude=1.8)
    save_signal(os.path.join(output_dir, "test_impulse_noise.txt"), sig6_noisy)

if __name__ == "__main__":
    main()
