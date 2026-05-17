function [vAdmm, info] = optimize_ris_admm(Hsr, Hrd, params, options)
%OPTIMIZE_RIS_ADMM Optimize RIS phases with a projected ADMM framework.
%
%   Inputs:
%       Hsr     - Source/Radar-to-RIS channel, size Nr x Nt.
%       Hrd     - Stage-2 RIS-domain target/return effective channel, size
%                 Nr x Nr.
%       params  - Struct from config/paper_params.m.
%       options - Optional struct with fields:
%                 initialV, maxIter, tolerance, rho, gradientStep,
%                 minGradientStep, backtrackingFactor, finiteDifferenceStep.
%
%   Outputs:
%       vAdmm - Optimized RIS phase vector, size Nr x 1, projected to
%               satisfy |v_i| = 1.
%       info  - Struct with objectiveHistory, primalResidualHistory,
%               dualResidualHistory, numIter, converged, rho, and method.
%
%   Current objective:
%       maximize gain(v) = ||Hsr' * diag(v) * Hrd * diag(v)' * Hsr||_F^2.
%
%   Relation to the paper:
%       The paper's printed ADMM x/u/mu update is derived from a quadratic
%       T-matrix form. Under the current Stage-2 Hrd: Nr x Nr convention,
%       the executable Frobenius path gain is quartic in v. Therefore this
%       implementation keeps the ADMM-style consensus/projection variables
%       x, u, and mu, but uses a finite-difference phase-gradient surrogate
%       for the x-step instead of forcing an inconsistent T matrix.

arguments
    Hsr {mustBeNumeric}
    Hrd {mustBeNumeric}
    params struct
    options struct = struct()
end

Nr = size(Hsr, 1);
if size(Hrd, 1) ~= Nr || size(Hrd, 2) ~= Nr
    error("RIS_MIMO_FMCW:DimensionMismatch", ...
        "Hrd must be Nr x Nr. Got Hrd %s and Nr=%d.", mat2str(size(Hrd)), Nr);
end

maxIter = get_option(options, "maxIter", params.optim.maxIter);
tolerance = get_option(options, "tolerance", min(params.optim.tolerances));
rho = get_option(options, "rho", 1);
gradientStep = get_option(options, "gradientStep", 0.2);
minGradientStep = get_option(options, "minGradientStep", 1e-6);
backtrackingFactor = get_option(options, "backtrackingFactor", 0.5);
finiteDifferenceStep = get_option(options, "finiteDifferenceStep", 1e-4);

if isfield(options, "initialV")
    u = project_unit_modulus(options.initialV(:));
else
    u = exp(1j .* 2 .* pi .* rand(Nr, 1));
end
x = u;
mu = zeros(Nr, 1);

objectiveHistory = zeros(maxIter + 1, 1);
primalResidualHistory = zeros(maxIter, 1);
dualResidualHistory = zeros(maxIter, 1);
stepHistory = zeros(maxIter, 1);

currentGain = compute_path_gain(Hsr, Hrd, u);
bestGain = currentGain;
bestV = u;
objectiveHistory(1) = currentGain;
converged = false;

for iter = 1:maxIter
    uPrev = u;
    xPrev = x;

    phaseGradient = finite_difference_phase_gradient(Hsr, Hrd, u, finiteDifferenceStep);
    gradientScale = max(norm(phaseGradient, inf), eps);
    phaseDirection = phaseGradient ./ gradientScale;

    step = gradientStep;
    theta = angle(u);
    accepted = false;
    candidateU = u;

    while step >= minGradientStep
        candidateU = exp(1j .* (theta + step .* phaseDirection));
        candidateGain = compute_path_gain(Hsr, Hrd, candidateU);
        if candidateGain >= currentGain
            accepted = true;
            break;
        end
        step = step .* backtrackingFactor;
    end

    if ~accepted
        candidateU = u;
        step = 0;
    end

    % Surrogate x-step for the current quartic objective.
    x = candidateU;

    % Paper-style unit-modulus projection step for u.
    u = project_unit_modulus(x - (mu ./ rho));

    % Paper-style dual update for the consensus constraint u = x.
    mu = mu + rho .* (u - x);

    currentGain = compute_path_gain(Hsr, Hrd, u);
    if currentGain > bestGain
        bestGain = currentGain;
        bestV = u;
    end

    objectiveHistory(iter + 1) = currentGain;
    primalResidualHistory(iter) = norm(u - x);
    dualResidualHistory(iter) = rho .* norm(x - xPrev);
    stepHistory(iter) = step;

    relativeObjectiveChange = double(abs(objectiveHistory(iter + 1) - objectiveHistory(iter)) ...
        ./ max(abs(objectiveHistory(iter)), eps));
    consensusResidual = double(primalResidualHistory(iter) + dualResidualHistory(iter));

    if iter > 2 && all(relativeObjectiveChange < tolerance) && all(consensusResidual < sqrt(Nr) * tolerance)
        converged = true;
        break;
    end

    if norm(u - uPrev) < tolerance && all(relativeObjectiveChange < tolerance)
        converged = true;
        break;
    end
end

numIter = iter;
vAdmm = project_unit_modulus(bestV);

info = struct();
info.method = "stage3_projected_phase_admm_surrogate";
info.objective = "maximize ||Hsr'' * diag(v) * Hrd * diag(v)'' * Hsr||_F^2";
info.objectiveHistory = objectiveHistory(1:numIter + 1);
info.primalResidualHistory = primalResidualHistory(1:numIter);
info.dualResidualHistory = dualResidualHistory(1:numIter);
info.stepHistory = stepHistory(1:numIter);
info.numIter = numIter;
info.converged = converged;
info.rho = rho;
info.tolerance = tolerance;
info.finiteDifferenceStep = finiteDifferenceStep;
info.initialObjective = objectiveHistory(1);
info.finalObjective = compute_path_gain(Hsr, Hrd, vAdmm);
info.bestObjective = bestGain;
info.unitModulusMaxError = max(abs(abs(vAdmm) - 1));

end

function value = get_option(options, fieldName, defaultValue)
if isfield(options, fieldName)
    value = options.(fieldName);
else
    value = defaultValue;
end
end

function v = project_unit_modulus(z)
v = exp(1j .* angle(z));
zeroMask = abs(z) < eps;
v(zeroMask) = 1;
end

function grad = finite_difference_phase_gradient(Hsr, Hrd, v, delta)
Nr = numel(v);
theta = angle(v);
grad = zeros(Nr, 1);

for idx = 1:Nr
    thetaPlus = theta;
    thetaMinus = theta;
    thetaPlus(idx) = thetaPlus(idx) + delta;
    thetaMinus(idx) = thetaMinus(idx) - delta;

    vPlus = exp(1j .* thetaPlus);
    vMinus = exp(1j .* thetaMinus);

    gainPlus = compute_path_gain(Hsr, Hrd, vPlus);
    gainMinus = compute_path_gain(Hsr, Hrd, vMinus);
    grad(idx) = (gainPlus - gainMinus) ./ (2 .* delta);
end
end
