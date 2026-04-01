% lena图像的一级小波变换

clc;
clear;
close all;

% 读取图像
b = imread('lena.jpg');

% 将图像转换为二值图像
a = im2bw(b);

% 获取图像行数，作为后续小波系数编码显示的尺寸参数
nbcol = size(a, 1);

% 进行二维一级离散小波变换，采用 Daubechies 4(db4) 小波
% ca1: 低频近似分量（Approximation）
% ch1: 水平方向细节分量（Horizontal detail）
% cv1: 垂直方向细节分量（Vertical detail）
% cd1: 对角线方向细节分量（Diagonal detail）
[ca1, ch1, cv1, cd1] = dwt2(a, 'db4');

% 将各个小波子带编码为可显示图像
cod_ca1 = wcodemat(ca1, nbcol);
cod_ch1 = wcodemat(ch1, nbcol);
cod_cv1 = wcodemat(cv1, nbcol);
cod_cd1 = wcodemat(cd1, nbcol);

% 将四个子带拼接显示
% 左上：近似分量
% 右上：水平细节
% 左下：垂直细节
% 右下：对角细节
image([cod_ca1, cod_ch1; cod_cv1, cod_cd1]);
title('Lena图像的一级小波分解结果');
