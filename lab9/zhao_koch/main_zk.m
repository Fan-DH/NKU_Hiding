% 经典 Zhao-Koch 方案（频域法应用在二值图像）
clc; clear; close all;
cd(fileparts(mfilename('fullpath')));

% 读取载体图像
cover = imread('../binary.bmp');
if size(cover, 3) == 3; cover = rgb2gray(cover); end
if ~islogical(cover); cover = imbinarize(cover); end

%% 1. 嵌入文字
text_msg = 'FDH2312326';
text_bits = reshape(dec2bin(text_msg, 8).'-'0', 1, []);

key_text = 12345;
[stego_text, success, max_cap] = embed_zk(cover, text_bits, key_text);
if ~success
    error('容量不足，无法嵌入文字！');
end
imwrite(stego_text, 'stego_text.png');

psnr_text = psnr(uint8(stego_text)*255, uint8(cover)*255);
fprintf('Zhao-Koch - 文字隐藏 PSNR: %.4f dB\n', psnr_text);

ext_text_bits = extract_zk(stego_text, length(text_bits), key_text);
ext_text = char(bin2dec(reshape(char(ext_text_bits + '0'), 8, []).')).';
ber_text = sum(text_bits ~= ext_text_bits) / length(text_bits);
fprintf('Zhao-Koch - 文字提取 BER: %.4f, 提取内容: %s\n', ber_text, ext_text);

%% 2. 嵌入图像
secret_img = imread('../secret.png');
if size(secret_img, 3) == 3; secret_img = rgb2gray(secret_img); end
if ~islogical(secret_img); secret_img = imbinarize(secret_img); end
img_bits = secret_img(:)';
key_img = 54321;
[stego_img, success, ~] = embed_zk(cover, img_bits, key_img);
if ~success
    error('容量不足，无法嵌入图像！');
end
imwrite(stego_img, 'stego_image.png');

psnr_img = psnr(uint8(stego_img)*255, uint8(cover)*255);
fprintf('Zhao-Koch - 图像隐藏 PSNR: %.4f dB\n', psnr_img);

ext_img_bits = extract_zk(stego_img, length(img_bits), key_img);
ext_img = reshape(ext_img_bits, size(secret_img));
ber_img = sum(img_bits ~= ext_img_bits) / length(img_bits);
fprintf('Zhao-Koch - 图像提取 BER: %.4f\n', ber_img);
imwrite(logical(ext_img), 'extracted_image.png');

%% 辅助函数
function [stego, success, max_cap] = embed_zk(cover, bits, key)
    [h, w] = size(cover);
    stego = double(cover);
    K = 0.05;
    success = true;
    
    blocks_per_row = floor(w/8);
    blocks_per_col = floor(h/8);
    max_cap = blocks_per_row * blocks_per_col;
    
    if length(bits) > max_cap
        success = false;
        return;
    end
    
    % 加入随机块映射，使隐藏更加分散
    rng(key);
    perm_idx = randperm(max_cap);
    
    for i = 1:length(bits)
        block_id = perm_idx(i);
        row_idx = ceil(block_id / blocks_per_row);
        col_idx = block_id - (row_idx - 1) * blocks_per_row;
        r = (row_idx - 1) * 8 + 1;
        c = (col_idx - 1) * 8 + 1;
        
        block = stego(r:r+7, c:c+7);
        bit = bits(i);
        
        if check_zk(block, bit, K)
            continue;
        end
        
        found = false;
        % 尝试翻转 1 个像素
        for f1 = 1:64
            b_new = block; b_new(f1) = 1 - b_new(f1);
            if check_zk(b_new, bit, K)
                stego(r:r+7, c:c+7) = b_new; found = true; break;
            end
        end
        if found; continue; end
        
        % 尝试翻转 2 个像素（为了提升运行速度，最多只搜索2次翻转）
        for f1 = 1:63
            for f2 = f1+1:64
                b_new = block; b_new(f1) = 1 - b_new(f1); b_new(f2) = 1 - b_new(f2);
                if check_zk(b_new, bit, K)
                    stego(r:r+7, c:c+7) = b_new; found = true; break;
                end
            end
            if found; break; end
        end
    end
    stego = logical(stego);
end

function ok = check_zk(block, bit, K)
    D = dct2(block - 0.5);
    C1 = abs(D(4,5));
    C2 = abs(D(5,4));
    if bit == 1
        ok = (C1 > C2 + K);
    else
        ok = (C2 > C1 + K);
    end
end

function ext_bits = extract_zk(stego, len, key)
    [h, w] = size(stego);
    ext_bits = zeros(1, len);
    stego = double(stego);
    
    blocks_per_row = floor(w/8);
    blocks_per_col = floor(h/8);
    max_cap = blocks_per_row * blocks_per_col;
    
    rng(key);
    perm_idx = randperm(max_cap);
    
    for i = 1:len
        block_id = perm_idx(i);
        row_idx = ceil(block_id / blocks_per_row);
        col_idx = block_id - (row_idx - 1) * blocks_per_row;
        r = (row_idx - 1) * 8 + 1;
        c = (col_idx - 1) * 8 + 1;
        
        block = stego(r:r+7, c:c+7);
        D = dct2(block - 0.5);
        C1 = abs(D(4,5));
        C2 = abs(D(5,4));
        
        if C1 > C2
            ext_bits(i) = 1;
        else
            ext_bits(i) = 0;
        end
    end
end