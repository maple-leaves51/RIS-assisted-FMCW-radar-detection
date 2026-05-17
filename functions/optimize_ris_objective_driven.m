function [vBest, info] = optimize_ris_objective_driven(Hsr, Hrd, params, objectiveType, options)
%OPTIMIZE_RIS_OBJECTIVE_DRIVEN Optimize RIS phases for an explicit objective.
%
%   Inputs:
%       Hsr           - Source/Radar-to-RIS channel, size Nr x Nt.
%       Hrd           - RIS-domain target/return effective channel, size Nr x Nr.
%       params        - Struct from config/paper_params.m.
%       objectiveType - Objective passed to evaluate_ris_objective:
%                       "path_gain", "zf_snr", or
%                       "zf_snr_with_condition_penalty".
%                       Default is "zf_snr".
%       options       - Optional struct:
%                       initialV, numStarts, maxSweeps, phaseGridSize,
%                       tolerance, conditionPenaltyAlpha, rngSeed.
%
%   Outputs:
%       vBest - Best unit-modulus RIS phase vector, size Nr x 1.
%       info  - Struct with objectiveHistory, pathGainHistory, snrDbHistory,
%               condHistory, stepHistory, numIter, converged, method, and
%               objectiveType.
%
%   Method:
%       Multi-start coordinate phase search. For each coordinate, the method
%       evaluates a fixed phase grid and accepts the phase that maximizes the
%       selected objective. This is not ADMM. It is an engineering optimizer
%       whose optimized objective is exactly the requested objectiveType.

arguments
    Hsr {mustBeNumeric}
    Hrd {mustBeNumeric}
    params struct
    objectiveType {mustBeTextScalar} = "zf_snr"
    options struct = struct()
end

objectiveType = string(objectiveType);
Nr = size(Hsr, 1);
if size(Hrd, 1) ~= Nr || size(Hrd, 2) ~= Nr
    error("RIS_MIMO_FMCW:DimensionMismatch", ...
        "Hrd must be Nr x Nr. Got Hrd %s and Nr=%d.", mat2str(size(Hrd)), Nr);
end

numStarts = get_option(options, "numStarts", 5);
maxSweeps = get_option(options, "maxSweeps", 12);
phaseGridSize = get_option(options, "phaseGridSize", 24);
tolerance = get_option(options, "tolerance", 1e-5);
conditionPenaltyAlpha = get_option(options, "conditionPenaltyAlpha", 0.05);
objectiveOptions = struct("conditionPenaltyAlpha", conditionPenaltyAlpha);

if isfield(options, "rngSeed")
    rng(options.rngSeed, "twister");
end

initialCandidates = cell(numStarts, 1);
if isfield(options, "initialV")
    initialCandidates{1} = project_unit_modulus(options.initialV(:));
    firstRandomStart = 2;
else
    firstRandomStart = 1;
end
for startIdx = firstRandomStart:numStarts
    initialCandidates{startIdx} = exp(1j .* 2 .* pi .* rand(Nr, 1));
end

maxRecords = numStarts * maxSweeps + 1;
objectiveHistory = zeros(maxRecords, 1);
pathGainHistory = zeros(maxRecords, 1);
snrDbHistory = zeros(maxRecords, 1);
condHistory = zeros(maxRecords, 1);
stepHistory = zeros(maxRecords, 1);
recordIdx = 0;

bestObjective = -Inf;
bestV = initialCandidates{1};
bestMetrics = struct();
convergedAny = false;
phaseGrid = linspace(0, 2*pi, phaseGridSize + 1).';
phaseGrid(end) = [];

for startIdx = 1:numStarts
    v = initialCandidates{startIdx};
    currentObjective = evaluate_ris_objective( ...
        Hsr, Hrd, v, params, objectiveType, objectiveOptions);
    previousSweepObjective = currentObjective;

    for sweepIdx = 1:maxSweeps
        acceptedUpdates = 0;
        for elementIdx = 1:Nr
            bestLocalObjective = currentObjective;
            bestLocalPhase = v(elementIdx);

            for phaseIdx = 1:numel(phaseGrid)
                candidateV = v;
                candidateV(elementIdx) = exp(1j .* phaseGrid(phaseIdx));
                candidateObjective = evaluate_ris_objective( ...
                    Hsr, Hrd, candidateV, params, objectiveType, objectiveOptions);

                if candidateObjective > bestLocalObjective
                    bestLocalObjective = candidateObjective;
                    bestLocalPhase = candidateV(elementIdx);
                end
            end

            if bestLocalObjective > currentObjective
                v(elementIdx) = bestLocalPhase;
                currentObjective = bestLocalObjective;
                acceptedUpdates = acceptedUpdates + 1;
            end
        end

        [currentObjective, currentMetrics] = evaluate_ris_objective( ...
            Hsr, Hrd, v, params, objectiveType, objectiveOptions);

        recordIdx = recordIdx + 1;
        objectiveHistory(recordIdx) = currentObjective;
        pathGainHistory(recordIdx) = currentMetrics.pathGain;
        snrDbHistory(recordIdx) = currentMetrics.snrDb;
        condHistory(recordIdx) = currentMetrics.condHeff;
        stepHistory(recordIdx) = acceptedUpdates;

        if currentObjective > bestObjective
            bestObjective = currentObjective;
            bestV = v;
            bestMetrics = currentMetrics;
        end

        relativeImprovement = double(abs(currentObjective - previousSweepObjective) ...
            ./ max(abs(previousSweepObjective), eps));
        if all(relativeImprovement < tolerance) || acceptedUpdates == 0
            convergedAny = true;
            break;
        end
        previousSweepObjective = currentObjective;
    end
end

vBest = project_unit_modulus(bestV);
[finalObjective, finalMetrics] = evaluate_ris_objective( ...
    Hsr, Hrd, vBest, params, objectiveType, objectiveOptions);

info = struct();
info.method = "multi_start_coordinate_phase_search";
info.objectiveType = objectiveType;
info.objectiveHistory = objectiveHistory(1:recordIdx);
info.pathGainHistory = pathGainHistory(1:recordIdx);
info.snrDbHistory = snrDbHistory(1:recordIdx);
info.condHistory = condHistory(1:recordIdx);
info.stepHistory = stepHistory(1:recordIdx);
info.numIter = recordIdx;
info.converged = convergedAny;
info.numStarts = numStarts;
info.maxSweeps = maxSweeps;
info.phaseGridSize = phaseGridSize;
info.conditionPenaltyAlpha = conditionPenaltyAlpha;
info.initialObjective = info.objectiveHistory(1);
info.finalObjective = finalObjective;
info.finalMetrics = finalMetrics;
info.bestMetrics = bestMetrics;
info.unitModulusMaxError = max(abs(abs(vBest) - 1));
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
