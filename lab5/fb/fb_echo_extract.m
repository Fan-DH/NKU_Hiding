function message = fb_echo_extract(stegoWav, L, dF, dB, guard, energyRatio, minRms)
    % fb_echo_extract
    % 前后向回声核提取函数。
    % 作用：比较前向与后向回声位置的倒谱强度，恢复每一帧的 bit 值。

    % 若未给定帧长，则使用默认值 8192。
    if nargin < 2 || isempty(L),           L = 8192; end
    % 若未给定前向延时，则使用默认值 140。
    if nargin < 3 || isempty(dF),          dF = 140; end
    % 若未给定后向延时，则使用默认值 220。
    if nargin < 4 || isempty(dB),          dB = 220; end
    % 若未给定邻域保护宽度，则使用默认值 2。
    if nargin < 5 || isempty(guard),       guard = 2; end
    % 若未给定有效帧筛选比例，则使用默认值 0.25。
    if nargin < 6 || isempty(energyRatio), energyRatio = 0.25; end
    % 若未给定最小 RMS 门限，则使用默认值 0.01。
    if nargin < 7 || isempty(minRms),      minRms = 0.01; end
    % 检查帧长必须大于最大延时。
    assert(L > max([dF, dB]), '帧长 L 必须大于最大延时。');

    % 读入隐写音频。
    [y, ~] = audioread(stegoWav);
    % 转为 double。
    y = double(y);
    % 多声道时先均值化为单声道。
    if size(y, 2) > 1
        yMono = mean(y, 2);
    else
        % 单声道时直接使用。
        yMono = y;
    end

    % 选择有效帧。
    [activeFrames, ~, thr] = echo_select_active_frames_local(yMono, L, energyRatio, minRms);
    % 至少要能读取 16 bit 头部。
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
        % 当前帧乘窗。
        frame = yMono(idx) .* w;
        % 计算实倒谱。
        c = real(ifft(log(abs(fft(frame)) + eps)));
        % 估计前向回声位置的局部强度。
        sF = neighborhood_mean_abs(c, dF, guard);
        % 估计后向回声位置的局部强度。
        sB = neighborhood_mean_abs(c, dB, guard);
        % 若后向强于前向，则判为 bit=1。
        bits(k) = sB > sF;
    end

    % 头部前 16 bit 表示正文长度。
    headerBits = bits(1:16);
    % 将头部解码为正文字节数。
    payloadLenBytes = bin2dec(char(headerBits + '0'));
    % 计算完整消息所需比特数。
    needBits = 16 + payloadLenBytes * 8;
    % 若比特数不足，则报错。
    if numel(bits) < needBits
        error('可提取比特不足：有效帧数不够或头部检测错误。');
    end

    % 截取正文比特序列。
    payloadBits = bits(17:needBits);
    % 还原为正文字节数组。
    payloadBytes = echo_bits_to_bytes_local(payloadBits);
    % 解码为 UTF-8 字符串。
    message = native2unicode(payloadBytes, 'UTF-8');
    % 打印完成信息。
    fprintf('前后向回声核提取完成，消息长度 = %d 字节\n', payloadLenBytes);
    % 打印有效帧和门限信息。
    fprintf('有效帧数 = %d, 门限 = %.6f\n', numel(activeFrames), thr);
    % 打印提取到的消息。
    fprintf('提取消息：%s\n', message);
end

function val = neighborhood_mean_abs(c, d, guard)
% neighborhood_mean_abs
% 在倒谱指定延时附近取实部绝对值平均。

    % 计算邻域左边界。
    left = max(1, d + 1 - guard);
    % 计算邻域右边界。
    right = min(length(c), d + 1 + guard);
    % 计算邻域平均强度。
    val = mean(abs(real(c(left:right))));
end

function bytes = echo_bits_to_bytes_local(bits)
% echo_bits_to_bytes_local
% 将比特序列恢复为 uint8 字节流。

    % 检查 bit 数必须是 8 的整数倍。
    assert(mod(numel(bits), 8) == 0, '比特数必须为 8 的整数倍。');
    % 按字节重排。
    bitMat = reshape(bits, 8, []).';
    % 还原为 uint8 字节数组。
    bytes = uint8(bin2dec(char(bitMat + '0')));
end

function w = echo_hann_window_local(L)
% echo_hann_window_local
% 生成周期型 Hann 窗。

    % 构造样本索引向量。
    n = (0:L-1).';
    % 按 Hann 公式生成窗函数。
    w = 0.5 - 0.5 * cos(2*pi*n/L);
end

function [activeFrames, frameRms, threshold] = echo_select_active_frames_local(x, L, energyRatio, minRms)
% echo_select_active_frames_local
% 基于帧 RMS 选择有效帧。

    % 默认能量比例。
    if nargin < 3 || isempty(energyRatio), energyRatio = 0.25; end
    % 默认最小 RMS 门限。
    if nargin < 4 || isempty(minRms),      minRms = 0.01; end

    % 多声道时先取均值。
    if size(x, 2) > 1
        xMono = mean(double(x), 2);
    else
        % 单声道时直接转 double。
        xMono = double(x);
    end

    % 计算完整帧数。
    nFrames = floor(length(xMono) / L);
    % 若无完整帧，则直接返回空结果。
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
    % 计算每帧 RMS。
    frameRms = sqrt(mean(frameMat.^2, 2));
    % 计算门限。
    threshold = max(minRms, median(frameRms) * energyRatio);
    % 选出有效帧编号。
    activeFrames = find(frameRms >= threshold);
end
