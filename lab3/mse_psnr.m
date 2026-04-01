clc;
clear;
close all;

img = imread('lena.bmp');      % 原始图像
[h, w] = size(img);            % 获取图像尺寸
img = double(img);             % 转为 double 类型
B = 8;                         
MAX = 2^B - 1;
% ================= 无噪声 =================
imgn = img;    
imgn = double(imgn);
MSE = sum(sum((img - imgn).^2)) / (h * w);
PSNR = 20 * log10(MAX / sqrt(MSE));
fprintf('无噪声 PSNR = %.4f dB\n', PSNR);

% ================= 高斯噪声 =================
imgn = imread('gauss.png');    
imgn = double(imgn);
MSE = sum(sum((img - imgn).^2)) / (h * w);
PSNR = 20 * log10(MAX / sqrt(MSE));
fprintf('高斯噪声 PSNR = %.4f dB\n', PSNR);

% ================= 椒盐噪声 =================
imgn = imread('sp.png');       
imgn = double(imgn);
MSE = sum(sum((img - imgn).^2)) / (h * w);
PSNR = 20 * log10(MAX / sqrt(MSE));
fprintf('椒盐噪声 PSNR = %.4f dB\n', PSNR);

% ================= 泊松噪声 =================
imgn = imread('poisson.png');  
imgn = double(imgn);
MSE = sum(sum((img - imgn).^2)) / (h * w);
PSNR = 20 * log10(MAX / sqrt(MSE));
fprintf('泊松噪声 PSNR = %.4f dB\n', PSNR);

% ================= 斑点噪声 =================
imgn = imread('speckle.png');  
imgn = double(imgn);
MSE = sum(sum((img - imgn).^2)) / (h * w);
PSNR = 20 * log10(MAX / sqrt(MSE));
fprintf('斑点噪声 PSNR = %.4f dB\n', PSNR);