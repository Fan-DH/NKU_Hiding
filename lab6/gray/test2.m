clc; clear; close all;

% 创建输出文件夹
out_dir = 'output_test2';
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

% 1. 读取图像
gray_path = 'gray.png';
img = imread(gray_path);

% 确保图像是灰度图
if size(img, 3) == 3
    img = rgb2gray(img);
end

% 2. 循环处理 n = 1 到 8
for n = 1:8
    if n < 8
        % 构造 1~n 低位平面的掩码
        mask_low = uint8((2^n) - 1);
        mask_high = uint8(255 - mask_low);
    else
        % 当 n=8 时，1~8为全取，剩下部分为全不取
        mask_low = uint8(255);
        mask_high = uint8(0);
    end
    
    low_img = bitand(img, mask_low);
    high_img = bitand(img, mask_high);
    
    % 保存图像
    imwrite(low_img, fullfile(out_dir, sprintf('low_1_to_%d.png', n)));
    if n < 8
        imwrite(high_img, fullfile(out_dir, sprintf('high_%d_to_8.png', n+1)));
    else
        % n=8时，去掉前八层相当于空图像（全0）
        imwrite(high_img, fullfile(out_dir, 'removed_first_8_layers.png'));
    end
end
