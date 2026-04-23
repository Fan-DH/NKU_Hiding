function metrics = echo_evaluate(inWav, outWav, L, markers, markerLabels)
% ECHO_EVALUATE 通用音频评测函数：比较原始音频与水印音频。
    % 如果没有传入倒谱展示帧长，则默认使用 8192。
    if nargin < 3 || isempty(L),            L = 8192;     end
    % 如果没有传入倒谱标记位置，则默认不标记任何位置。
    if nargin < 4 || isempty(markers),      markers = []; end
    % 如果没有传入标记标签，则默认使用空单元数组。
    if nargin < 5 || isempty(markerLabels), markerLabels = {}; end

    % 读取原始音频。
    [x, fsX] = audioread(inWav);
    % 读取含密音频。
    [y, fsY] = audioread(outWav);
    % 检查两段音频采样率是否一致。
    assert(fsX == fsY, '原始音频与水印音频采样率不一致。');
    % 将统一采样率保存为 fs。
    fs = fsX;

    % 取两段音频的共同最短长度，避免长度不一致带来索引问题。
    N = min(size(x, 1), size(y, 1));
    % 将原始音频截断到共同长度。
    x = x(1:N, :);
    % 将含密音频截断到共同长度。
    y = y(1:N, :);

    % 将原始音频转换为单声道版本，用于客观指标和作图。
    xMono = to_mono_local(x);
    % 将含密音频转换为单声道版本，用于客观指标和作图。
    yMono = to_mono_local(y);
    % 计算误差信号 e(t)=y(t)-x(t)。
    errMono = yMono - xMono;
    % 构造时间轴（单位：秒）。
    t = (0:N-1)' / fs;

    % 根据信号能量和误差能量计算时域 SNR。
    snrDB = 10 * log10(sum(xMono.^2) / (sum((xMono - yMono).^2) + eps));
    % 计算对数谱失真 LSD。
    lsdDB = calc_lsd_local(xMono, yMono);

    % 从输出音频路径中解析输出目录和文件基名。
    [outDir, outBase, ~] = fileparts(outWav);
    % 如果输出目录为空，则默认保存到当前工作目录。
    if isempty(outDir), outDir = pwd; end
    % 如果文件基名为空，则使用 stego 作为默认前缀。
    if isempty(outBase), outBase = 'stego'; end

    % -------------------- 误差波形图 --------------------
    % 创建不可见的误差波形图窗口，避免批处理时弹窗。
    figError = figure('Name', 'Error Waveform', 'Color', 'w', 'Visible', 'off');
    % 绘制误差信号波形。
    plot(t, errMono, 'k');
    % 打开网格，便于观察波形细节。
    grid on;
    % 设置横轴标签为时间。
    xlabel('Time (s)');
    % 设置纵轴标签为幅度。
    ylabel('Amplitude');
    % 设置图标题。
    title('误差波形图 e(t) = y(t) - x(t)');
    % 构造误差波形图输出路径。
    errorFigPath = fullfile(outDir, [outBase '_error_waveform.png']);
    % 将误差波形图保存到 PNG 文件。
    saveas(figError, errorFigPath);
    % 关闭图窗以释放资源。
    close(figError);

    % -------------------- 声谱图 --------------------
    % 设置短时分析窗长。
    specWin = 1024;
    % 设置相邻分析帧之间的重叠长度。
    specOverlap = 768;
    % 设置 FFT 点数。
    specNfft = 1024;
    % 手工计算原始音频的短时频谱，避免依赖 spectrogram/hann 工具箱接口。
    [Sx, Fx, Tx] = compute_spectrogram_local(xMono, fs, specWin, specOverlap, specNfft);
    % 手工计算含密音频的短时频谱，避免依赖 spectrogram/hann 工具箱接口。
    [Sy, Fy, Ty] = compute_spectrogram_local(yMono, fs, specWin, specOverlap, specNfft);
    % 将原始音频幅度谱转换为 dB 标度。
    SxDB = 20 * log10(abs(Sx) + eps);
    % 将含密音频幅度谱转换为 dB 标度。
    SyDB = 20 * log10(abs(Sy) + eps);
    % 计算差分声谱图（含密减原始）。
    dSDB = SyDB - SxDB;

    % 创建不可见的声谱图比较窗口。
    figSpec = figure('Name', 'Spectrogram Comparison', 'Color', 'w', 'Visible', 'off');
    % 在第 1 个子图中绘制原始音频声谱图。
    subplot(3, 1, 1);
    % 使用 imagesc 显示原始音频声谱图矩阵。
    imagesc(Tx, Fx, SxDB); axis xy; colorbar;
    % 设置横轴标签。
    xlabel('Time (s)'); ylabel('Frequency (Hz)');
    % 设置图标题。
    title('原始音频声谱图');

    % 在第 2 个子图中绘制含密音频声谱图。
    subplot(3, 1, 2);
    % 使用 imagesc 显示含密音频声谱图矩阵。
    imagesc(Ty, Fy, SyDB); axis xy; colorbar;
    % 设置横轴标签。
    xlabel('Time (s)'); ylabel('Frequency (Hz)');
    % 设置图标题。
    title('水印音频声谱图');

    % 在第 3 个子图中绘制差分声谱图。
    subplot(3, 1, 3);
    % 使用 imagesc 显示差分声谱图矩阵。
    imagesc(Tx, Fx, dSDB); axis xy; colorbar;
    % 设置横轴标签。
    xlabel('Time (s)'); ylabel('Frequency (Hz)');
    % 设置图标题。
    title('差分声谱图 (watermarked - original)');

    % 构造声谱图输出路径。
    specFigPath = fullfile(outDir, [outBase '_spectrogram.png']);
    % 保存声谱图比较图像。
    saveas(figSpec, specFigPath);
    % 关闭图窗释放资源。
    close(figSpec);

    % -------------------- 倒谱图 --------------------
    % 计算原始单声道音频中完整帧的数量。
    nFrames = floor(numel(xMono) / L);
    % 检查是否至少存在一帧可用于倒谱分析。
    assert(nFrames >= 1, '音频长度不足以形成一个完整帧，无法生成倒谱图。');

    % 预分配每帧 RMS 数组，用于选择代表帧。
    rmsList = zeros(1, nFrames);
    % 逐帧计算 RMS，寻找能量最大的代表帧。
    for k = 1:nFrames
        % 计算第 k 帧对应的样本索引。
        idx = (k - 1) * L + (1:L);
        % 取出当前帧信号。
        frm = xMono(idx);
        % 计算该帧的 RMS。
        rmsList(k) = sqrt(mean(frm.^2));
    end
    % 找到 RMS 最大的帧作为可视化代表帧。
    [~, bestFrameIdx] = max(rmsList);
    % 计算该代表帧的样本索引区间。
    idxBest = (bestFrameIdx - 1) * L + (1:L);

    % 取出原始音频代表帧并乘周期型 Hann 窗。
    xFrame = xMono(idxBest) .* hann_window_local(L);
    % 取出含密音频代表帧并乘周期型 Hann 窗。
    yFrame = yMono(idxBest) .* hann_window_local(L);
    % 计算原始音频代表帧的实倒谱。
    cx = real(ifft(log(abs(fft(xFrame)) + eps)));
    % 计算含密音频代表帧的实倒谱。
    cy = real(ifft(log(abs(fft(yFrame)) + eps)));
    % 计算差分倒谱。
    ce = cy - cx;
    % 构造 quefrency 采样下标。
    q = 0:L-1;

    % 创建不可见的倒谱比较窗口。
    figCep = figure('Name', 'Cepstrum Comparison', 'Color', 'w', 'Visible', 'off');
    % 在第 1 个子图中绘制原始音频倒谱。
    subplot(3, 1, 1);
    % 绘制原始音频倒谱曲线。
    plot(q, cx, 'b'); grid on;
    % 设置坐标轴标签。
    xlabel('Quefrency (samples)'); ylabel('Cepstrum');
    % 设置图标题。
    title(sprintf('原始音频倒谱（第 %d 帧）', bestFrameIdx));
    % 在图中叠加延时标记线。
    draw_marker_lines_local(markers, markerLabels);

    % 在第 2 个子图中绘制含密音频倒谱。
    subplot(3, 1, 2);
    % 绘制含密音频倒谱曲线。
    plot(q, cy, 'r'); grid on;
    % 设置坐标轴标签。
    xlabel('Quefrency (samples)'); ylabel('Cepstrum');
    % 设置图标题。
    title(sprintf('水印音频倒谱（第 %d 帧）', bestFrameIdx));
    % 在图中叠加延时标记线。
    draw_marker_lines_local(markers, markerLabels);

    % 在第 3 个子图中绘制差分倒谱。
    subplot(3, 1, 3);
    % 绘制差分倒谱曲线。
    plot(q, ce, 'k'); grid on;
    % 设置坐标轴标签。
    xlabel('Quefrency (samples)'); ylabel('Cepstrum difference');
    % 设置图标题。
    title('差分倒谱 (watermarked - original)');
    % 在图中叠加延时标记线。
    draw_marker_lines_local(markers, markerLabels);

    % 构造倒谱图输出路径。
    cepFigPath = fullfile(outDir, [outBase '_cepstrum.png']);
    % 保存倒谱比较图像。
    saveas(figCep, cepFigPath);
    % 关闭图窗释放资源。
    close(figCep);

    % 初始化输出结构体。
    metrics = struct();
    % 记录原始音频路径。
    metrics.inWav = inWav;
    % 记录含密音频路径。
    metrics.outWav = outWav;
    % 记录采样率。
    metrics.fs = fs;
    % 记录实际参与比较的样本数。
    metrics.numSamplesCompared = N;
    % 记录倒谱分析帧长。
    metrics.L = L;
    % 记录倒谱标记位置。
    metrics.markers = markers;
    % 记录倒谱标记标签。
    metrics.markerLabels = markerLabels;
    % 记录信噪比。
    metrics.snrDB = snrDB;
    % 记录对数谱失真。
    metrics.lsdDB = lsdDB;
    % 记录误差波形图输出路径。
    metrics.figureError = errorFigPath;
    % 记录声谱图输出路径。
    metrics.figureSpectrogram = specFigPath;
    % 记录倒谱图输出路径。
    metrics.figureCepstrum = cepFigPath;
    % 记录被选作倒谱展示的代表帧编号。
    metrics.bestFrameIndex = bestFrameIdx;
end

function xMono = to_mono_local(x)
% TO_MONO_LOCAL 将单声道或多声道音频统一转换为单声道序列。

    % 如果输入本来就是单声道，则直接返回。
    if size(x, 2) == 1
        xMono = x;
    else
        % 如果输入是多声道，则对通道求均值。
        xMono = mean(x, 2);
    end
end

function draw_marker_lines_local(markers, markerLabels)
% DRAW_MARKER_LINES_LOCAL 在当前坐标轴中绘制延时标记线和标签。

    % 如果没有传入任何标记位置，则直接返回。
    if isempty(markers)
        return;
    end

    % 将标记位置整理为行向量。
    markers = markers(:).';
    % 如果没有提供标签，则自动生成默认标签。
    if isempty(markerLabels)
        markerLabels = arrayfun(@(m) sprintf('d=%g', m), markers, 'UniformOutput', false);
    end

    % 读取当前坐标轴的 y 轴范围，用于画竖线。
    yl = ylim;
    % 保持当前图形内容，避免后续绘图覆盖已有曲线。
    hold on;
    % 逐个绘制延时标记线和文本标签。
    for i = 1:numel(markers)
        % 取出当前标记位置。
        x = markers(i);
        % 在当前位置画红色虚线标记。
        line([x x], yl, 'LineStyle', '--', 'Color', [0.85 0.1 0.1], 'LineWidth', 1.0);
        % 如果当前标记存在对应标签，则在图顶端写出标签。
        if i <= numel(markerLabels) && ~isempty(markerLabels{i})
            text(x, yl(2), [' ' markerLabels{i}], 'Color', [0.85 0.1 0.1], ...
                'VerticalAlignment', 'top', 'Interpreter', 'none');
        end
    end
    % 结束保持状态。
    hold off;
end

function lsdDB = calc_lsd_local(x, y)
% CALC_LSD_LOCAL 计算两段单声道音频之间的平均对数谱失真 LSD。

    % 设置谱分析帧长。
    frameLen = 1024;
    % 设置相邻分析帧的步长对应的 hop 长度。
    hop = 512;
    % 生成周期型 Hann 窗。
    win = hann_window_local(frameLen);
    % 取两段信号的共同最短长度。
    N = min(length(x), length(y));
    % 截断原始信号到共同长度。
    x = x(1:N);
    % 截断含密信号到共同长度。
    y = y(1:N);

    % 计算可参与分析的帧数。
    nFrames = floor((N - frameLen) / hop) + 1;
    % 若帧数不足，则报错提示音频过短。
    if nFrames < 1
        error('音频过短，无法计算 LSD。');
    end

    % 预分配每帧 LSD 数组。
    lsdPerFrame = zeros(nFrames, 1);
    % 逐帧计算局部对数谱失真。
    for i = 1:nFrames
        % 计算当前分析帧对应的样本索引。
        idx = (i - 1) * hop + (1:frameLen);
        % 取出原始音频分析帧并乘窗。
        xw = x(idx) .* win;
        % 取出含密音频分析帧并乘窗。
        yw = y(idx) .* win;

        % 计算原始分析帧幅度谱。
        X = abs(fft(xw));
        % 计算含密分析帧幅度谱。
        Y = abs(fft(yw));

        % 只保留单边谱部分。
        X = X(1:floor(frameLen / 2) + 1);
        % 只保留单边谱部分。
        Y = Y(1:floor(frameLen / 2) + 1);

        % 将原始幅度谱转换到 dB 域。
        logX = 20 * log10(X + eps);
        % 将含密幅度谱转换到 dB 域。
        logY = 20 * log10(Y + eps);
        % 计算当前帧的 LSD。
        lsdPerFrame(i) = sqrt(mean((logX - logY).^2));
    end

    % 对所有分析帧的 LSD 取平均，得到整体 LSD。
    lsdDB = mean(lsdPerFrame);
end

function [S, F, T] = compute_spectrogram_local(x, fs, winLen, overlap, nfft)
% COMPUTE_SPECTROGRAM_LOCAL 手工计算短时频谱，避免依赖 spectrogram 工具箱接口。

    % 计算短时分析步长。
    hop = winLen - overlap;
    % 生成周期型 Hann 窗。
    win = hann_window_local(winLen);
    % 将输入音频整理为列向量。
    x = x(:);
    % 计算可分析的帧数。
    nFrames = floor((length(x) - winLen) / hop) + 1;
    % 如果可分析帧数不足，则至少补成 1 帧零填充信号。
    if nFrames < 1
        % 对输入做零填充以形成 1 帧。
        x = [x; zeros(winLen - length(x), 1)];
        % 将帧数设置为 1。
        nFrames = 1;
    end

    % 预分配频谱矩阵，只保留单边频谱。
    S = zeros(floor(nfft / 2) + 1, nFrames);
    % 逐帧进行短时傅里叶变换。
    for k = 1:nFrames
        % 计算当前帧样本区间。
        idx = (k - 1) * hop + (1:winLen);
        % 取出当前帧；若越界则在尾部零填充。
        frame = zeros(winLen, 1);
        frame(1:min(winLen, length(x) - (k - 1) * hop)) = x(idx(idx <= length(x)));
        % 对当前帧加窗。
        frame = frame .* win;
        % 计算当前帧 FFT。
        X = fft(frame, nfft);
        % 保存单边频谱。
        S(:, k) = X(1:floor(nfft / 2) + 1);
    end

    % 构造频率坐标轴。
    F = (0:floor(nfft / 2))' * fs / nfft;
    % 构造时间坐标轴，取每帧起始位置对应的时间。
    T = ((0:nFrames - 1) * hop) / fs;
end

function w = hann_window_local(L)
% HANN_WINDOW_LOCAL 生成不依赖工具箱的周期型 Hann 窗。

    % 生成 0 到 L-1 的列向量下标。
    n = (0:L - 1).';
    % 根据周期型 Hann 窗公式计算窗值。
    w = 0.5 - 0.5 * cos(2 * pi * n / L);
end
