
clc;
close all;

fn_dec = 'v4_printout_x6_decimal_i.txt';
fn_bin = 'v4_printout_x6_binary_i.txt';
the_title = 'x6 imaginary part';

% Read decimal numbers
fileID1 = fopen(fn_dec, 'r');
decimal_numbers = fscanf(fileID1, '%f'); 
fclose(fileID1);

% Read binary numbers
fileID2 = fopen(fn_bin, 'r');
binary_strings = textscan(fileID2, '%s', 'Delimiter', '\n');
binary_strings = binary_strings{1}; 
fclose(fileID2);

% Define fixed-point parameters
word_length = 16; 
fraction_length = 10;
q = quantizer([word_length fraction_length]);

% Convert binary strings to fixed-point numbers
fixed_point_numbers = zeros(size(binary_strings));

for i = 1:length(binary_strings)
    binary_number = binary_strings{i}(3:end); % Remove '0b' prefix

    % Create fixed-point object
    fixed_point_numbers(i) = fi(bin2num(q, binary_number), 1, word_length, fraction_length); 
end

% Convert decimal numbers to fixed-point numbers
fixed_point_decimal_numbers = fi(decimal_numbers, 1, word_length, fraction_length);

% Plot
figure;
subplot(211);
plot(fixed_point_decimal_numbers, 'b-', 'DisplayName', 'Decimal Numbers');
xlabel('Index');
ylabel('Value');
legend('Location', 'best');
title(the_title);

subplot(212); 
plot(fixed_point_numbers, 'r-', 'DisplayName', 'Binary Numbers');
xlabel('Index');
ylabel('Value');
legend('Location', 'best');
title(the_title);