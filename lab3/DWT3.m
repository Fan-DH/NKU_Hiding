clc;
clear;
close all;

b = imread('lena.jpg');
b = rgb2gray(b);
b = im2double(b);

% 一级
[ca1, ch1, cv1, cd1] = dwt2(b, 'db4');

% 二级
[ca2, ch2, cv2, cd2] = dwt2(ca1, 'db4');

% 三级
[ca3, ch3, cv3, cd3] = dwt2(ca2, 'db4');

% 编码显示
A1 = wcodemat(ca1,255); H1 = wcodemat(ch1,255); V1 = wcodemat(cv1,255); D1 = wcodemat(cd1,255);
A2 = wcodemat(ca2,255); H2 = wcodemat(ch2,255); V2 = wcodemat(cv2,255); D2 = wcodemat(cd2,255);
A3 = wcodemat(ca3,255); H3 = wcodemat(ch3,255); V3 = wcodemat(cv3,255); D3 = wcodemat(cd3,255);

T3 = [A3,H3;V3,D3];
T3 = imresize(T3, size(ca2));

T2 = [T3,H2;V2,D2];
T2 = imresize(T2, size(ca1));

figure;
image([T2,H1;V1,D1]);
title('三级小波分解嵌套显示');
