function message = bipolar_echo_extract(stegoWav, L, d0, d1, guard, energyRatio, minRms)
    % bipolar_echo_extract
    % 双极性回声核提取函数。
    % 作用：利用倒谱在两个延时位置的符号强弱差异恢复比特序列。

    % 若未给定帧长，则使用默认值 8192。
    if nargin < 2 || isempty(L),           L = 8192; end
    % 若未给定第一个延时，则使用默认值 120。
    if nargin < 3 || isempty(d0),          d0 = 120; end
    % 若未给定第二个延时，则使用默认值 200。
    if nargin < 4 || isempty(d1),          d1 = 200; end
    % 若未给定邻域保护宽度，则使用默认值 2。
    if nargin < 5 || isempty(guard),       guard = 2; end
    % 若未给定有效帧筛选比例，则使用默认值 0.25。
    if nargin < 6 || isempty(energyRatio), energyRatio = 0.25; end
    % 若未给定最小 RMS 门限，则使用默认值 0.01。
    if nargin < 7 || isempty(minRms),      minRms = 0.01; end
    % 检查帧长必须大于最大延时。
    assert(L > max([d0, d1]), '帧长 L 必须大于最大延时。');

    % 读入隐写音频。
    [y, ~] = audioread(stegoWav);
    % 转为 double。
    y = double(y);
    % 多声道时先平均为单声道检测信号。
    if size(y, 2) > 1
        yMono = mean(y, 2);
    else
        % 单声道时直接使用。
        yMono = y;
    end

    % 选择有效帧。
    [activeFrames, ~, thr] = echo_select_active_frames_local(yMono, L, energyRatio, minRms);
    % 至少要有 16 个有效帧才能读取头部。
    if numel(activeFrames) < 16
        error('有效帧不足，无法读取 16 bit 头。');
    end

    % 预分配比特数组。
    bits = zeros(1, numel(activeFrames));
    % 生成 Hann 窗。
    w = echo_hann_window_local(L);

    % 逐帧提取。
    for k = 1:numel(activeFrames)
        % 当前帧编号。
        frameId = activeFrames(k);
        % 当前帧下标范围。
        idx = (frameId-1)*L + (1:L);
        % 取出帧并加窗。
        frame = yMono(idx) .* w;
        % 计算实倒谱。
        c = real(ifft(log(abs(fft(frame)) + eps)));
        % 计算 d0 附近带符号邻域均值。
        v0 = neighborhood_mean_signed(c, d0, guard);
        % 计算 d1 附近带符号邻域均值。
        v1 = neighborhood_mean_signed(c, d1, guard);
        % 若 v1-v0 大于 0，则判为 bit=1，否则判为 bit=0。
        bits(k) = (v1 - v0) > 0;
    end

    % 前 16 bit 为正文长度头。
    headerBits = bits(1:16);
    % 把头部解码为正文长度（字节）。
    payloadLenBytes = bin2dec(char(headerBits + '0'));
    % 计算完整消息所需总比特数。
    needBits = 16 + payloadLenBytes * 8;
    % 若有效帧数不足，则报错。
    if numel(bits) < needBits
        error('可提取比特不足：有效帧数不够或头部检测错误。');
    end

    % 截取正文比特。
    payloadBits = bits(17:needBits);
    % 将正文比特还原为字节流。
    payloadBytes = echo_bits_to_bytes_local(payloadBits);
    % 将 UTF-8 字节流解码为字符串。
    message = native2unicode(payloadBytes, 'UTF-8');
    % 打印提取完成信息。
    fprintf('双极性回声核提取完成，消息长度 = %d 字节\n', payloadLenBytes);
    % 打印有效帧和门限信息。
    fprintf('有效帧数 = %d, 门限 = %.6f\n', numel(activeFrames), thr);
    % 打印提取消息。
    fprintf('提取消息：%s\n', message);
end

function val = neighborhood_mean_signed(c, d, guard)
% neighborhood_mean_signed
% 在倒谱指定延时附近取带符号实部均值，用于双极性判决。

    % 计算左边界。
    left = max(1, d + 1 - guard);
    % 计算右边界。
    right = min(length(c), d + 1 + guard);
    % 计算邻域内实部平均值，保留正负符号信息。
    val = mean(real(c(left:right)));
end

function bytes = echo_bits_to_bytes_local(bits)
% echo_bits_to_bytes_local
% 将 0/1 比特流恢复为 uint8 字节数组。

    % 检查 bit 数必须是 8 的整数倍。
    assert(mod(numel(bits), 8) == 0, '比特数必须为 8 的整数倍。');
    % 重排成每行 8 bit 的矩阵。
    bitMat = reshape(bits, 8, []).';
    % 还原为十进制字节并转为 uint8。
    bytes = uint8(bin2dec(char(bitMat + '0')));
end

function w = echo_hann_window_local(L)
% echo_hann_window_local
% 生成周期型 Hann 窗。

    % 构造样本索引。
    n = (0:L-1).';
    % 根据公式生成 Hann 窗。
    w = 0.5 - 0.5 * cos(2*pi*n/L);
end

function [activeFrames, frameRms, threshold] = echo_select_active_frames_local(x, L, energyRatio, minRms)
% echo_select_active_frames_local
% 基于帧 RMS 选择有效帧。

    % 设置默认能量比例。
    if nargin < 3 || isempty(energyRatio), energyRatio = 0.25; end
    % 设置默认最小 RMS。
    if nargin < 4 || isempty(minRms),      minRms = 0.01; end

    % 多声道先求均值。
    if size(x, 2) > 1
        xMono = mean(double(x), 2);
    else
        % 单声道直接转 double。
        xMono = double(x);
    end

    % 计算完整帧数。
    nFrames = floor(length(xMono) / L);
    % 若帧数不足，则返回空。
    if nFrames <= 0
        activeFrames = [];
        frameRms = [];
        threshold = minRms;
        return;
    end

    % 截成整帧长度。
    xMono = xMono(1:nFrames * L);
    % 整理为帧矩阵。
    frameMat = reshape(xMono, L, nFrames).';
    % 计算逐帧 RMS。
    frameRms = sqrt(mean(frameMat.^2, 2));
    % 计算门限。
    threshold = max(minRms, median(frameRms) * energyRatio);
    % 取出有效帧编号。
    activeFrames = find(frameRms >= threshold);
end
