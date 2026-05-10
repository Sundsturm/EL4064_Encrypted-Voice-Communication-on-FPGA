clear all; close all;

% forked from goertzel4_b
% work on visualizing and comparing y(n)

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

size(yDTMF1)
size(yDTMF2)
size(yDTMF3)

% filter configurations to try
dtmf_freqs = [697 770 852 941 1209 1336 1477];
%dtmf_freqs = [1209 1336 1477];
%dtmf_freqs = [697 770 852]; 
%dtmf_freqs = [697 770 1209 1336 1477];

% APPLY GOERTZEL ALGORITHM
k_indices = round(dtmf_freqs * N_total / Fs);

outputs1 = zeros(length(dtmf_freqs), 1);
filter_outputs1 = zeros(length(dtmf_freqs), N_total);
yns1 = zeros(length(dtmf_freqs), N_total+3);
for i = 1:length(dtmf_freqs)
    [yn1, outputs1(i), filter_output] = goertzel4(yDTMF1, k_indices(i));
    filter_outputs1(i, :) = filter_output;
    yns1(i, :) = yn1;
end

outputs2 = zeros(length(dtmf_freqs), 1);
filter_outputs2 = zeros(length(dtmf_freqs), N_total);
yns2 = zeros(length(dtmf_freqs), N_total+3);
for i = 1:length(dtmf_freqs)
    [yn2, outputs2(i), filter_output] = goertzel4(yDTMF2, k_indices(i));
    filter_outputs2(i, :) = filter_output;
    yns2(i, :) = yn2;
end

outputs3 = zeros(length(dtmf_freqs), 1);
filter_outputs3 = zeros(length(dtmf_freqs), N_total);
yns3 = zeros(length(dtmf_freqs), N_total+3);
for i = 1:length(dtmf_freqs)
    [yn3, outputs3(i), filter_output] = goertzel4(yDTMF3, k_indices(i));
    filter_outputs3(i, :) = filter_output;
    yns3(i, :) = yn3;
end

% PLOT 
figure;
subplot(length(dtmf_freqs) + 1, 1, 1);
plot(yDTMF1(1, :));
title(yDTMF1_name);
xlabel('Sample');
ylabel('Amplitude');
for i = 2:length(dtmf_freqs)+1
    ax(i) = subplot(length(dtmf_freqs) + 1, 1, i);
    plot(yns1(i-1, :));
    title(['Filter Output for ', num2str(dtmf_freqs(i-1)), ' Hz']);
    xlabel('Sample');
    ylabel('Amplitude');
    grid on;
    linkaxes(ax,'xy');
end

figure;
subplot(length(dtmf_freqs) + 1, 1, 1);
plot(yDTMF2(1, :));
title(yDTMF2_name);
xlabel('Sample');
ylabel('Amplitude');
for i = 2:length(dtmf_freqs)+1
    ax(i) = subplot(length(dtmf_freqs) + 1, 1, i);
    plot(yns2(i-1, :));
    title(['Filter Output for ', num2str(dtmf_freqs(i-1)), ' Hz']);
    xlabel('Sample');
    ylabel('Amplitude');
    grid on;
    linkaxes(ax,'xy');
end

figure;
subplot(length(dtmf_freqs) + 1, 1, 1);
plot(yDTMF3(1, :));
title(yDTMF3_name);
xlabel('Sample');
ylabel('Amplitude');
for i = 2:length(dtmf_freqs)+1
    ax(i) = subplot(length(dtmf_freqs) + 1, 1, i);
    plot(yns3(i-1, :));
    title(['Filter Output for ', num2str(dtmf_freqs(i-1)), ' Hz']);
    xlabel('Sample');
    ylabel('Amplitude');
    grid on;
    linkaxes(ax,'xy');
end

function [yn, Ak, filter_output] = goertzel4(x, k)

    % x = input vector, data x(n)
    % k = frequency index, di mana k = (f*N)/Fs
    % yn = y(n)
    % Ak = sqrt(Xk)/N
    % filter_output = vk(n)
    
    N = length(x);

    x = [x 0];
    vk = zeros(1, N+3);
    yn = zeros(1, N+3);
    filter_output = zeros(1, N);

    for n = 1:N+1
        vk(n+2) = 2*cos(2*pi*k/N)*vk(n+1) - vk(n) + x(n);
        yn(n+2) = vk(n+2) - exp(-2*pi*1i*k/N)*vk(n+1);
        if n <= N
            filter_output(n) = vk(n+2);
        end
    end

    %yn = vk(N+3) - exp(-2*pi*1i*k/N)*vk(N+2);
    yn(N+3) = vk(N+3) - exp(-2*pi*1i*k/N)*vk(N+2);
    Xk = vk(N+3)*vk(N+3) + vk(N+2)*vk(N+2) - 2*cos(2*pi*k/N)*vk(N+3)*vk(N+2);
    Ak = sqrt(Xk)/N;
end