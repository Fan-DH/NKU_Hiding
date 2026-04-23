function results = multi_echo_main(inWav, outWav, message, L, D0, D1, A, guard)
% MULTI_ECHO_MAIN 多回声核完整测试函数：嵌入、提取、客观评测、BER 统计。
% 用法示例：
%   results = multi_echo_main('sample.wav', 'multi_stego.wav', 'HELLO');

    % 如果没有传入原始音频路径，则使用默认测试音频。
    if nargin < 1 || isempty(inWav),   inWav = 'sample.wav';      end
    % 如果没有传入输出音频路径，则使用默认输出文件名。
    if nargin < 2 || isempty(outWav),  outWav = 'multi_stego.wav'; end
    % 如果没有传入待嵌入消息，则默认嵌入字符串 HELLO。
    if nargin < 3 || isempty(message), message = 'HELLO';         end
    % 如果没有传入帧长，则默认每帧长度为 8192 个采样点。
    if nargin < 4 || isempty(L),       L = 8192;                  end
    % 如果没有传入 bit=0 对应的多延时集合，则使用默认 D0。
    if nargin < 5 || isempty(D0),      D0 = [110 180 260];        end
    % 如果没有传入 bit=1 对应的多延时集合，则使用默认 D1。
    if nargin < 6 || isempty(D1),      D1 = [140 210 290];        end
    % 如果没有传入各回声核权重，则使用默认 A。
    if nargin < 7 || isempty(A),       A = [0.22 0.15 0.10];      end
    % 如果没有传入倒谱邻域保护宽度，则默认 guard=2。
    if nargin < 8 || isempty(guard),   guard = 2;                 end

    % 调用多回声核嵌入函数，生成含密水印音频。
    multi_echo_embed(inWav, outWav, message, L, D0, D1, A);

    % 尝试从输出音频中提取消息。
    try
        % 调用多回声核提取函数恢复文本消息。
        extractedMessage = multi_echo_extract(outWav, L, D0, D1, A, guard);
        % 若未报错，则认为提取成功。
        extractSucceeded = true;
        % 成功时错误信息置为空。
        extractError = '';
    % 如果提取过程中出现异常，则进入错误处理分支。
    catch ME
        % 提取失败时消息置为空。
        extractedMessage = '';
        % 标记提取失败。
        extractSucceeded = false;
        % 记录异常信息。
        extractError = ME.message;
    end

    % 将 D0 强制整理为行向量，便于统一记录和后续运算。
    D0 = D0(:).';
    % 将 D1 强制整理为行向量，便于统一记录和后续运算。
    D1 = D1(:).';
    % 将 A 强制整理为行向量，便于统一记录和后续运算。
    A = A(:).';
    % 取出所有唯一的延时位置，作为倒谱图标记位置。
    markerVals = unique([D0 D1]);
    % 为每个标记位置自动生成文本标签。
    markerLabels = arrayfun(@(m) sprintf('d=%g', m), markerVals, 'UniformOutput', false);
    % 调用客观评测函数，计算 SNR、LSD 并生成图像结果。
    evalResults = echo_evaluate(inWav, outWav, L, markerVals, markerLabels);

    % 按嵌入端一致的 UTF-8 规则构造真实比特序列。
    trueBits = build_true_bits_local(message);
    % 按正式提取端一致的规则提取固定长度比特，用于 BER 统计。
    detectedBits = extract_bits_fixed_local(outWav, numel(trueBits), L, D0, D1, A, guard);
    % 计算总 BER 和正文 BER。
    [berTotal, berPayload] = calc_ber_local(trueBits, detectedBits);

    % 先复制客观评测结果结构体。
    results = evalResults;
    % 写入当前方案名称。
    results.scheme = 'multi_echo';
    % 写入原始嵌入消息。
    results.message = message;
    % 写入提取得到的消息。
    results.extractedMessage = extractedMessage;
    % 写入提取是否成功的标志。
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
    % 写入 bit=0 对应的延时集合。
    results.D0 = D0;
    % 写入 bit=1 对应的延时集合。
    results.D1 = D1;
    % 写入多回声核权重集合。
    results.A = A;
    % 写入倒谱邻域保护宽度。
    results.guard = guard;

    % 打印实验摘要。
    print_summary_local(results);
end

function bits = build_true_bits_local(message)
% BUILD_TRUE_BITS_LOCAL 按嵌入端一致的编码规则构造真实比特序列。

    % 按 UTF-8 将字符串编码为字节流。
    payloadBytes = unicode2native(message, 'UTF-8');
    % 将正文 UTF-8 字节流展开为 0/1 比特序列。
    payloadBits = bytes_to_bits_local(payloadBytes);
    % 计算正文长度（单位：字节）。
    payloadLenBytes = numel(payloadBytes);
    % 使用 16 bit 头部记录正文长度。
    headerBits = reshape(dec2bin(payloadLenBytes, 16).' - '0', 1, []);
    % 拼接头部和正文比特，得到完整真实比特序列。
    bits = [headerBits, payloadBits];
end

function bits = extract_bits_fixed_local(stegoWav, nBits, L, D0, D1, A, guard)
% EXTRACT_BITS_FIXED_LOCAL 按正式多回声核提取规则提取前 nBits 个比特。

    % 读取含密音频。
    [y, ~] = audioread(stegoWav);
    % 转为 double 类型，方便数值运算。
    y = double(y);
    % 若为多声道音频，则转换为单声道。
    if size(y, 2) > 1
        % 多声道时对各通道求均值。
        yMono = mean(y, 2);
    else
        % 单声道时直接使用。
        yMono = y;
    end

    % 按正式提取端一致的规则筛选有效帧。
    [activeFrames, ~, ~] = select_active_frames_local(yMono, L, 0.25, 0.01);
    % 检查有效帧数量是否足够。
    assert(nBits <= numel(activeFrames), '需要提取的比特数超过可用有效帧数。');
    % 预分配输出比特向量。
    bits = zeros(1, nBits);
    % 生成与正式提取端一致的 Hann 窗。
    w = hann_window_local(L);

    % 逐个有效帧执行多回声核判决。
    for k = 1:nBits
        % 获取第 k 个比特对应的有效帧编号。
        frameId = activeFrames(k);
        % 将帧编号转换为样本索引区间。
        idx = (frameId - 1) * L + (1:L);
        % 取出当前帧并加 Hann 窗。
        frame = yMono(idx) .* w;
        % 计算该帧的实倒谱。
        c = real(ifft(log(abs(fft(frame)) + eps)));
        % 初始化 bit=0 的综合得分。
        score0 = 0;
        % 初始化 bit=1 的综合得分。
        score1 = 0;
        % 对每个回声核分量分别累加判决得分。
        for j = 1:numel(A)
            % 将 D0(j) 位置的倒谱峰值按权重累加到 score0。
            score0 = score0 + A(j) * neighborhood_mean_abs_local(c, D0(j), guard);
            % 将 D1(j) 位置的倒谱峰值按权重累加到 score1。
            score1 = score1 + A(j) * neighborhood_mean_abs_local(c, D1(j), guard);
        end
        % 若 score1 大于 score0，则判为 bit=1，否则判为 bit=0。
        bits(k) = score1 > score0;
    end
end

function val = neighborhood_mean_abs_local(c, d, guard)
% NEIGHBORHOOD_MEAN_ABS_LOCAL 计算目标延时附近倒谱绝对值均值。

    % 确定邻域左边界，避免索引越界。
    left = max(1, d + 1 - guard);
    % 确定邻域右边界，避免索引越界。
    right = min(length(c), d + 1 + guard);
    % 计算邻域内实倒谱绝对值的平均值。
    val = mean(abs(real(c(left:right))));
end

function bits = bytes_to_bits_local(bytes)
% BYTES_TO_BITS_LOCAL 将字节数组展开为按高位在前的比特序列。

    % 如果输入为空，则直接返回空向量。
    if isempty(bytes)
        bits = [];
        return;
    end
    % 将输入整理为 uint8 列向量。
    bytes = uint8(bytes(:));
    % 将每个字节转成 8 位二进制字符。
    bitChars = dec2bin(bytes, 8);
    % 将二进制字符矩阵重排为 0/1 行向量。
    bits = reshape((bitChars.' - '0'), 1, []);
end

function [activeFrames, frameRms, threshold] = select_active_frames_local(x, L, energyRatio, minRms)
% SELECT_ACTIVE_FRAMES_LOCAL 按帧 RMS 选取高能量有效帧。

    % 若未指定能量比例，则使用默认值 0.25。
    if nargin < 3 || isempty(energyRatio), energyRatio = 0.25; end
    % 若未指定最小 RMS 门限，则使用默认值 0.01。
    if nargin < 4 || isempty(minRms),      minRms = 0.01; end

    % 若输入是多声道，则先转为单声道。
    if size(x, 2) > 1
        % 多声道时取各通道均值。
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
    % 重排为每行一帧的矩阵形式。
    frameMat = reshape(xMono, L, nFrames).';
    % 计算每帧 RMS。
    frameRms = sqrt(mean(frameMat.^2, 2));
    % 用中位 RMS 和最小门限共同确定最终阈值。
    threshold = max(minRms, median(frameRms) * energyRatio);
    % 选出所有满足门限条件的帧编号。
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
    % 如果存在正文部分，则单独计算正文 BER。
    if numel(trueBits) > 16
        % 跳过 16 bit 头部，只统计正文比特误码率。
        berPayload = mean(trueBits(17:end) ~= detectedBits(17:end));
    else
        % 如果没有正文，则正文 BER 定义为 0。
        berPayload = 0;
    end
end

function print_summary_local(results)
% PRINT_SUMMARY_LOCAL 打印实验结果摘要。

    % 打印标题分隔线。
    fprintf('\n========== multi_echo_main =========');
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
        % 若提取失败，则打印异常原因。
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
    fprintf('\n====================================\n');
end
