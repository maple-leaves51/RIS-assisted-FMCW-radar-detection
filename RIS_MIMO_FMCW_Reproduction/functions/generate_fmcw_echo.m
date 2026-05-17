function [echoCube, axesInfo, meta] = generate_fmcw_echo(params, channelState)
%GENERATE_FMCW_ECHO Generate multi-target FMCW beat signals.
%   Placeholder only. Later implementation should support the paper's four
%   target ranges/velocities and record whether triangular or sawtooth chirps
%   are used.

arguments
    params struct
    channelState = struct()
end

unusedInputs = {params, channelState}; %#ok<NASGU>
echoCube = []; %#ok<NASGU>
axesInfo = struct(); %#ok<NASGU>
meta = struct(); %#ok<NASGU>

error("RIS_MIMO_FMCW:NotImplemented", ...
    "generate_fmcw_echo is a placeholder. FMCW echo generation is not implemented in round 1.");
end
