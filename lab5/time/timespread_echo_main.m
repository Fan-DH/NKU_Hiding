function results = timespread_echo_main(inWav, outWav, message, L, d0, d1, pnLen, alpha, seed, guard)
% TIMESPREAD_ECHO_MAIN 时域扩展回声核完整测试函数：嵌入、提取、客观评测、BER 统计。
% 用法示例：
%   results = timespread_echo_main('sample.wav', 'timespread_stego.wav', 'HELLO');

    % 如果没有传入原始音频路径，则使用默认测试音频。
    if nargin < 1 || isempty(inWav),   inWav = 'sample.wav';            end
    % 如果没有传入输出音频路径，则使用默认输出文件名。
    if nargin < 2 || isempty(outWav),  outWav = 'timespread_stego.wav'; end
    % 如果没有传入待嵌入消息，则默认嵌入字符串 HELLO。
    if nargin < 3 || isempty(message), message = 'HELLO';               end
    % 如果没有传入帧长，则默认每帧长度为 8192 个采样点。
    if nargin < 4 || isempty(L),       L = 8192;                        end
    % 如果没有传入 bit=0 时的起始延时，则默认 d0=120。
    if nargin < 5 || isempty(d0),      d0 = 120;                        end
    % 如果没有传入 bit=1 时的起始延时，则默认 d1=220。
    if nargin < 6 || isempty(d1),      d1 = 220;                        end
    % 如果没有传入 PN 序列长度，则默认 pnLen=32。
    if nargin < 7 || isempty(pnLen),   pnLen = 32;                      end
    % 如果没有传入扩展回声强度，则默认 alpha=0.12。
    if nargin < 8 || isempty(alpha),   alpha = 0.12;                    end
    % 如果没有传入随机种子，则默认 seed=2025。
    if nargin < 9 || isempty(seed),    seed = 2025;                     end
    % 如果没有传入邻域保护宽度，则默认 guard=0。
    if nargin < 10 || isempty(guard),  guard = 0;                       end

    % 调用时域扩展回声核嵌入函数，生成含密水印音频。
    timespread_echo_embed(inWav, outWav, message, L, d0, d1, pnLen, alpha, seed);

    % 尝试从输出音频中恢复消息。
    try
        % 调用时域扩展回声核提取函数恢复消息。
        extractedMessage = timespread_echo_extract(outWav, L, d0, d1, pnLen, seed, guard);
        % 若未报错，则认为提取成功。
        extractSucceeded = true;
        % 成功时错误信息置为空字符串。
        extractError = '';
    % 若提取过程中出现异常，则进入错误处理分支。
    catch ME
        % 失败时提取消息置为空字符串。
        extractedMessage = '';
        % 标记提取失败。
        extractSucceeded = false;
        % 保存异常信息，便于排查。
        extractError = ME.message;
    end

    % 构造所有需要在倒谱图中标记的位置范围。
    markers = [d0:(d0 + pnLen - 1), d1:(d1 + pnLen - 1)];
    % 构造关键标记位置，包括两个扩展段的起点和终点。
    markerVals = [d0, d0 + pnLen - 1, d1, d1 + pnLen - 1];
    % 为关键标记位置设置文字标签。
    markerLabels = {'d0', 'd0+pnLen-1', 'd1', 'd1+pnLen-1'};
    % 调用客观评测函数，计算 SNR、LSD 并生成图像结果。
    evalResults = echo_evaluate(inWav, outWav, L, markerVals, markerLabels);

    % 构造与嵌入端一致的真实比特序列。
    trueBits = build_true_bits_local(message);
    % 按正式提取端一致的逻辑提取固定长度比特，用于 BER 统计。
    detectedBits = extract_bits_fixed_local(outWav, numel(trueBits), L, d0, d1, pnLen, seed, guard);
    % 计算总 BER 和正文 BER。
    [berTotal, berPayload] = calc_ber_local(trueBits, detectedBits);

    % 先复制客观评测结果结构体。
    results = evalResults;
    % 写入当前方案名称。
    results.scheme = 'timespread_echo';
    % 写入原始嵌入消息。
    results.message = message;
    % 写入提取出的消息。
    results.extractedMessage = extractedMessage;
    % 写入提取成功标志。
    results.extractSucceeded = extractSucceeded;
    % 写入提取异常信息。
    results.extractError = extractError;
    % 写入总 BER。
    results.berTotal = berTotal;
    % 写入正文 BER。
    results.berPayload = berPayload;
    % 写入真实比特序列。
    results.trueBits = trueBits;
    % 写入检测比特序列。
    results.detectedBits = detectedBits;
    % 写入 bit=0 的起始延时。
    results.d0 = d0;
    % 写入 bit=1 的起始延时。
    results.d1 = d1;
    % 写入 PN 序列长度。
    results.pnLen = pnLen;
    % 写入扩展回声强度系数。
    results.alpha = alpha;
    % 写入随机种子。
    results.seed = seed;
    % 写入邻域保护宽度。
    results.guard = guard;
    % 写入完整延时范围，便于后续可视化分析。
    results.markerRange = markers;

    % 打印实验摘要。
    print_summary_local(results);
end

function bits = build_true_bits_local(message)
% BUILD_TRUE_BITS_LOCAL 按嵌入端一致的编码规则构造真实比特序列。

    % 按 UTF-8 将字符串编码为字节流。
    payloadBytes = unicode2native(message, 'UTF-8');
    % 将 UTF-8 正文字节流展开为比特序列。
    payloadBits = bytes_to_bits_local(payloadBytes);
    % 计算正文长度（单位：字节）。
    payloadLenBytes = numel(payloadBytes);
    % 将正文长度编码为 16 bit 头部。
    headerBits = reshape(dec2bin(payloadLenBytes, 16).' - '0', 1, []);
    % 拼接头部与正文比特，得到完整真实比特序列。
    bits = [headerBits, payloadBits];
end

function bits = extract_bits_fixed_local(stegoWav, nBits, L, d0, d1, pnLen, seed, guard)
% EXTRACT_BITS_FIXED_LOCAL 按正式时域扩展回声提取流程提取前 nBits 个比特。

    % 固定随机种子，确保 PN 序列与嵌入端保持一致。
    rng(seed);
    % 生成长度为 pnLen 的双极性随机 PN 序列。
    pn = 2 * randi([0 1], pnLen, 1) - 1;
    % 去除 PN 序列均值，减小直流分量影响。
    pn = pn - mean(pn);
    % 将 PN 序列归一化到单位范数。
    pn = pn / (norm(pn) + eps);

    % 读取含密音频。
    [y, ~] = audioread(stegoWav);
    % 转为 double 类型便于数值运算。
    y = double(y);
    % 若为多声道音频，则转为单声道。
    if size(y, 2) > 1
        % 多声道时取均值。
        yMono = mean(y, 2);
    else
        % 单声道时直接使用。
        yMono = y;
    end

    % 按正式提取端一致的规则筛选有效帧。
    [activeFrames, ~, ~] = select_active_frames_local(yMono, L, 0.25, 0.01);
    % 检查有效帧数是否足够提取目标比特数。
    assert(nBits <= numel(activeFrames), '需要提取的比特数超过可用有效帧数。');
    % 预分配输出比特向量。
    bits = zeros(1, nBits);
    % 生成正式提取端使用的 Hann 窗。
    w = hann_window_local(L);

    % 逐个有效帧执行扩展回声判决。
    for k = 1:nBits
        % 获取第 k 个比特对应的有效帧编号。
        frameId = activeFrames(k);
        % 将帧编号转换为样本索引区间。
        idx = (frameId - 1) * L + (1:L);
        % 取出当前帧并乘以 Hann 窗。
        frame = yMono(idx) .* w;
        % 计算该帧的实倒谱。
        c = real(ifft(log(abs(fft(frame)) + eps)));
        % 提取 d0 起始处的扩展段倒谱序列。
        seg0 = extract_segment_local(c, d0, pnLen, guard);
        % 提取 d1 起始处的扩展段倒谱序列。
        seg1 = extract_segment_local(c, d1, pnLen, guard);
        % 计算 seg0 与 PN 序列的归一化相关得分。
        score0 = dot(seg0(:), pn(:)) / (norm(seg0) + eps);
        % 计算 seg1 与 PN 序列的归一化相关得分。
        score1 = dot(seg1(:), pn(:)) / (norm(seg1) + eps);
        % 若 score1 大于 score0，则判为 bit=1，否则判为 bit=0。
        bits(k) = score1 > score0;
    end
end

function seg = extract_segment_local(c, d, pnLen, guard)
% EXTRACT_SEGMENT_LOCAL 从倒谱中提取目标延时开始的一段扩展倒谱序列。

    % 预分配长度为 pnLen 的输出序列。
    seg = zeros(pnLen, 1);
    % 逐个提取扩展段中的每个位置。
    for m = 1:pnLen
        % 计算当前扩展位置在倒谱中的中心索引。
        center = d + (m - 1) + 1;
        % 计算邻域左边界并防止越界。
        left = max(1, center - guard);
        % 计算邻域右边界并防止越界。
        right = min(length(c), center + guard);
        % 对邻域内倒谱取平均，作为当前位置的估计值。
        seg(m) = mean(real(c(left:right)));
    end
end

function bits = bytes_to_bits_local(bytes)
% BYTES_TO_BITS_LOCAL 将字节数组展开为按高位在前的比特序列。

    % 如果输入字节流为空，则返回空比特向量。
    if isempty(bytes)
        bits = [];
        return;
    end
    % 将输入统一整理为 uint8 列向量。
    bytes = uint8(bytes(:));
    % 将每个字节转换成 8 位二进制字符串。
    bitChars = dec2bin(bytes, 8);
    % 将字符矩阵展开为 0/1 行向量。
    bits = reshape((bitChars.' - '0'), 1, []);
end

function [activeFrames, frameRms, threshold] = select_active_frames_local(x, L, energyRatio, minRms)
% SELECT_ACTIVE_FRAMES_LOCAL 按帧 RMS 选取高能量有效帧。

    % 若未指定能量比例阈值，则使用默认值 0.25。
    if nargin < 3 || isempty(energyRatio), energyRatio = 0.25; end
    % 若未指定最小 RMS 门限，则使用默认值 0.01。
    if nargin < 4 || isempty(minRms),      minRms = 0.01; end

    % 若输入为多声道，则转换为单声道。
    if size(x, 2) > 1
        % 多声道时对通道求均值。
        xMono = mean(double(x), 2);
    else
        % 单声道时直接转为 double。
        xMono = double(x);
    end

    % 计算完整帧数量。
    nFrames = floor(length(xMono) / L);
    % 若不足一帧，则返回空结果。
    if nFrames <= 0
        activeFrames = [];
        frameRms = [];
        threshold = minRms;
        return;
    end

    % 将信号截断到整帧长度。
    xMono = xMono(1:nFrames * L);
    % 重排为每行一帧的矩阵。
    frameMat = reshape(xMono, L, nFrames).';
    % 计算每帧 RMS。
    frameRms = sqrt(mean(frameMat.^2, 2));
    % 用中位 RMS 和最小门限共同决定最终阈值。
    threshold = max(minRms, median(frameRms) * energyRatio);
    % 选出所有高于门限的有效帧编号。
    activeFrames = find(frameRms >= threshold);
end

function w = hann_window_local(L)
% HANN_WINDOW_LOCAL 生成周期型 Hann 窗。

    % 生成样本下标列向量。
    n = (0:L-1).';
    % 按周期型 Hann 窗公式计算窗值。
    w = 0.5 - 0.5 * cos(2 * pi * n / L);
end

function [berTotal, berPayload] = calc_ber_local(trueBits, detectedBits)
% CALC_BER_LOCAL 计算总 BER 和正文 BER。

    % 统计完整比特序列上的平均误码率。
    berTotal = mean(trueBits ~= detectedBits);
    % 如果存在正文部分，则额外统计正文 BER。
    if numel(trueBits) > 16
        % 跳过前 16 bit 头部，仅统计正文误码率。
        berPayload = mean(trueBits(17:end) ~= detectedBits(17:end));
    else
        % 若不存在正文，则正文 BER 定义为 0。
        berPayload = 0;
    end
end

function print_summary_local(results)
% PRINT_SUMMARY_LOCAL 打印实验结果摘要。

    % 打印标题分隔线。
    fprintf('\n======== timespread_echo_main ========');
    % 打印输出音频路径。
    fprintf('\n输出音频: %s', results.outWav);
    % 打印嵌入消息内容。
    fprintf('\n嵌入消息: %s', results.message);
    % 打印提取是否成功。
    fprintf('\n提取成功: %d', results.extractSucceeded);
    % 若提取成功，则打印提取消息。
    if results.extractSucceeded
        fprintf('\n提取消息: %s', results.extractedMessage);
    else
        % 若提取失败，则打印失败原因。
        fprintf('\n提取失败原因: %s', results.extractError);
    end
    % 打印 SNR。
    fprintf('\nSNR = %.4f dB', results.snrDB);
    % 打印 LSD。
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
