clc; clear; close all;

% 创建输出文件夹
out_dir = 'output_test3';
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

gray_path = 'gray.png';
secret_path = 'secret.png';

% 1. 读取载体图像与秘密图像
gray = imread(gray_path);
if size(gray, 3) == 3
    gray = rgb2gray(gray);
end

secret = imread(secret_path);
[Hs, Ws, Cs] = size(secret);

% 2. 合理地隐藏：为了能将彩色图像隐藏在单一位平面中，必须控制数据量。
[Hc, Wc] = size(gray);
capacity_bits = Hc * Wc; 
bits_per_pixel = Cs * 8; 
max_pixels = floor(capacity_bits / bits_per_pixel);

% 计算缩放比例，并进行缩放
ratio = sqrt(max_pixels / (Hs * Ws));
Hs_r = floor(Hs * ratio);
Ws_r = floor(Ws * ratio);
secret_r = imresize(secret, [Hs_r, Ws_r]);

% 保存缩放信息，方便提取时恢复尺寸 
save(fullfile(out_dir, 'secret_info.mat'), 'Hs', 'Ws', 'Hs_r', 'Ws_r', 'Cs');

% 3. 将缩放后的秘密图像转换为比特流
secret_vec = secret_r(:);
bits = zeros(length(secret_vec), 8, 'uint8');
for b = 1:8
    bits(:, 9-b) = bitget(secret_vec, b);
end
secret_bits = reshape(bits', [], 1);

% 将比特流填充到与载体图一样大小的矩阵中
bit_plane_secret = zeros(Hc * Wc, 1, 'uint8');
bit_plane_secret(1:length(secret_bits)) = secret_bits;
bit_plane_secret = reshape(bit_plane_secret, Hc, Wc);

% 4. 分别隐藏在第1~8位平面并输出 PSNR
planes_to_hide = 1:8;

for p = planes_to_hide
    % 将秘密信息替换到指定的位平面
    stego = bitset(gray, p, bit_plane_secret);
    
    % 保存此时的载体图像
    stego_name = fullfile(out_dir, sprintf('stego_plane%d.png', p));
    imwrite(stego, stego_name);
    
    % 计算与原图的 PSNR
    mse = mean((double(stego(:)) - double(gray(:))).^2);
    if mse == 0
        psnr_val = Inf;
    else
        psnr_val = 10 * log10(255^2 / mse);
    end
    fprintf('秘密图像只隐藏在第 %d 位平面，保存为 %s，与原图的 PSNR = %.4f dB\n', p, stego_name, psnr_val);
end