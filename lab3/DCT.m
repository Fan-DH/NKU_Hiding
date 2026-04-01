clc;
clear;
close all;

% 读入图像
b = imread('lena.jpg');          % 图像像素矩阵保存在 b 中

% 转换为灰度图像
b = rgb2gray(b);

% 显示原始灰度图像
figure(1);
imshow(b);
title('(a) 原图像');

% 将灰度图像转换为二值图像
I = im2bw(b);

% 对图像进行二维离散余弦变换
figure(2);
c = dct2(I);                     % 计算 2D DCT 变换系数
imshow(c);
title('(b) DCT变换系数');

% 绘制 DCT 系数的三维网格图
figure(3);
mesh(c);                         % 观察 DCT 系数的空间分布
title('(c) DCT变换系数(立体视图)');