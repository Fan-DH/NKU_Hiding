clear; clc; close all;

%% 1. 设置路径和参数
output_base = 'Output';
original_audio = 'secret.wav';
extract_folder = fullfile(output_base, 'extracted_wav');
bit_planes = [1, 2, 3];
noise_types = {'none', 'low', 'high'};
noise_names = {'无噪', '低噪 (0.01)', '重噪 (0.05)'};

%% 2. 准备绘图窗口
% 创建一个全屏或较大的窗口来容纳多张图
figure('Name', '音频波形全维度对比展示', 'Color', 'w', 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);
% 总行数：3个位面 + 1行原始音频
% 总列数：3种噪声
num_rows = length(bit_planes) + 1;
num_cols = length(noise_types);

%% 3. 绘制原始音频 (第一行，跨列展示)
% 读取原始音频
fid = fopen(original_audio, 'rb');
y_orig = fread(fid, 'uint8');
fclose(fid);
t_orig = 1:length(y_orig);
% 在第一行创建一个大的 subplot 展示原始音频
subplot(num_rows, num_cols, 1:num_cols);
plot(t_orig, y_orig, 'k', 'LineWidth', 1);
title('原始秘密音频 (参考)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('数值 (0-255)');
grid on;
ylim([-10, 265]);
xlim([1, length(y_orig)]);

%% 4. 遍历位面和噪声类型绘图
for i = 1:length(bit_planes)
    bp = bit_planes(i);
    for j = 1:length(noise_types)
        nt = noise_types{j};
        % 计算 subplot 索引
        plot_idx = i * num_cols + j;
        subplot(num_rows, num_cols, plot_idx);
        filename = fullfile(extract_folder, sprintf('extracted_wav_bp%d_noise_%s.wav', bp, nt));
        if exist(filename, 'file')
            fid = fopen(filename, 'rb');
            y = fread(fid, 'uint8');
            fclose(fid);
            t = 1:length(y);
            plot(t, y, 'Color', [0, 0.4470, 0.7410]);
            % 只在每列顶部显示噪声类型，每行开头显示位面信息
            title_str = '';
            if i == 1, title_str = [noise_names{j}, ' | ']; end
            title_str = [title_str, sprintf('位面 %d', bp)];
            title(title_str, 'FontSize', 10);
            grid on;
            ylim([-10, 265]);
            xlim([1, length(y)]);
            % 减少标签冗余
            if j == 1, ylabel('幅度'); end
            if i == length(bit_planes), xlabel('样本点'); end
        else
            text(0.5, 0.5, '文件缺失', 'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', 'r');
            title(sprintf('BP%d - %s', bp, nt));
            axis off;
        end
    end
end

sgtitle('音频秘密信息：不同位面与噪声环境下的提取波形对比', 'FontSize', 16, 'FontWeight', 'bold');