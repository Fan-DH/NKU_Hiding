clc;
clear;
close all;

%% 读取音频
[x, fs] = audioread('alarm.wav');
x = x(:,1);
N = length(x);
t = (0:N-1) / fs;

subplot(6,1,1);
plot(t, x);
title('原始信号');
xlabel('时间 (s)');
ylabel('幅值');

%% wavedec 三级分解
[C, L] = wavedec(x, 3, 'db4');

% 提取系数
ca3 = appcoef(C, L, 'db4', 3);
cd1 = detcoef(C, L, 1);
cd2 = detcoef(C, L, 2);
cd3 = detcoef(C, L, 3);

subplot(6,1,2);
plot(cd1);
title('高频分量（cd1）');
xlabel('样本点');
ylabel('幅值');

subplot(6,1,3);
plot(cd2);
title('高频分量（cd2）');
xlabel('样本点');
ylabel('幅值');

subplot(6,1,4);
plot(cd3);
title('高频分量（cd3）');
xlabel('样本点');
ylabel('幅值');

subplot(6,1,5);
plot(ca3);
title('低频分量（ca3）');
xlabel('样本点');
ylabel('幅值');

%% 重构
xi = waverec(C, L, 'db4');
subplot(6,1,6);
plot(t, xi);
title('重构信号');
xlabel('时间 (s)');
ylabel('幅值');