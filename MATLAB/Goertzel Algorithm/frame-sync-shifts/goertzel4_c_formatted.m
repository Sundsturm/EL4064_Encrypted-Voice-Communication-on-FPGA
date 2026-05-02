clear all; close all;

% goertzel4_c -> check all tones
% reimplementation

Fs = 16000; 
duration = 0.05;
N = Fs * duration; 
t = (0:N-1) / Fs; 

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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fileID = fopen('goertzel4_c_formatted.html','w');

document_start = sprintf([ ... 
    '<!DOCTYPE html>' ...
    '<html>' ...
    '<head>' ...
    '<title>goertzel4, 12 tones</title>' ...
    '</head>' ...
    '<body>'
]);

document_heading = sprintf([ ...
    '<h1>goertzel4, 12 tones</h1>' ...
    '<h2>based on goertzel4_c</h2>'
    ]);

document_end = sprintf([ ...
    '</body>' ...
    '</html>'
    ]);

fprintf(fileID, document_start);
fprintf(fileID, document_heading);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

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

figure;
for tn = 1:12
    tone = tones(tn,:);
    yDTMF1 = [(4*rand(1, 320))-2, tone, 4*(rand(1, 320))-2]; 
    yDTMF1_name = strcat(tone_names(tn), ' noise L+R');
    yDTMF2 = [(4*rand(1, 640))-2, tone]; 
    yDTMF2_name = strcat(tone_names(tn), ' noise L');
    yDTMF3 = [tone, 4*(rand(1, 640))-2]; 
    yDTMF3_name = strcat(tone_names(tn), ' noise R');
    N_total = length(yDTMF3);
    
    dtmf_freqs = [697 770 852 941 1209 1336 1477];
    
    % APPLY GOERTZEL ALGORITHM
    k_indices = round(dtmf_freqs * N_total / Fs);
    
    outputs1 = zeros(length(dtmf_freqs), 1);
    filter_outputs1 = zeros(length(dtmf_freqs), N_total);
    for i = 1:length(dtmf_freqs)
        [yn, outputs1(i), filter_output] = goertzel4(yDTMF1, k_indices(i));
        filter_outputs1(i, :) = filter_output;
    end
    
    outputs2 = zeros(length(dtmf_freqs), 1);
    filter_outputs2 = zeros(length(dtmf_freqs), N_total);
    for i = 1:length(dtmf_freqs)
        [yn, outputs2(i), filter_output] = goertzel4(yDTMF2, k_indices(i));
        filter_outputs2(i, :) = filter_output;
    end
    
    outputs3 = zeros(length(dtmf_freqs), 1);
    filter_outputs3 = zeros(length(dtmf_freqs), N_total);
    for i = 1:length(dtmf_freqs)
        [yn, outputs3(i), filter_output] = goertzel4(yDTMF3, k_indices(i));
        filter_outputs3(i, :) = filter_output;
    end
    
    % THE PLOT
    outputs = [outputs1, outputs2, outputs3];
    subplot(12, 1, tn);

    f = nexttile;
    bar(dtmf_freqs, outputs);
    title(tone_names(tn,:));
    xlabel('Frequency (Hz)');
    ylabel('Magnitude');
    xticks(dtmf_freqs);
    xticklabels(cellstr(num2str(dtmf_freqs')));
    legend(yDTMF1_name, yDTMF2_name, yDTMF3_name);
    grid on;

    exportgraphics(f, ['barchart' num2str(tn) '.png'],'Resolution',300);
    fprintf(fileID, ['<img src="barchart' num2str(tn) '.png" width="400px"/><br/>']);
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf(fileID, document_end);

fclose(fileID);

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