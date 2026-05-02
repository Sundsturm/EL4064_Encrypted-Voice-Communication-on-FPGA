
clear all; close all;

% actually shift + awgn

%%%%%%%%%%%%%%% HTML DOCUMENT SETUP %%%%%%%%%%%%%%%


fileID = fopen('shifts7_results.html','w');

document_start = sprintf([ ... 
    '<!DOCTYPE html>' ...
    '<html>' ...
        '<head>' ...
            '<title>Ak vs Shifting</title>' ...
        '</head>' ...
        '<body>' ...
        '<center>'
]);

document_heading = sprintf([ ...
    '<h1>Shift More</h1>' ...
    '<br/>'
    ]);

document_end = sprintf([ ...
        '</body>' ...
        '</center>' ...
    '</html>'
    ]);

fprintf(fileID, document_start);
fprintf(fileID, document_heading);

%%%%%%%%%%%%%% LOOKUP TABLE & CONSTANTS %%%%%%%%%%%%%%%%%%

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

yDTMF = tones(1,:);
yDTMF_awgn = awgn(yDTMF, -20, 'measured');
yDTMF_name = '697 Hz + 1209 Hz';

N_total = length(yDTMF);
dtmf_freqs = [697 770 852 941 1209 1336 1477];
k_indices = round(dtmf_freqs * N_total / Fs);

%%%%%%%%%%%% COMPUTE RESULTS & PLOT %%%%%%%%%%%%%%%

% we have an input tone stored in yDTMF composed of 697 Hz and 1209 Hz
% then we want to try various "shift" values with 697 and 1209 Hz filters
% (i=1 and i=5)

maxShift = 200;
step = 50;

filt_output = zeros(1, N_total);
Ak = 0;
Ak_all = zeros(length(dtmf_freqs), (maxShift/step));
yn = zeros(1, N_total);


fprintf(fileID, ['<p>Input signal: <strong>', yDTMF_name, '</strong><br/>to be shifted from 0 to ', num2str(maxShift), ' samples (step = ', num2str(step), ').</p>']);

x = 1;
for shift = 0:step:maxShift+1

    yDTMF_shifted = [rand(1,shift), yDTMF_awgn(1:N_total - shift)];
    
    %%%

    p_shifted_yDTMF_(shift+1) = figure;
    p_shifted_yDTMF_(shift+1).Position(3:4) = [880 150];
    plot(yDTMF_shifted);
    title(['Input 697+1209 Hz, shifted ', num2str(shift), ' sample(s)']);

    exportgraphics(p_shifted_yDTMF_(shift+1), ['shifted_yDTMF_', num2str(shift), '.png'], 'Resolution', 300);
    fprintf(fileID, ['<br/><br/><br/><img src="shifted_yDTMF_', num2str(shift), '.png" width="880px"/><br/><br/>']);
    fprintf(fileID, ['<div style="page-break-after: always;"></div>']);

    for i = 1:length(dtmf_freqs)
    
        [yn, Ak, filt_output] = goertzel4(yDTMF_shifted, k_indices(i));
        %filt_output(1,:) = goertzel4(yDTMF_shifted, k_indices(i));
        p_res(i) = figure;
        p_res(i).Position(3:4) = [900 150];
        
        plot(filt_output(1,:));
        axis([0 800 -1500 1500]);
        title(['Detected for ', num2str(dtmf_freqs(i)), ' Hz, shifted ', num2str(shift), ' sample(s), max = ', num2str(max(filt_output(1,:))), ', Ak = ', num2str(Ak)])
        grid on;
        
        exportgraphics(p_res(i), ['p_', num2str(i), '_', num2str(shift), '.png'], 'Resolution', 300);
        fprintf(fileID, ['<img src="p_', num2str(i), '_', num2str(shift), '.png" width="900px"/><br/><br/>']);

        Ak_all(i, x) = Ak;
        
    end 

    x = x + 1;

end

Ak_all

ak_bar = figure;
bar(dtmf_freqs, Ak_all);
title('Ak vs Shifting');
xlabel('Frequency (Hz)');
ylabel('Magnitude');
xticks(dtmf_freqs);
xticklabels(cellstr(num2str(dtmf_freqs')));
grid on;

exportgraphics(ak_bar, 'ak_bar.png', 'Resolution', 300);
fprintf(fileID, '<img src="ak_bar.png" width="900px"/><br/><br/>');

%%%%%%%%%%%%%%%%% END DOCUMENT %%%%%%%%%%%%%%%%%%%%%%%%%

fprintf(fileID, document_end);

fclose(fileID);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

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