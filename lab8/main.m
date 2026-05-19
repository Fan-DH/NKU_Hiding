clear; clc; close all;

%% ================== 准备工作 ==================
% 1. 路径设置与输出文件夹创建
base_dir = '.';
out_dir = fullfile(base_dir, 'output');
% 2. 读取载体彩色图像
cover_path = fullfile(base_dir, 'target.png');
cover = imread(cover_path);
[H_cov, W_cov, C_cov] = size(cover);
fprintf('载体图像 target.png 尺寸: %d x %d x %d\n', W_cov, H_cov, C_cov);
% 3. 读取四类秘密信息并转为比特流
% (1) 二值图像
bin_img = imread(fullfile(base_dir, 'binary.png'));
if size(bin_img, 3) > 1, bin_img = rgb2gray(bin_img); end
% 使用动态阈值以适配不同格式的二值图（0/1 格式或 0/255 格式）
bin_img_logical = bin_img > (max(bin_img(:)) / 2);
bin_bits = double(bin_img_logical(:));
[H_bin, W_bin] = size(bin_img_logical);
% (2) 灰度图像
gray_img = imread(fullfile(base_dir, 'gray.png'));
if size(gray_img, 3) > 1, gray_img = rgb2gray(gray_img); end
gray_bits = bytes2bits(gray_img(:));
[H_gray, W_gray] = size(gray_img);
% (3) 文本文件
fid = fopen(fullfile(base_dir, 'text.txt'), 'r');
text_bytes = fread(fid, '*uint8');
fclose(fid);
text_bits = bytes2bits(text_bytes);
% (4) 音频文件
fid = fopen(fullfile(base_dir, 'Audio.wav'), 'r');
audio_bytes = fread(fid, '*uint8');
fclose(fid);
audio_bits = bytes2bits(audio_bytes);
% 设定不同的嵌入密钥以实现随机分散
keys = struct('bin', 1001, 'gray', 1002, 'text', 1003, 'audio', 1004);

%% ================== 第一部分：信息隐藏 ==================
% 1. 嵌入二值图像
stego_bin = embed_group_parity(cover, bin_bits, keys.bin);
imwrite(stego_bin, fullfile(out_dir, 'stego_bin.png'));
psnr_bin = psnr(stego_bin, cover);
fprintf('1. 二值图像隐藏完毕，载荷图 PSNR: %.4f dB\n', psnr_bin);
% 2. 嵌入灰度图像
stego_gray = embed_group_parity(cover, gray_bits, keys.gray);
imwrite(stego_gray, fullfile(out_dir, 'stego_gray.png'));
psnr_gray = psnr(stego_gray, cover);
fprintf('2. 灰度图像隐藏完毕，载荷图 PSNR: %.4f dB\n', psnr_gray);
% 3. 嵌入文本文件
stego_text = embed_group_parity(cover, text_bits, keys.text);
imwrite(stego_text, fullfile(out_dir, 'stego_text.png'));
psnr_text = psnr(stego_text, cover);
fprintf('3. 文本文件隐藏完毕，载荷图 PSNR: %.4f dB\n', psnr_text);
% 4. 嵌入音频文件
stego_audio = embed_group_parity(cover, audio_bits, keys.audio);
imwrite(stego_audio, fullfile(out_dir, 'stego_audio.png'));
psnr_audio = psnr(stego_audio, cover);
fprintf('4. 音频文件隐藏完毕，载荷图 PSNR: %.4f dB\n', psnr_audio);

%% ================== 第二部分：提取测试 ==================
% None表示无干扰，Noise_Minor表示微小噪声干扰
attacks = {'None', 'Noise_Minor'}; 
figure('Name', '提取音频波形对比', 'Position', [100, 100, 800, 600]);
for i_att = 1:length(attacks)
    att = attacks{i_att};
    fprintf('\n>>> 测试场景: %s <<<\n', att);
    % 1. 提取二值图像
    stego_curr = simulate_attack(stego_bin, att, out_dir, 'stego_bin');
    ext_bin_bits = extract_group_parity(stego_curr, keys.bin);
    ber_bin = calc_ber(ext_bin_bits, bin_bits);
    % 为了确保imwrite正确映射黑白像素，将其乘以255
    ext_bin_img = uint8(reshape(ext_bin_bits(1:length(bin_bits)), H_bin, W_bin) * 255);
    imwrite(ext_bin_img, fullfile(out_dir, sprintf('ext_bin_%s.png', att)));
    fprintf('1. 二值图像提取 BER: %.4f%%\n', ber_bin * 100);
    % 2. 提取灰度图像
    stego_curr = simulate_attack(stego_gray, att, out_dir, 'stego_gray');
    ext_gray_bits = extract_group_parity(stego_curr, keys.gray);
    ber_gray = calc_ber(ext_gray_bits, gray_bits);
    ext_gray_bytes = bits2bytes(ext_gray_bits(1:length(gray_bits)));
    ext_gray_img = reshape(ext_gray_bytes, H_gray, W_gray);
    imwrite(ext_gray_img, fullfile(out_dir, sprintf('ext_gray_%s.png', att)));
    fprintf('2. 灰度图像提取 BER: %.4f%%\n', ber_gray * 100);
    % 3. 提取文本文件
    stego_curr = simulate_attack(stego_text, att, out_dir, 'stego_text');
    ext_text_bits = extract_group_parity(stego_curr, keys.text);
    ber_text = calc_ber(ext_text_bits, text_bits);
    ext_text_bytes = bits2bytes(ext_text_bits(1:length(text_bits)));
    fid = fopen(fullfile(out_dir, sprintf('ext_text_%s.txt', att)), 'w');
    fwrite(fid, ext_text_bytes, 'uint8');
    fclose(fid);
    fprintf('3. 文本文件提取 BER: %.4f%%\n', ber_text * 100);
    % 4. 提取音频文件
    stego_curr = simulate_attack(stego_audio, att, out_dir, 'stego_audio');
    ext_audio_bits = extract_group_parity(stego_curr, keys.audio);
    ber_audio = calc_ber(ext_audio_bits, audio_bits);
    ext_audio_bytes = bits2bytes(ext_audio_bits(1:length(audio_bits)));
    audio_path = fullfile(out_dir, sprintf('ext_audio_%s.wav', att));
    fid = fopen(audio_path, 'w');
    fwrite(fid, ext_audio_bytes, 'uint8');
    fclose(fid);
    fprintf('4. 音频文件提取 BER: %.4f%%\n', ber_audio * 100);
    % 5. 绘制提取后的音频波形
    subplot(length(attacks), 1, i_att);
    try
        [y_audio, ~] = audioread(audio_path);
        plot(y_audio);
        title(sprintf('提取音频波形 - 攻击: %s (BER: %.4f%%)', att, ber_audio * 100));
        xlabel('Sample'); ylabel('Amplitude');
    catch
        title(sprintf('文件已损坏无法读取波形'));
    end
end


%% ================== 核心功能函数 ==================
% 将字节序列转换为列向量比特流
function b = bytes2bits(bytes)
    b_mat = bitget(repmat(bytes(:), 1, 8), repmat(8:-1:1, numel(bytes), 1));
    b_mat = b_mat';
    b = double(b_mat(:));
end
% 将比特流还原为字节序列
function bytes = bits2bytes(bits)
    rem_bits = mod(length(bits), 8);
    if rem_bits ~= 0
        bits = [bits(:); zeros(8 - rem_bits, 1)];
    end
    b_mat = reshape(bits, 8, [])';
    bytes = uint8(sum(b_mat .* (2.^(7:-1:0)), 2));
end
% 计算误码率，容错处理长度不一致情况
function ber = calc_ber(ext_bits, true_bits)
    len_true = length(true_bits);
    len_ext = length(ext_bits);
    if len_ext > len_true
        ext_bits = ext_bits(1:len_true);
    elseif len_ext < len_true
        ext_bits = [ext_bits(:); zeros(len_true - len_ext, 1)];
    end
    ber = sum(ext_bits(:) ~= true_bits(:)) / len_true;
end
% 信息隐藏函数
function stego = embed_group_parity(cover, secret_bits, key)
    [H, W, C] = size(cover);
    N = H * W;
    max_cap = floor(N / 2);
    L = length(secret_bits);
    % 将长度 L 转换为 32 位比特流，并采用重复编码15次提升抗噪性
    rep_N = 15; 
    L_bits = bitget(uint32(L), 1:32)';
    L_bits_rep = repmat(L_bits, rep_N, 1); 
    full_bits = double([L_bits_rep; secret_bits(:)]);
    if length(full_bits) > max_cap
        error('秘密信息超出载体图像的容量');
    end
    % 使用密钥生成随机序列，决定嵌入位置，实现随机分散嵌入
    rng(key);
    perm = randperm(max_cap);
    embed_indices = perm(1:length(full_bits));
    % 按照加权概率生成选择，提升安全性的同时兼顾视觉质量:
    % 1: R1 (15%), 2: G1 (5%), 3: B1 (30%)
    % 4: R2 (15%), 5: G2 (5%), 6: B2 (30%)
    rands = rand(length(full_bits), 1);
    choices = zeros(length(full_bits), 1);
    choices(rands < 0.15) = 1;
    choices(rands >= 0.15 & rands < 0.20) = 2;
    choices(rands >= 0.20 & rands < 0.50) = 3;
    choices(rands >= 0.50 & rands < 0.65) = 4;
    choices(rands >= 0.65 & rands < 0.70) = 5;
    choices(rands >= 0.70) = 6;
    img_1d = reshape(cover, N, C);
    % 提取涉及的两个像素的索引
    p1_all = 2 * embed_indices - 1;
    p2_all = 2 * embed_indices;
    % 提取两个像素的所有 6 个通道的值
    r1_all = img_1d(p1_all, 1);
    g1_all = img_1d(p1_all, 2);
    b1_all = img_1d(p1_all, 3);
    r2_all = img_1d(p2_all, 1);
    g2_all = img_1d(p2_all, 2);
    b2_all = img_1d(p2_all, 3);
    % 计算 6 个通道的 LSB 奇偶校验位
    p_all = mod(bitget(r1_all, 1) + bitget(g1_all, 1) + bitget(b1_all, 1) + ...
                bitget(r2_all, 1) + bitget(g2_all, 1) + bitget(b2_all, 1), 2);
    % 找出需要修改的位
    diff_mask = (p_all(:) ~= full_bits(:));
    % 分别找出需要修改各个通道的索引
    change_r1 = diff_mask & (choices == 1);
    change_g1 = diff_mask & (choices == 2);
    change_b1 = diff_mask & (choices == 3);
    change_r2 = diff_mask & (choices == 4);
    change_g2 = diff_mask & (choices == 5);
    change_b2 = diff_mask & (choices == 6);
    % 仅在必要时翻转相应像素相应通道的 LSB
    img_1d(p1_all(change_r1), 1) = bitset(r1_all(change_r1), 1, ~bitget(r1_all(change_r1), 1));
    img_1d(p1_all(change_g1), 2) = bitset(g1_all(change_g1), 1, ~bitget(g1_all(change_g1), 1));
    img_1d(p1_all(change_b1), 3) = bitset(b1_all(change_b1), 1, ~bitget(b1_all(change_b1), 1));
    img_1d(p2_all(change_r2), 1) = bitset(r2_all(change_r2), 1, ~bitget(r2_all(change_r2), 1));
    img_1d(p2_all(change_g2), 2) = bitset(g2_all(change_g2), 1, ~bitget(g2_all(change_g2), 1));
    img_1d(p2_all(change_b2), 3) = bitset(b2_all(change_b2), 1, ~bitget(b2_all(change_b2), 1));
    stego = reshape(img_1d, H, W, C);
end
% 信息提取函数
function secret_bits = extract_group_parity(stego, key)
    [H, W, C] = size(stego);
    N = H * W;
    max_cap = floor(N / 2);
    rng(key);
    perm = randperm(max_cap);
    img_1d = reshape(stego, N, C);
    % 1. 先提取头部（32位 * 15次重复）
    rep_N = 15;
    L_indices = perm(1 : 32 * rep_N);
    p1_L = 2 * L_indices - 1;
    p2_L = 2 * L_indices;
    sum_L = bitget(img_1d(p1_L, 1), 1) + bitget(img_1d(p1_L, 2), 1) + bitget(img_1d(p1_L, 3), 1) + ...
            bitget(img_1d(p2_L, 1), 1) + bitget(img_1d(p2_L, 2), 1) + bitget(img_1d(p2_L, 3), 1);
    L_bits_rep = mod(double(sum_L), 2);
    % 多数表决纠错
    L_bits_matrix = reshape(L_bits_rep, 32, rep_N);
    L_bits = mode(L_bits_matrix, 2); % 对每行的15个重复位求众数
    L = sum(L_bits(:) .* (2.^(0:31)'));
    % 容错处理，直接提取最大可能长度
    if L < 0 || L > max_cap - (32 * rep_N)
        L = max_cap - (32 * rep_N);
    end
    % 2. 提取数据内容
    data_indices = perm(32 * rep_N + 1 : 32 * rep_N + L);
    p1_data = 2 * data_indices - 1;
    p2_data = 2 * data_indices;
    sum_data = bitget(img_1d(p1_data, 1), 1) + bitget(img_1d(p1_data, 2), 1) + bitget(img_1d(p1_data, 3), 1) + ...
               bitget(img_1d(p2_data, 1), 1) + bitget(img_1d(p2_data, 2), 1) + bitget(img_1d(p2_data, 3), 1);
    secret_bits = mod(double(sum_data), 2);
    secret_bits = double(secret_bits(:));
end
% 模拟噪声干扰
function img_att = simulate_attack(img, type, out_dir, name)
    if strcmp(type, 'None')
        img_att = img;
    elseif strcmp(type, 'Noise_Minor')
        % 施加微小的高斯噪声
        img_att = imnoise(img, 'gaussian', 0, 0.001);
    else
        img_att = img;
    end
end