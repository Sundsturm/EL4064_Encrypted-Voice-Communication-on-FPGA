
clear all; close all;

% which of the 12 DTMF tones "correlate" the least with each other? 
% using Goertzel detection algorithm

%%%%%%%%%%%%%%% HTML DOCUMENT SETUP %%%%%%%%%%%%%%%


fileID = fopen('tonevstone_1_results.html', 'w');
title = sprintf('Tone versus Tone 1');
h1 = sprintf('Tone versus Tone');
subtitle = sprintf('Which of the 12 DTMF tones "correlate" the least with each other?<br/>Computed using the sum(xcorr()).');

document_start = sprintf([ ... 
    '<!DOCTYPE html>' ...
    '<html>' ...
        '<head>' ...
            '<title>', title, '</title>' ...
        '</head>' ...
        '<body>' ...
        '<center>'
]);

document_heading = sprintf([ ...
    '<h1>', h1, '</h1>' ...
    '<p>', subtitle, '</p>' ...
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

N_total = N;
dtmf_freqs = [697 770 852 941 1209 1336 1477];
k_indices = round(dtmf_freqs * N_total / Fs);

%%%%%%%%%%%% COMPUTE RESULTS & PLOT %%%%%%%%%%%%%%%
cr = 0;

for tone1 = 1:11
    for tone2 = tone1 + 1:12 

        yTone1 = tones(tone1, :);
        yTone2 = tones(tone2, :);

        cr = sum(xcorr(yTone1, yTone2));

        fprintf(fileID, ['<p>', tone_names(tone1,:), ' Hz vs ', tone_names(tone2,:), ' Hz: <strong>', num2str(cr), '</strong></p>']);
    end
end
    
    %%%

    %p_shifted_yDTMF_(shift+1) = figure;
    %p_shifted_yDTMF_(shift+1).Position(3:4) = [880 150];
    %plot(yDTMF_shifted);
    %title(['Input 697+1209 Hz, shifted ', num2str(shift), ' sample(s)']);

    %exportgraphics(p_shifted_yDTMF_(shift+1), ['shifted_yDTMF_', num2str(shift), '.png'], 'Resolution', 300);
    %fprintf(fileID, ['<br/><br/><br/><img src="shifted_yDTMF_', num2str(shift), '.png" width="880px"/><br/><br/>']);


%%%%%%%%%%%%%%%%% END DOCUMENT %%%%%%%%%%%%%%%%%%%%%%%%%

fprintf(fileID, document_end);

fclose(fileID);