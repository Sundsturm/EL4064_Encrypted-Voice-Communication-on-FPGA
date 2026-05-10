%%%%%% DOCUMENT SETUP %%%%%%

fileID = fopen('scramble1_report.html', 'w');
doc_title = sprintf('Scrambling Experiment 1');
h1 = sprintf('Scrambling Experiment 1');
doc_subtitle = sprintf('Variant: Only move around freqs from 1:160 and 801:960. Scrambling configuration is the exact same as source_h.');
img_res = 80; % MATLAB's default is 150

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
tic
% based on source_h (from /botol/) but with pre-computed FFTs

load('lut.mat');

[y, f] = audioread("botol.wav");    % amplitude vs frequency
n = 0.02 * f;                       % panjang array audio selama 20 ms
fc = 7000/(f/2);

f_audio_init = figure('visible', 'off');
f_audio_init.Position(3:4) = [450 400];
plot(y);
title("Initial input audio in time domain");
exportgraphics(f_audio_init, 'f_audio_init.png', 'Resolution', img_res);

z = zeros(ceil(length(y)/n), n);
counter = 1;
for m = n:n:length(y)
    z(counter, :) = y(n*(counter-1)+1:m, 1);
    counter = counter + 1;
end

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

temp1 = [];
temp2 = [];
R = zeros(ceil(length(y)/n), n);
Ri = zeros(ceil(length(y)/n), n);

desc_scramble = sprintf(['' ...
    'Scrambling configuration: <br/>' ...
    '<code>temp1(1:160) = temp1([101:120 81:100 141:160 121:140 21:40 1:20 61:80 41:60]);</code><br/>' ...
    '<code>temp1(801:960) = temp1([901:920 881:900 941:960 921:940 821:840 801:820 861:880 841:860]);</code><br/>' ...
    '<br/>']);

for m = 1:counter
    temp1 = Z(m, :);
    temp2 = Zi(m, :);

    temp1(1:160) = temp1([101:120 81:100 141:160 121:140 21:40 1:20 61:80 41:60]); 
    temp2(1:160) = temp2([101:120 81:100 141:160 121:140 21:40 1:20 61:80 41:60]);
    
    temp1(801:960) = temp1([901:920 881:900 941:960 921:940 821:840 801:820 861:880 841:860]);
    temp2(801:960) = temp2([901:920 881:900 941:960 921:940 821:840 801:820 861:880 841:860]);

    R(m,:) = temp1;
    Ri(m,:) = temp2;

    temp1 = [];
    temp2 = [];
end

f_R_100 = figure('visible', 'off');
f_R.Position(3:4) = [450 250];
plot((abs(real(R(100,:)))));
title("R after scrambling (real absolute parts) (100, :)");
exportgraphics(f_R_100, 'f_R_100.png', 'Resolution', img_res);

f_Ri_100 = figure('visible', 'off');
f_Ri.Position(3:4) = [450 250];
plot((abs(real(Ri(100,:)))));
title("Ri after scrambling (real absolute parts) (100, :)");
exportgraphics(f_Ri_100, 'f_Ri_100.png', 'Resolution', img_res);

for m = 1:counter
    re(m, :) = mat_ifft(R(m,:), Ri(m,:), r, i);
end

c = [];
for m = 1:counter
    c = [c real(re(m,:))];
end

f_audio_out = figure('visible', 'off');
f_audio_out.Position(3:4) = [450 400];
plot(c);
title("Resulting output audio in time domain");
exportgraphics(f_audio_out, 'f_audio_out.png', 'Resolution', img_res);

audiowrite('botol_scrambled.wav', c, f);

%%%%%%%%%%%%%%

[c, f] = audioread("botol_scrambled.wav");

x = zeros(ceil(length(y)/n), n);
counter = 1;
for m = n:n:length(y)
    x(counter, :) = c(n*(counter-1)+1:m, 1);
    counter = counter + 1;
end

X = zeros(counter,960);
Xi = zeros(counter,960);

for m=1:counter
    [X(m,:), Xi(m,:)] = mat_fft(x(m,:), r, i);
end

% Proses inversi scramble dengan benar pada urutan frekuensi yang tepat
B = zeros(ceil(length(y)/n),n);
for m=1:counter
    temp1 = X(m, :);
    temp2 = Xi(m, :);

    % Inversi urutan scrambling untulpk frekuensi rendah dan tinggi
    temp1(1:160) = temp1([101:120 81:100 141:160 121:140 21:40 1:20 61:80 41:60]); 
    temp2(1:160) = temp2([101:120 81:100 141:160 121:140 21:40 1:20 61:80 41:60]);

    temp1(801:960) = temp1([901:920 881:900 941:960 921:940 821:840 801:820 861:880 841:860]);
    temp2(801:960) = temp2([901:920 881:900 941:960 921:940 821:840 801:820 861:880 841:860]);

    B(m,:) = temp1;
    Bi(m,:) = temp2;
end

for m=1:counter
    b(m,:)=mat_ifft(B(m,:), Bi(m,:), r, i);
end

d = [];
for m = 1:counter
    d = [d real(b(m,:))];
end

f_audio_recon = figure('visible', 'off');
f_audio_recon.Position(3:4) = [450 400];
plot(d);
title("Reconstructed descrambled audio in time domain");
exportgraphics(f_audio_recon, 'f_audio_recon.png', 'Resolution', img_res);

audiowrite('botol_recon.wav', d, f);

%%%%%%%%%%%%%%%%%%

document_start = sprintf([ ... 
    '<!DOCTYPE html>' ...
    '<html>' ...
        '<head>' ...
            '<title>', doc_title, '</title>' ...
        '</head>' ...
        '<body>' ...
        '<center>'
]);

document_heading = sprintf([ ...
    '<h1>', h1, '</h1>' ...
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

fprintf(fileID, desc_scramble);

fprintf(fileID, [ ...
    '<table class="table-no-border">' ...
        '<tr>' ...
            '<td><img src="f_audio_init.png"/></td>' ...
            '<td><img src="f_audio_out.png"/></td>' ...
            '<td><img src="f_audio_recon.png"/></td>' ...
        '</tr>' ...
        '<tr>' ...
            '<td><audio controls src="botol.wav"></audio></td>' ...
            '<td><audio controls src="botol_scrambled.wav"></audio></td>' ...
            '<td><audio controls src="botol_recon.wav"></audio></td>' ...
        '<tr>' ...
            '<td><img src="f_Z_100.png"/></td>' ...
            '<td><img src="f_R_100.png"/></td>' ...
        '</tr>' ...
        '<tr>' ...
            '<td><img src="f_Zi_100.png"/></td>' ...
            '<td><img src="f_Ri_100.png"/></td>' ...
        '</tr>' ...
    '</table>' ...
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
