clc;
clear;
close all;

img = imread('lena.jpg');
img = rgb2gray(img);
% 1. 高斯噪声
img_gauss = imnoise(img, 'gaussian', 0, 0.01);
% 2. 椒盐噪声
img_sp = imnoise(img, 'salt & pepper', 0.02);
% 3. 泊松噪声
img_poisson = imnoise(img, 'poisson');
% 4. 斑点噪声
img_speckle = imnoise(img, 'speckle', 0.04);

figure;
subplot(1,4,1); imshow(img_gauss); title('高斯噪声');
subplot(1,4,2); imshow(img_sp); title('椒盐噪声');
subplot(1,4,3); imshow(img_poisson); title('泊松噪声');
subplot(1,4,4); imshow(img_speckle); title('斑点噪声');

imwrite(img_gauss, 'gauss.png');
imwrite(img_sp, 'sp.png');
imwrite(img_poisson, 'poisson.png');
imwrite(img_speckle, 'speckle.png');