function results = fb_echo_main(inWav, outWav, message, L, dF, dB, alphaStrong, alphaWeak, guard)
% FB_ECHO_MAIN 前后向回声核完整测试函数：嵌入、提取、客观评测、BER 统计。
% 用法示例：
%   results = fb_echo_main('sample.wav', 'fb_stego.wav', 'HELLO');

    % 如果没有传入原始音频路径，则使用默认测试音频。
    if nargin < 1 || isempty(inWav),       inWav = 'sample.wav';    end
    % 如果没有传入输出音频路径，则使用默认输出文件名。
    if nargin < 2 || isempty(outWav),      outWav = 'fb_stego.wav'; end
    % 如果没有传入待嵌入消息，则默认嵌入字符串 HELLO。
    if nargin < 3 || isempty(message),     message = 'HELLO';       end
    % 如果没有传入帧长，则默认每帧长度为 8192 个采样点。
    if nargin < 4 || isempty(L),           L = 8192;                end
    % 如果没有传入前向回声延时，则默认 dF=140。
    if nargin < 5 || isempty(dF),          dF = 140;                end
    % 如果没有传入后向回声延时，则默认 dB=220。
    if nargin < 6 || isempty(dB),          dB = 220;                end
    % 如果没有传入强回声系数，则默认 alphaStrong=0.20。
    if nargin < 7 || isempty(alphaStrong), alphaStrong = 0.20;      end
    % 如果没有传入弱回声系数，则默认 alphaWeak=0.06。
    if nargin < 8 || isempty(alphaWeak),   alphaWeak = 0.06;        end
    % 如果没有传入倒谱邻域保护宽度，则默认 guard=2。
    if nargin < 9 || isempty(guard),       guard = 2;               end

    % 调用前后向回声核嵌入函数，生成含密水印音频。
    fb_echo_embed(inWav, outWav, message, L, dF, dB, alphaStrong, alphaWeak);

    % 尝试从输出音频中恢复消息。
    try
        % 调用前后向回声核提取函数提取文本消息。
        extractedMessage = fb_echo_extract(outWav, L, dF, dB, guard);
        % 若未报错，则认为提取成功。
        extractSucceeded = true;
        % 成功时错误信息置为空。
        extractError = '';
    % 若提取阶段出现异常，则进入错误处理分支。
    catch ME
        % 失败时提取消息置为空。
        extractedMessage = '';
        % 标记提取失败。
        extractSucceeded = false;
        % 保存异常信息。
        extractError = ME.message;
    end

    % 调用客观评测函数，计算波形和频谱层面的失真指标。
    evalResults = echo_evaluate(inWav, outWav, L, [dF dB], {'dF', 'dB'});

    % 构造与嵌入端一致的真实比特序列。
    trueBits = build_true_bits_local(message);
    % 按与正式提取端一致的逻辑提取固定长度比特，用于 BER 统计。
    detectedBits = extract_bits_fixed_local(outWav, numel(trueBits), L, dF, dB, guard);
    % 计算总 BER 和正文 BER。
    [berTotal, berPayload] = calc_ber_local(trueBits, detectedBits);

    % 先复制客观评测结果结构体。
    results = evalResults;
    % 写入方案名称。
    results.scheme = 'fb_echo';
    % 写入原始消息。
    results.message = message;
    % 写入提取消息。
    results.extractedMessage = extractedMessage;
    % 写入提取成功标志。
    results.extractSucceeded = extractSucceeded;
    % 写入错误信息。
    results.extractError = extractError;
    % 写入总 BER。
    results.berTotal = berTotal;
    % 写入正文 BER。
    results.berPayload = berPayload;
    % 写入真实比特序列。
    results.trueBits = trueBits;
    % 写入检测比特序列。
    results.detectedBits = detectedBits;
    % 写入前向延时参数。
    results.dF = dF;
    % 写入后向延时参数。
    results.dB = dB;
    % 写入强回声系数。
    results.alphaStrong = alphaStrong;
    % 写入弱回声系数。
    results.alphaWeak = alphaWeak;
    % 写入保护带宽度。
    results.guard = guard;

    % 打印本次实验摘要。
    print_summary_local(results);
end

function bits = build_true_bits_local(message)
% BUILD_TRUE_BITS_LOCAL 按嵌入端规则将消息编码为真实比特序列。

    % 按 UTF-8 将字符串编码为字节流。
    payloadBytes = unicode2native(message, 'UTF-8');
    % 将 UTF-8 字节流展开为比特行向量。
    payloadBits = bytes_to_bits_local(payloadBytes);
    % 计算正文长度（单位：字节）。
    payloadLenBytes = numel(payloadBytes);
    % 将正文长度编码为 16 bit 头部。
    headerBits = reshape(dec2bin(payloadLenBytes, 16).' - '0', 1, []);
    % 拼接头部与正文比特，得到完整真实比特序列。
    bits = [headerBits, payloadBits];
end

function bits = extract_bits_fixed_local(stegoWav, nBits, L, dF, dB, guard)
% EXTRACT_BITS_FIXED_LOCAL 按正式提取端的前后向回声判决规则提取固定长度比特。

    % 读取含密音频。
    [y, ~] = audioread(stegoWav);
    % 转为 double 类型便于后续计算。
    y = double(y);
    % 若为多声道音频，则转单声道。
    if size(y, 2) > 1
        % 多声道时求通道均值。
        yMono = mean(y, 2);
    else
        % 单声道时直接使用。
        yMono = y;
    end

    % 按正式提取端一致的规则筛选高能量有效帧。
    [activeFrames, ~, ~] = select_active_frames_local(yMono, L, 0.25, 0.01);
    % 检查有效帧数是否足够提取目标比特数。
    assert(nBits <= numel(activeFrames), '需要提取的比特数超过可用有效帧数。');
    % 预分配输出比特向量。
    bits = zeros(1, nBits);
    % 生成正式提取端使用的 Hann 窗。
    w = hann_window_local(L);

    % 逐个有效帧执行前后向回声检测。
    for k = 1:nBits
        % 获取第 k 个待提取比特对应的有效帧编号。
        frameId = activeFrames(k);
        % 将帧编号转换为样本索引区间。
        idx = (frameId - 1) * L + (1:L);
        % 取出当前帧并加窗。
        frame = yMono(idx) .* w;
        % 计算实倒谱。
        c = real(ifft(log(abs(fft(frame)) + eps)));
        % 估计前向延时处的倒谱峰值强度。
        sF = neighborhood_mean_abs_local(c, dF, guard);
        % 估计后向延时处的倒谱峰值强度。
        sB = neighborhood_mean_abs_local(c, dB, guard);
        % 若后向位置强于前向位置，则判为 bit=1，否则判为 bit=0。
        bits(k) = sB > sF;
    end
end

function val = neighborhood_mean_abs_local(c, d, guard)
% NEIGHBORHOOD_MEAN_ABS_LOCAL 计算目标延时附近倒谱幅值绝对值均值。

    % 计算左边界并防止越界。
    left = max(1, d + 1 - guard);
    % 计算右边界并防止越界。
    right = min(length(c), d + 1 + guard);
    % 计算邻域绝对值均值作为目标延时得分。
    val = mean(abs(real(c(left:right))));
end

function bits = bytes_to_bits_local(bytes)
% BYTES_TO_BITS_LOCAL 将字节数组展开为比特行向量。

    % 如果输入为空，则直接返回空比特序列。
    if isempty(bytes)
        bits = [];
        return;
    end
    % 将输入统一转为 uint8 列向量。
    bytes = uint8(bytes(:));
    % 将每个字节转换为 8 位二进制字符。
    bitChars = dec2bin(bytes, 8);
    % 将字符矩阵展开为 0/1 行向量。
    bits = reshape((bitChars.' - '0'), 1, []);
end

function [activeFrames, frameRms, threshold] = select_active_frames_local(x, L, energyRatio, minRms)
% SELECT_ACTIVE_FRAMES_LOCAL 按 RMS 选取高能量有效帧。

    % 若未指定能量比例阈值，则使用默认值 0.25。
    if nargin < 3 || isempty(energyRatio), energyRatio = 0.25; end
    % 若未指定最小 RMS 门限，则使用默认值 0.01。
    if nargin < 4 || isempty(minRms),      minRms = 0.01; end

    % 若输入为多声道，则先转换为单声道。
    if size(x, 2) > 1
        % 多声道时对各通道取均值。
        xMono = mean(double(x), 2);
    else
        % 单声道时直接转换为 double。
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

    % 截断到完整帧长度。
    xMono = xMono(1:nFrames * L);
    % 重排为每行一帧的矩阵。
    frameMat = reshape(xMono, L, nFrames).';
    % 计算每帧 RMS。
    frameRms = sqrt(mean(frameMat.^2, 2));
    % 计算最终能量门限。
    threshold = max(minRms, median(frameRms) * energyRatio);
    % 选出所有满足门限的有效帧编号。
    activeFrames = find(frameRms >= threshold);
end

function w = hann_window_local(L)
% HANN_WINDOW_LOCAL 生成周期型 Hann 窗。

    % 生成样本下标列向量。
    n = (0:L-1).';
    % 根据周期型 Hann 窗公式计算窗值。
    w = 0.5 - 0.5 * cos(2 * pi * n / L);
end

function [berTotal, berPayload] = calc_ber_local(trueBits, detectedBits)
% CALC_BER_LOCAL 计算总 BER 和正文 BER。

    % 计算完整比特序列的平均误码率。
    berTotal = mean(trueBits ~= detectedBits);
    % 如果存在正文部分，则统计正文 BER。
    if numel(trueBits) > 16
        % 跳过前 16 bit 头部，仅统计正文误码率。
        berPayload = mean(trueBits(17:end) ~= detectedBits(17:end));
    else
        % 若无正文部分，则正文 BER 记为 0。
        berPayload = 0;
    end
end

function print_summary_local(results)
% PRINT_SUMMARY_LOCAL 打印实验结果摘要。

    % 打印标题分隔线。
    fprintf('\n============ fb_echo_main ===========');
    % 打印输出音频路径。
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
    fprintf('\n=====================================\n');
end
