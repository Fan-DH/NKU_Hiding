function stego = embed_compare(cover, bits, D)
    % DCT域信息隐藏实验：系数比较方法 - 嵌入
    stego = cover;
    [h, w] = size(cover);
    block_size = 8;
    h_blocks = floor(h / block_size);
    w_blocks = floor(w / block_size);
    max_capacity = h_blocks * w_blocks;
    
    len = length(bits);
    indices = round(linspace(1, max_capacity, len));
    
    for k = 1:len
        idx = indices(k);
        
        r = ceil(idx / w_blocks);
        c = mod(idx - 1, w_blocks) + 1;
        
        row_idx = (r-1)*block_size + 1 : r*block_size;
        col_idx = (c-1)*block_size + 1 : c*block_size;
        block = cover(row_idx, col_idx);
        
        dct_block = dct2(block);
        
        C1 = dct_block(4, 5);
        C2 = dct_block(5, 4);
        bit = bits(k);
        
        avg = (C1 + C2) / 2;
        if bit == 1
            if C1 - C2 < D
                C1 = avg + D/2 + 1;
                C2 = avg - D/2 - 1;
            end
        else
            if C1 - C2 > -D
                C1 = avg - D/2 - 1;
                C2 = avg + D/2 + 1;
            end
        end
        
        dct_block(4, 5) = C1;
        dct_block(5, 4) = C2;
        
        stego(row_idx, col_idx) = idct2(dct_block);
    end
end
