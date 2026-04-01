clc;
clear;
close all;

% 读取位图图像
% A 为图像矩阵，M 为颜色映射表（如果是索引图像时才有意义）
[A, M] = imread('lena.jpg', 'jpg');

% 新建一个图窗并显示原始图像
figure;
imshow(A);
title('原始图像');

% 获取图像尺寸
% 对彩色图像，size(A) 通常返回 [行, 列, 通道数]
[x, y] = size(A);

% 查看图像的数据类型，比如 uint8
class(A);

% 将彩色图像转换为灰度图像
gray = rgb2gray(A);

% 查看灰度图尺寸
size(gray);

% 显示灰度图像
figure;
imshow(gray);
title('灰度图像');

% 将灰度图像转换为二值图像
% im2bw 会根据默认阈值将图像变成黑白图
bw = im2bw(gray);

% 显示二值图像
figure;
imshow(bw);
title('二值图像');