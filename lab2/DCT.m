clc;
clear;
close all;

%% 读取音频
[x, fs] = audioread('birds.wav');   % x: 音频信号, fs: 采样率
x = x(:,1);               % 单声道
N = length(x);            % 信号长度
t = (0:N-1) / fs;         % 时间轴

%% 原始语音波形
subplot(4,1,1);
plot(t, x);
xlabel('时间 / s');
ylabel('幅值');
title('原始语音波形');

%% DCT 变换
X_dct = dct(x);

subplot(4,1,2);
plot(abs(X_dct), 'k');
xlabel('索引');
ylabel('幅值');
title('DCT 系数幅值图');

%% 压缩，只保留前10%的DCT系数
keep = round(N * 0.1);      % 保留前10%
X_dct(keep+1:end) = 0;

subplot(4,1,3);
plot(abs(X_dct), 'k');
xlabel('索引');
ylabel('幅值');
title('DCT 压缩后系数图');

%% 逆DCT还原
x_idct = idct(X_dct);

subplot(4,1,4);
plot(t, x_idct);
xlabel('时间 / s');
ylabel('幅值');
title('逆DCT复原波形');
