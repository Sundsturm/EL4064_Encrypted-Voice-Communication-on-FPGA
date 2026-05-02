clear all; close all;

% based on goertzel4_f

% CONFIGURE PARAMETERS
Fs = 16000; 
duration = 0.05;
N = Fs * duration; 
t = (0:N-1) / Fs; 

% DTMF LOOKUP TABLE
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

% CONFIGURE INPUT HERE
% input tone to be filtered
yDTMF1 = [(4*rand(1, 320))-2, tones(1,:), 4*(rand(1, 320))-2]; 
yDTMF1_name = '697 Hz + 1209 Hz, noise L+R';
yDTMF2 = [(4*rand(1, 640))-2, tones(1,:)]; 
yDTMF2_name = '697 Hz + 1209 Hz, noise L';
yDTMF3 = [tones(1,:), 4*(rand(1, 640))-2]; 
yDTMF3_name = '697 Hz + 1209 Hz, noise R';

N_total = length(yDTMF3);

% filter configurations to try
dtmf_freqs = [697 770 852 941 1209 1336 1477];

% APPLY GOERTZEL ALGORITHM
k_indices = round(dtmf_freqs * N_total / Fs);

[outputs1, outputs2, outputs3, outputs4] = deal(zeros(length(dtmf_freqs), 1));

[filter_outputs1, filter_outputs2, filter_outputs3] = deal(zeros(length(dtmf_freqs), N_total));

[yns1, yns2, yns3] = deal(zeros(length(dtmf_freqs), N_total));

for i = 1:length(dtmf_freqs)
    [yn, outputs1(i), filter_output] = goertzel4(yDTMF1, k_indices(i));
    [yn, outputs2(i), filter_output] = goertzel4(yDTMF2, k_indices(i));
    [yn, outputs3(i), filter_output] = goertzel4(yDTMF3, k_indices(i));
end


% PLOT 1
figure;
outputs = [outputs1, outputs2, outputs3]
avgs = [mean(outputs1), mean(outputs2), mean(outputs3)];
bar(dtmf_freqs, outputs);
title(['Tone Detection Results (Average = ', num2str(avgs(1)), ', ', num2str(avgs(2)), ', ', num2str(avgs(3)), ')' ]);
xlabel('Frequency (Hz)');
ylabel('Magnitude');
xticks(dtmf_freqs);
xticklabels(cellstr(num2str(dtmf_freqs')));
legend(yDTMF1_name, yDTMF2_name, yDTMF3_name);
grid on;

% PLOT 2
figure;
outputs = [outputs1, outputs2, outputs3]
avgs = [mean(outputs1), mean(outputs2), mean(outputs3)];
outputs = [outputs1/avgs(1), outputs2/avgs(2), outputs3/avgs(3)]
bar(dtmf_freqs, outputs);
title(['Results / Average (using Average = ', num2str(avgs(1)), ', ', num2str(avgs(2)), ', ', num2str(avgs(3)), ')' ]);
xlabel('Frequency (Hz)');
ylabel('Magnitude');
xticks(dtmf_freqs);
xticklabels(cellstr(num2str(dtmf_freqs')));
legend(yDTMF1_name, yDTMF2_name, yDTMF3_name);
grid on;

function [yn, Ak, filter_output] = goertzel4(x, k)

    % x = input vector, data x(n)
    % k = frequency index, di mana k = (f*N)/Fs
    % yn = y(n)
    % Ak = sqrt(Xk)/N
    % filter_output = vk(n)
    
    N = length(x);

    x = [x 0];
    vk = zeros(1, N+3);
    filter_output = zeros(1, N);

    for n = 1:N+1
        vk(n+2) = 2*cos(2*pi*k/N)*vk(n+1) - vk(n) + x(n);
        if n <= N
            filter_output(n) = vk(n+2);
        end
    end

    yn = vk(N+3) - exp(-2*pi*1i*k/N)*vk(N+2);
    Xk = vk(N+3)*vk(N+3) + vk(N+2)*vk(N+2) - 2*cos(2*pi*k/N)*vk(N+3)*vk(N+2);
    Ak = sqrt(Xk)/N;
end