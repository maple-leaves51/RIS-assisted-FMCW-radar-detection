%% MAIN_STAGE3_ADMM_VALIDATION
% Stage 3 validation for RIS phase optimization.
%
% This script compares three RIS phase choices:
%   1. random phase;
%   2. quadratic ADMM approximation phase from optimize_ris_admm.m;
%   3. finite-difference surrogate phase from optimize_ris_surrogate.m.
%
% Fixed matrix convention:
%   Hsr: Nr x Nt
%   Hrd: Nr x Nr
%   Phi = diag(v): Nr x Nr
%   Heff = Hsr' * Phi * Hrd * Phi' * Hsr
%   B: Nt x Nt
%   v: Nr x 1, |v_i| = 1

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
randomMetrics = evaluate_phase("random", Hsr, Hrd, vRandom, params);

admmOptions = struct();
admmOptions.initialV = vRandom;
admmOptions.maxIter = 500;
admmOptions.tolerance = 1e-7;
admmOptions.rho = 1;

[vAdmm, admmInfo] = optimize_ris_admm(Hsr, Hrd, params, admmOptions);
admmMetrics = evaluate_phase("quadratic_admm", Hsr, Hrd, vAdmm, params);

surrogateOptions = struct();
surrogateOptions.initialV = vRandom;
surrogateOptions.maxIter = 50;
surrogateOptions.tolerance = 1e-7;
surrogateOptions.gradientStep = 0.005;
surrogateOptions.minGradientStep = 1e-6;
surrogateOptions.backtrackingFactor = 0.5;
surrogateOptions.finiteDifferenceStep = 1e-4;

[vSurrogate, surrogateInfo] = optimize_ris_surrogate(Hsr, Hrd, params, surrogateOptions);
surrogateMetrics = evaluate_phase("surrogate", Hsr, Hrd, vSurrogate, params);

assert(admmMetrics.unitModulusError < 1e-10, "ADMM phase must satisfy unit-modulus constraints.");
assert(admmMetrics.gain + max(1e-18, abs(randomMetrics.gain) * 1e-10) >= randomMetrics.gain, ...
    "ADMM path gain must not be lower than random phase.");
assert(admmMetrics.snrLinear + max(1e-18, abs(randomMetrics.snrLinear) * 1e-10) >= randomMetrics.snrLinear, ...
    "ADMM SNR must not be lower than random phase.");

timestamp = string(datetime("now", "Format", "yyyyMMdd_HHmmss"));
logPath = fullfile(logDir, "stage3_admm_validation_" + timestamp + ".txt");
dataPath = fullfile(dataDir, "stage3_admm_validation_" + timestamp + ".mat");
pngPath = fullfile(figureDir, "stage3_admm_convergence.png");
figPath = fullfile(figureDir, "stage3_admm_convergence.fig");

validation = struct();
validation.timestamp = timestamp;
validation.dimensions.Hsr = size(Hsr);
validation.dimensions.Hrd = size(Hrd);
validation.channelMeta = channelMeta;
validation.random = randomMetrics;
validation.admm = admmMetrics;
validation.surrogate = surrogateMetrics;
validation.admmInfo = admmInfo;
validation.surrogateInfo = surrogateInfo;
validation.logPath = logPath;
validation.dataPath = dataPath;
validation.pngPath = pngPath;
validation.figPath = figPath;

save(dataPath, "validation", "params", "Hsr", "Hrd", ...
    "vRandom", "vAdmm", "vSurrogate");

fig = figure("Visible", "off");
plot(0:admmInfo.numIter, admmInfo.objectiveHistory, "LineWidth", 1.5);
hold on;
plot(0:surrogateInfo.numIter, surrogateInfo.objectiveHistory, "--", "LineWidth", 1.2);
grid on;
xlabel("Iteration");
ylabel("Path gain ||Heff||_F^2");
title("Stage 3 RIS phase optimization convergence");
legend("Quadratic ADMM approximation", "Finite-difference surrogate", "Location", "best");
saveas(fig, pngPath);
savefig(fig, figPath);
close(fig);

logLines = [
    "Stage 3 ADMM validation"
    "Project root: " + string(projectRoot)
    "Random seed: " + string(params.repro.rngSeed + 3)
    "Hsr size: " + mat2str(size(Hsr))
    "Hrd size: " + mat2str(size(Hrd))
    "ADMM method: " + string(admmInfo.method)
    "ADMM uses finite difference gradient: " + string(admmInfo.usesFiniteDifferenceGradient)
    "Random path gain: " + string(randomMetrics.gain)
    "ADMM path gain: " + string(admmMetrics.gain)
    "Surrogate path gain: " + string(surrogateMetrics.gain)
    "ADMM gain improvement dB: " + string(10 * log10(admmMetrics.gain / randomMetrics.gain))
    "Surrogate gain improvement dB: " + string(10 * log10(surrogateMetrics.gain / randomMetrics.gain))
    "Random SNR dB: " + string(randomMetrics.snrDb)
    "ADMM SNR dB: " + string(admmMetrics.snrDb)
    "Surrogate SNR dB: " + string(surrogateMetrics.snrDb)
    "ADMM SNR improvement dB: " + string(admmMetrics.snrDb - randomMetrics.snrDb)
    "Surrogate SNR improvement dB: " + string(surrogateMetrics.snrDb - randomMetrics.snrDb)
    "ADMM unit modulus max error: " + string(admmMetrics.unitModulusError)
    "Surrogate unit modulus max error: " + string(surrogateMetrics.unitModulusError)
    "ADMM final primal residual: " + string(admmInfo.primalResidualHistory(end))
    "ADMM final dual residual: " + string(admmInfo.dualResidualHistory(end))
    "ADMM iterations: " + string(admmInfo.numIter)
    "ADMM converged: " + string(admmInfo.converged)
    "ADMM rho: " + string(admmInfo.rho)
    "Surrogate iterations: " + string(surrogateInfo.numIter)
    "Surrogate converged: " + string(surrogateInfo.converged)
    "Saved data: " + string(dataPath)
    "Saved PNG: " + string(pngPath)
    "Saved FIG: " + string(figPath)
    "Validation status: passed"
    ];
writelines(logLines, logPath);

fprintf("%s\n", logLines);

function metrics = evaluate_phase(name, Hsr, Hrd, v, params)
[gain, Heff] = compute_path_gain(Hsr, Hrd, v);
[B, zfInfo] = design_precoder_zf(Heff, params.power.txPower_W);
[snrLinear, snrDb] = compute_snr(Heff, B, params.power.noisePower_W);

metrics = struct();
metrics.name = name;
metrics.gain = gain;
metrics.snrLinear = snrLinear;
metrics.snrDb = snrDb;
metrics.unitModulusError = max(abs(abs(v(:)) - 1));
metrics.HeffSize = size(Heff);
metrics.BSize = size(B);
metrics.zfInfo = zfInfo;
end
