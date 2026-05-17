function [rdMap, rangeAxis, velocityAxis, meta] = range_doppler_fft(echoCube, params)
%RANGE_DOPPLER_FFT Compute range-Doppler spectrum from FMCW echoes.
%   Placeholder only. Later implementation must document FFT sizes, windowing,
%   scaling, and axis conventions.

arguments
    echoCube
    params struct
end

unusedInputs = {echoCube, params}; %#ok<NASGU>
rdMap = []; %#ok<NASGU>
rangeAxis = []; %#ok<NASGU>
velocityAxis = []; %#ok<NASGU>
meta = struct(); %#ok<NASGU>

error("RIS_MIMO_FMCW:NotImplemented", ...
    "range_doppler_fft is a placeholder. Implement after FMCW echo model is fixed.");
end
