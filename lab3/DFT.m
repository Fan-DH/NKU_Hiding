clc;
clear;
close all;

% 读入图像
img = imread('lena.jpg');
% 转灰度
img = rgb2gray(img);
% 转为 double
img = im2double(img);

% 二维傅里叶变换
F = fft2(img);
% 频谱中心化
F_shift = fftshift(F);
% 幅度谱
mag = abs(F_shift);
% 对数增强
mag_log = log(1 + mag);

% 显示
figure;
imshow(img, []);
title('原始图像');
figure;
imshow(mag_log, []);
title('中心化+对数增强的DFT幅度谱');
figure;
mesh(mag);
title('幅度谱的能量分布');