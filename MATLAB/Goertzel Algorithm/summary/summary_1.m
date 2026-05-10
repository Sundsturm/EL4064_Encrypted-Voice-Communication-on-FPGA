
clear all; close all;

%%%% HTML DOCUMENT SETUP %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


fileID = fopen('summary_1_results.html', 'w');
doc_title = sprintf('Simulating the Goertzel Algorithm');
h1 = sprintf('Simulating the Goertzel Algorithm');
doc_subtitle = sprintf('Detection Results with 12 Tones, Randomized Noise, Frame Shifting, + AWGN.');

document_start = sprintf([ ... 
    '<!DOCTYPE html>' ...
    '<html>' ...
        '<head>' ...
            '<title>', doc_title, '</title>' ...
            '<style>' ...
                'table { margin: 5px; }' ... 
                'table, th, td {' ...
                    'border: 2px solid #333;' ...
                    'border-collapse: collapse;' ...
                    'padding: 5px;' ...
                '} ' ...
                '.highlighted_td {' ...
                    'background-color: skyblue;' ...
                '}' ...
            '</style>' ...
        '</head>' ...
        '<body>' ...
        '<center>'
]);

document_heading = sprintf([ ...
    '<br/><h1>', h1, '</h1>' ...
    '<p>', doc_subtitle, '</p>' ...
    '<br/>' ...
    '<p>29 October 2024</p>'
    ]);

document_end = sprintf([ ...
        '</body>' ...
        '</center>' ...
    '</html>'
    ]);

fprintf(fileID, document_start);
fprintf(fileID, document_heading);

%%%% DTMF SETUP %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Fs = 16000; 
duration = 0.02;
N = Fs * duration; 
t = (0:N-1) / Fs; 

dtmf_freqs = [697 770 852 941 1209 1336 1477];
k_indices = round(dtmf_freqs * N / Fs);

fprintf(fileID, [ ...
    '<p>' ...
    'Configuration used: F<sub>s</sub> = ', num2str(Fs), ', duration = ', num2str(duration), ' s, N = ', num2str(N), '.' ...
    '</p><hr/>' ...
    '<div style="page-break-after: always;"></div>' % add page break
    ]);

dtmf = {
    '1', 697, 1209, zeros(1, 320);
    '2', 697, 1336, zeros(1, 320);
    '3', 697, 1477, zeros(1, 320);
    '4', 770, 1209, zeros(1, 320);
    '5', 770, 1336, zeros(1, 320);
    '6', 770, 1477, zeros(1, 320);
    '7', 852, 1209, zeros(1, 320);
    '8', 852, 1336, zeros(1, 320); 
    '9', 852, 1477, zeros(1, 320);
    '*', 941, 1209, zeros(1, 320);
    '0', 941, 1336, zeros(1, 320);
    '#', 941, 1477, zeros(1, 320);
};

% notes:
% access low-frequency tone: dtmf{i, 2}
% access high-frequency tone: dtmf{i, 3}
% access tone: dtmf{i, 4, :}

for i = 1:12
    dtmf{i, 4, :} = sin(2 * pi * dtmf{i, 2} * t) + sin(2 * pi * dtmf{i, 3} * t);
end


%%%% PLOT: EACH OF THE 12 DTMF TONES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
SKIP = false;

if ~SKIP
    fprintf(fileID, [ ...
        '<h2>The 12 Tones</h2>' 
        ]);
    
    for i = 1:12
        f1(i) = figure('visible','off');
        f1(i).Position(3:4) = [400 80];
    
        plot(dtmf{i, 4, :});
        axis([0 320 -2 2]);
    
        title([num2str(dtmf{i, 2}), ' Hz + ', num2str(dtmf{i, 3}), ' Hz (', dtmf{i, 1}, ')'])
    
        exportgraphics(f1(i), ['f1_', num2str(i), '.png'], 'Resolution', 100);
        fprintf(fileID, ['<img src="f1_', num2str(i), '.png"/> <br/><br/>']);
    end
    
    fprintf(fileID, '<br/><hr/><div style="page-break-after: always;"></div>');
end

%%%% PLOT: MAXIMUM MAGNITUDES OF DETECTION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
SKIP = false; 

if ~SKIP
    fprintf(fileID, [ ...
        '<h2>Detection using the Goertzel Algorithm<h2>' ...
        '<h3>Before Normalization</h3>'
        ]);
    
    Ak = zeros(1, 7);
    for i = 1:7
        test_sig = sin(2 * pi * dtmf_freqs(i) * t);
    
        [~, Ak(i), ~] = goertzel(test_sig, k_indices(i));
    
    end

    f2 = figure('visible', 'off');
    f2.Position(3:4) = [600 300];
    bar(dtmf_freqs, Ak);
    xlabel('Frequency (Hz)');
    ylabel('Magnitude');
    xticklabels(cellstr(num2str(dtmf_freqs')));
    title(['Maximum Magnitude for Each Input Frequency']);

    exportgraphics(f2, 'f2.png', 'Resolution', 100);
    fprintf(fileID, ['<img src="f2.png"/> <br/><br/>']);

    fprintf(fileID, '<br/><div style="page-break-after: always;"></div>');

    %%%%%

    fprintf(fileID, '<h3>After Normalization</h3>');
    
    scaling_factors = zeros(1, 7);
    for i = 1:7
        scaling_factors(i) = 1/Ak(i); 
    end

    f3 = figure('visible', 'off');
    f3.Position(3:4) = [600 300];
    bar(dtmf_freqs, Ak.*scaling_factors);
    xlabel('Frequency (Hz)');
    ylabel('Magnitude');
    xticklabels(cellstr(num2str(dtmf_freqs')));
    title(['Maximum Magnitude for Each Input Frequency']);

    exportgraphics(f3, 'f3.png', 'Resolution', 100);
    fprintf(fileID, ['<img src="f3.png"/> <br/><br/>']);

    fprintf(fileID, '<br/><div style="page-break-after: always;"></div>');

    fprintf(fileID, [ ...
        '<table>' ...
            '<tr><th style="padding: 5px;">Frequency</th><th style="padding: 5px;">Scaling Factor</th></tr>' ...
        ]);

    for i = 1:7
        fprintf(fileID, [ ...
            '<tr>' ...
                '<td>', num2str(dtmf_freqs(i)), ' Hz</td>' ...
                '<td>', num2str(scaling_factors(i)), '</td>' ...
            '</tr>'
            ]);
    end
    fprintf(fileID, '</table>');

    fprintf(fileID, '<br/><hr/><div style="page-break-after: always;"></div>');

else % note: scaling factors needed for the following sections
    scaling_factors = [2.0084 2.6215 2.0077 2.11 2.1172 2.2914 2.936];
end

%%%% PLOT: DTMF TONE DETECTION BY SUBCOMPONENT %%%%%%%%%%%%%%%%%%%%%%%%%%
SKIP = false;

if ~SKIP

    fprintf(fileID, [ ...
        '<h2>Detecting 12 DTMF (Pure) Tones</h2>'
        ]);

    Ak = zeros(7, 12); % reset + new size

    for i = 1:12        % iterator for dtmf tone
        for j = 1:7     % iterator for tone to be detected
            [~, Ak(j, i), ~] = goertzel(dtmf{i, 4}, k_indices(j));
            Ak(j, i) = Ak(j, i)  * scaling_factors(j);

        end

        f4(i) = figure('visible', 'off');
        f4(i).Position(3:4) = [500 180];

        bar(dtmf_freqs, Ak(:, i))
        axis([600 1500 0 1.1]);
        xlabel('Frequency (Hz)');
        ylabel('Magnitude');
        xticklabels(cellstr(num2str(dtmf_freqs')));

        title(['Detected Frequencies for ', num2str(dtmf{i, 2}), ' + ', num2str(dtmf{i, 3}), ' Hz (', dtmf{i, 1}, ') (Normalized)']);
        subtitle(['Magnitudes: ', mat2str(Ak(:,i), 2)]);

        exportgraphics(f4(i), ['f4_', num2str(i), '.png'], 'Resolution', 100);
        fprintf(fileID, ['<img src="f4_', num2str(i), '.png"/><br/>']);
    end

    fprintf(fileID, '<br/><hr/><div style="page-break-after: always;"></div>');

    fprintf(fileID, [ ...
        '<p>Summary of Resulting Detection Magnitudes for Pure Tone Inputs</p></br>' ...
        '<table style="border: 1px solid black">' ...
            '<tr>' ...
                '<th>Input Signal</th>' ...
                '<th>g(697)</th>' ...
                '<th>g(770)</th>' ...
                '<th>g(852)</th>' ...
                '<th>g(941)</th>' ...
                '<th>g(1209)</th>' ...
                '<th>g(1336)</th>' ...
                '<th>g(1477)</th>' ...
            '</tr>'
        ]);

    for in_sig = 1:12
        fprintf(fileID, [ ...
            '<tr>' ...
                '<td>', ...
                '<strong>', num2str(dtmf{in_sig, 2}), ' + ', num2str(dtmf{in_sig, 3}), '</strong>' ...
                '</td>'
            ]);

        for comp_sig = 1:7
            if dtmf_freqs(comp_sig) == dtmf{in_sig, 2} || dtmf_freqs(comp_sig) == dtmf{in_sig, 3}
                fprintf(fileID, [ ...
                    '<td class="highlighted_td">', ...
                    num2str(Ak(comp_sig, in_sig), 2), ...
                    '</td>'
                    ]);
            else
                fprintf(fileID, [ ...
                    '<td>', ...
                    num2str(Ak(comp_sig, in_sig), 2), ...
                    '</td>'
                    ]);
            end
        end 

        fprintf(fileID, '</tr>');
    end

    fprintf(fileID, '</table>');

    fprintf(fileID, '<br/><hr/><div style="page-break-after: always;"></div>');
end

%%%% USING AWGN %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
SKIP = false;

if ~SKIP
    fprintf(fileID, [ ...
        '<h2>Input Signals with Additive White Gaussian Noise (AWGN)</h2>' ...
        '<p>Configuration: awgn(pure tone, SNR in dB, measured)</p><br/><br/>'
        ]);

    % illustrate AWGN
    % no AWGN
    f5b(1) = figure('visible','off');
    f5b(1).Position(3:4) = [400 120];

    plot(dtmf{1, 4, :});
    axis([0 320 -3 3]);
    title([num2str(dtmf{1, 2}), ' Hz + ', num2str(dtmf{1, 3}), ' Hz (', dtmf{1, 1}, '), no AWGN']);

    exportgraphics(f5b(1), 'f5b_1.png', 'Resolution', 100);
    fprintf(fileID, '<img src="f5b_1.png"/> <br/>');

    % +20 dB
    f5b(2) = figure('visible','off');
    f5b(2).Position(3:4) = [400 120];

    plot(awgn(dtmf{1, 4, :}, 20, 'measured'));
    axis([0 320 -3 3]);
    title([num2str(dtmf{1, 2}), ' Hz + ', num2str(dtmf{1, 3}), ' Hz (', dtmf{1, 1}, '), +20 dB SNR']);

    exportgraphics(f5b(2), 'f5b_2.png', 'Resolution', 100);
    fprintf(fileID, '<img src="f5b_2.png"/> <br/>');

    % 0 dB
    f5b(3) = figure('visible','off');
    f5b(3).Position(3:4) = [400 120];

    plot(awgn(dtmf{1, 4, :}, 0, 'measured'));
    axis([0 320 -3 3]);
    title([num2str(dtmf{1, 2}), ' Hz + ', num2str(dtmf{1, 3}), ' Hz (', dtmf{1, 1}, '), 0 dB SNR']);

    exportgraphics(f5b(3), 'f5b_3.png', 'Resolution', 100);
    fprintf(fileID, '<img src="f5b_3.png"/> <br/>');

    % -20 dB
    f5b(4) = figure('visible','off');
    f5b(4).Position(3:4) = [400 120];

    plot(awgn(dtmf{1, 4, :}, -10, 'measured'));
    axis([0 320 -3 3]);
    title([num2str(dtmf{1, 2}), ' Hz + ', num2str(dtmf{1, 3}), ' Hz (', dtmf{1, 1}, '), -10 dB SNR']);

    exportgraphics(f5b(4), 'f5b_4.png', 'Resolution', 100);
    fprintf(fileID, '<img src="f5b_4.png"/> <br/><br/>');

    Ak_none     = zeros(7, 12);    % no AWGN
    Ak_20       = zeros(7, 12);    % AWGN +20 dB
    Ak_0        = zeros(7, 12);    % AWGN 0 dB
    Ak_min10    = zeros(7, 12);    % AWGN -10 dB

    for i = 1:12        % iterator for dtmf tone
        for j = 1:7     % iterator for tone to be detected

            [~, Ak_none(j, i), ~] = goertzel(dtmf{i, 4}, k_indices(j));
            Ak_none(j, i) = Ak_none(j, i)  * scaling_factors(j);

            [~, Ak_20(j, i), ~] = goertzel(awgn(dtmf{i, 4}, 20, 'measured'), k_indices(j));
            Ak_20(j, i) = Ak_20(j, i)  * scaling_factors(j);

            [~, Ak_0(j, i), ~] = goertzel(awgn(dtmf{i, 4}, 0, 'measured'), k_indices(j));
            Ak_0(j, i) = Ak_0(j, i)  * scaling_factors(j);

            [~, Ak_min10(j, i), ~] = goertzel(awgn(dtmf{i, 4}, -10, 'measured'), k_indices(j));
            Ak_min10(j, i) = Ak_min10(j, i)  * scaling_factors(j);

        end

        f5(i) = figure('visible', 'off');
        f5(i).Position(3:4) = [700 250];

        bar(dtmf_freqs, [Ak_none(:, i), Ak_20(:, i), Ak_0(:, i), Ak_min10(:, i)]);
        axis([600 1500 0 1.5]);
        xlabel('Frequency (Hz)');
        ylabel('Magnitude');
        xticklabels(cellstr(num2str(dtmf_freqs')));

        title(['Detected Frequencies for ', num2str(dtmf{i, 2}), ' + ', num2str(dtmf{i, 3}), ' Hz (', dtmf{i, 1}, ') (Normalized)']);
        subtitle('Left to right: no AWGN, +20 dB SNR, 0 dB SNR, -10 dB SNR');

        exportgraphics(f5(i), ['f5_', num2str(i), '.png'], 'Resolution', 120);
        fprintf(fileID, ['<img src="f5_', num2str(i), '.png"/><br/><br/>']);
    end

    fprintf(fileID, '<br/><hr/><div style="page-break-after: always;"></div>');

    fprintf(fileID, [ ...
        '<p>Summary of Resulting Detection Magnitudes for Inputs with AWGN</p></br>' 
   
        ]);

    for in_sig = 1:12
        % create new table for each of the 12 tones
        fprintf(fileID, [ ...
            '<br/><table style="border: 1px solid black">' ...
            '<tr>' ...
                '<th>Input Signal</th>' ...
                '<th>g(697)</th>' ...
                '<th>g(770)</th>' ...
                '<th>g(852)</th>' ...
                '<th>g(941)</th>' ...
                '<th>g(1209)</th>' ...
                '<th>g(1336)</th>' ...
                '<th>g(1477)</th>' ...
            '</tr>'
            ]);
        % no AWGN
        fprintf(fileID, [ ...
            '<tr>' ...
                '<td>', ...
                '<strong>', num2str(dtmf{in_sig, 2}), ' + ', num2str(dtmf{in_sig, 3}), ', no AWGN</strong>' ...
                '</td>'
            ]);

        for comp_sig = 1:7
            if dtmf_freqs(comp_sig) == dtmf{in_sig, 2} || dtmf_freqs(comp_sig) == dtmf{in_sig, 3}
                fprintf(fileID, [ ...
                    '<td class="highlighted_td">', ...
                    num2str(Ak_none(comp_sig, in_sig), 2), ...
                    '</td>'
                    ]);
            else
                fprintf(fileID, [ ...
                    '<td>', ...
                    num2str(Ak_none(comp_sig, in_sig), 2), ...
                    '</td>'
                    ]);
            end
        end 

        fprintf(fileID, '</tr>');

        % +20 dB
        fprintf(fileID, [ ...
            '<tr>' ...
                '<td>', ...
                '<strong>', num2str(dtmf{in_sig, 2}), ' + ', num2str(dtmf{in_sig, 3}), ', +20 dB</strong>' ...
                '</td>'
            ]);

        for comp_sig = 1:7
            if dtmf_freqs(comp_sig) == dtmf{in_sig, 2} || dtmf_freqs(comp_sig) == dtmf{in_sig, 3}
                fprintf(fileID, [ ...
                    '<td class="highlighted_td">', ...
                    num2str(Ak_20(comp_sig, in_sig), 2), ...
                    '</td>'
                    ]);
            else
                fprintf(fileID, [ ...
                    '<td>', ...
                    num2str(Ak_20(comp_sig, in_sig), 2), ...
                    '</td>'
                    ]);
            end
        end 

        fprintf(fileID, '</tr>');

        % 0 dB
        fprintf(fileID, [ ...
            '<tr>' ...
                '<td>', ...
                '<strong>', num2str(dtmf{in_sig, 2}), ' + ', num2str(dtmf{in_sig, 3}), ', 0 dB</strong>' ...
                '</td>'
            ]);

        for comp_sig = 1:7
            if dtmf_freqs(comp_sig) == dtmf{in_sig, 2} || dtmf_freqs(comp_sig) == dtmf{in_sig, 3}
                fprintf(fileID, [ ...
                    '<td class="highlighted_td">', ...
                    num2str(Ak_0(comp_sig, in_sig), 2), ...
                    '</td>'
                    ]);
            else
                fprintf(fileID, [ ...
                    '<td>', ...
                    num2str(Ak_0(comp_sig, in_sig), 2), ...
                    '</td>'
                    ]);
            end
        end 

        fprintf(fileID, '</tr>');

        % -10 dB
        fprintf(fileID, [ ...
            '<tr>' ...
                '<td>', ...
                '<strong>', num2str(dtmf{in_sig, 2}), ' + ', num2str(dtmf{in_sig, 3}), ', -10 dB</strong>' ...
                '</td>'
            ]);

        for comp_sig = 1:7
            if dtmf_freqs(comp_sig) == dtmf{in_sig, 2} || dtmf_freqs(comp_sig) == dtmf{in_sig, 3}
                fprintf(fileID, [ ...
                    '<td class="highlighted_td">', ...
                    num2str(Ak_min10(comp_sig, in_sig), 2), ...
                    '</td>'
                    ]);
            else
                fprintf(fileID, [ ...
                    '<td>', ...
                    num2str(Ak_min10(comp_sig, in_sig), 2), ...
                    '</td>'
                    ]);
            end
        end 

        fprintf(fileID, '</tr><br/>');
    end

    fprintf(fileID, '</table>');

    fprintf(fileID, '<br/><hr/><div style="page-break-after: always;"></div>');
    
end 

%%%% FRAME SHIFTING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
SKIP = false;

if ~SKIP
    fprintf(fileID, [ ...
        '<h2>Frame Shifting</h2>' ...
        '<p>Simulating what happens when frame synchronization is not perfect.</p>' ...
        '<p>No AWGN, for now.</p><br/><br/>'
        ]);

    shiftBy = [-80 -60 -40 -20 0 20 40 60 80];

    % illustrate frame shifting
    for s = 1:length(shiftBy)

        if shiftBy(s) < 0
            shifted_sig = [dtmf{1, 4, :}(-shiftBy(s):N), rand(1, -(shiftBy(s)))*4 - 2];
        else
            shifted_sig = [rand(1, shiftBy(s))*4 - 2, dtmf{1, 4, :}(1:N - shiftBy(s))];
        end

        f6(s) = figure('visible', 'off');
        f6(s).Position(3:4) = [400 120];
        plot(shifted_sig);
        axis([0 320 -2 2]);
        title([num2str(dtmf{1, 2}), ' Hz + ', num2str(dtmf{1, 3}), ' Hz (', dtmf{1, 1}, '), shifted by ', num2str(shiftBy(s)), ' samples (', num2str(round(shiftBy(s)/N, 4)*100), '%)']);

        exportgraphics(f6(s), ['f6_', num2str(s), '.png'], 'Resolution', 100);
        fprintf(fileID, ['<img src="f6_', num2str(s), '.png"/> <br/>']);
    end

    fprintf(fileID, '<br/><hr/><div style="page-break-after: always;"></div>');

    fprintf(fileID, '<br/><p>Left to right: Shifted ');
    for s = 1:length(shiftBy) - 1
        fprintf(fileID, [num2str(round(shiftBy(s)/N, 4)*100), ' %%, ']);
    end
    fprintf(fileID, [num2str(round(shiftBy(length(shiftBy))/N, 4)*100), '%%.</p><p>All magnitudes have been normalized.</p><br/>']);

    Ak_s = zeros(12, length(shiftBy), 7); % 12 dtmf tones, number of shift values, 7 freqs to detect
    for s = 1:length(shiftBy)
        shift = shiftBy(s);

        if shift < 0
            for i = 1:12
                shifted_sig = [dtmf{i, 4, :}(-shift:N), rand(1, -shift)*4 - 2];
                for j = 1:7
                    [~, Ak_s(i, s, j), ~] = goertzel(shifted_sig, k_indices(j));
                    Ak_s(i, s, j) = Ak_s(i, s, j) * scaling_factors(j);
                end
            end
        else
            for i = 1:12
                shifted_sig = [rand(1, shift)*4 - 2, dtmf{i, 4, :}(1:N - shift)];
                for j = 1:7
                    [~, Ak_s(i, s, j), ~] = goertzel(shifted_sig, k_indices(j));
                    Ak_s(i, s, j) = Ak_s(i, s, j) * scaling_factors(j);
                end
            end
        end
    end

    for i = 1:12
        f7(i) = figure('visible', 'off');
        f7(i).Position(3:4) = [850 300];
        bar(dtmf_freqs, squeeze(Ak_s(i,:,:)));
        xlabel('Frequency (Hz)');
        ylabel('Magnitude');
        xticklabels(cellstr(num2str(dtmf_freqs')));
        title(['Effect of Shifting on Input: ', num2str(dtmf{i, 2}), ' + ', num2str(dtmf{i, 3}), ' Hz (', num2str(dtmf{i, 1}), ')']);
    
        exportgraphics(f7(i), ['f7_', num2str(i), '.png'], 'Resolution', 100);
        fprintf(fileID, ['<img src="f7_', num2str(i), '.png"/> <br/><br/>']);
    end

    fprintf(fileID, '<br/><hr/><div style="page-break-after: always;"></div>');

end

%%%% FRAME SHIFTING + AWGN %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
SKIP = false;

if ~SKIP
    awgn_snr = 0; % in dB

    fprintf(fileID, [ ...
        '<h2>Frame Shifting + AWGN</h2>' ...
        '<p>Combining both frame shifting and Additive White Gaussian Noise.</p>' ...
        '<p>AWGN setting: ', num2str(awgn_snr), ' dB Signal-to-Noise ratio (SNR).</p><br/><br/>'
        ]);

    % example illustration
    f9b = figure('visible','off');
    f9b.Position(3:4) = [400 120];

    plot(awgn([rand(1, 40)*4 - 2, dtmf{1, 4, :}(1:N - 40)], awgn_snr, 'measured'));
    axis([0 320 -3 3]);
    title(['Example: ', num2str(dtmf{1, 2}), ' Hz + ', num2str(dtmf{1, 3}), ' Hz (', dtmf{1, 1}, ')']);
    subtitle(['Shifted ', num2str(round(40/N, 4)*100), '%% with AWGN of ', num2str(awgn_snr), ' dB SNR.']);

    exportgraphics(f9b, 'f9b.png', 'Resolution', 100);
    fprintf(fileID, '<img src="f9b.png"/> <br/>');

    % actual calculations
    shiftBy = [-80 -60 -40 -20 0 20 40 60 80];
    fprintf(fileID, '<br/><p>Left to right: Shifted ');
    for s = 1:length(shiftBy) - 1
        fprintf(fileID, [num2str(round(shiftBy(s)/N, 4)*100), ' %%, ']);
    end
    fprintf(fileID, [num2str(round(shiftBy(length(shiftBy))/N, 4)*100), '%%.</p><p>All magnitudes have been normalized using the scaling factors that were calculated using pure/ideal tone (no AWGN + shifting) inputs.</p><br/>']);

    Ak_sn = zeros(12, length(shiftBy), 7); % 12 dtmf tones, number of shift values, 7 freqs to detect
    for s = 1:length(shiftBy)
        shift = shiftBy(s);

        if shift < 0
            for i = 1:12
                shifted_sig = awgn([dtmf{i, 4, :}(-shift:N), rand(1, -shift)*4 - 2], awgn_snr, 'measured');
                for j = 1:7
                    [~, Ak_sn(i, s, j), ~] = goertzel(shifted_sig, k_indices(j));
                    Ak_sn(i, s, j) = Ak_sn(i, s, j) * scaling_factors(j);
                end
            end
        else
            for i = 1:12
                shifted_sig = awgn([rand(1, shift)*4 - 2, dtmf{i, 4, :}(1:N - shift)], awgn_snr, 'measured');
                for j = 1:7
                    [~, Ak_sn(i, s, j), ~] = goertzel(shifted_sig, k_indices(j));
                    Ak_sn(i, s, j) = Ak_sn(i, s, j) * scaling_factors(j);
                end
            end
        end
    end

    for i = 1:12
        f8(i) = figure('visible', 'off');
        f8(i).Position(3:4) = [850 300];
        bar(dtmf_freqs, squeeze(Ak_sn(i,:,:)));
        xlabel('Frequency (Hz)');
        ylabel('Magnitude');
        xticklabels(cellstr(num2str(dtmf_freqs')));
        title(['Effect of Shifting on Input: ', num2str(dtmf{i, 2}), ' + ', num2str(dtmf{i, 3}), ' Hz (', num2str(dtmf{i, 1}), ')']);
    
        exportgraphics(f8(i), ['f8_', num2str(i), '.png'], 'Resolution', 100);
        fprintf(fileID, ['<img src="f8_', num2str(i), '.png"/> <br/><br/>']);
    end

    fprintf(fileID, '<br/><div style="page-break-after: always;"></div>');

    % table
    for in_sig = 1:12
        % create new table for each of the 12 tones
        fprintf(fileID, [ ...
            '<br/><table style="border: 1px solid black">' ...
            '<tr>' ...
                '<th>Input Signal</th>' ...
                '<th>g(697)</th>' ...
                '<th>g(770)</th>' ...
                '<th>g(852)</th>' ...
                '<th>g(941)</th>' ...
                '<th>g(1209)</th>' ...
                '<th>g(1336)</th>' ...
                '<th>g(1477)</th>' ...
            '</tr>'
            ]);

        for s = 1:length(shiftBy)
            fprintf(fileID, [ ...
                '<tr>' ...
                    '<td>', ...
                            '<strong>', num2str(dtmf{in_sig, 2}), ' + ', num2str(dtmf{in_sig, 3}), ', shifted by ', num2str(round(shiftBy(s)/N, 4)*100), '%%</strong>' ...
                    '</td>'
                ]);

            for comp_sig = 1:7
                if dtmf_freqs(comp_sig) == dtmf{in_sig, 2} || dtmf_freqs(comp_sig) == dtmf{in_sig, 3}
                    fprintf(fileID, [ ...
                        '<td class="highlighted_td">', ...
                        num2str(Ak_sn(in_sig, s, comp_sig), 2), ...
                        '</td>'
                        ]);
                else
                    fprintf(fileID, [ ...
                        '<td>', ...
                        num2str(Ak_sn(in_sig, s, comp_sig), 2), ...
                        '</td>'
                        ]);
                end
            end 

            fprintf(fileID, '</tr><br/>');
        end
        fprintf(fileID, '</table><br/>');
    end

end

%%%% END DOCUMENT %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf(fileID, document_end);

fclose(fileID);

%%%% GOERTZEL ALGORITHM IMPLEMENTATION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [yn, Ak, filter_output] = goertzel(x, k)

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