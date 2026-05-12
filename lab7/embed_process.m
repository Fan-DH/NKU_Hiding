clear; clc; close all;

%% 1. 读取载体图像
carrier_img = imread('Object.png');
if size(carrier_img, 3) == 3
    carrier_img = rgb2gray(carrier_img); % 确保是灰度图
end
[M, N] = size(carrier_img);
max_capacity = M * N;

%% 2. 分别处理三种秘密信息

% 2.1 整数数据
secret_int = 2312326;
int_bin = dec2bin(secret_int, 32) - '0'; % 32位二进制

% 2.2 秘密图像
secret_img = imread('secret.png');
secret_img_bin = secret_img > 0;
[m_sec, n_sec] = size(secret_img_bin);
img_bin = secret_img_bin(:)'; 

% 2.3 音频文件
fid = fopen('secret.wav', 'rb');
wav_data = fread(fid, 'uint8');
fclose(fid);
wav_len = length(wav_data);
wav_bin = dec2bin(wav_data, 8)';
wav_bin = wav_bin(:)' - '0'; 

% 准备单独处理的数据集
secrets = {int_bin, img_bin, wav_bin};
secret_names = {'int', 'img', 'wav'};
secret_desc = {'整数', '图像', '音频'};

% 保存提取时需要的元数据
output_base = 'Output';
if ~exist(output_base, 'dir'), mkdir(output_base); end
metadata_path = fullfile(output_base, 'metadata.mat');
save(metadata_path, 'm_sec', 'n_sec', 'wav_len');

%% 3. 分别嵌入信息并施加噪声
bit_planes = [1, 2, 3]; % 1=最低位(LSB), 2=次低位, 3=次次低位
noise_types = {'none', 'low', 'high'};
noise_densities = [0, 0.01, 0.05];

fprintf('\n--- 开始分别嵌入与 PSNR 计算 ---\n');
for k = 1:3
    current_secret = secrets{k};

    curr_len = length(current_secret);
    fprintf('\n[%s] 秘密信息长度: %d bits\n', secret_desc{k}, curr_len);
    if curr_len > max_capacity
        error('%s信息过大无法容纳', secret_desc{k});
    end
    
    
    % 准备文件夹
    folder_name = fullfile(output_base, ['stego_', secret_names{k}]);
    if ~exist(folder_name, 'dir')
        mkdir(folder_name);
    end

    % 遍历每个位面并嵌入
    for i = 1:length(bit_planes)
        bp = bit_planes(i);
        % 写入秘密信息
        stego = carrier_img;
        idx = 1:curr_len;
        stego(idx) = bitset(stego(idx), bp, cast(current_secret, class(stego)));
        % 计算 PSNR
        mse = sum(sum((double(carrier_img) - double(stego)).^2)) / (M * N);
        if mse == 0
            psnr_val = Inf;
        else
            psnr_val = 10 * log10(255^2 / mse);
        end
        fprintf('  -> 嵌入到第 %d 位面的 PSNR: %.4f dB\n', bp, psnr_val);
        % 添加噪声并保存
        for j = 1:length(noise_types)
            if noise_densities(j) > 0
                stego_noisy = imnoise(stego, 'salt & pepper', noise_densities(j));
            else
                stego_noisy = stego;
            end
            filename = fullfile(folder_name, sprintf('stego_%s_bp%d_noise_%s.png', ...
                secret_names{k}, bp, noise_types{j}));
            imwrite(stego_noisy, filename);
        end
    end
end