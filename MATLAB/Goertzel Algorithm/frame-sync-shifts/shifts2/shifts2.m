
clear all; close all;

% reformat goertzel_f for one input, is all

%%%%%%%%%%%%%%% HTML DOCUMENT SETUP %%%%%%%%%%%%%%%


fileID = fopen('shifts2_results.html','w');

document_start = sprintf([ ... 
    '<!DOCTYPE html>' ...
    '<html>' ...
    '<head>' ...
    '<title>goertzel4 test</title>' ...
    '</head>' ...
    '<body>'
]);

document_heading = sprintf([ ...
    '<h1>goertzel4 shifts 2</h1>' ...
    '<h2>based on goertzel4_f</h2>'
    ]);

document_end = sprintf([ ...
    '</body>' ...
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

yDTMF = tones(1,:)
yDTMF_name = '697 Hz + 1209 Hz';

N_total = length(yDTMF);
dtmf_freqs = [697 770 852 941 1209 1336 1477];
k_indices = round(dtmf_freqs * N_total / Fs);

filter_outputs = deal(zeros(length(dtmf_freqs), N_total));

%%%%%%%%%%%% COMPUTE RESULTS & PLOT %%%%%%%%%%%%%%%

% we have an input tone stored in yDTMF composed of 697 Hz and 1209 Hz
% then we want to try various "shift" values with 697 and 1209 Hz filters
% (i=1 and i=5)

filt_output_697_0 = goertzel4(yDTMF, k_indices(1));
p_697_0 = figure;
p_697_0.Position(3:4) = [800 200];

plot(filt_output_697_0);
axis([0 800 -1500 1500]);
title('697 Hz, 0 shifting')
grid on;

exportgraphics(p_697_0, 'p697_0.png', 'Resolution',300);
fprintf(fileID, ['<img src="p697_0', '.png" width="900px"/><br/>']);

filt_output_1209_0 = goertzel4(yDTMF, k_indices(5));
p_1209_0 = figure;
p_1209_0.Position(3:4) = [800 200];

plot(filt_output_1209_0);
axis([0 800 -1500 1500]);
title('1209 Hz, 0 shifting')
grid on;

exportgraphics(p_1209_0, 'p1209_0.png', 'Resolution',300);
fprintf(fileID, ['<img src="p1209_0', '.png" width="900px"/><br/>']);

%%%%%%%%%%%%%%%%% END DOCUMENT %%%%%%%%%%%%%%%%%%%%%%%%%

fprintf(fileID, document_end);

fclose(fileID);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function filter_output = goertzel4(x, k)

    % x = input vector, data x(n)
    % k = frequency index, di mana k = (f*N)/Fs
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

end