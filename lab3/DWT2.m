% 图像的二级小波变换

clc;
clear;
close all;

% 读取图像
b = imread('lena.jpg');

% 将图像二值化
a = im2bw(b);

% 设置显示尺寸参数
nbcol = 512;
nbc = 256;

% 第一级二维离散小波分解
[ca1, ch1, cv1, cd1] = dwt2(a, 'db4');

% 对第一级分解得到的低频近似分量 ca1 再做一次小波分解
% 即得到第二级小波分解
[ca2, ch2, cv2, cd2] = dwt2(ca1, 'db4');

% 对一级分解结果进行编码显示
cod_ca1 = wcodemat(ca1, nbc);
cod_ch1 = wcodemat(ch1, nbc);
cod_cv1 = wcodemat(cv1, nbc);
cod_cd1 = wcodemat(cd1, nbc);

% 对二级分解结果进行编码显示
cod_ca2 = wcodemat(ca2, nbcol);
cod_ch2 = wcodemat(ch2, nbcol);
cod_cv2 = wcodemat(cv2, nbcol);
cod_cd2 = wcodemat(cd2, nbcol);

% 将二级小波的四个子带拼成一个块
tt = [cod_ca2, cod_ch2; cod_cv2, cod_cd2];

% 将这个二级分解块缩放到和一级近似分量 ca1 对应的显示尺寸
tt = imresize(tt, size(ca1));

% 最终显示方式：
% 左上角为二级分解块
% 右上、左下、右下仍然是一级分解的细节部分
image([tt, cod_ch1; cod_cv1, cod_cd1]);
title('Lena图像的二级小波分解结果');
