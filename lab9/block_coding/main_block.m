% 块编码隐藏法 (Block Coding Method)
clc; clear; close all;
cd(fileparts(mfilename('fullpath')));

% 读取载体图像
cover = imread('../binary.bmp');
if size(cover, 3) == 3; cover = rgb2gray(cover); end
if ~islogical(cover); cover = imbinarize(cover); end

%% 1. 嵌入文字
text_msg = 'FDH2312326';
text_bits = reshape(dec2bin(text_msg, 8).'-'0', 1, []);

% 使用密钥进行随机块打乱，避免信息堆积在图像上方
key_text = 12345;
stego_text = embed_block(cover, text_bits, key_text);
imwrite(stego_text, 'stego_text.png');

psnr_text = psnr(uint8(stego_text)*255, uint8(cover)*255);
fprintf('块编码 - 文字隐藏 PSNR: %.4f dB\n', psnr_text);

ext_text_bits = extract_block(stego_text, length(text_bits), key_text);
ext_text = char(bin2dec(reshape(char(ext_text_bits + '0'), 8, []).')).';
ber_text = sum(text_bits ~= ext_text_bits) / length(text_bits);
fprintf('块编码 - 文字提取 BER: %.4f, 提取内容: %s\n', ber_text, ext_text);

%% 2. 嵌入图像
secret_img = imread('../secret.png');
if size(secret_img, 3) == 3; secret_img = rgb2gray(secret_img); end
if ~islogical(secret_img); secret_img = imbinarize(secret_img); end

[h, w] = size(cover);
max_cap = floor(h * w / 4);
img_bits = secret_img(:)';

key_img = 54321; % 图像使用的密钥
stego_img = embed_block(cover, img_bits, key_img);
imwrite(stego_img, 'stego_image.png');

psnr_img = psnr(uint8(stego_img)*255, uint8(cover)*255);
fprintf('块编码 - 图像隐藏 PSNR: %.4f dB\n', psnr_img);

ext_img_bits = extract_block(stego_img, length(img_bits), key_img);
ext_img = reshape(ext_img_bits, size(secret_img));
ber_img = sum(img_bits ~= ext_img_bits) / length(img_bits);
fprintf('块编码 - 图像提取 BER: %.4f\n', ber_img);
imwrite(logical(ext_img), 'extracted_image.png');

%% 辅助函数
function stego = embed_block(cover, bits, key)
    stego = cover;
    [h, w] = size(cover);
    num_blocks = floor(h * w / 4);
    if length(bits) > num_blocks
        error('容量不足');
    end
    
    rng(key);
    perm_idx = randperm(num_blocks);
    
    stego_1d = stego(:);
    for i = 1:length(bits)
        block_id = perm_idx(i);
        idx = (block_id-1)*4 + 1 : block_id*4;
        block = stego_1d(idx);
        num_black = sum(block == 0);
        bit = bits(i);
        
        target_black = 3; % bit 0 对应 3黑1白
        if bit == 1
            target_black = 1; % bit 1 对应 1黑3白
        end
        
        if num_black ~= target_black
            diff = target_black - num_black;
            if diff > 0 % 需要更多黑像素 (1变0)
                white_idx = find(block == 1);
                block(white_idx(1:diff)) = 0;
            else % 需要更多白像素 (0变1)
                black_idx = find(block == 0);
                block(black_idx(1:-diff)) = 1;
            end
            stego_1d(idx) = block;
        end
    end
    stego = reshape(stego_1d, h, w);
end

function ext_bits = extract_block(stego, len, key)
    [h, w] = size(stego);
    num_blocks = floor(h * w / 4);
    rng(key);
    perm_idx = randperm(num_blocks);
    
    stego_1d = stego(:);
    ext_bits = zeros(1, len);
    for i = 1:len
        block_id = perm_idx(i);
        idx = (block_id-1)*4 + 1 : block_id*4;
        block = stego_1d(idx);
        num_black = sum(block == 0);
        if num_black == 1
            ext_bits(i) = 1;
        elseif num_black == 3
            ext_bits(i) = 0;
        else
            % 容错处理
            if num_black <= 2
                ext_bits(i) = 1;
            else
                ext_bits(i) = 0;
            end
        end
    end
end