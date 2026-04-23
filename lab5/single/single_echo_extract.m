function message = single_echo_extract(stegoWav, L, d0, d1, guard, energyRatio, minRms)
    % single_echo_extract
    % 单回声核提取函数。
    % 作用：从隐写音频中逐帧检测倒谱峰值，恢复消息头和正文。

    % 如果未给定帧长，则使用默认值 8192。
    if nargin < 2 || isempty(L),           L = 8192; end
    % 如果未给定 bit=0 的延时，则使用默认值 120。
    if nargin < 3 || isempty(d0),          d0 = 120; end
    % 如果未给定 bit=1 的延时，则使用默认值 180。
    if nargin < 4 || isempty(d1),          d1 = 180; end
    % 如果未给定邻域保护宽度，则使用默认值 2。
    if nargin < 5 || isempty(guard),       guard = 2; end
    % 如果未给定有效帧筛选比例，则使用默认值 0.25。
    if nargin < 6 || isempty(energyRatio), energyRatio = 0.25; end
    % 如果未给定最小 RMS 门限，则使用默认值 0.01。
    if nargin < 7 || isempty(minRms),      minRms = 0.01; end
    % 检查帧长必须大于最大延时。
    assert(L > max([d0, d1]), '帧长 L 必须大于最大延时。');

    % 读入隐写音频。
    [y, ~] = audioread(stegoWav);
    % 转为 double，便于后续频域与倒谱运算。
    y = double(y);
    % 若为多声道音频，则先做均值得到单声道检测信号。
    if size(y, 2) > 1
        yMono = mean(y, 2);
    else
        % 若本来就是单声道，则直接使用。
        yMono = y;
    end

    % 根据帧 RMS 选择有效帧，提取时只在有效帧上判决比特。
    [activeFrames, ~, thr] = echo_select_active_frames_local(yMono, L, energyRatio, minRms);
    % 至少需要 16 个有效帧来读取长度头。
    if numel(activeFrames) < 16
        error('有效帧不足，无法读取 16 bit 头。');
    end

    % 预分配比特数组，长度等于有效帧数。
    bits = zeros(1, numel(activeFrames));
    % 生成 Hann 窗，减轻分帧边界泄漏对倒谱的影响。
    w = echo_hann_window_local(L);

    % 逐个有效帧进行倒谱分析。
    for k = 1:numel(activeFrames)
        % 取出当前有效帧编号。
        frameId = activeFrames(k);
        % 计算该帧对应的样本下标范围。
        idx = (frameId-1)*L + (1:L);
        % 当前帧乘以 Hann 窗。
        frame = yMono(idx) .* w;
        % 计算实倒谱：先做 FFT，再取对数幅度谱，最后 IFFT。
        c = real(ifft(log(abs(fft(frame)) + eps)));
        % 在 d0 附近求邻域平均幅值，作为 bit=0 的得分。
        s0 = neighborhood_mean_abs(c, d0, guard);
        % 在 d1 附近求邻域平均幅值，作为 bit=1 的得分。
        s1 = neighborhood_mean_abs(c, d1, guard);
        % 若 d1 得分更大，则判为 1，否则判为 0。
        bits(k) = s1 > s0;
    end

    % 头部前 16 bit 表示正文的字节长度。
    headerBits = bits(1:16);
    % 把 16 bit 头部还原为字节长度。
    payloadLenBytes = bin2dec(char(headerBits + '0'));
    % 根据头部长度，计算总共需要的比特数。
    needBits = 16 + payloadLenBytes * 8;
    % 若有效帧数量不足以覆盖全部正文，则报错。
    if numel(bits) < needBits
        error('可提取比特不足：有效帧数不够或头部检测错误。');
    end

    % 取出正文部分的比特序列。
    payloadBits = bits(17:needBits);
    % 将正文比特按字节还原。
    payloadBytes = echo_bits_to_bytes_local(payloadBits);
    % 将 UTF-8 字节流解码为字符串消息。
    message = native2unicode(payloadBytes, 'UTF-8');
    % 打印提取完成提示。
    fprintf('单回声核提取完成，消息长度 = %d 字节\n', payloadLenBytes);
    % 打印提取阶段的有效帧和门限信息。
    fprintf('有效帧数 = %d, 门限 = %.6f\n', numel(activeFrames), thr);
    % 打印提取到的消息内容。
    fprintf('提取消息：%s\n', message);
end

function val = neighborhood_mean_abs(c, d, guard)
% neighborhood_mean_abs
% 在指定倒谱延时附近取一个小邻域，并计算实部绝对值平均。

    % 计算左边界，并防止越界到 1 之前。
    left = max(1, d + 1 - guard);
    % 计算右边界，并防止越界到向量末尾之后。
    right = min(length(c), d + 1 + guard);
    % 取邻域样本的实部绝对值平均，作为该延时位置的强度估计。
    val = mean(abs(real(c(left:right))));
end

function bytes = echo_bits_to_bytes_local(bits)
% echo_bits_to_bytes_local
% 将 0/1 比特行向量恢复为 uint8 字节数组。

    % 检查比特总数必须是 8 的整数倍。
    assert(mod(numel(bits), 8) == 0, '比特数必须为 8 的整数倍。');
    % 将比特流重排成“每行 8 bit”的矩阵。
    bitMat = reshape(bits, 8, []).';
    % 将每行二进制字符转回十进制字节，并转为 uint8。
    bytes = uint8(bin2dec(char(bitMat + '0')));
end

function w = echo_hann_window_local(L)
% echo_hann_window_local
% 生成不依赖工具箱的周期型 Hann 窗。

    % 构造 0 到 L-1 的列向量索引。
    n = (0:L-1).';
    % 根据 Hann 窗公式逐点生成窗函数。
    w = 0.5 - 0.5 * cos(2*pi*n/L);
end

function [activeFrames, frameRms, threshold] = echo_select_active_frames_local(x, L, energyRatio, minRms)
% echo_select_active_frames_local
% 基于帧 RMS 选择高能量帧，用于避开静音或极弱片段。

    % 若未给定能量比例，则使用默认值 0.25。
    if nargin < 3 || isempty(energyRatio), energyRatio = 0.25; end
    % 若未给定最小 RMS 门限，则使用默认值 0.01。
    if nargin < 4 || isempty(minRms),      minRms = 0.01; end

    % 若输入是多声道音频，则先平均为单声道。
    if size(x, 2) > 1
        xMono = mean(double(x), 2);
    else
        % 若输入本身就是单声道，则直接转为 double。
        xMono = double(x);
    end

    % 计算能够完整分出的帧数。
    nFrames = floor(length(xMono) / L);
    % 若没有完整帧，则返回空结果。
    if nFrames <= 0
        activeFrames = [];
        frameRms = [];
        threshold = minRms;
        return;
    end

    % 截去最后不足一帧的样本。
    xMono = xMono(1:nFrames * L);
    % 重排为帧矩阵，每行对应一帧。
    frameMat = reshape(xMono, L, nFrames).';
    % 计算每帧 RMS。
    frameRms = sqrt(mean(frameMat.^2, 2));
    % 根据经验比例设置门限，但不低于 minRms。
    threshold = max(minRms, median(frameRms) * energyRatio);
    % 选出所有有效帧的编号。
    activeFrames = find(frameRms >= threshold);
end
