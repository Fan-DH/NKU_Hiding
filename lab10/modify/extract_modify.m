function ext_bits = extract_modify(stego, len, Q)
    % DCT域信息隐藏实验：修改系数方法 - 提取
    [h, w] = size(stego);
    block_size = 8;
    h_blocks = floor(h / block_size);
    w_blocks = floor(w / block_size);
    max_capacity = h_blocks * w_blocks;
    
    indices = round(linspace(1, max_capacity, len));
    ext_bits = zeros(1, len);
    
    for k = 1:len
        idx = indices(k);
        r = ceil(idx / w_blocks);
        c = mod(idx - 1, w_blocks) + 1;
        
        row_idx = (r-1)*block_size + 1 : r*block_size;
        col_idx = (c-1)*block_size + 1 : c*block_size;
        block = stego(row_idx, col_idx);
        
        dct_block = dct2(block);
        C = dct_block(5, 5);
        
        d0 = abs(C - round(C / (2*Q)) * 2 * Q);
        d1 = abs(C - (round((C - Q) / (2*Q)) * 2 * Q + Q));
        
        if d0 < d1
            ext_bits(k) = 0;
        else
            ext_bits(k) = 1;
        end
    end
end
