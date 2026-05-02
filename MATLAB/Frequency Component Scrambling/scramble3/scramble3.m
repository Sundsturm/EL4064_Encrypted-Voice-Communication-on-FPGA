
tic
% based on source_h (from /botol/) but with pre-computed FFTs

fileID = fopen('scramble3_report.html', 'w');
doc_title = sprintf('Scrambling Experiment 3');
doc_h1 = sprintf('Scrambling Experiment 3');
doc_subtitle = sprintf('Various Scrambling/Descrambling Configurations');
img_res = 80; % MATLAB's default is 150

% scramble configuration
% 0 1 2 3 4 5 6 7 = does not get scrambled
% 4 5 6 7 0 1 2 3 = swap first 4 freqs with 4 latter freqs
% and so on

experiments = [
    0 1 2 3 4 5 6 7;
    7 0 1 2 3 4 5 6;
    6 7 0 1 2 3 4 5;
    5 6 7 0 1 2 3 4;
    4 5 6 7 0 1 2 3;
    5 4 7 6 0 1 2 3;
    6 7 4 5 0 1 2 3;
    7 6 5 4 0 1 2 3;
    4 5 6 7 1 0 3 2;
    4 5 6 7 2 3 0 1;
    4 5 6 7 3 2 1 0;
    7 6 5 4 0 1 2 3;
    4 5 6 7 3 2 1 0;
    7 6 4 5 3 2 1 0;
    2 3 0 1 4 5 6 7;
    2 3 4 0 1 5 6 7;
    2 3 4 5 0 1 6 7;
    2 3 4 5 6 0 1 7;
    2 3 4 5 6 7 0 1
    ];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

load('lut.mat');

[y, f] = audioread("botol.wav");    % amplitude vs frequency
n = 0.02 * f;                       % panjang array audio selama 20 ms
fc = 7000/(f/2);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

f_audio_init = figure('visible', 'off');
f_audio_init.Position(3:4) = [450 400];
plot(y);
title("Initial input audio in time domain");
exportgraphics(f_audio_init, 'f_audio_init.png', 'Resolution', img_res);

z = zeros(ceil(length(y)/n), n);
counter = 1;
for m = n:n:length(y)
    z(counter, :) = y(n*(counter - 1) + 1:m, 1);
    counter = counter + 1;
end

                  %-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%


Z = readmatrix("botol_fft_z.csv");
Zi = readmatrix("botol_fft_zi.csv");

f_Z_100 = figure('visible', 'off');
f_Z.Position(3:4) = [450 250];
plot((abs(real(Z(100,:)))));
title("Z before scrambling (real absolute parts) (100, :)");
exportgraphics(f_Z_100, 'f_Z_100.png', 'Resolution', img_res);

f_Zi_100 = figure('visible', 'off');
f_Zi.Position(3:4) = [450 250];
plot((abs(real(Zi(100,:)))));
title("Zi before scrambling (real absolute parts) (100, :)");
exportgraphics(f_Zi_100, 'f_Zi_100.png', 'Resolution', img_res);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for ex = 1:size(experiments, 1) 

    temp1 = [];
    temp2 = [];
    R = zeros(ceil(length(y)/n), n);
    Ri = zeros(ceil(length(y)/n), n);
    
    for m = 1:counter
        temp1 = Z(m, :);
        temp2 = Zi(m, :);

        % temp(n*20+1:(n+1)*20)
        a1 = experiments(ex, 1)*20+1;
        a2 = (experiments(ex, 1)+1)*20;
        b1 = experiments(ex, 2)*20+1;
        b2 = (experiments(ex, 2)+1)*20;
        c1 = experiments(ex, 3)*20+1;
        c2 = (experiments(ex, 3)+1)*20;
        d1 = experiments(ex, 4)*20+1;
        d2 = (experiments(ex, 4)+1)*20;
        e1 = experiments(ex, 5)*20+1;
        e2 = (experiments(ex, 5)+1)*20;
        f1 = experiments(ex, 6)*20+1;
        f2 = (experiments(ex, 6)+1)*20;
        g1 = experiments(ex, 7)*20+1;
        g2 = (experiments(ex, 7)+1)*20;
        h1 = experiments(ex, 8)*20+1;
        h2 = (experiments(ex, 8)+1)*20;

        temp1(1:160) =  [Z(m, a1:a2) Z(m, b1:b2) Z(m, c1:c2) Z(m, d1:d2) Z(m, e1:e2) Z(m, f1:f2) Z(m, g1:g2) Z(m, h1:h2)];
        temp2(1:160) = [Zi(m,  a1:a2) Zi(m, b1:b2) Zi(m, c1:c2) Zi(m, d1:d2) Zi(m, e1:e2) Zi(m, f1:f2) Zi(m, g1:g2) Zi(m, h1:h2)];

        % temp(n*20+801:(n+1)*20+800)
        a1 = experiments(ex, 1)*20+801;
        a2 = (experiments(ex, 1)+1)*20+800;
        b1 = experiments(ex, 2)*20+801;
        b2 = (experiments(ex, 2)+1)*20+800;
        c1 = experiments(ex, 3)*20+801;
        c2 = (experiments(ex, 3)+1)*20+800;
        d1 = experiments(ex, 4)*20+801;
        d2 = (experiments(ex, 4)+1)*20+800;
        e1 = experiments(ex, 5)*20+801;
        e2 = (experiments(ex, 5)+1)*20+800;
        f1 = experiments(ex, 6)*20+801;
        f2 = (experiments(ex, 6)+1)*20+800;
        g1 = experiments(ex, 7)*20+801;
        g2 = (experiments(ex, 7)+1)*20+800;
        h1 = experiments(ex, 8)*20+801;
        h2 = (experiments(ex, 8)+1)*20+800;

        temp1(801:960) = [Z(m, a1:a2) Z(m, b1:b2) Z(m, c1:c2) Z(m, d1:d2) Z(m, e1:e2) Z(m, f1:f2) Z(m, g1:g2) Z(m, h1:h2)];
        temp2(801:960) = [Zi(m,  a1:a2) Zi(m, b1:b2) Zi(m, c1:c2) Zi(m, d1:d2) Zi(m, e1:e2) Zi(m, f1:f2) Zi(m, g1:g2) Zi(m, h1:h2)];
    
        R(m, :) = temp1;
        Ri(m, :) = temp2;
    
        temp1 = [];
        temp2 = [];
    end
    
    for m = 1:counter
        re(m, :) = mat_ifft(R(m,:), Ri(m,:), r, i);
    end
    
    c = [];
    for m = 1:counter
        c = [c real(re(m,:))];
    end
    
    f_audio_out(ex) = figure('visible', 'off');
    f_audio_out(ex).Position(3:4) = [450 400];
    plot(c);
    title(sprintf(['ex', num2str(ex), ' - Resulting output audio in time domain']));
    exportgraphics(f_audio_out(ex), sprintf(['ex', num2str(ex), '_f_audio_out.png']), 'Resolution', img_res);
    
    audiowrite(sprintf(['ex', num2str(ex), '_botol_scrambled.wav']), c, f);

    f_R_100(ex) = figure('visible', 'off');
    f_R_100(ex).Position(3:4) = [450 250];
    plot((abs(real(R(100,:)))));
    title(sprintf(['ex', num2str(ex), '- R after scrambling (real absolute parts) (100, :)']));
    exportgraphics(f_R_100(ex), ['ex', num2str(ex), '_f_R_100.png'], 'Resolution', img_res);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for ex = 1:size(experiments, 1) 

    [c, f] = audioread(sprintf(['ex', num2str(ex), '_botol_scrambled.wav']));
    
    x = zeros(ceil(length(y)/n), n);
    counter = 1;
    for m = n:n:length(y)
        x(counter, :) = c(n*(counter-1)+1:m, 1);
        counter = counter + 1;
    end
    
    X = zeros(counter,960);
    Xi = zeros(counter,960);
    
    for m = 1:counter
        [X(m,:), Xi(m,:)] = mat_fft(x(m,:), r, i);
    end
    
    B = zeros(ceil(length(y)/n),n);
    for m = 1:counter
        temp1 = X(m, :);
        temp2 = Xi(m, :);
        
        % temp(n*20+1:(n+1)*20)
        a1 = experiments(ex, 1)*20+1;
        a2 = (experiments(ex, 1)+1)*20;
        b1 = experiments(ex, 2)*20+1;
        b2 = (experiments(ex, 2)+1)*20;
        c1 = experiments(ex, 3)*20+1;
        c2 = (experiments(ex, 3)+1)*20;
        d1 = experiments(ex, 4)*20+1;
        d2 = (experiments(ex, 4)+1)*20;
        e1 = experiments(ex, 5)*20+1;
        e2 = (experiments(ex, 5)+1)*20;
        f1 = experiments(ex, 6)*20+1;
        f2 = (experiments(ex, 6)+1)*20;
        g1 = experiments(ex, 7)*20+1;
        g2 = (experiments(ex, 7)+1)*20;
        h1 = experiments(ex, 8)*20+1;
        h2 = (experiments(ex, 8)+1)*20;

        temp1(1:160) = [X(m, a1:a2) X(m, b1:b2) X(m, c1:c2) X(m, d1:d2) X(m, e1:e2) X(m, f1:f2) X(m, g1:g2) X(m, h1:h2)];
        temp2(1:160) = [Xi(m, a1:a2) Xi(m, b1:b2) Xi(m, c1:c2) Xi(m, d1:d2) Xi(m, e1:e2) Xi(m, f1:f2) Xi(m, g1:g2) Xi(m, h1:h2)];

        % temp(n*20+801:(n+1)*20+800)
        a1 = experiments(ex, 1)*20+801;
        a2 = (experiments(ex, 1)+1)*20+800;
        b1 = experiments(ex, 2)*20+801;
        b2 = (experiments(ex, 2)+1)*20+800;
        c1 = experiments(ex, 3)*20+801;
        c2 = (experiments(ex, 3)+1)*20+800;
        d1 = experiments(ex, 4)*20+801;
        d2 = (experiments(ex, 4)+1)*20+800;
        e1 = experiments(ex, 5)*20+801;
        e2 = (experiments(ex, 5)+1)*20+800;
        f1 = experiments(ex, 6)*20+801;
        f2 = (experiments(ex, 6)+1)*20+800;
        g1 = experiments(ex, 7)*20+801;
        g2 = (experiments(ex, 7)+1)*20+800;
        h1 = experiments(ex, 8)*20+801;
        h2 = (experiments(ex, 8)+1)*20+800;

        temp1(801:960) = [X(m, a1:a2) X(m, b1:b2) X(m, c1:c2) X(m, d1:d2) X(m, e1:e2) X(m, f1:f2) X(m, g1:g2) X(m, h1:h2)];
        temp2(801:960) = [Xi(m, a1:a2) Xi(m, b1:b2) Xi(m, c1:c2) Xi(m, d1:d2) Xi(m, e1:e2) Xi(m, f1:f2) Xi(m, g1:g2) Xi(m, h1:h2)];
    
        B(m,:) = temp1;
        Bi(m,:) = temp2;
    end
    
    b = zeros(ceil(length(y)/n),n);
    for m = 1:counter
        b(m,:) = mat_ifft(B(m,:), Bi(m,:), r, i);
    end
    
    d = [];
    for m = 1:counter
        d = [d real(b(m,:))];
    end

    audiowrite(sprintf(['ex', num2str(ex), '_botol_recon.wav']), d, f);
    
    f_B_100(ex) = figure('visible', 'off');
    f_B_100(ex).Position(3:4) = [450 250];
    plot((abs(real(B(100,:)))));
    title(sprintf(['ex', num2str(ex), '- B after reconstruction (real absolute parts) (100, :)']));
    exportgraphics(f_B_100(ex), ['ex', num2str(ex), '_f_B_100.png'], 'Resolution', img_res);
    
    %f_Ri_100(ex) = figure('visible', 'off');
    %f_Ri_100(ex).Position(3:4) = [450 250];
    %plot((abs(real(Ri(100,:)))));
    %title(sprintf(['ex', num2str(ex), '- Ri after scrambling (real absolute parts) (100, :)']));
    %exportgraphics(f_Ri_100(ex), ['ex', num2str(ex), '_f_Ri_100.png'], 'Resolution', img_res);
    
    f_audio_recon(ex) = figure('visible', 'off');
    f_audio_recon(ex).Position(3:4) = [450 400];
    plot(d);
    title(sprintf(['ex', num2str(ex), '- Reconstructed descrambled audio in time domain']));
    exportgraphics(f_audio_recon(ex), ['ex', num2str(ex), '_f_audio_recon.png'], 'Resolution', img_res);
    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


document_start = sprintf([ ... 
    '<!DOCTYPE html>' ...
    '<html>' ...
        '<head>' ...
            '<title>', doc_title, '</title>' ...
            '<style>' ...
                '.bordered-table, .bordered-table tr, .bordered-table tr td, .bordered-table tr th {border: 1px solid gray; border-collapse: collapse;}' ...
            '</style>' ...
        '</head>' ...
        '<body>' ...
        '<center>'
]);

document_heading = sprintf([ ...
    '<h1>', doc_h1, '</h1>' ...
    '<p>', doc_subtitle, '</p>' ...
    '<p> Image resolution for plots: ', num2str(img_res), '</p>' ...
    '<p>Fs = ', num2str(f), ', Fc = ', num2str(fc), '</p>' ...
    '<p>n = ', num2str(length(y)), ', ', num2str(length(c)), ', ', num2str(length(d)), ' for input, scrambled, and reconstructed audio respectively.</p>' ...
    '<br/>'
    ]);

document_end = sprintf([ ...
        '</body>' ...
        '</center>' ...
    '</html>'
    ]);

fprintf(fileID, document_start);
fprintf(fileID, document_heading);

fprintf(fileID, ['' ...
    '<table class="bordered-table">' ...
        '<tr>' ...
            '<th>Config</th>' ...
            '<th>Scrambling</th>' ...
            '<th>Reconstruction</th>' ...
        '</tr>'
        ]);

for ex = 1:size(experiments, 1)
    fprintf(fileID, [ ...
        '<tr>' ...
            '<td>', mat2str(experiments(ex,:)), '</td>' ...
            '<td><audio controls src="ex', num2str(ex), '_botol_scrambled.wav"></audio><br/><img src="ex', num2str(ex), '_f_audio_out.png"/><br/><img src="ex', num2str(ex), '_f_R_100.png"/></td>' ...
            '<td><audio controls src="ex', num2str(ex), '_botol_recon.wav"></audio><br/><img src="ex', num2str(ex), '_f_audio_recon.png"/><br/><img src="ex', num2str(ex), '_f_B_100.png"/></td>' ...
        '</tr>'
        ]);
end

fprintf(fileID, [ ...
    '</table>'
        ]);

%%%%%% END DOCUMENT %%%%%%

fprintf(fileID, document_end);
fclose(fileID);

toc
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5

function [R, I] = mat_fft(x, r, i)
    temp1 = 0;
    temp2 = 0;

    R = zeros(1, 960);
    I = zeros(1, 960);

    % actual algorithm:
    % for k = 0:959
    %   for n = 0:959
    %       idx = mod(k*n, 960) + 1
    %       temp1 = temp1 + (x(n+1) * r(idx));
    %       temp2 = temp2 + (x(n+1) * -i(idx));
    %
    %   end "for n"
    %
    %   R(k+1) = fi(temp1);
    %   I(k+1) = fi(temp2);
    %   temp1 = 0;
    %   temp2 = 0;
    %
    % end "for k" 

    for k = 0:959
        idx = -k + 1; % so that at n = 0, "idx = idx + k" = 1
        for n = 0:959 
            idx = idx + k;
            if (idx > 960)
                idx = idx - 960;
            end
            temp1 = temp1 + (x(n+1) * r(idx));
            temp2 = temp2 + (x(n+1) * -i(idx));
        end

        R(k+1) = fi(temp1);
        I(k+1) = fi(temp2);

        temp1 = 0;
        temp2 = 0;
    end
end

function x = mat_ifft(R, I, r, i)
    x = zeros(1, 960);
    temp = 0;
    for n = 0:959
        for k = 0:959
            idx = mod(k*n, 960) + 1;
            temp = temp + ((R(k+1))*r(idx) - I(k+1)*i(idx));
        end
        x(n+1) = temp;
        temp = 0;
    end
    x = (x/960);
end
