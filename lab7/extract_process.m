clear; clc; close all;

%% 1. 加载元数据及读取原始秘密信息
output_base = 'Output';
load(fullfile(output_base, 'metadata.mat')); % 加载 m_sec, n_sec, wav_len

% 重新读取原始秘密信息用于计算 BER
secret_int = 2312326;
int_bin_orig = dec2bin(secret_int, 32) - '0';

secret_img = imread('secret.png');
secret_img_bin = secret_img > 0;
img_size = size(secret_img_bin);
img_bin_orig = secret_img_bin(:)';

fid = fopen('secret.wav', 'rb');
wav_data_orig = fread(fid, 'uint8');
fclose(fid);
wav_bin_orig = dec2bin(wav_data_orig, 8)';
wav_bin_orig = wav_bin_orig(:)' - '0';

secrets_orig = {int_bin_orig, img_bin_orig, wav_bin_orig};
secret_names = {'int', 'img', 'wav'};
secret_desc = {'整数', '图像', '音频'};

%% 2. 遍历提取并计算 BER
bit_planes = [1, 2, 3];
noise_types = {'none', 'low', 'high'};
noise_names = {'无噪', '低噪 (S&P 0.01)', '重噪 (S&P 0.05)'};
% 记录 BER (数据类型, 嵌入位面, 噪声类型)
ber_results = zeros(3, length(bit_planes), length(noise_types));
fprintf('================= 提取结果与误码率分析 =================\n');
for k = 1:3
    orig_bits = secrets_orig{k};
    curr_len = length(orig_bits);
    fprintf('\n>>> 正在处理秘密信息类型: %s (长度: %d bits) <<<\n', secret_desc{k}, curr_len);
    
    % 准备文件夹
    stego_folder = fullfile(output_base, ['stego_', secret_names{k}]);
    save_folder = fullfile(output_base, ['extracted_', secret_names{k}]);
    if ~exist(save_folder, 'dir')
        mkdir(save_folder);
    end

    for i = 1:length(bit_planes)
        for j = 1:length(noise_types)
            bp = bit_planes(i);
            filename = fullfile(stego_folder, sprintf('stego_%s_bp%d_noise_%s.png', ...
                secret_names{k}, bp, noise_types{j}));
            if ~exist(filename, 'file')
                warning('文件不存在：%s', filename);
                continue;
            end
            stego_noisy = imread(filename);
            % 提取对应位面
            extracted_plane = bitget(stego_noisy, bp);
            extracted_bits_all = extracted_plane(:)';
            % 截取实际信息长度
            extracted_bits = extracted_bits_all(1:curr_len);
            % 计算 BER
            errors = sum(extracted_bits ~= orig_bits);
            ber = errors / curr_len;
            ber_results(k, i, j) = ber;
            fprintf('嵌入位: 第 %d 位 | 噪声: %-15s | BER: %.4f (错误位数: %d / %d)\n', ...
                bp, noise_names{j}, ber, errors, curr_len);
            
            % 保存提取出的秘密信息
            save_name = sprintf('extracted_%s_bp%d_noise_%s', ...
                secret_names{k}, bp, noise_types{j});
            if k == 1 % 整数
                extracted_val = bin2dec(char(extracted_bits + '0'));
                fid_save = fopen(fullfile(save_folder, [save_name, '.txt']), 'w');
                fprintf(fid_save, '%d', extracted_val);
                fclose(fid_save);
            elseif k == 2 % 图像
                extracted_img = reshape(extracted_bits, img_size);
                imwrite(logical(extracted_img), fullfile(save_folder, [save_name, '.png']));
            elseif k == 3 % 音频
                reshaped_bits = reshape(extracted_bits, 8, [])';
                extracted_bytes = uint8(bin2dec(char(reshaped_bits + '0')));
                fid_save = fopen(fullfile(save_folder, [save_name, '.wav']), 'wb');
                fwrite(fid_save, extracted_bytes, 'uint8');
                fclose(fid_save);
            end
        end
    end
end