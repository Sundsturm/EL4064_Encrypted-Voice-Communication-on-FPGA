
img_res = 120;

% original audio is sampled at 48 kHz
[y48, f48] = audioread("input_audio_48kHz.wav");    % amplitude vs frequency
n48 = 0.02 * f48;                           % panjang array audio selama 20 ms
fc48 = 7000/(f48/2);

f_audio_init48 = figure('visible', 'off');
f_audio_init48.Position(3:4) = [600 500];
plot(y48);
title("Initial input audio in time domain (48 kHz Fs)");
exportgraphics(f_audio_init48, 'f_audio_init48.png', 'Resolution', img_res);

% downsample to 32 kHz (2/3 of 48 kHz)
y = resample(y48, 2, 3); 
f = 32000;                       % panjang array audio selama 20 ms
n = 0.02 * f;   
fc = 7000/(f/2);
audiowrite('input_audio_32kHz.wav', y, f);

f_audio_init = figure('visible', 'off');
f_audio_init.Position(3:4) = [600 500];
plot(y);
title("Resampled input audio in time domain (32 kHz Fs)");
exportgraphics(f_audio_init, 'f_audio_init.png', 'Resolution', img_res);