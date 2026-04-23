function single_echo_embed(inWav, outWav, message, L, d0, d1, alpha, energyRatio, minRms)
    % single_echo_embed
    % 单回声核嵌入函数。
    % 作用：把字符串消息按 bit 映射到不同延时的单回声核中，并写出隐写音频。

    % 如果未给定帧长，则使用默认值 8192。
    if nargin < 4 || isempty(L),           L = 8192;  end
    % 如果未给定比特 0 的延时，则使用默认值 120。
    if nargin < 5 || isempty(d0),          d0 = 120;  end
    % 如果未给定比特 1 的延时，则使用默认值 180。
    if nargin < 6 || isempty(d1),          d1 = 180;  end
    % 如果未给定回声强度，则使用默认值 0.25。
    if nargin < 7 || isempty(alpha),       alpha = 0.25; end
    % 如果未给定有效帧筛选比例，则使用默认值 0.25。
    if nargin < 8 || isempty(energyRatio), energyRatio = 0.25; end
    % 如果未给定最小 RMS 门限，则使用默认值 0.01。
    if nargin < 9 || isempty(minRms),      minRms = 0.01; end
    % 检查帧长必须大于两种延时中的最大值。
    assert(L > max([d0, d1]), '帧长 L 必须大于最大延时。');

    % 读入宿主音频与采样率。
    [x, fs] = audioread(inWav);
    % 将音频转换为 double，便于后续数值运算。
    x = double(x);

    % 将待嵌入字符串转为 UTF-8 字节流。
    payloadBytes = unicode2native(message, 'UTF-8');
    % 计算消息字节长度。
    payloadLenBytes = numel(payloadBytes);
    % 约束消息长度不超过 65535 字节，因为头部只保留 16 bit 长度字段。
    assert(payloadLenBytes <= 65535, '消息过长');
    % 将消息字节长度编码为 16 bit 头部比特。
    headerBits = reshape(dec2bin(payloadLenBytes, 16).'-'0', 1, []);
    % 将正文的字节流展开为 0/1 比特序列。
    payloadBits = echo_bytes_to_bits_local(payloadBytes);
    % 将头部与正文拼接为完整载荷比特流。
    bits = [headerBits, payloadBits];

    % 依据帧能量选择适合嵌入的有效帧。
    [activeFrames, ~, thr] = echo_select_active_frames_local(x, L, energyRatio, minRms);
    % 根据有效帧数估算当前音频最多可承载的正文长度（单位：字节）。
    maxPayloadBytes = floor((numel(activeFrames) - 16) / 8);
    % 检查有效帧数是否足以嵌入头部和正文。
    assert(numel(bits) <= numel(activeFrames), ...
        '可用有效帧不足：当前音频最多只能嵌入 %d 字节正文。', max(maxPayloadBytes, 0));

    % 先把输出初始化为原始音频。
    y = x;
    % 仅取前 numel(bits) 个有效帧作为嵌入目标帧。
    targetFrames = activeFrames(1:numel(bits));

    % 逐声道处理，保证多声道音频的每个声道都嵌入相同信息。
    for ch = 1:size(x, 2)
        % 取出当前声道。
        channel = x(:, ch);
        % 逐比特嵌入。
        for k = 1:numel(bits)
            % 取出当前比特对应的目标帧编号。
            frameId = targetFrames(k);
            % 计算当前帧在整段音频中的样本下标范围。
            idx = (frameId-1)*L + (1:L);
            % 取出当前帧信号。
            frame = channel(idx);
            % 根据当前 bit 决定采用哪一个回声延时。
            if bits(k) == 0
                % bit=0 时使用 d0。
                d = d0;
            else
                % bit=1 时使用 d1。
                d = d1;
            end
            % 生成延时信号，前面补零，后面截断。
            delayed = [zeros(d, 1); frame(1:end-d)];
            % 将延时副本按强度 alpha 叠加到原帧上，形成隐写帧。
            stegoFrame = frame + alpha * delayed;
            % 把隐写帧写回输出音频。
            y(idx, ch) = stegoFrame;
        end
    end

    % 计算输出音频峰值，检查是否可能削波。
    peak = max(abs(y(:)));
    % 若峰值过大，则整体缩放到 0.99 以内。
    if peak > 0.99
        y = 0.99 * y / peak;
    end

    % 将隐写后的音频写出到目标文件。
    audiowrite(outWav, y, fs);
    % 打印嵌入完成提示。
    fprintf('单回声核嵌入完成：%s\n', outWav);
    % 打印本次实验的关键参数与统计信息。
    fprintf('采样率 = %d Hz, 帧长 = %d, 有效帧数 = %d, 门限 = %.6f, 已嵌入比特数 = %d\n', ...
        fs, L, numel(activeFrames), thr, numel(bits));
end

function bits = echo_bytes_to_bits_local(bytes)
% echo_bytes_to_bits_local
% 将 uint8 字节数组展开为 0/1 比特行向量，高位在前。

    % 若输入为空，则直接返回空比特序列。
    if isempty(bytes)
        bits = [];
        return;
    end
    % 强制整理为 uint8 列向量，避免输入类型不一致。
    bytes = uint8(bytes(:));
    % 把每个字节转成 8 位二进制字符矩阵。
    bitChars = dec2bin(bytes, 8);
    % 按列展开，并将字符 '0'/'1' 转为数值 0/1。
    bits = reshape((bitChars.' - '0'), 1, []);
end

function [activeFrames, frameRms, threshold] = echo_select_active_frames_local(x, L, energyRatio, minRms)
% echo_select_active_frames_local
% 基于帧 RMS 选择高能量帧，用于避开静音或极弱片段。

    % 若未给定能量比例，则使用默认值 0.25。
    if nargin < 3 || isempty(energyRatio), energyRatio = 0.25; end
    % 若未给定最小 RMS 门限，则使用默认值 0.01。
    if nargin < 4 || isempty(minRms),      minRms = 0.01; end

    % 若输入是多声道音频，则先平均为单声道以便统一做能量统计。
    if size(x, 2) > 1
        xMono = mean(double(x), 2);
    else
        % 若本来就是单声道，则直接转为 double。
        xMono = double(x);
    end

    % 只统计能够整帧切分的帧数。
    nFrames = floor(length(xMono) / L);
    % 若整帧数不大于 0，则返回空结果。
    if nFrames <= 0
        activeFrames = [];
        frameRms = [];
        threshold = minRms;
        return;
    end

    % 丢弃末尾不足一帧的部分，保证 reshape 时维度正确。
    xMono = xMono(1:nFrames * L);
    % 把音频重排为“每行一帧”的矩阵。
    frameMat = reshape(xMono, L, nFrames).';
    % 计算每一帧的 RMS 能量。
    frameRms = sqrt(mean(frameMat.^2, 2));
    % 用“中位数 RMS × 比例”和最小门限中的较大者作为判决门限。
    threshold = max(minRms, median(frameRms) * energyRatio);
    % 选出所有 RMS 不低于门限的帧编号。
    activeFrames = find(frameRms >= threshold);
end
