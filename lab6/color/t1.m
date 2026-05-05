clc; clear; close all;

% 创建输出文件夹
out_dir = 'output_t1';
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

% 1. 读取彩色图像
color_path = 'color.png';
img = imread(color_path);

% 2. 提取 8 个位平面并组合保存
for i = 1:8
    % 初始化当前位平面的彩色图
    bit_plane_color = zeros(size(img), 'logical');
    
    % 分别对 R, G, B 通道提取第 i 个位平面
    for c = 1:3
        bit_plane_color(:, :, c) = logical(bitget(img(:, :, c), i));
    end
    
    % 保存组合后的彩色位平面到本地文件夹
    out_name = fullfile(out_dir, sprintf('color_bitplane_%d.png', i));
    % logical类型乘255保存为可见的图像
    imwrite(uint8(bit_plane_color) * 255, out_name);
end