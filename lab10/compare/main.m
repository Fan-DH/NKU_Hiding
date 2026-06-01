% DCT域信息隐藏实验：系数比较方法
clear; clc; close all;

%% 1. 读取载体图像
cover_path = '..\gray.png';
cover = imread(cover_path);
cover = double(cover);
[h, w] = size(cover);

% 计算最大容量
block_size = 8;
h_blocks = floor(h / block_size);
w_blocks = floor(w / block_size);
max_capacity = h_blocks * w_blocks;

%% 2. 读取并处理两类秘密信息
% (1) 秘密图像 (128*128 二值图)
secret_img_path = '..\secret.png';
secret_img = imread(secret_img_path);
if size(secret_img, 3) == 3
    secret_img = rgb2gray(secret_img);
end
secret_img_bin = imbinarize(secret_img); % 转为逻辑二值图
img_bits = secret_img_bin(:)';           % 按列展开为一维向量
img_len = length(img_bits);

% (2) 文本信息
text_str = 'FDH2312326';
text_uint8 = uint8(text_str);
% 转换为二进制矩阵，并转置以确保按位展开的正确性
text_bits_mat = dec2bin(text_uint8, 8) - '0';
text_bits_mat = text_bits_mat'; 
text_bits = text_bits_mat(:)';
text_len = length(text_bits);

% 差值阈值 D，控制鲁棒性
D = 25; 

%% 3. 实验一：隐藏和测试秘密图像
fprintf('====== 实验一：隐藏和测试秘密图像 ======\n');
stego_img = embed_compare(cover, img_bits, D);

% 保存含密图像
stego_img = max(min(round(stego_img), 255), 0);
stego_img_uint8 = uint8(stego_img);
cover_uint8 = uint8(cover);
imwrite(stego_img_uint8, 'stego_compare_img.png');

% 计算 PSNR
mse_img = mean((double(cover_uint8(:)) - double(stego_img_uint8(:))).^2);
if mse_img == 0
    psnr_img = Inf;
else
    psnr_img = 10 * log10(255^2 / mse_img);
end
fprintf('秘密图像嵌入完成，PSNR: %.4f dB\n', psnr_img);

% 提取秘密图像
stego_img_read = double(imread('stego_compare_img.png'));
ext_img_bits = extract_compare(stego_img_read, img_len);

% 计算 BER 并保存提取的图像
ber_img = sum(ext_img_bits ~= img_bits) / img_len;
fprintf('秘密图像提取完成，BER: %.4f\n\n', ber_img);
ext_img = logical(reshape(ext_img_bits, size(secret_img_bin)));
imwrite(ext_img, 'extracted_secret_compare_img.png');

% 加噪并再次提取
fprintf('--- 加噪测试（高斯噪声） ---\n');
noisy_stego_img_uint8 = imnoise(stego_img_uint8, 'gaussian', 0, 0.005);
imwrite(noisy_stego_img_uint8, 'noisy_stego_compare_img.png');
noisy_stego_img_read = double(imread('noisy_stego_compare_img.png'));
noisy_ext_img_bits = extract_compare(noisy_stego_img_read, img_len);

noisy_ber_img = sum(noisy_ext_img_bits ~= img_bits) / img_len;
fprintf('加噪后秘密图像提取完成，BER: %.4f\n\n', noisy_ber_img);
noisy_ext_img = logical(reshape(noisy_ext_img_bits, size(secret_img_bin)));
imwrite(noisy_ext_img, 'noisy_extracted_secret_compare_img.png');


%% 4. 实验二：隐藏和测试文本信息
fprintf('====== 实验二：隐藏和测试文本信息 ======\n');
stego_text = embed_compare(cover, text_bits, D);

% 保存含密图像
stego_text = max(min(round(stego_text), 255), 0);
stego_text_uint8 = uint8(stego_text);
imwrite(stego_text_uint8, 'stego_compare_text.png');

% 计算 PSNR
mse_text = mean((double(cover_uint8(:)) - double(stego_text_uint8(:))).^2);
if mse_text == 0
    psnr_text = Inf;
else
    psnr_text = 10 * log10(255^2 / mse_text);
end
fprintf('文本信息嵌入完成，PSNR: %.4f dB\n', psnr_text);

% 提取文本信息
stego_text_read = double(imread('stego_compare_text.png'));
ext_text_bits = extract_compare(stego_text_read, text_len);

% 计算 BER 并恢复文本
ber_text = sum(ext_text_bits ~= text_bits) / text_len;
fprintf('文本信息提取完成，BER: %.4f\n', ber_text);

ext_text_mat = reshape(ext_text_bits, 8, [])';
ext_text_chars = char(ext_text_mat + '0');
ext_text_uint8 = uint8(bin2dec(ext_text_chars));
ext_text_str = char(ext_text_uint8');
fprintf('提取出的文字信息: %s\n\n', ext_text_str);

% 加噪并再次提取
fprintf('--- 加噪测试（高斯噪声） ---\n');
noisy_stego_text_uint8 = imnoise(stego_text_uint8, 'gaussian', 0, 0.005);
imwrite(noisy_stego_text_uint8, 'noisy_stego_compare_text.png');
noisy_stego_text_read = double(imread('noisy_stego_compare_text.png'));
noisy_ext_text_bits = extract_compare(noisy_stego_text_read, text_len);

noisy_ber_text = sum(noisy_ext_text_bits ~= text_bits) / text_len;
fprintf('加噪后文本信息提取完成，BER: %.4f\n', noisy_ber_text);

noisy_ext_text_mat = reshape(noisy_ext_text_bits, 8, [])';
noisy_ext_text_chars = char(noisy_ext_text_mat + '0');
noisy_ext_text_uint8 = uint8(bin2dec(noisy_ext_text_chars));
noisy_ext_text_str = char(noisy_ext_text_uint8');
fprintf('加噪后提取出的文字信息: %s\n\n', noisy_ext_text_str);
