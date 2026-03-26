clc;
clear;
close all;

%% 读取音频，x: 音频信号, fs: 采样率(Hz)
[x, fs] = audioread('alarm.wav');
x = x(:,1);                 % 单声道
N = length(x);              % 获取信号长度
t = (0:N-1) / fs;           % 构造时间轴
fx = fft(x);                % 快速傅里叶变换
f = (-N/2:N/2-1) * (fs/N);  % 构造频率轴

%% 时域上原始语音波形
subplot(2,1,1);
plot(t, x);              
xlabel('时间 / s');     
ylabel('幅值');        
title('原始语音波形');

%% 频域上FFT频谱
subplot(2,1,2);
plot(f, abs(fftshift(fx)));  
xlabel('频率 / Hz');         
ylabel('幅度');             
title('FFT频谱');
