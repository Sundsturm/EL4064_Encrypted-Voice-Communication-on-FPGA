function [detect_enable_941, detect_enable_1477, precision_enable] = flagging(batch_sums)
    detect_enable_941 = 0;
    detect_enable_1477 = 0;
    precision_enable = 0;
    count_941 = 0;
    count_1477 = 0;
    
    for slide_i = 25:size(batch_sums, 1)
        if batch_sums(slide_i, 2) >= 5* batch_sums(slide_i - 24, 2)
            count_941 = count_941 + 1;
            if count_941 == 5
                detect_enable_941 = 1;
            end
        else
            count_941 = 0;
        end

        if batch_sums(slide_i, 3) >= 5* batch_sums(slide_i - 24, 3)
            count_1477 = count_1477 + 1;
            if count_1477 == 5
                detect_enable_1477 = 1;
            end
        else
            count_1477 = 0;
        end

        if detect_enable_941 && detect_enable_1477
            precision_enable = 1;
            fprintf('Sinyal Flag dimulai pada batch ke-%d\n', slide_i - 4);
            fprintf('Nilai korelasi pada frekuensi 941 Hz sebesar %d\n', batch_sums(slide_i-4, 2));
            fprintf('Nilai korelasi pada frekuensi 1477 Hz sebesar %d\n', batch_sums(slide_i-4, 3));
            break;
        end
    end
end
