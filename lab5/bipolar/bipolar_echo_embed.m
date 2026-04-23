function bipolar_echo_embed(inWav, outWav, message, L, d0, d1, alpha, energyRatio, minRms)
    % bipolar_echo_embed
    % 双极性回声核嵌入函数。
    % 作用：通过两种相反符号组合的回声对分别表示 bit=0 和 bit=1。

    % 若未给定帧长，则使用默认值 8192。
    if nargin < 4 || isempty(L),           L = 8192; end
    % 若未给定第一个延时，则使用默认值 120。
    if nargin < 5 || isempty(d0),          d0 = 120; end
    % 若未给定第二个延时，则使用默认值 200。
    if nargin < 6 || isempty(d1),          d1 = 200; end
    % 若未给定回声强度，则使用默认值 0.18。
    if nargin < 7 || isempty(alpha),       alpha = 0.18; end
    % 若未给定有效帧筛选比例，则使用默认值 0.25。
    if nargin < 8 || isempty(energyRatio), energyRatio = 0.25; end
    % 若未给定最小 RMS 门限，则使用默认值 0.01。
    if nargin < 9 || isempty(minRms),      minRms = 0.01; end
    % 检查帧长必须大于所有延时中的最大值。
    assert(L > max([d0, d1]), '帧长 L 必须大于最大延时。');

    % 读入宿主音频。
    [x, fs] = audioread(inWav);
    % 转为 double 便于后续计算。
    x = double(x);

    % 将消息转为 UTF-8 字节流。
    payloadBytes = unicode2native(message, 'UTF-8');
    % 统计正文长度。
    payloadLenBytes = numel(payloadBytes);
    % 检查消息长度是否超出 16 bit 头部可表达的范围。
    assert(payloadLenBytes <= 65535, '消息过长');
    % 编码 16 bit 长度头。
    headerBits = reshape(dec2bin(payloadLenBytes, 16).'-'0', 1, []);
    % 将正文转换为比特流。
    payloadBits = echo_bytes_to_bits_local(payloadBytes);
    % 拼接头部和正文。
    bits = [headerBits, payloadBits];

    % 选择有效帧。
    [activeFrames, ~, thr] = echo_select_active_frames_local(x, L, energyRatio, minRms);
    % 估算可容纳的最大正文长度。
    maxPayloadBytes = floor((numel(activeFrames) - 16) / 8);
    % 检查有效帧数是否足够。
    assert(numel(bits) <= numel(activeFrames), ...
        '可用有效帧不足：当前音频最多只能嵌入 %d 字节正文。', max(maxPayloadBytes, 0));

    % 初始化输出音频。
    y = x;
    % 选取前若干个有效帧作为嵌入目标。
    targetFrames = activeFrames(1:numel(bits));

    % 逐声道处理。
    for ch = 1:size(x, 2)
        % 取出当前声道。
        channel = x(:, ch);
        % 逐比特嵌入。
        for k = 1:numel(bits)
            % 当前目标帧编号。
            frameId = targetFrames(k);
            % 当前帧的样本区间。
            idx = (frameId-1)*L + (1:L);
            % 取出当前帧。
            frame = channel(idx);

            % 构造第一个延时回声分量。
            delay0 = [zeros(d0, 1); frame(1:end-d0)];
            % 构造第二个延时回声分量。
            delay1 = [zeros(d1, 1); frame(1:end-d1)];

            % bit=0 和 bit=1 使用相反极性的线性组合。
            if bits(k) == 0
                % bit=0 时强化 d0，抑制 d1。
                stegoFrame = frame + alpha * delay0 - alpha * delay1;
            else
                % bit=1 时强化 d1，抑制 d0。
                stegoFrame = frame - alpha * delay0 + alpha * delay1;
            end
            % 将隐写帧写回输出音频。
            y(idx, ch) = stegoFrame;
        end
    end

    % 计算峰值，检查是否会削波。
    peak = max(abs(y(:)));
    % 如有必要则整体缩放。
    if peak > 0.99
        y = 0.99 * y / peak;
    end

    % 写出隐写音频。
    audiowrite(outWav, y, fs);
    % 打印完成信息。
    fprintf('双极性回声核嵌入完成：%s\n', outWav);
    % 打印关键实验参数。
    fprintf('采样率 = %d Hz, 帧长 = %d, 有效帧数 = %d, 门限 = %.6f, 已嵌入比特数 = %d\n', ...
        fs, L, numel(activeFrames), thr, numel(bits));
end

function bits = echo_bytes_to_bits_local(bytes)
% echo_bytes_to_bits_local
% 将 uint8 字节流展开为高位在前的比特序列。

    % 若输入为空，则直接返回空向量。
    if isempty(bytes)
        bits = [];
        return;
    end
    % 统一整理为 uint8 列向量。
    bytes = uint8(bytes(:));
    % 将字节转成 8 位二进制字符矩阵。
    bitChars = dec2bin(bytes, 8);
    % 展开为 0/1 比特行向量。
    bits = reshape((bitChars.' - '0'), 1, []);
end

function [activeFrames, frameRms, threshold] = echo_select_active_frames_local(x, L, energyRatio, minRms)
% echo_select_active_frames_local
% 按帧 RMS 选出高能量帧。

    % 设置默认能量比例。
    if nargin < 3 || isempty(energyRatio), energyRatio = 0.25; end
    % 设置默认最小 RMS 门限。
    if nargin < 4 || isempty(minRms),      minRms = 0.01; end

    % 多声道先平均成单声道。
    if size(x, 2) > 1
        xMono = mean(double(x), 2);
    else
        % 单声道直接转为 double。
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

    % 去掉不足一帧的尾部样本。
    xMono = xMono(1:nFrames * L);
    % 组织为每行一帧的矩阵。
    frameMat = reshape(xMono, L, nFrames).';
    % 计算每帧 RMS。
    frameRms = sqrt(mean(frameMat.^2, 2));
    % 得到最终门限。
    threshold = max(minRms, median(frameRms) * energyRatio);
    % 返回所有有效帧的编号。
    activeFrames = find(frameRms >= threshold);
end
