
% export the FFT of WAV audio to CSV files
fn_csv_fft_z = "botol_fft_z.csv";
fn_csv_fft_zi = "botol_fft_zi.csv";


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%load('lut.mat');
load('lut16.mat');

[y, f] = audioread("botol_16kHz.wav");
n = 0.02 * f;                         
fc = 7000 / (f/2);
n = 0.02*f;                     % panjang array audio selama 20 ms
fc = 7000/(f/2);
filt = fir1(256,fc,'low');
z = zeros(ceil(length(y)/n),n);
temp = [];
counter = 1;
for m = 1:length(y)             % parse audio menjadi matriks
    temp = [temp, y(m)];
    if mod(m, n) == 0
        z(counter, :) = temp;
        counter = counter + 1;
        temp = [];
    end
end 

Z = zeros(counter,320);
Zi = zeros(counter,320);
echo off;
for m=1:counter
    [Z(m,:), Zi(m,:)]=mat_fft(z(m,:), r, i);
end
echo on;

writematrix(Z, fn_csv_fft_z);
writematrix(Zi, fn_csv_fft_zi);

figure;
plot(Z);
figure;
plot(Zi);

% % %

function [R, I] = mat_fft(x, r, i)
    temp1 = 0;
    temp2 = 0;
    % load('lut.mat', 'coef')
    R = zeros(1, 320);
    I = zeros(1, 320);
    for k=0:319
        for n=0:319
            idx = mod(k*n, 320) + 1;
            temp1 = temp1 + (x(n+1)*r(idx));
            temp2 = temp2 + (x(n+1)*-i(idx));
        end
        % signed, 16 word length, 7 fraction bits
        % default is signed, 16, 13
        R(k+1) = fi(temp1, 1, 16, 7);
        I(k+1) = fi(temp2, 1, 16, 7);
        temp1 = 0;
        temp2 = 0;
    end
end
