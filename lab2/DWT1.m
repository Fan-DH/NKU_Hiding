clc;
clear;
close all;

%% 读取音频，x: 音频信号, fs: 采样率(Hz)
[x, fs] = audioread('birds.wav');
x = x(:,1);                 % 单声道
N = length(x);              % 获取信号长度
t = (0:N-1) / fs;           % 构造时间轴

subplot(4,1,1);
plot(t, x);
title('原始信号');
xlabel('时间 (s)');
ylabel('幅值');

%% 小波分解（DWT）
[ca1,cd1]=dwt(x,'db4');

subplot(4,1,2);
plot(cd1);
title('高频分量（cd1）');
xlabel('样本点');
ylabel('幅值');

subplot(4,1,3);
plot(ca1);
title('低频分量（ca1）');
xlabel('样本点');
ylabel('幅值');


%% 小波重构（IDWT）
xi = idwt(ca1, cd1, 'db4', N);

subplot(4,1,4);
plot(t, xi);
title('重构信号');
xlabel('时间 (s)');
ylabel('幅值');