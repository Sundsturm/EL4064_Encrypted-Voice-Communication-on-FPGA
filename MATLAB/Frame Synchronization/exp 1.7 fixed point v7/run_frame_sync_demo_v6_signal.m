% RUN_FRAME_SYNC_DEMO_V6_SIGNAL  Top-level demo script for frame_sync().
%
%   This script generates a test DTMF signal (sync point "##3#" + noise)
%   and calls frame_sync(inputsignal, true) to verify sync point detection
%   using the input signal format from exp 1.7 fixed point v6.
%
%   Use this script for standalone testing / debugging with noisy inputs.

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
% Generate DTMF tones
% DTMF frequencies:
%   '#' = 941 Hz (row) + 1477 Hz (col)
%   '3' = 697 Hz (row) + 1477 Hz (col)
% =========================================
tone_hash = sin(2*pi*941*t)  + sin(2*pi*1477*t);  % '#'
tone_3    = sin(2*pi*697*t)  + sin(2*pi*1477*t);  % '3'

% =========================================
% Compose the input signal matching v6:
%   [noise | '#' | '#' | '3' | '#' | noise]
%   = [noise + 4 sync symbols "##3#" + noise]
% =========================================
inputsignal = [(4*rand(1,1280))-2, ...  % Leading noise
               tone_hash, ...           % Symbol '#' (1)
               tone_hash, ...           % Symbol '#' (2)
               tone_3,   ...            % Symbol '3'
               tone_hash, ...           % Symbol '#' (4) -> end of sync point
               (4*rand(1,1280))-2];     % Trailing noise

% Convert to fixed-point Q3.13
inputsignal = fi(inputsignal, 1, 16, 13, 'fimath', F);

% =========================================
% Call frame_sync as a function (with verbose = true from v7)
% =========================================
fprintf('=== Running Frame Synchronization (v6 Input Signal) ===\n');
goertzel_enable = frame_sync(inputsignal, true);

fprintf('\n=== Final Result ===\n');
if goertzel_enable
    fprintf('✓ Sync point "##3#" detected. Goertzel receiver ENABLED.\n');
else
    fprintf('✗ Sync point not detected. Goertzel receiver DISABLED.\n');
end
