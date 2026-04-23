function message = multi_echo_extract(stegoWav, L, D0, D1, W, guard, energyRatio, minRms)
    % multi_echo_extract
    % 多回声核提取函数。
    % 作用：在多个候选延时位置累计倒谱得分，并判决每一帧对应的比特值。

    % 若未给定帧长，则使用默认值 8192。
    if nargin < 2 || isempty(L),           L = 8192; end
    % 若未给定 bit=0 的延时集合，则使用默认值。
    if nargin < 3 || isempty(D0),          D0 = [110 180 260]; end
    % 若未给定 bit=1 的延时集合，则使用默认值。
    if nargin < 4 || isempty(D1),          D1 = [140 210 290]; end
    % 若未给定提取权重，则使用默认值。
    if nargin < 5 || isempty(W),           W = [0.22 0.15 0.10]; end
    % 若未给定邻域保护宽度，则使用默认值 2。
    if nargin < 6 || isempty(guard),       guard = 2; end
    % 若未给定有效帧筛选比例，则使用默认值 0.25。
    if nargin < 7 || isempty(energyRatio), energyRatio = 0.25; end
    % 若未给定最小 RMS 门限，则使用默认值 0.01。
    if nargin < 8 || isempty(minRms),      minRms = 0.01; end
    % 检查两组延时集合与权重长度是否一致。
    assert(numel(D0) == numel(D1) && numel(D0) == numel(W), 'D0、D1、W 长度必须一致。');
    % 检查帧长必须大于所有延时中的最大值。
    assert(L > max([D0(:); D1(:)]), '帧长 L 必须大于最大延时。');

    % 读入隐写音频。
    [y, ~] = audioread(stegoWav);
    % 转为 double。
    y = double(y);
    % 多声道时先取均值得到单声道检测信号。
    if size(y, 2) > 1
        yMono = mean(y, 2);
    else
        % 单声道时直接使用。
        yMono = y;
    end

    % 选出有效帧。
    [activeFrames, ~, thr] = echo_select_active_frames_local(yMono, L, energyRatio, minRms);
    % 至少要能读取 16 bit 头部。
    if numel(activeFrames) < 16
        error('有效帧不足，无法读取 16 bit 头。');
    end

    % 预分配比特向量。
    bits = zeros(1, numel(activeFrames));
    % 生成 Hann 窗。
    w = echo_hann_window_local(L);

    % 逐有效帧提取。
    for k = 1:numel(activeFrames)
        % 当前帧编号。
        frameId = activeFrames(k);
        % 当前帧的样本下标范围。
        idx = (frameId-1)*L + (1:L);
        % 取出当前帧并加窗。
        frame = yMono(idx) .* w;
        % 计算实倒谱。
        c = real(ifft(log(abs(fft(frame)) + eps)));

        % 初始化 bit=0 的综合得分。
        score0 = 0;
        % 初始化 bit=1 的综合得分。
        score1 = 0;
        % 对每个候选延时位置累加加权得分。
        for j = 1:numel(W)
            % 累加 bit=0 对应延时集合的得分。
            score0 = score0 + W(j) * neighborhood_mean_abs(c, D0(j), guard);
            % 累加 bit=1 对应延时集合的得分。
            score1 = score1 + W(j) * neighborhood_mean_abs(c, D1(j), guard);
        end
        % 谁的综合得分更大，就判为对应的 bit。
        bits(k) = score1 > score0;
    end

    % 前 16 bit 是正文长度头部。
    headerBits = bits(1:16);
    % 把头部还原为正文长度（字节）。
    payloadLenBytes = bin2dec(char(headerBits + '0'));
    % 计算提取完整消息所需的总比特数。
    needBits = 16 + payloadLenBytes * 8;
    % 若有效帧数不够，则认为头部错误或载荷不完整。
    if numel(bits) < needBits
        error('可提取比特不足：有效帧数不够或头部检测错误。');
    end

    % 截取正文对应的比特序列。
    payloadBits = bits(17:needBits);
    % 将正文 bit 流还原为字节数组。
    payloadBytes = echo_bits_to_bytes_local(payloadBits);
    % 将 UTF-8 字节流转回字符串。
    message = native2unicode(payloadBytes, 'UTF-8');
    % 输出提取完成提示。
    fprintf('多回声核提取完成，消息长度 = %d 字节\n', payloadLenBytes);
    % 输出有效帧和门限信息。
    fprintf('有效帧数 = %d, 门限 = %.6f\n', numel(activeFrames), thr);
    % 输出提取到的消息。
    fprintf('提取消息：%s\n', message);
end

function val = neighborhood_mean_abs(c, d, guard)
% neighborhood_mean_abs
% 在倒谱指定延时附近取局部平均绝对值作为检测强度。

    % 计算邻域左边界。
    left = max(1, d + 1 - guard);
    % 计算邻域右边界。
    right = min(length(c), d + 1 + guard);
    % 计算邻域内实部绝对值均值。
    val = mean(abs(real(c(left:right))));
end

function bytes = echo_bits_to_bytes_local(bits)
% echo_bits_to_bytes_local
% 将比特序列恢复为 uint8 字节流。

    % 确保比特总数是 8 的整数倍。
    assert(mod(numel(bits), 8) == 0, '比特数必须为 8 的整数倍。');
    % 每 8 bit 重排为一行。
    bitMat = reshape(bits, 8, []).';
    % 将二进制字符串转为十进制字节并转为 uint8。
    bytes = uint8(bin2dec(char(bitMat + '0')));
end

function w = echo_hann_window_local(L)
% echo_hann_window_local
% 生成周期型 Hann 窗。

    % 构造样本索引列向量。
    n = (0:L-1).';
    % 按 Hann 公式生成窗函数。
    w = 0.5 - 0.5 * cos(2*pi*n/L);
end

function [activeFrames, frameRms, threshold] = echo_select_active_frames_local(x, L, energyRatio, minRms)
% echo_select_active_frames_local
% 基于帧 RMS 选择有效帧。

    % 设置默认能量比例。
    if nargin < 3 || isempty(energyRatio), energyRatio = 0.25; end
    % 设置默认最小 RMS 门限。
    if nargin < 4 || isempty(minRms),      minRms = 0.01; end

    % 若为多声道，则先取均值转单声道。
    if size(x, 2) > 1
        xMono = mean(double(x), 2);
    else
        % 单声道时直接转 double。
        xMono = double(x);
    end

    % 计算完整帧数。
    nFrames = floor(length(xMono) / L);
    % 若不存在完整帧，则返回空结果。
    if nFrames <= 0
        activeFrames = [];
        frameRms = [];
        threshold = minRms;
        return;
    end

    % 截去尾部不足一帧的部分。
    xMono = xMono(1:nFrames * L);
    % 整理为帧矩阵。
    frameMat = reshape(xMono, L, nFrames).';
    % 计算各帧 RMS。
    frameRms = sqrt(mean(frameMat.^2, 2));
    % 计算判决门限。
    threshold = max(minRms, median(frameRms) * energyRatio);
    % 选出满足门限的帧编号。
    activeFrames = find(frameRms >= threshold);
end
