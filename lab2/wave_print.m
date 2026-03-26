clc;
clear;
close all;

figure;

%% alarm
[x, fs] = audioread('alarm.wav');
x = x(:,1);
N = length(x);
t = (0:N-1) / fs;

subplot(3,1,1);
plot(t, x);
xlabel('时间 / s');
ylabel('幅值');
title('警报·原始波形');

%% wind
[x, fs] = audioread('wind.wav');
x = x(:,1);
N = length(x);
t = (0:N-1) / fs;

subplot(3,1,2);
plot(t, x);
xlabel('时间 / s');
ylabel('幅值');
title('风·原始波形');

%% birds
[x, fs] = audioread('birds.wav');
x = x(:,1);
N = length(x);
t = (0:N-1) / fs;

subplot(3,1,3);
plot(t, x);
xlabel('时间 / s');
ylabel('幅值');
title('鸟鸣·原始波形');