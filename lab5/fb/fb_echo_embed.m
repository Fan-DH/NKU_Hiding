function fb_echo_embed(inWav, outWav, message, L, dF, dB, alphaStrong, alphaWeak, energyRatio, minRms)
    % fb_echo_embed
    % 前后向回声核嵌入函数。
    % 作用：使用前向回声与后向回声的强弱组合来承载 bit 信息。

    % 若未给定帧长，则使用默认值 8192。
    if nargin < 4 || isempty(L),             L = 8192; end
    % 若未给定前向延时，则使用默认值 140。
    if nargin < 5 || isempty(dF),            dF = 140; end
    % 若未给定后向延时，则使用默认值 220。
    if nargin < 6 || isempty(dB),            dB = 220; end
    % 若未给定强回声权重，则使用默认值 0.20。
    if nargin < 7 || isempty(alphaStrong),   alphaStrong = 0.20; end
    % 若未给定弱回声权重，则使用默认值 0.06。
    if nargin < 8 || isempty(alphaWeak),     alphaWeak = 0.06; end
    % 若未给定有效帧筛选比例，则使用默认值 0.25。
    if nargin < 9 || isempty(energyRatio),   energyRatio = 0.25; end
    % 若未给定最小 RMS 门限，则使用默认值 0.01。
    if nargin < 10 || isempty(minRms),       minRms = 0.01; end
    % 检查帧长必须大于前后向延时中的最大值。
    assert(L > max([dF, dB]), '帧长 L 必须大于最大延时。');

    % 读入宿主音频。
    [x, fs] = audioread(inWav);
    % 转为 double。
    x = double(x);

    % 将消息字符串转为 UTF-8 字节数组。
    payloadBytes = unicode2native(message, 'UTF-8');
    % 获取正文长度。
    payloadLenBytes = numel(payloadBytes);
    % 检查长度是否超限。
    assert(payloadLenBytes <= 65535, '消息过长');
    % 构造 16 bit 长度头。
    headerBits = reshape(dec2bin(payloadLenBytes, 16).'-'0', 1, []);
    % 将正文字节转为 bit 流。
    payloadBits = echo_bytes_to_bits_local(payloadBytes);
    % 拼接头部和正文。
    bits = [headerBits, payloadBits];

    % 选择有效帧。
    [activeFrames, ~, thr] = echo_select_active_frames_local(x, L, energyRatio, minRms);
    % 估算最大可嵌入正文长度。
    maxPayloadBytes = floor((numel(activeFrames) - 16) / 8);
    % 检查有效帧数量是否足够。
    assert(numel(bits) <= numel(activeFrames), ...
        '可用有效帧不足：当前音频最多只能嵌入 %d 字节正文。', max(maxPayloadBytes, 0));

    % 初始化输出音频。
    y = x;
    % 选取前若干个有效帧承载比特。
    targetFrames = activeFrames(1:numel(bits));

    % 对每个声道分别做嵌入。
    for ch = 1:size(x, 2)
        % 当前声道信号。
        channel = x(:, ch);
        % 逐比特嵌入。
        for k = 1:numel(bits)
            % 当前比特对应帧编号。
            frameId = targetFrames(k);
            % 当前帧的样本下标范围。
            idx = (frameId-1)*L + (1:L);
            % 当前帧信号。
            frame = channel(idx);

            % 构造前向回声分量：使用过去样本延时得到。
            fwd = [zeros(dF, 1); frame(1:end-dF)];
            % 构造后向回声分量：使用未来样本前移得到。
            bwd = [frame(dB+1:end); zeros(dB, 1)];

            % bit=0 与 bit=1 通过前后向分量的强弱互换来区分。
            if bits(k) == 0
                % bit=0 时前向更强、后向更弱。
                af = alphaStrong; ab = alphaWeak;
            else
                % bit=1 时前向更弱、后向更强。
                af = alphaWeak;   ab = alphaStrong;
            end
            % 叠加前后向回声得到隐写帧。
            stegoFrame = frame + af * fwd + ab * bwd;
            % 写回输出音频。
            y(idx, ch) = stegoFrame;
        end
    end

    % 计算整体峰值。
    peak = max(abs(y(:)));
    % 若峰值超限，则整体归一化。
    if peak > 0.99
        y = 0.99 * y / peak;
    end

    % 写出隐写音频。
    audiowrite(outWav, y, fs);
    % 打印完成信息。
    fprintf('前后向回声核嵌入完成：%s\n', outWav);
    % 打印实验参数。
    fprintf('采样率 = %d Hz, 帧长 = %d, 有效帧数 = %d, 门限 = %.6f, 已嵌入比特数 = %d\n', ...
        fs, L, numel(activeFrames), thr, numel(bits));
end

function bits = echo_bytes_to_bits_local(bytes)
% echo_bytes_to_bits_local
% 将字节数组展开为 0/1 比特行向量。

    % 若无字节输入，则返回空比特序列。
    if isempty(bytes)
        bits = [];
        return;
    end
    % 统一整理为 uint8 列向量。
    bytes = uint8(bytes(:));
    % 转成 8 位二进制字符矩阵。
    bitChars = dec2bin(bytes, 8);
    % 展开为数值比特行向量。
    bits = reshape((bitChars.' - '0'), 1, []);
end

function [activeFrames, frameRms, threshold] = echo_select_active_frames_local(x, L, energyRatio, minRms)
% echo_select_active_frames_local
% 根据帧 RMS 选择有效帧。

    % 默认能量比例。
    if nargin < 3 || isempty(energyRatio), energyRatio = 0.25; end
    % 默认最小 RMS。
    if nargin < 4 || isempty(minRms),      minRms = 0.01; end

    % 多声道时先平均为单声道。
    if size(x, 2) > 1
        xMono = mean(double(x), 2);
    else
        % 单声道直接转 double。
        xMono = double(x);
    end

    % 计算可完整分帧的帧数。
    nFrames = floor(length(xMono) / L);
    % 若无完整帧，则返回空。
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
    % 返回满足门限的帧编号。
    activeFrames = find(frameRms >= threshold);
end
