clc; clear; close all;

% 创建输出文件夹
out_dir = 'output_t2';
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

% 1. 读取图像
color_path = 'color.png';
img = imread(color_path);

% 2. 循环处理 n = 1 到 8
for n = 1:8
    if n < 8
        mask_low = uint8((2^n) - 1);
        mask_high = uint8(255 - mask_low);
    else
        mask_low = uint8(255);
        mask_high = uint8(0);
    end
    
    % 初始化高低位图像矩阵
    low_img_color = zeros(size(img), 'uint8');
    high_img_color = zeros(size(img), 'uint8');
    
    % 分通道处理
    for c = 1:3
        low_img_color(:, :, c) = bitand(img(:, :, c), mask_low);
        high_img_color(:, :, c) = bitand(img(:, :, c), mask_high);
    end
    
    % 保存图像
    imwrite(low_img_color, fullfile(out_dir, sprintf('color_low_1_to_%d.png', n)));
    if n < 8
        imwrite(high_img_color, fullfile(out_dir, sprintf('color_high_%d_to_8.png', n+1)));
    else
        imwrite(high_img_color, fullfile(out_dir, 'color_removed_first_8_layers.png'));
    end
end