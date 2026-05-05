clc; clear; close all;

in_dir = 'output_t3';
out_dir = 'output_t4';
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

secret_path = 'secret.png';
secret_orig = imread(secret_path);

% 读取尺寸信息
info_path = fullfile(in_dir, 'color_secret_info.mat');
load(info_path, 'Hs', 'Ws', 'Hs_r', 'Ws_r', 'Cs');

planes = 1:8;
noise_types = {'无加噪', '椒盐噪声 0.01', '椒盐噪声 0.05'};

for p = planes
    stego_name = fullfile(in_dir, sprintf('color_stego_plane%d.png', p));
    fprintf('\n--- 处理隐藏在第 %d 位平面的彩色载体图像 %s ---\n', p, stego_name);
    
    stego_img = imread(stego_name);
    
    for n_idx = 1:3
        % 1. 加噪操作
        if n_idx == 1
            noisy_stego = stego_img;
        elseif n_idx == 2
            % 彩色图分别对各通道加噪
            noisy_stego = stego_img;
            for c = 1:3
                noisy_stego(:,:,c) = imnoise(stego_img(:,:,c), 'salt & pepper', 0.01);
            end
        elseif n_idx == 3
            noisy_stego = stego_img;
            for c = 1:3
                noisy_stego(:,:,c) = imnoise(stego_img(:,:,c), 'salt & pepper', 0.05);
            end
        end
        
        % 2. 提取秘密图像
        extr_bit_plane = zeros(size(noisy_stego), 'uint8');
        for c = 1:3
            extr_bit_plane(:,:,c) = bitget(noisy_stego(:,:,c), p);
        end
        extr_bit_plane = extr_bit_plane(:);
        
        % 获取有效的秘密比特
        secret_len = Hs_r * Ws_r * Cs * 8;
        extr_bits = extr_bit_plane(1:secret_len);
        
        % 将比特流恢复为像素值
        extr_bits = reshape(extr_bits, 8, [])';
        secret_dec = zeros(size(extr_bits, 1), 1, 'uint8');
        for b = 1:8
            secret_dec = bitset(secret_dec, 9-b, extr_bits(:, b));
        end
        
        % 恢复成缩放后的大小
        secret_extr = reshape(secret_dec, Hs_r, Ws_r, Cs);
        
        % 插值放大回原秘密图像的尺寸，以便计算 PSNR
        secret_extr_full = imresize(secret_extr, [Hs, Ws]);
        
        % 保存提取出来的图像
        out_name = fullfile(out_dir, sprintf('color_extr_plane%d_noise%d.png', p, n_idx));
        imwrite(secret_extr_full, out_name);
        
        % 3. 计算提取图与原秘密图像的 PSNR
        mse = mean((double(secret_extr_full(:)) - double(secret_orig(:))).^2);
        if mse == 0
            psnr_val = Inf;
        else
            psnr_val = 10 * log10(255^2 / mse);
        end
        
        fprintf('%s，提取图保存为 %s，与原秘密图的 PSNR = %.4f dB\n', noise_types{n_idx}, out_name, psnr_val);
    end
end