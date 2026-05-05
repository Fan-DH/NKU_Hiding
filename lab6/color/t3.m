clc; clear; close all;

% 创建输出文件夹
out_dir = 'output_t3';
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

color_path = 'color.png';
secret_path = 'secret.png';

% 1. 读取彩色载体图像与秘密图像
cover = imread(color_path);
secret = imread(secret_path);
[Hs, Ws, Cs] = size(secret);

% 2. 合理地隐藏：彩色载体图有三个通道，相当于总容量是灰度图的 3 倍。
% 载体图的单一位平面(3个通道)容量为 Hc * Wc * 3 个比特。
[Hc, Wc, Cc] = size(cover);
capacity_bits = Hc * Wc * Cc; 
bits_per_pixel = Cs * 8; 
max_pixels = floor(capacity_bits / bits_per_pixel);

% 计算缩放比例，并进行缩放
ratio = sqrt(max_pixels / (Hs * Ws));
Hs_r = floor(Hs * ratio);
Ws_r = floor(Ws * ratio);
secret_r = imresize(secret, [Hs_r, Ws_r]);

% 保存缩放信息，方便提取时恢复尺寸
save(fullfile(out_dir, 'color_secret_info.mat'), 'Hs', 'Ws', 'Hs_r', 'Ws_r', 'Cs');

% 3. 将缩放后的秘密图像转换为比特流
secret_vec = secret_r(:);
bits = zeros(length(secret_vec), 8, 'uint8');
for b = 1:8
    bits(:, 9-b) = bitget(secret_vec, b);
end
secret_bits = reshape(bits', [], 1);

% 将比特流填充到与彩色载体图一样大小的矩阵中 (Hc x Wc x 3)
bit_plane_secret = zeros(Hc * Wc * Cc, 1, 'uint8');
bit_plane_secret(1:length(secret_bits)) = secret_bits;
bit_plane_secret = reshape(bit_plane_secret, Hc, Wc, Cc);

% 4. 分别隐藏在第1~8位平面并输出 PSNR
planes_to_hide = 1:8;

for p = planes_to_hide
    % 将秘密信息替换到指定的位平面，逐通道处理
    stego = cover;
    for c = 1:3
        stego(:, :, c) = bitset(cover(:, :, c), p, bit_plane_secret(:, :, c));
    end
    
    % 保存此时的载体图像
    stego_name = fullfile(out_dir, sprintf('color_stego_plane%d.png', p));
    imwrite(stego, stego_name);
    
    % 计算与原彩色图的 PSNR
    mse = mean((double(stego(:)) - double(cover(:))).^2);
    if mse == 0
        psnr_val = Inf;
    else
        psnr_val = 10 * log10(255^2 / mse);
    end
    fprintf('秘密图像只隐藏在各通道的第 %d 位平面，保存为 %s，与原图的 PSNR = %.4f dB\n', p, stego_name, psnr_val);
end