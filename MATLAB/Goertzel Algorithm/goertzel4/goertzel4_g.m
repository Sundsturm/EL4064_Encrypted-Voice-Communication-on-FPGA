clear all; close all;

% try longer noise periods

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
yDTMF1 = [(4*rand(1, 2500))-2, tones(1,:), 4*(rand(1, 2500))-2]; 
yDTMF1_name = '697 Hz + 1209 Hz, noise L+R';
yDTMF2 = [(4*rand(1, 5000))-2, tones(1,:)]; 
yDTMF2_name = '697 Hz + 1209 Hz, noise L';
yDTMF3 = [tones(1,:), 4*(rand(1, 5000))-2]; 
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

[outputs1, outputs2, outputs3] = deal(zeros(length(dtmf_freqs), 1));

[filter_outputs1, filter_outputs2, filter_outputs3] = deal(zeros(length(dtmf_freqs), N_total));

[yns1, yns2, yns3] = deal(zeros(length(dtmf_freqs), N_total));

for i = 1:length(dtmf_freqs)
    [yn, outputs1(i), filter_output] = goertzel4(yDTMF1, k_indices(i));
    filter_outputs1(i, :) = filter_output;
    yns1(i) = yn;

    [yn, outputs2(i), filter_output] = goertzel4(yDTMF2, k_indices(i));
    filter_outputs2(i, :) = filter_output;
    yns2(i) = yn;

    [yn, outputs3(i), filter_output] = goertzel4(yDTMF3, k_indices(i));
    filter_outputs3(i, :) = filter_output;
    yns3(i) = yn;
end


% PLOT 1
figure;
outputs = [outputs1, outputs2, outputs3]
bar(dtmf_freqs, outputs);
title('Goertzel Algorithm Tone Detection Results');
xlabel('Frequency (Hz)');
ylabel('Magnitude');
xticks(dtmf_freqs);
xticklabels(cellstr(num2str(dtmf_freqs')));
legend(yDTMF1_name, yDTMF2_name, yDTMF3_name);
grid on;

% PLOT 2
figure;
tiledlayout(length(dtmf_freqs)+1,1,"TileSpacing","tight");
nexttile;
plot(yDTMF1(1, :));
title(yDTMF1_name);
for i = 2:length(dtmf_freqs)+1
    p2(i) = nexttile;
    plot(filter_outputs1(i-1, :));
    title([num2str(dtmf_freqs(i-1)), ' Hz → y(n) = ', num2str(yns1(i-1))])
    grid on;
    linkaxes(p2,'xy');
end

% PLOT 3
figure;
tiledlayout(length(dtmf_freqs)+1,1,"TileSpacing","tight");
nexttile;
plot(yDTMF2(1, :));
title(yDTMF2_name);
for i = 2:length(dtmf_freqs)+1
    p3(i) = nexttile;
    plot(filter_outputs2(i-1, :));
    title([num2str(dtmf_freqs(i-1)), ' Hz → y(n) = ', num2str(yns2(i-1))])
    grid on;
    linkaxes(p3,'xy');
end

% PLOT 4
figure;
tiledlayout(length(dtmf_freqs)+1,1,"TileSpacing","tight");
nexttile;
plot(yDTMF3(1, :));
title(yDTMF3_name);
for i = 2:length(dtmf_freqs)+1
    p4(i) = nexttile;
    plot(filter_outputs3(i-1, :));
    title([num2str(dtmf_freqs(i-1)), ' Hz → y(n) = ', num2str(yns3(i-1))])
    grid on;
    linkaxes(p4,'xy');
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