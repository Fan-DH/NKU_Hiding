function results = single_echo_main(inWav, outWav, message, L, d0, d1, alpha, guard)
% SINGLE_ECHO_MAIN 单回声核完整测试函数：嵌入、提取、客观评测、BER 统计。
% 用法示例：
%   results = single_echo_main('sample.wav', 'single_stego.wav', 'HELLO');

    % 如果没有传入原始音频路径，则使用默认测试音频。
    if nargin < 1 || isempty(inWav),   inWav = 'sample.wav';        end
    % 如果没有传入输出音频路径，则使用默认输出文件名。
    if nargin < 2 || isempty(outWav),  outWav = 'single_stego.wav'; end
    % 如果没有传入待嵌入消息，则默认嵌入字符串 HELLO。
    if nargin < 3 || isempty(message), message = 'HELLO';           end
    % 如果没有传入帧长，则默认每帧长度为 8192 个采样点。
    if nargin < 4 || isempty(L),       L = 8192;                    end
    % 如果没有传入 bit=0 时的回声延时，则默认 d0=120。
    if nargin < 5 || isempty(d0),      d0 = 120;                    end
    % 如果没有传入 bit=1 时的回声延时，则默认 d1=180。
    if nargin < 6 || isempty(d1),      d1 = 180;                    end
    % 如果没有传入回声强度系数，则默认 alpha=0.25。
    if nargin < 7 || isempty(alpha),   alpha = 0.25;                end
    % 如果没有传入倒谱邻域保护宽度，则默认 guard=2。
    if nargin < 8 || isempty(guard),   guard = 2;                   end

    % 调用单回声核嵌入函数，生成含密水印音频。
    single_echo_embed(inWav, outWav, message, L, d0, d1, alpha);

    % 尝试从输出音频中提取消息。
    try
        % 调用单回声核提取函数恢复消息文本。
        extractedMessage = single_echo_extract(outWav, L, d0, d1, guard);
        % 如果没有报错，则认为提取成功。
        extractSucceeded = true;
        % 提取成功时，错误信息置为空字符串。
        extractError = '';
    % 如果提取阶段出现异常，则进入异常处理分支。
    catch ME
        % 提取失败时，恢复消息置为空字符串。
        extractedMessage = '';
        % 标记提取失败。
        extractSucceeded = false;
        % 记录 MATLAB 返回的错误信息，便于后续排查。
        extractError = ME.message;
    end

    % 调用客观评测函数，计算 SNR、LSD 并生成误差波形图、声谱图、倒谱图。
    evalResults = echo_evaluate(inWav, outWav, L, [d0 d1], {'d0', 'd1'});

    % 按与嵌入端一致的 UTF-8 规则构造真实比特序列（16 bit 头 + 载荷比特）。
    trueBits = build_true_bits_local(message);
    % 使用与正式提取端一致的有效帧筛选和倒谱判决逻辑，提取固定长度比特用于 BER 统计。
    detectedBits = extract_bits_fixed_local(outWav, numel(trueBits), L, d0, d1, guard);
    % 计算整段比特 BER 和仅正文部分的 BER。
    [berTotal, berPayload] = calc_ber_local(trueBits, detectedBits);

    % 先继承客观评测函数返回的结构体字段。
    results = evalResults;
    % 记录当前测试方案名称。
    results.scheme = 'single_echo';
    % 记录原始嵌入消息。
    results.message = message;
    % 记录提取出的消息。
    results.extractedMessage = extractedMessage;
    % 记录提取是否成功。
    results.extractSucceeded = extractSucceeded;
    % 记录提取失败时的异常信息。
    results.extractError = extractError;
    % 记录总 BER。
    results.berTotal = berTotal;
    % 记录仅正文部分的 BER。
    results.berPayload = berPayload;
    % 记录真实比特序列，便于调试和复现实验。
    results.trueBits = trueBits;
    % 记录检测得到的比特序列，便于调试和复现实验。
    results.detectedBits = detectedBits;
    % 记录 bit=0 对应的延时参数。
    results.d0 = d0;
    % 记录 bit=1 对应的延时参数。
    results.d1 = d1;
    % 记录回声强度系数。
    results.alpha = alpha;
    % 记录倒谱邻域保护宽度。
    results.guard = guard;

    % 在命令行打印测试摘要。
    print_summary_local(results);
end

function bits = build_true_bits_local(message)
% BUILD_TRUE_BITS_LOCAL 按嵌入端规则把字符串转成“头部 + 正文”的真实比特序列。

    % 按 UTF-8 将字符串编码为字节流，保证与嵌入函数保持一致。
    payloadBytes = unicode2native(message, 'UTF-8');
    % 将正文 UTF-8 字节流展开为 0/1 比特序列。
    payloadBits = bytes_to_bits_local(payloadBytes);
    % 计算正文长度（单位：字节）。
    payloadLenBytes = numel(payloadBytes);
    % 用 16 bit 无符号头部记录正文长度。
    headerBits = reshape(dec2bin(payloadLenBytes, 16).' - '0', 1, []);
    % 将头部比特和正文比特拼接成完整真实比特序列。
    bits = [headerBits, payloadBits];
end

function bits = extract_bits_fixed_local(stegoWav, nBits, L, d0, d1, guard)
% EXTRACT_BITS_FIXED_LOCAL 按正式提取端思路，从含密音频中提取前 nBits 个比特用于 BER 计算。

    % 读取含密音频。
    [y, ~] = audioread(stegoWav);
    % 将音频样本转换为 double，便于后续数值运算。
    y = double(y);
    % 如果是多声道音频，则转为单声道以保持与正式提取端一致。
    if size(y, 2) > 1
        % 多声道时对各声道取均值。
        yMono = mean(y, 2);
    else
        % 单声道时直接使用原始列向量。
        yMono = y;
    end

    % 使用与正式提取端一致的有效帧筛选策略选择高能量帧。
    [activeFrames, ~, ~] = select_active_frames_local(yMono, L, 0.25, 0.01);
    % 检查有效帧数量是否足够提取所需比特数。
    assert(nBits <= numel(activeFrames), '需要提取的比特数超过可用有效帧数。');
    % 预分配输出比特向量。
    bits = zeros(1, nBits);
    % 生成与正式提取端一致的周期型 Hann 窗，减轻分帧边界效应。
    w = hann_window_local(L);

    % 逐个提取目标比特。
    for k = 1:nBits
        % 取出第 k 个比特对应的有效帧编号。
        frameId = activeFrames(k);
        % 根据帧编号计算该帧在音频中的样本索引范围。
        idx = (frameId - 1) * L + (1:L);
        % 取出当前音频帧并乘 Hann 窗。
        frame = yMono(idx) .* w;
        % 计算实倒谱，用于检测回声延时峰值。
        c = real(ifft(log(abs(fft(frame)) + eps)));
        % 估计 d0 附近倒谱能量。
        s0 = neighborhood_mean_abs_local(c, d0, guard);
        % 估计 d1 附近倒谱能量。
        s1 = neighborhood_mean_abs_local(c, d1, guard);
        % 若 d1 处强于 d0，则判为 bit=1，否则判为 bit=0。
        bits(k) = s1 > s0;
    end
end

function val = neighborhood_mean_abs_local(c, d, guard)
% NEIGHBORHOOD_MEAN_ABS_LOCAL 计算倒谱在目标延时附近的绝对值均值。

    % 确定左边界，防止索引越界。
    left = max(1, d + 1 - guard);
    % 确定右边界，防止索引越界。
    right = min(length(c), d + 1 + guard);
    % 计算邻域内实倒谱幅值绝对值的平均值。
    val = mean(abs(real(c(left:right))));
end

function bits = bytes_to_bits_local(bytes)
% BYTES_TO_BITS_LOCAL 将 uint8 字节数组展开为按高位在前排列的比特序列。

    % 如果输入字节流为空，则直接返回空比特向量。
    if isempty(bytes)
        bits = [];
        return;
    end
    % 将输入整理为 uint8 列向量，避免类型和形状不一致。
    bytes = uint8(bytes(:));
    % 将每个字节转换为 8 位二进制字符。
    bitChars = dec2bin(bytes, 8);
    % 按列优先方式拉直为一维比特行向量。
    bits = reshape((bitChars.' - '0'), 1, []);
end

function [activeFrames, frameRms, threshold] = select_active_frames_local(x, L, energyRatio, minRms)
% SELECT_ACTIVE_FRAMES_LOCAL 按帧 RMS 选择高能量帧。

    % 如果没有指定能量比例阈值，则使用默认值 0.25。
    if nargin < 3 || isempty(energyRatio), energyRatio = 0.25; end
    % 如果没有指定最小 RMS 门限，则使用默认值 0.01。
    if nargin < 4 || isempty(minRms),      minRms = 0.01; end

    % 如果输入为多声道，则先转单声道。
    if size(x, 2) > 1
        % 多声道时取通道平均。
        xMono = mean(double(x), 2);
    else
        % 单声道时直接转 double。
        xMono = double(x);
    end

    % 计算能够整除帧长的完整帧数量。
    nFrames = floor(length(xMono) / L);
    % 如果不足一帧，则返回空结果。
    if nFrames <= 0
        activeFrames = [];
        frameRms = [];
        threshold = minRms;
        return;
    end

    % 截断到完整帧长度，避免 reshape 失败。
    xMono = xMono(1:nFrames * L);
    % 重排为“每行一帧”的矩阵。
    frameMat = reshape(xMono, L, nFrames).';
    % 计算每一帧的 RMS。
    frameRms = sqrt(mean(frameMat.^2, 2));
    % 取“最小门限”和“中位 RMS 乘比例”中的较大值作为最终门限。
    threshold = max(minRms, median(frameRms) * energyRatio);
    % 选出 RMS 不低于门限的有效帧编号。
    activeFrames = find(frameRms >= threshold);
end

function w = hann_window_local(L)
% HANN_WINDOW_LOCAL 生成不依赖工具箱的周期型 Hann 窗。

    % 生成 0 到 L-1 的列向量下标。
    n = (0:L-1).';
    % 按周期型 Hann 窗公式计算窗函数样值。
    w = 0.5 - 0.5 * cos(2 * pi * n / L);
end

function [berTotal, berPayload] = calc_ber_local(trueBits, detectedBits)
% CALC_BER_LOCAL 计算总 BER 和仅正文比特的 BER。

    % 计算完整比特序列的平均误码率。
    berTotal = mean(trueBits ~= detectedBits);
    % 如果真实比特数超过 16，则说明存在正文部分。
    if numel(trueBits) > 16
        % 仅对正文比特计算 BER，跳过 16 bit 长度头。
        berPayload = mean(trueBits(17:end) ~= detectedBits(17:end));
    else
        % 若只有头部而没有正文，则正文 BER 定义为 0。
        berPayload = 0;
    end
end

function print_summary_local(results)
% PRINT_SUMMARY_LOCAL 在命令行打印当前实验结果摘要。

    % 打印标题分隔线。
    fprintf('\n========== single_echo_main ==========' );
    % 打印输出音频文件路径。
    fprintf('\n输出音频: %s', results.outWav);
    % 打印嵌入消息内容。
    fprintf('\n嵌入消息: %s', results.message);
    % 打印提取是否成功。
    fprintf('\n提取成功: %d', results.extractSucceeded);
    % 如果提取成功，则打印提取消息。
    if results.extractSucceeded
        fprintf('\n提取消息: %s', results.extractedMessage);
    else
        % 如果提取失败，则打印失败原因。
        fprintf('\n提取失败原因: %s', results.extractError);
    end
    % 打印信噪比。
    fprintf('\nSNR = %.4f dB', results.snrDB);
    % 打印对数谱失真。
    fprintf('\nLSD = %.4f dB', results.lsdDB);
    % 打印总 BER。
    fprintf('\nBER(total) = %.6f', results.berTotal);
    % 打印正文 BER。
    fprintf('\nBER(payload) = %.6f', results.berPayload);
    % 打印误差波形图路径。
    fprintf('\n误差波形图: %s', results.figureError);
    % 打印声谱图路径。
    fprintf('\n声谱图: %s', results.figureSpectrogram);
    % 打印倒谱图路径。
    fprintf('\n倒谱图: %s', results.figureCepstrum);
    % 打印结束分隔线。
    fprintf('\n======================================\n');
end
