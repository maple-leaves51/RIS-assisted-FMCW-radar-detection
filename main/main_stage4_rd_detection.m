%% MAIN_STAGE4_RD_DETECTION
% Stage 4: single-target FMCW echo and range-Doppler detection validation.
%
% This script does not reproduce Fig. 3/Fig. 4 and does not use ADMM/CD.
% Main RIS optimizer: fixed_grid_zf_snr.

clear; clc;

projectRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(fullfile(projectRoot, "config"));
addpath(fullfile(projectRoot, "functions"));

params = paper_params();
params.repro.rngSeed = params.repro.rngSeed + 5000;
params.repro.resetRngInGenerateChannels = true;

figureDir = fullfile(projectRoot, "outputs", "figures");
logDir = fullfile(projectRoot, "outputs", "logs");
dataDir = fullfile(projectRoot, "outputs", "data");
if ~exist(figureDir, "dir"), mkdir(figureDir); end
if ~exist(logDir, "dir"), mkdir(logDir); end
if ~exist(dataDir, "dir"), mkdir(dataDir); end

rng(params.repro.rngSeed, "twister");
[Hsr, Hrd, channelMeta] = generate_channels(params);
Nr = size(Hsr, 1);

startPhases = exp(1j .* 2 .* pi .* rand(Nr, 3));
vRandom = startPhases(:, 1);

fixedOptions = struct();
fixedOptions.initialV = startPhases;
fixedOptions.numStarts = size(startPhases, 2);
fixedOptions.maxSweeps = 4;
fixedOptions.phaseGridSize = 16;
fixedOptions.searchMode = "fixed_grid";
fixedOptions.tolerance = 1e-5;
fixedOptions.rngSeed = params.repro.rngSeed + 100;
[vOptimized, optInfo] = optimize_ris_objective_driven( ...
    Hsr, Hrd, params, "zf_snr", fixedOptions);

[randomGain, randomMetrics] = zf_effective_gain(Hsr, Hrd, vRandom, params);
[optimizedGain, optimizedMetrics] = zf_effective_gain(Hsr, Hrd, vOptimized, params);
gainImprovementDb = 10 .* log10(optimizedGain ./ randomGain);

targets = struct();
targets.range_m = 25;
targets.velocity_mps = 3;
targets.alpha = 1;

% Controlled echo-domain noise for RD smoke validation. This is separate
% from the conservative link-budget noise used in Stage 2/3 SNR diagnostics.
echoNoisePower_W = 1e-12;
echoSeed = params.repro.rngSeed + 200;
[Yrandom, echoMetaRandom] = generate_fmcw_echo( ...
    params, targets, sqrt(randomGain), echoNoisePower_W, struct("rngSeed", echoSeed));
[Yoptimized, echoMetaOptimized] = generate_fmcw_echo( ...
    params, targets, sqrt(optimizedGain), echoNoisePower_W, struct("rngSeed", echoSeed));

[RDrandom, RDrandomDb, rangeAxis, velocityAxis, rdMeta] = range_doppler_fft(Yrandom, params);
[RDoptimized, RDoptimizedDb] = range_doppler_fft(Yoptimized, params);

searchWindow = struct();
searchWindow.rangeHalfWidth_m = max(1.0, 3 * rdMeta.rangeResolution_m);
searchWindow.velocityHalfWidth_m = max(0.5, 3 * rdMeta.velocityResolution_mps);
randomDetection = detect_local_peak(RDrandomDb, rangeAxis, velocityAxis, targets, searchWindow);
optimizedDetection = detect_local_peak(RDoptimizedDb, rangeAxis, velocityAxis, targets, searchWindow);
rdPeakImprovementDb = optimizedDetection.peakDb - randomDetection.peakDb;

rangePass = abs(optimizedDetection.peakRange_m - targets.range_m) <= searchWindow.rangeHalfWidth_m;
velocityPass = abs(optimizedDetection.peakVelocity_mps - targets.velocity_mps) <= searchWindow.velocityHalfWidth_m;
gainPass = optimizedGain > randomGain;
rdPeakPass = rdPeakImprovementDb > 1;
validationPassed = rangePass && velocityPass && gainPass && rdPeakPass;

timestamp = string(datetime("now", "Format", "yyyyMMdd_HHmmss"));
pngPath = fullfile(figureDir, "stage4_rd_detection_" + timestamp + ".png");
figPath = fullfile(figureDir, "stage4_rd_detection_" + timestamp + ".fig");
logPath = fullfile(logDir, "stage4_rd_detection_" + timestamp + ".txt");
dataPath = fullfile(dataDir, "stage4_rd_detection_" + timestamp + ".mat");

create_stage4_figure(RDrandomDb, RDoptimizedDb, rangeAxis, velocityAxis, ...
    targets, randomDetection, optimizedDetection, rdPeakImprovementDb, pngPath, figPath);

save(dataPath, "params", "channelMeta", "Hsr", "Hrd", "vRandom", "vOptimized", ...
    "optInfo", "randomGain", "optimizedGain", "randomMetrics", "optimizedMetrics", ...
    "targets", "echoNoisePower_W", "Yrandom", "Yoptimized", "RDrandom", ...
    "RDoptimized", "RDrandomDb", "RDoptimizedDb", "rangeAxis", "velocityAxis", ...
    "rdMeta", "echoMetaRandom", "echoMetaOptimized", "randomDetection", ...
    "optimizedDetection", "rdPeakImprovementDb", "validationPassed");

logLines = [
    "Stage 4 FMCW RD detection validation"
    "Optimizer: fixed_grid_zf_snr"
    "Target range m: " + string(targets.range_m)
    "Target velocity m/s: " + string(targets.velocity_mps)
    "Random G_ZF: " + string(randomGain)
    "Optimized G_ZF: " + string(optimizedGain)
    "G_ZF improvement dB: " + string(gainImprovementDb)
    "Random SNR dB: " + string(randomMetrics.snrDb)
    "Optimized SNR dB: " + string(optimizedMetrics.snrDb)
    "Random RD peak dB: " + string(randomDetection.peakDb)
    "Random peak range m: " + string(randomDetection.peakRange_m)
    "Random peak velocity m/s: " + string(randomDetection.peakVelocity_mps)
    "Optimized RD peak dB: " + string(optimizedDetection.peakDb)
    "Optimized peak range m: " + string(optimizedDetection.peakRange_m)
    "Optimized peak velocity m/s: " + string(optimizedDetection.peakVelocity_mps)
    "RD peak improvement dB: " + string(rdPeakImprovementDb)
    "Range pass: " + string(rangePass)
    "Velocity pass: " + string(velocityPass)
    "Gain pass: " + string(gainPass)
    "RD peak pass (>1 dB): " + string(rdPeakPass)
    "Validation status: " + string(pass_fail(validationPassed))
    "Saved figure PNG: " + string(pngPath)
    "Saved figure FIG: " + string(figPath)
    "Saved data MAT: " + string(dataPath)
    ];
writelines(logLines, logPath);
fprintf("%s\n", logLines);

function [gain, metrics] = zf_effective_gain(Hsr, Hrd, v, params)
[Heff] = compute_effective_channel(Hsr, Hrd, v);
[B, zfInfo] = design_precoder_zf(Heff, params.power.txPower_W);
[snrLinear, snrDb] = compute_snr(Heff, B, params.power.noisePower_W);
gain = norm(Heff * B, "fro")^2;
metrics = struct();
metrics.Heff = Heff;
metrics.B = B;
metrics.zfInfo = zfInfo;
metrics.snrLinear = snrLinear;
metrics.snrDb = snrDb;
metrics.condHeff = cond(Heff);
metrics.zfRawPower = zfInfo.rawPower_W;
metrics.pathGain = norm(Heff, "fro")^2;
end

function detection = detect_local_peak(RD_dB, rangeAxis, velocityAxis, targets, searchWindow)
rangeMask = abs(rangeAxis - targets.range_m) <= searchWindow.rangeHalfWidth_m;
velocityMask = abs(velocityAxis - targets.velocity_mps) <= searchWindow.velocityHalfWidth_m;
localMap = RD_dB(rangeMask, velocityMask);
[peakDb, localLinearIdx] = max(localMap(:));
[localRangeIdx, localVelocityIdx] = ind2sub(size(localMap), localLinearIdx);
rangeIdxList = find(rangeMask);
velocityIdxList = find(velocityMask);
rangeIdx = rangeIdxList(localRangeIdx);
velocityIdx = velocityIdxList(localVelocityIdx);
detection = struct();
detection.peakDb = peakDb;
detection.peakRange_m = rangeAxis(rangeIdx);
detection.peakVelocity_mps = velocityAxis(velocityIdx);
detection.rangeError_m = detection.peakRange_m - targets.range_m;
detection.velocityError_mps = detection.peakVelocity_mps - targets.velocity_mps;
detection.rangeIdx = rangeIdx;
detection.velocityIdx = velocityIdx;
end

function create_stage4_figure(RDrandomDb, RDoptimizedDb, rangeAxis, velocityAxis, ...
        targets, randomDetection, optimizedDetection, rdPeakImprovementDb, pngPath, figPath)
fig = figure("Visible", "off", "Position", [100, 100, 1250, 720]);
tiledlayout(1, 3);

mapMax = max([RDrandomDb(:); RDoptimizedDb(:)]);
mapLimits = [mapMax - 55, mapMax];

nexttile;
imagesc(velocityAxis, rangeAxis, RDrandomDb);
axis xy; grid on; clim(mapLimits); colorbar;
xlabel("Velocity (m/s)"); ylabel("Range (m)");
title("Random RIS RD map");
hold on;
plot(targets.velocity_mps, targets.range_m, "rx", "LineWidth", 1.5, "MarkerSize", 9);
plot(randomDetection.peakVelocity_mps, randomDetection.peakRange_m, "wo", "LineWidth", 1.2, "MarkerSize", 7);

nexttile;
imagesc(velocityAxis, rangeAxis, RDoptimizedDb);
axis xy; grid on; clim(mapLimits); colorbar;
xlabel("Velocity (m/s)"); ylabel("Range (m)");
title("Fixed-grid ZF-SNR RIS RD map");
hold on;
plot(targets.velocity_mps, targets.range_m, "rx", "LineWidth", 1.5, "MarkerSize", 9);
plot(optimizedDetection.peakVelocity_mps, optimizedDetection.peakRange_m, "wo", "LineWidth", 1.2, "MarkerSize", 7);

nexttile;
methodLabels = categorical(["random", "optimized"], ["random", "optimized"], "Ordinal", true);
bar(methodLabels, [randomDetection.peakDb, optimizedDetection.peakDb]);
grid on; ylabel("Local target peak (dB)");
title("Target peak comparison (+" + compose("%.2f dB", rdPeakImprovementDb) + ")");
ylim([min([randomDetection.peakDb, optimizedDetection.peakDb]) - 5, 0]);

sgtitle("Stage 4 single-target range-Doppler detection");
saveas(fig, pngPath);
savefig(fig, figPath);
close(fig);
end

function textValue = pass_fail(flag)
if flag
    textValue = "PASS";
else
    textValue = "FAIL";
end
end
