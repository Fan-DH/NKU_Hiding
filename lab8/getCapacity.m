clear; clc; close all;

% 读取载体图像计算容量
cover = imread('target.png');
[h, w, c] = size(cover);
max_capacity_bits = floor((h * w) / 2); % 两个彩色像素隐藏一个比特
fprintf('载体图像 target.png 尺寸: %d x %d x %d\n', w, h, c);
fprintf('理论最大隐藏容量: %d bits (约 %.2f KB)\n\n', max_capacity_bits, max_capacity_bits/8/1024);

% 1. 检查二值图像
bin_img = imread('binary.png');
[h1, w1, ~] = size(bin_img);
bin_bits = h1 * w1; % 二值图每个像素1bit
fprintf('1. 二值图像 binary.png: 需要 %d bits (%.2f%%) - %s\n', ...
    bin_bits, (bin_bits/max_capacity_bits)*100, check_status(bin_bits, max_capacity_bits));

% 2. 检查灰度图像
gray_img = imread('gray.png');
[h2, w2, ~] = size(gray_img);
gray_bits = h2 * w2 * 8; % 灰度图每个像素8bit
fprintf('2. 灰度图像 gray.png:   需要 %d bits (%.2f%%) - %s\n', ...
    gray_bits, (gray_bits/max_capacity_bits)*100, check_status(gray_bits, max_capacity_bits));

% 3. 检查文本文件
text_info = dir('text.txt');
text_bits = text_info.bytes * 8;
fprintf('3. 文本文件 text.txt:   需要 %d bits (%.2f%%) - %s\n', ...
    text_bits, (text_bits/max_capacity_bits)*100, check_status(text_bits, max_capacity_bits));

% 4. 检查音频文件
audio_info = dir('Audio.wav');
audio_bits = audio_info.bytes * 8;
fprintf('4. 音频文件 Audio.wav:  需要 %d bits (%.2f%%) - %s\n', ...
    audio_bits, (audio_bits/max_capacity_bits)*100, check_status(audio_bits, max_capacity_bits));

function status = check_status(req, max_cap)
    if req <= max_cap
        status = '容量充足';
    else
        status = '容量不足';
    end
end