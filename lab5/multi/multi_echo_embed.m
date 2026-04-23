function multi_echo_embed(inWav, outWav, message, L, D0, D1, A, energyRatio, minRms)
    % multi_echo_embed
    % 多回声核嵌入函数。
    % 作用：使用两组多延时回声模板分别表示 bit=0 和 bit=1。

    % 若未给定帧长，则使用默认值 8192。
    if nargin < 4 || isempty(L),           L = 8192; end
    % 若未给定 bit=0 的多回声延时集合，则使用默认值。
    if nargin < 5 || isempty(D0),          D0 = [110 180 260]; end
    % 若未给定 bit=1 的多回声延时集合，则使用默认值。
    if nargin < 6 || isempty(D1),          D1 = [140 210 290]; end
    % 若未给定各回声分量的强度，则使用默认值。
    if nargin < 7 || isempty(A),           A  = [0.22 0.15 0.10]; end
    % 若未给定有效帧筛选比例，则使用默认值 0.25。
    if nargin < 8 || isempty(energyRatio), energyRatio = 0.25; end
    % 若未给定最小 RMS 门限，则使用默认值 0.01。
    if nargin < 9 || isempty(minRms),      minRms = 0.01; end
    % 检查两组延时和强度向量长度必须一致。
    assert(numel(D0) == numel(D1) && numel(D0) == numel(A), 'D0、D1、A 长度必须一致。');
    % 检查帧长必须大于所有回声延时中的最大值。
    assert(L > max([D0(:); D1(:)]), '帧长 L 必须大于最大延时。');

    % 读入宿主音频。
    [x, fs] = audioread(inWav);
    % 转为 double 便于数值叠加。
    x = double(x);

    % 将消息字符串编码为 UTF-8 字节流。
    payloadBytes = unicode2native(message, 'UTF-8');
    % 统计正文的字节长度。
    payloadLenBytes = numel(payloadBytes);
    % 限制正文长度不超过 16 bit 头所能表示的范围。
    assert(payloadLenBytes <= 65535, '消息过长');
    % 将长度字段编码成 16 bit 头部。
    headerBits = reshape(dec2bin(payloadLenBytes, 16).'-'0', 1, []);
    % 将正文逐字节展开为比特流。
    payloadBits = echo_bytes_to_bits_local(payloadBytes);
    % 拼接得到最终待嵌入比特序列。
    bits = [headerBits, payloadBits];

    % 选择适合嵌入的有效帧。
    [activeFrames, ~, thr] = echo_select_active_frames_local(x, L, energyRatio, minRms);
    % 估计最多可容纳的正文字节数。
    maxPayloadBytes = floor((numel(activeFrames) - 16) / 8);
    % 检查有效帧数是否足够嵌入完整消息。
    assert(numel(bits) <= numel(activeFrames), ...
        '可用有效帧不足：当前音频最多只能嵌入 %d 字节正文。', max(maxPayloadBytes, 0));

    % 初始化输出音频为原始音频。
    y = x;
    % 仅使用前若干个有效帧作为嵌入目标。
    targetFrames = activeFrames(1:numel(bits));

    % 对每个声道分别做嵌入。
    for ch = 1:size(x, 2)
        % 取出当前声道。
        channel = x(:, ch);
        % 逐比特嵌入。
        for k = 1:numel(bits)
            % 当前比特对应的目标帧编号。
            frameId = targetFrames(k);
            % 当前帧在音频中的样本区间。
            idx = (frameId-1)*L + (1:L);
            % 取出当前帧。
            frame = channel(idx);

            % 根据当前比特，选择 D0 或 D1 作为延时模板。
            if bits(k) == 0
                D = D0;
            else
                D = D1;
            end

            % 初始化隐写帧为原始帧。
            stegoFrame = frame;
            % 将多个延时分量逐个叠加，形成多回声核。
            for j = 1:numel(D)
                % 当前回声分量的延时。
                d = D(j);
                % 构造当前延时对应的回声副本。
                delayed = [zeros(d, 1); frame(1:end-d)];
                % 按对应权重 A(j) 叠加到隐写帧中。
                stegoFrame = stegoFrame + A(j) * delayed;
            end
            % 将嵌入后的帧写回输出音频。
            y(idx, ch) = stegoFrame;
        end
    end

    % 检查整体峰值，避免写出时出现削波。
    peak = max(abs(y(:)));
    % 若峰值过大，则整体归一化。
    if peak > 0.99
        y = 0.99 * y / peak;
    end

    % 写出隐写音频。
    audiowrite(outWav, y, fs);
    % 打印完成信息。
    fprintf('多回声核嵌入完成：%s\n', outWav);
    % 打印关键实验参数。
    fprintf('采样率 = %d Hz, 帧长 = %d, 有效帧数 = %d, 门限 = %.6f, 已嵌入比特数 = %d\n', ...
        fs, L, numel(activeFrames), thr, numel(bits));
end

function bits = echo_bytes_to_bits_local(bytes)
% echo_bytes_to_bits_local
% 将 uint8 字节数组展开为 0/1 比特行向量，高位在前。

    % 若输入为空，则直接返回空向量。
    if isempty(bytes)
        bits = [];
        return;
    end
    % 将输入整理成 uint8 列向量。
    bytes = uint8(bytes(:));
    % 将每个字节转为 8 位二进制字符。
    bitChars = dec2bin(bytes, 8);
    % 把字符矩阵展开为数值比特行向量。
    bits = reshape((bitChars.' - '0'), 1, []);
end

function [activeFrames, frameRms, threshold] = echo_select_active_frames_local(x, L, energyRatio, minRms)
% echo_select_active_frames_local
% 基于帧 RMS 选择高能量帧。

    % 设置默认的能量比例参数。
    if nargin < 3 || isempty(energyRatio), energyRatio = 0.25; end
    % 设置默认的最小 RMS 门限。
    if nargin < 4 || isempty(minRms),      minRms = 0.01; end

    % 多声道时先转单声道。
    if size(x, 2) > 1
        xMono = mean(double(x), 2);
    else
        % 单声道时直接转 double。
        xMono = double(x);
    end

    % 计算能够完整切分的帧数。
    nFrames = floor(length(xMono) / L);
    % 若没有完整帧，则返回空结果。
    if nFrames <= 0
        activeFrames = [];
        frameRms = [];
        threshold = minRms;
        return;
    end

    % 丢弃不足一帧的尾部样本。
    xMono = xMono(1:nFrames * L);
    % 组织为帧矩阵。
    frameMat = reshape(xMono, L, nFrames).';
    % 逐帧计算 RMS。
    frameRms = sqrt(mean(frameMat.^2, 2));
    % 根据中位数 RMS 和下限得到门限。
    threshold = max(minRms, median(frameRms) * energyRatio);
    % 取出所有满足门限的帧编号。
    activeFrames = find(frameRms >= threshold);
end
