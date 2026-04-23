function message = timespread_echo_extract(stegoWav, L, d0, d1, pnLen, seed, guard, energyRatio, minRms)
    % timespread_echo_extract
    % 时域扩展回声核提取函数。
    % 作用：用同一 PN 序列相关检测两个起始延时处的扩展回声，从而恢复比特。

    % 若未给定帧长，则使用默认值 8192。
    if nargin < 2 || isempty(L),           L = 8192; end
    % 若未给定 bit=0 起始延时，则使用默认值 120。
    if nargin < 3 || isempty(d0),          d0 = 120; end
    % 若未给定 bit=1 起始延时，则使用默认值 220。
    if nargin < 4 || isempty(d1),          d1 = 220; end
    % 若未给定 PN 长度，则使用默认值 32。
    if nargin < 5 || isempty(pnLen),       pnLen = 32; end
    % 若未给定随机种子，则使用默认值 2025。
    if nargin < 6 || isempty(seed),        seed = 2025; end
    % 若未给定邻域保护宽度，则使用默认值 0。
    if nargin < 7 || isempty(guard),       guard = 0; end
    % 若未给定有效帧筛选比例，则使用默认值 0.25。
    if nargin < 8 || isempty(energyRatio), energyRatio = 0.25; end
    % 若未给定最小 RMS 门限，则使用默认值 0.01。
    if nargin < 9 || isempty(minRms),      minRms = 0.01; end
    % 检查帧长必须覆盖最大扩展延时位置。
    assert(L > max([d0 + pnLen - 1, d1 + pnLen - 1]), '帧长 L 必须大于最大扩展延时。');

    % 设置随机种子，保证与嵌入端 PN 序列一致。
    rng(seed);
    % 重新生成与嵌入端相同的双极性 PN 序列。
    pn = 2 * randi([0 1], pnLen, 1) - 1;
    % 去除均值，减小直流偏置。
    pn = pn - mean(pn);
    % 检查范数不为 0。
    assert(norm(pn) > 0, 'PN 序列归一化失败，请调整 pnLen 或 seed');
    % 归一化为单位范数。
    pn = pn / norm(pn);

    % 读入隐写音频。
    [y, ~] = audioread(stegoWav);
    % 转为 double。
    y = double(y);
    % 多声道时先均值为单声道。
    if size(y, 2) > 1
        yMono = mean(y, 2);
    else
        % 单声道时直接使用。
        yMono = y;
    end

    % 选择有效帧。
    [activeFrames, ~, thr] = echo_select_active_frames_local(yMono, L, energyRatio, minRms);
    % 至少需要 16 个有效帧才能提取头部。
    if numel(activeFrames) < 16
        error('有效帧不足，无法读取 16 bit 头。');
    end

    % 预分配比特数组。
    bits = zeros(1, numel(activeFrames));
    % 生成 Hann 窗。
    w = echo_hann_window_local(L);

    % 逐帧检测。
    for k = 1:numel(activeFrames)
        % 当前帧编号。
        frameId = activeFrames(k);
        % 当前帧下标范围。
        idx = (frameId-1)*L + (1:L);
        % 当前帧加窗。
        frame = yMono(idx) .* w;
        % 计算实倒谱。
        c = real(ifft(log(abs(fft(frame)) + eps)));

        % 取出 d0 起始处长度为 pnLen 的扩展倒谱片段。
        seg0 = extract_segment(c, d0, pnLen, guard);
        % 取出 d1 起始处长度为 pnLen 的扩展倒谱片段。
        seg1 = extract_segment(c, d1, pnLen, guard);

        % 计算 seg0 与 PN 序列的归一化相关得分。
        score0 = dot(seg0(:), pn(:)) / (norm(seg0) + eps);
        % 计算 seg1 与 PN 序列的归一化相关得分。
        score1 = dot(seg1(:), pn(:)) / (norm(seg1) + eps);
        % 哪个起始延时处的相关得分更大，就判为对应的 bit。
        bits(k) = score1 > score0;
    end

    % 前 16 bit 为正文长度头。
    headerBits = bits(1:16);
    % 将头部解码为正文字节数。
    payloadLenBytes = bin2dec(char(headerBits + '0'));
    % 计算完整消息需要的总比特数。
    needBits = 16 + payloadLenBytes * 8;
    % 若有效帧数不足，则报错。
    if numel(bits) < needBits
        error('可提取比特不足：有效帧数不够或头部检测错误。');
    end

    % 截取正文比特。
    payloadBits = bits(17:needBits);
    % 将正文 bit 流恢复为字节流。
    payloadBytes = echo_bits_to_bytes_local(payloadBits);
    % 将 UTF-8 字节流解码为字符串消息。
    message = native2unicode(payloadBytes, 'UTF-8');
    % 打印提取完成信息。
    fprintf('时域扩展回声核提取完成，消息长度 = %d 字节\n', payloadLenBytes);
    % 打印有效帧和门限信息。
    fprintf('有效帧数 = %d, 门限 = %.6f\n', numel(activeFrames), thr);
    % 打印提取消息。
    fprintf('提取消息：%s\n', message);
end

function seg = extract_segment(c, d, pnLen, guard)
% extract_segment
% 从倒谱中提取以 d 为起点、长度为 pnLen 的片段，并在每个点做局部平均。

    % 预分配片段向量。
    seg = zeros(pnLen, 1);
    % 逐个芯片位置提取局部值。
    for m = 1:pnLen
        % 当前芯片对应的倒谱中心位置，注意 MATLAB 下标从 1 开始。
        center = d + (m-1) + 1;
        % 计算当前邻域左边界。
        left = max(1, center - guard);
        % 计算当前邻域右边界。
        right = min(length(c), center + guard);
        % 对当前邻域求实部平均，作为该芯片位置的观测值。
        seg(m) = mean(real(c(left:right)));
    end
end

function bytes = echo_bits_to_bytes_local(bits)
% echo_bits_to_bytes_local
% 将比特序列恢复为 uint8 字节流。

    % 检查比特数必须是 8 的整数倍。
    assert(mod(numel(bits), 8) == 0, '比特数必须为 8 的整数倍。');
    % 每 8 bit 重排为一行。
    bitMat = reshape(bits, 8, []).';
    % 还原为十进制字节并转为 uint8。
    bytes = uint8(bin2dec(char(bitMat + '0')));
end

function w = echo_hann_window_local(L)
% echo_hann_window_local
% 生成周期型 Hann 窗。

    % 构造索引向量。
    n = (0:L-1).';
    % 按 Hann 公式计算窗函数。
    w = 0.5 - 0.5 * cos(2*pi*n/L);
end

function [activeFrames, frameRms, threshold] = echo_select_active_frames_local(x, L, energyRatio, minRms)
% echo_select_active_frames_local
% 根据帧 RMS 选择有效帧。

    % 默认能量比例。
    if nargin < 3 || isempty(energyRatio), energyRatio = 0.25; end
    % 默认最小 RMS 门限。
    if nargin < 4 || isempty(minRms),      minRms = 0.01; end

    % 多声道时先转单声道。
    if size(x, 2) > 1
        xMono = mean(double(x), 2);
    else
        % 单声道直接转 double。
        xMono = double(x);
    end

    % 计算完整帧数。
    nFrames = floor(length(xMono) / L);
    % 若没有完整帧，则返回空结果。
    if nFrames <= 0
        activeFrames = [];
        frameRms = [];
        threshold = minRms;
        return;
    end

    % 截断到整帧长度。
    xMono = xMono(1:nFrames * L);
    % 重排成帧矩阵。
    frameMat = reshape(xMono, L, nFrames).';
    % 计算各帧 RMS。
    frameRms = sqrt(mean(frameMat.^2, 2));
    % 计算门限。
    threshold = max(minRms, median(frameRms) * energyRatio);
    % 选出有效帧编号。
    activeFrames = find(frameRms >= threshold);
end
