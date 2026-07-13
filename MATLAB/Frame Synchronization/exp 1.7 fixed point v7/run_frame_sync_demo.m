% RUN_FRAME_SYNC_DEMO  Top-level demo script for frame_sync().
%
%   This script generates a test DTMF signal (sync point "##3#" + silence)
%   and calls frame_sync(inputsignal) to verify sync point detection.
%
%   Sinyal input signal dikalibrasi amplitudo puncaknya menjadi 1.0 agar cocok
%   dengan output dari hardware VHDL (Q2.14).

clear all; close all;

% =========================================
% Fixed-point setup
% =========================================
F = fimath('RoundingMethod','Nearest','OverflowAction','Saturate');

% =========================================
% Basic Parameters
% =========================================
Fs       = 32000;           % Sampling frequency (Hz)
duration = 0.02;            % Duration of one DTMF symbol (seconds)
N        = Fs * duration;   % Number of samples per symbol
t        = (0:N-1) / Fs;    % Time vector

% =========================================
% Compose input signal matching VHDL testbench (tb_receiver_isolated.vhd)
% Preamble: "#", "#", "3", "#"
% Payload:  "3", "A", "7", "C", "9", "B", "1", "D" (Key: 0x3A7C9B1D)
% =========================================

% DTMF Frequency Mapping (digits 0-F)
keys = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', '*', '#'};
f_lows  = [941, 697, 697, 697, 770, 770, 770, 852, 852, 852, 697, 770, 852, 941, 941, 941];
f_highs = [1336, 1209, 1336, 1477, 1209, 1336, 1477, 1209, 1336, 1477, 1633, 1633, 1633, 1633, 1209, 1477];

% 12 symbols: Preamble + Payload (Key 1: 0x3A7C9B1D, Key 2: 0xFF3F3FF3, Key 3: 0x88888888)
symbol_sequence = {'#', '#', '3', '#', '8', '8', '8', '8', '8', '8', '8', '8'};

% 1. Pre-silence (1600 samples of zero silence)
pre_silence = zeros(1, 1600);

% 2. Generate DTMF symbols (640 samples each)
% Skala amplitudo dikali 0.5 agar amplitudo puncak maksimum = 1.0 (sesuai VHDL Q2.14)
dtmf_signals = [];
for idx = 1:length(symbol_sequence)
    sym = symbol_sequence{idx};
    key_idx = find(strcmp(keys, sym));
    fl = f_lows(key_idx);
    fh = f_highs(key_idx);
    
    % Generate tone (sum of sines scaled by 0.5)
    tone = 0.5 * (sin(2*pi*fl*t) + sin(2*pi*fh*t));
    dtmf_signals = [dtmf_signals, tone];
end

% 3. Post-silence (1280 samples of zero silence)
post_silence = zeros(1, 1280);

% Combine all components
inputsignal = [pre_silence, dtmf_signals, post_silence];

% Convert to fixed-point Q3.13
inputsignal = fi(inputsignal, 1, 16, 13, 'fimath', F);

% =========================================
% Call frame_sync as a function
% =========================================
fprintf('=== Running Frame Synchronization ===\n');
goertzel_enable = frame_sync(inputsignal, true);

fprintf('\n=== Final Result ===\n');
if goertzel_enable
    fprintf('✓ Sync point "##3#" detected. Goertzel receiver ENABLED.\n');
else
    fprintf('✗ Sync point not detected. Goertzel receiver DISABLED.\n');
end
