clc; clear; close all;

% 创建输出文件夹
out_dir = 'output_test1';
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

% 2. 提取 8 个位平面并保存
for i = 1:8
    % 提取第 i 个位平面
    bit_plane = bitget(img, i);
    
    % 保存到本地文件夹 (转为 logical 保存黑白二值图)
    out_name = fullfile(out_dir, sprintf('bitplane_%d.png', i));
    imwrite(logical(bit_plane), out_name);
end
