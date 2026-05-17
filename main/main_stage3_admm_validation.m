%% MAIN_STAGE3_ADMM_VALIDATION
% Stage 3 validation for RIS phase optimization.
%
% Checks:
%   1. Uses the Stage-2 matrix convention:
%      Hsr: Nr x Nt, Hrd: Nr x Nr, Phi: Nr x Nr,
%      Heff = Hsr' * Phi * Hrd * Phi' * Hsr, B: Nt x Nt, v: Nr x 1.
%   2. Computes path gain for random RIS phases.
%   3. Runs optimize_ris_admm to obtain unit-modulus RIS phases.
%   4. Verifies ADMM path gain is not lower than the random initialization.
%   5. Verifies ADMM SNR is not lower than the random initialization.
%   6. Saves convergence data, a text log, and convergence figures.

clear; clc;

projectRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(fullfile(projectRoot, "config"));
addpath(fullfile(projectRoot, "functions"));

params = paper_params();
rng(params.repro.rngSeed + 3, "twister");

logDir = fullfile(projectRoot, "outputs", "logs");
dataDir = fullfile(projectRoot, "outputs", "data");
figureDir = fullfile(projectRoot, "outputs", "figures");
if ~exist(logDir, "dir"), mkdir(logDir); end
if ~exist(dataDir, "dir"), mkdir(dataDir); end
if ~exist(figureDir, "dir"), mkdir(figureDir); end

[Hsr, Hrd, channelMeta] = generate_channels(params);
Nr = params.array.Nr_default;
Nt = params.array.Nt;

assert(isequal(size(Hsr), [Nr, Nt]), "Hsr must be Nr x Nt.");
assert(isequal(size(Hrd), [Nr, Nr]), "Hrd must be Nr x Nr.");

vRandom = exp(1j * 2 * pi * rand(Nr, 1));
[gainRandom, HeffRandom] = compute_path_gain(Hsr, Hrd, vRandom);
[BRandom, zfRandomInfo] = design_precoder_zf(HeffRandom, params.power.txPower_W);
[snrRandomLinear, snrRandomDb] = compute_snr(HeffRandom, BRandom, params.power.noisePower_W);

options = struct();
options.initialV = vRandom;
options.maxIter = 50;
options.tolerance = 1e-7;
options.rho = 1;
options.gradientStep = 0.005;
options.minGradientStep = 1e-6;
options.backtrackingFactor = 0.5;
options.finiteDifferenceStep = 1e-4;
options.verbose = false;

[vAdmm, info] = optimize_ris_admm(Hsr, Hrd, params, options);
assert(isvector(vAdmm) && numel(vAdmm) == Nr, "v_admm must be Nr x 1.");
unitModulusError = max(abs(abs(vAdmm(:)) - 1));
assert(unitModulusError < 1e-10, "v_admm must satisfy unit-modulus constraints.");

[gainAdmm, HeffAdmm] = compute_path_gain(Hsr, Hrd, vAdmm);
[BAdmm, zfAdmmInfo] = design_precoder_zf(HeffAdmm, params.power.txPower_W);
[snrAdmmLinear, snrAdmmDb] = compute_snr(HeffAdmm, BAdmm, params.power.noisePower_W);

toleranceGain = max(1e-18, abs(gainRandom) * 1e-10);
toleranceSnr = max(1e-18, abs(snrRandomLinear) * 1e-10);
assert(gainAdmm + toleranceGain >= gainRandom, ...
    "ADMM path gain must not be lower than the random initialization.");
assert(snrAdmmLinear + toleranceSnr >= snrRandomLinear, ...
    "ADMM SNR must not be lower than the random initialization.");

timestamp = string(datetime("now", "Format", "yyyyMMdd_HHmmss"));
logPath = fullfile(logDir, "stage3_admm_validation_" + timestamp + ".txt");
dataPath = fullfile(dataDir, "stage3_admm_validation_" + timestamp + ".mat");
pngPath = fullfile(figureDir, "stage3_admm_convergence.png");
figPath = fullfile(figureDir, "stage3_admm_convergence.fig");

validation = struct();
validation.timestamp = timestamp;
validation.dimensions.Hsr = size(Hsr);
validation.dimensions.Hrd = size(Hrd);
validation.dimensions.HeffRandom = size(HeffRandom);
validation.dimensions.HeffAdmm = size(HeffAdmm);
validation.dimensions.BRandom = size(BRandom);
validation.dimensions.BAdmm = size(BAdmm);
validation.channelMeta = channelMeta;
validation.zfRandomInfo = zfRandomInfo;
validation.zfAdmmInfo = zfAdmmInfo;
validation.gainRandom = gainRandom;
validation.gainAdmm = gainAdmm;
validation.snrRandomLinear = snrRandomLinear;
validation.snrRandomDb = snrRandomDb;
validation.snrAdmmLinear = snrAdmmLinear;
validation.snrAdmmDb = snrAdmmDb;
validation.unitModulusError = unitModulusError;
validation.info = info;
validation.logPath = logPath;
validation.dataPath = dataPath;
validation.pngPath = pngPath;
validation.figPath = figPath;

save(dataPath, "validation", "params", "Hsr", "Hrd", "vRandom", "vAdmm", ...
    "HeffRandom", "HeffAdmm", "BRandom", "BAdmm");

fig = figure("Visible", "off");
plot(1:numel(info.objectiveHistory), info.objectiveHistory, "LineWidth", 1.5);
grid on;
xlabel("Iteration");
ylabel("Path gain ||Heff||_F^2");
title("Stage 3 ADMM RIS phase convergence");
saveas(fig, pngPath);
savefig(fig, figPath);
close(fig);

logLines = [
    "Stage 3 ADMM validation"
    "Project root: " + string(projectRoot)
    "Random seed: " + string(params.repro.rngSeed + 3)
    "Hsr size: " + mat2str(size(Hsr))
    "Hrd size: " + mat2str(size(Hrd))
    "vRandom size: " + mat2str(size(vRandom))
    "vAdmm size: " + mat2str(size(vAdmm))
    "Unit modulus max error: " + string(unitModulusError)
    "Random path gain: " + string(gainRandom)
    "ADMM path gain: " + string(gainAdmm)
    "Random SNR dB: " + string(snrRandomDb)
    "ADMM SNR dB: " + string(snrAdmmDb)
    "Gain improvement dB: " + string(10 * log10(gainAdmm / gainRandom))
    "SNR improvement dB: " + string(snrAdmmDb - snrRandomDb)
    "ADMM iterations: " + string(info.numIter)
    "ADMM converged: " + string(info.converged)
    "rho: " + string(info.rho)
    "Saved data: " + string(dataPath)
    "Saved PNG: " + string(pngPath)
    "Saved FIG: " + string(figPath)
    "Validation status: passed"
    ];
writelines(logLines, logPath);

fprintf("%s\n", logLines);
