% 游程编码法 (Run-Length Encoding Method)
clc; clear; close all;
cd(fileparts(mfilename('fullpath')));

% 读取载体图像
cover = imread('../binary.bmp');
if size(cover, 3) == 3; cover = rgb2gray(cover); end
if ~islogical(cover); cover = imbinarize(cover); end

%% 1. 嵌入文字
text_msg = 'FDH2312326';
text_bits = reshape(dec2bin(text_msg, 8).'-'0', 1, []);

[stego_text, success, max_cap] = embed_rle(cover, text_bits);
if ~success
    error('容量不足，无法嵌入文字！');
end
imwrite(stego_text, 'stego_text.png');

psnr_text = psnr(uint8(stego_text)*255, uint8(cover)*255);
fprintf('游程编码 - 文字隐藏 PSNR: %.4f dB\n', psnr_text);

ext_text_bits = extract_rle(stego_text, length(text_bits));
ext_text = char(bin2dec(reshape(char(ext_text_bits + '0'), 8, []).')).';
ber_text = sum(text_bits ~= ext_text_bits) / length(text_bits);
fprintf('游程编码 - 文字提取 BER: %.4f, 提取内容: %s\n', ber_text, ext_text);

%% 2. 嵌入图像
secret_img = imread('../secret.png');
if size(secret_img, 3) == 3; secret_img = rgb2gray(secret_img); end
if ~islogical(secret_img); secret_img = imbinarize(secret_img); end
img_bits = secret_img(:)';

[stego_img, success, ~] = embed_rle(cover, img_bits);
if ~success
    error('游程编码容量不足！');
end
imwrite(stego_img, 'stego_image.png');

psnr_img = psnr(uint8(stego_img)*255, uint8(cover)*255);
fprintf('游程编码 - 图像隐藏 PSNR: %.4f dB\n', psnr_img);

ext_img_bits = extract_rle(stego_img, length(img_bits));
ext_img = reshape(ext_img_bits, size(secret_img));
ber_img = sum(img_bits ~= ext_img_bits) / length(img_bits);
fprintf('游程编码 - 图像提取 BER: %.4f\n', ber_img);
imwrite(logical(ext_img), 'extracted_image.png');

%% 辅助函数
function [stego, success, max_cap] = embed_rle(cover, bits)
    [h, w] = size(cover);
    stego = cover;
    bit_idx = 1;
    success = true;
    max_cap = 0;
    
    % 首先计算最大容量
    for r = 1:h
        row = cover(r, :);
        runs = [];
        curr_len = 1;
        curr_color = row(1);
        for c = 2:w
            if row(c) == curr_color
                curr_len = curr_len + 1;
            else
                runs(end+1) = curr_len;
                curr_color = row(c);
                curr_len = 1;
            end
        end
        runs(end+1) = curr_len;
        for i = 1:2:length(runs)-1
            if runs(i) + runs(i+1) >= 3
                max_cap = max_cap + 1;
            end
        end
    end
    
    if length(bits) > max_cap
        success = false;
        return;
    end
    
    % 开始嵌入
    for r = 1:h
        row = cover(r, :);
        runs = [];
        colors = [];
        curr_len = 1;
        curr_color = row(1);
        for c = 2:w
            if row(c) == curr_color
                curr_len = curr_len + 1;
            else
                runs(end+1) = curr_len;
                colors(end+1) = curr_color;
                curr_color = row(c);
                curr_len = 1;
            end
        end
        runs(end+1) = curr_len;
        colors(end+1) = curr_color;
        
        for i = 1:2:length(runs)-1
            if bit_idx > length(bits)
                break;
            end
            
            R1 = runs(i);
            R2 = runs(i+1);
            if R1 + R2 >= 3
                bit = bits(bit_idx);
                if mod(R1, 2) ~= bit
                    % 确保不会出现 R1=0 或 R2=0 的情况
                    if R1 == 1
                        R1 = R1 + 1;
                        R2 = R2 - 1;
                    elseif R2 == 1
                        R1 = R1 - 1;
                        R2 = R2 + 1;
                    else
                        R1 = R1 + 1;
                        R2 = R2 - 1;
                    end
                end
                runs(i) = R1;
                runs(i+1) = R2;
                bit_idx = bit_idx + 1;
            end
        end
        
        new_row = zeros(1, w);
        idx = 1;
        for i = 1:length(runs)
            new_row(idx : idx+runs(i)-1) = colors(i);
            idx = idx + runs(i);
        end
        stego(r, :) = new_row;
        
        if bit_idx > length(bits)
            break;
        end
    end
end

function ext_bits = extract_rle(stego, len)
    [h, w] = size(stego);
    ext_bits = zeros(1, len);
    bit_idx = 1;
    
    for r = 1:h
        if bit_idx > len
            break;
        end
        row = stego(r, :);
        runs = [];
        curr_len = 1;
        curr_color = row(1);
        for c = 2:w
            if row(c) == curr_color
                curr_len = curr_len + 1;
            else
                runs(end+1) = curr_len;
                curr_color = row(c);
                curr_len = 1;
            end
        end
        runs(end+1) = curr_len;
        
        for i = 1:2:length(runs)-1
            if bit_idx > len
                break;
            end
            
            R1 = runs(i);
            R2 = runs(i+1);
            if R1 + R2 >= 3
                ext_bits(bit_idx) = mod(R1, 2);
                bit_idx = bit_idx + 1;
            end
        end
    end
end