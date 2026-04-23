function timespread_echo_embed(inWav, outWav, message, L, d0, d1, pnLen, alpha, seed, energyRatio, minRms)
    % timespread_echo_embed
    % 时域扩展回声核嵌入函数。
    % 作用：使用 PN 序列对一组连续延时回声进行扩展，并用两组起始延时表示 bit。

    % 若未给定帧长，则使用默认值 8192。
    if nargin < 4 || isempty(L),            L = 8192; end
    % 若未给定 bit=0 的起始延时，则使用默认值 120。
    if nargin < 5 || isempty(d0),           d0 = 120; end
    % 若未给定 bit=1 的起始延时，则使用默认值 220。
    if nargin < 6 || isempty(d1),           d1 = 220; end
    % 若未给定 PN 长度，则使用默认值 32。
    if nargin < 7 || isempty(pnLen),        pnLen = 32; end
    % 若未给定扩展回声强度，则使用默认值 0.12。
    if nargin < 8 || isempty(alpha),        alpha = 0.12; end
    % 若未给定随机种子，则使用默认值 2025。
    if nargin < 9 || isempty(seed),         seed = 2025; end
    % 若未给定有效帧筛选比例，则使用默认值 0.25。
    if nargin < 10 || isempty(energyRatio), energyRatio = 0.25; end
    % 若未给定最小 RMS 门限，则使用默认值 0.01。
    if nargin < 11 || isempty(minRms),      minRms = 0.01; end
    % 检查帧长必须大于最大扩展延时位置。
    assert(L > max([d0 + pnLen - 1, d1 + pnLen - 1]), '帧长 L 必须大于最大扩展延时。');

    % 设置随机种子，保证嵌入和提取使用相同 PN 序列。
    rng(seed);
    % 生成长度为 pnLen 的双极性 PN 序列，元素取值为 ±1。
    pn = 2 * randi([0 1], pnLen, 1) - 1;
    % 去除 PN 序列均值，避免直流偏置。
    pn = pn - mean(pn);
    % 检查 PN 序列归一化前的范数不为 0。
    assert(norm(pn) > 0, 'PN 序列归一化失败，请调整 pnLen 或 seed');
    % 将 PN 序列归一化为单位范数。
    pn = pn / norm(pn);

    % 读入宿主音频。
    [x, fs] = audioread(inWav);
    % 转为 double。
    x = double(x);

    % 将消息编码为 UTF-8 字节流。
    payloadBytes = unicode2native(message, 'UTF-8');
    % 统计正文长度。
    payloadLenBytes = numel(payloadBytes);
    % 限制正文长度不超过 65535 字节。
    assert(payloadLenBytes <= 65535, '消息过长');
    % 构造 16 bit 头部。
    headerBits = reshape(dec2bin(payloadLenBytes, 16).'-'0', 1, []);
    % 将正文字节展开为比特序列。
    payloadBits = echo_bytes_to_bits_local(payloadBytes);
    % 拼接头部与正文。
    bits = [headerBits, payloadBits];

    % 选择有效帧。
    [activeFrames, ~, thr] = echo_select_active_frames_local(x, L, energyRatio, minRms);
    % 估算最大可嵌入正文长度。
    maxPayloadBytes = floor((numel(activeFrames) - 16) / 8);
    % 检查有效帧是否足够承载全部比特。
    assert(numel(bits) <= numel(activeFrames), ...
        '可用有效帧不足：当前音频最多只能嵌入 %d 字节正文。', max(maxPayloadBytes, 0));

    % 初始化输出音频。
    y = x;
    % 选择前若干个有效帧作为嵌入帧。
    targetFrames = activeFrames(1:numel(bits));

    % 逐声道处理。
    for ch = 1:size(x, 2)
        % 当前声道信号。
        channel = x(:, ch);
        % 逐比特嵌入。
        for k = 1:numel(bits)
            % 当前目标帧编号。
            frameId = targetFrames(k);
            % 当前帧样本范围。
            idx = (frameId-1)*L + (1:L);
            % 取出当前帧。
            frame = channel(idx);

            % 根据当前 bit 决定扩展回声的起始延时。
            if bits(k) == 0
                d = d0;
            else
                d = d1;
            end

            % 初始化扩展回声分量。
            spreadEcho = zeros(L, 1);
            % 按 PN 序列逐个叠加连续延时的回声副本。
            for m = 1:pnLen
                % 当前 PN 芯片对应的具体延时位置。
                delay = d + (m-1);
                % 构造该延时位置的回声副本。
                delayed = [zeros(delay, 1); frame(1:end-delay)];
                % 按 PN 芯片符号与强度累计到扩展回声中。
                spreadEcho = spreadEcho + pn(m) * delayed;
            end
            % 将扩展回声叠加到原始帧上。
            stegoFrame = frame + alpha * spreadEcho;
            % 将隐写帧写回输出音频。
            y(idx, ch) = stegoFrame;
        end
    end

    % 检查输出峰值。
    peak = max(abs(y(:)));
    % 若峰值过大，则做整体归一化。
    if peak > 0.99
        y = 0.99 * y / peak;
    end

    % 写出隐写音频。
    audiowrite(outWav, y, fs);
    % 打印完成信息。
    fprintf('时域扩展回声核嵌入完成：%s\n', outWav);
    % 打印关键参数与统计量。
    fprintf('采样率 = %d Hz, 帧长 = %d, 有效帧数 = %d, 门限 = %.6f, 已嵌入比特数 = %d\n', ...
        fs, L, numel(activeFrames), thr, numel(bits));
end

function bits = echo_bytes_to_bits_local(bytes)
% echo_bytes_to_bits_local
% 将字节数组展开为 0/1 比特行向量。

    % 若输入为空，则返回空比特流。
    if isempty(bytes)
        bits = [];
        return;
    end
    % 整理为 uint8 列向量。
    bytes = uint8(bytes(:));
    % 转成 8 位二进制字符矩阵。
    bitChars = dec2bin(bytes, 8);
    % 展开为数值比特序列。
    bits = reshape((bitChars.' - '0'), 1, []);
end

function [activeFrames, frameRms, threshold] = echo_select_active_frames_local(x, L, energyRatio, minRms)
% echo_select_active_frames_local
% 根据帧 RMS 选择有效帧。

    % 默认能量比例。
    if nargin < 3 || isempty(energyRatio), energyRatio = 0.25; end
    % 默认最小 RMS 门限。
    if nargin < 4 || isempty(minRms),      minRms = 0.01; end

    % 若是多声道，则先平均为单声道。
    if size(x, 2) > 1
        xMono = mean(double(x), 2);
    else
        % 单声道直接转 double。
        xMono = double(x);
    end

    % 计算完整帧数。
    nFrames = floor(length(xMono) / L);
    % 若没有完整帧，则返回空。
    if nFrames <= 0
        activeFrames = [];
        frameRms = [];
        threshold = minRms;
        return;
    end

    % 截断到整帧长度。
    xMono = xMono(1:nFrames * L);
    % 重排为帧矩阵。
    frameMat = reshape(xMono, L, nFrames).';
    % 计算各帧 RMS。
    frameRms = sqrt(mean(frameMat.^2, 2));
    % 计算门限。
    threshold = max(minRms, median(frameRms) * energyRatio);
    % 取出满足门限的有效帧。
    activeFrames = find(frameRms >= threshold);
end
