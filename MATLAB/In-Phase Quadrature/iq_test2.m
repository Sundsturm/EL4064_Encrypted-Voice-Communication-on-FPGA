clear all; close all;

% parameters
Fs = 16000; 
duration = 0.05;
N = Fs * duration; 
t = (0:N - 1) / Fs; 

% look-up table
dtmf_matrix = [697 770 852 941; 1209 1336 1477 0];
dtmf_row = containers.Map({'1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '*', '#'}, ...
                          {1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4});
dtmf_col = containers.Map({'1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '*', '#'}, ...
                          {1, 2, 3, 1, 2, 3, 1, 2, 3, 2, 1, 3});

tones = [
    sin(2 * pi * dtmf_matrix(1, dtmf_row('1')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('1')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('2')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('2')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('3')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('3')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('4')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('4')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('5')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('5')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('6')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('6')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('7')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('7')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('8')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('8')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('9')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('9')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('0')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('0')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('*')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('*')) * t);
    sin(2 * pi * dtmf_matrix(1, dtmf_row('#')) * t) + sin(2 * pi * dtmf_matrix(2, dtmf_col('#')) * t)
    ];

tone_names = [
    '697 + 1209',
    '697 + 1336',
    '697 + 1477',
    '770 + 1209',
    '770 + 1336',
    '770 + 1477',
    '852 + 1209',
    '852 + 1336',
    '852 + 1477',
    '941 + 1336',
    '941 + 1209',
    '941 + 1477'
    ];

% plot bar chart
figure;

dtmf_freqs = [697 770 852 941 1209 1336 1477];
iq_corr_outputs = zeros(length(tones(:,1)), length(dtmf_freqs));

tiledlayout(length(tones(:,1)), 1, "TileSpacing", "tight");
for input_i = 1:length(tones(:,1)) 

    % try inputting each DTMF tone
    input_dtmf = tones(input_i,:);

    % for each input, loop through each reference tone
    for ref_i = 1:length(dtmf_freqs) 
        iq_corr_outputs(input_i, ref_i) = iq_corr(input_dtmf, dtmf_freqs(ref_i), Fs);
    end

    % draw bar chart for each inputted DTMF tone
    nexttile;
    
    bar(dtmf_freqs, iq_corr_outputs(input_i,:));
    title([num2str(tone_names(input_i,:)), ' Hz']);

    %xlabel('Frequency (Hz)');
    %ylabel('Magnitude');

end

% declare iq_corr()
function IQmag = iq_corr(input_tone, ref_freq, Fs)

    % input tone: tone = sin(2 * pi * LF * t) + sin(2 * pi * HF * t)
    % ref freq: e.g. 697, 770, etc.

    N = length(input_tone);
    t = (0:N - 1)/Fs; 

    % in-phase (I) and quadrature (Q) components of reference tone
    ref_sin = sin(2 * pi * ref_freq * t);
    ref_cos = cos(2 * pi * ref_freq * t);
    
    % multiply, accumulate, and raise to the power of 2
    IQmag = sum(input_tone .* ref_cos)^2 + sum(input_tone .* ref_sin)^2;

end
