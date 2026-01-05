% createSampleData.m - Create sample CSV data for testing
%
% This script creates a sample CSV file with simulated spike data
% that can be used to test the Robot Hand GUI in CSV mode.
%
% Usage:
%   >> createSampleData
%   >> createSampleData('custom_output.csv')

function createSampleData(outputPath)
    if nargin < 1
        outputPath = fullfile(fileparts(mfilename('fullpath')), ...
            '..', 'data', 'sample_spike_data.csv');
    end

    % Ensure output directory exists
    [parentDir, ~, ~] = fileparts(outputPath);
    if ~exist(parentDir, 'dir')
        mkdir(parentDir);
    end

    % Parameters
    totalTime = 420;      % 7 minutes
    windowSize = 5;       % 5 second windows
    numRecords = totalTime / windowSize;

    % Time column
    times = (0:numRecords-1)' * windowSize;

    % Finger names
    fingerNames = {'Thumb', 'Index', 'Middle', 'Ring', 'Pinky'};

    % Spike count ranges for each finger (realistic ranges)
    spikeRanges = [
        200, 800;    % Thumb
        400, 1500;   % Index
        300, 1000;   % Middle
        100, 600;    % Ring
        300, 1200;   % Pinky
    ];

    % Generate data
    rng(42);  % Reproducible random data

    data = table();
    data.Time = times;

    for i = 1:5
        % Generate spike counts with some temporal correlation
        baseSpikes = randi(spikeRanges(i, :), numRecords, 1);

        % Add smooth variation
        variation = smooth(randn(numRecords, 1) * 100, 5);
        spikeCounts = round(baseSpikes + variation);
        spikeCounts = max(spikeRanges(i, 1), min(spikeRanges(i, 2), spikeCounts));

        % Calculate angles from spike counts
        normalized = (spikeCounts - spikeRanges(i, 1)) / ...
            (spikeRanges(i, 2) - spikeRanges(i, 1));
        angles = round(normalized * 180);
        angles = max(0, min(180, angles));

        % Add to table
        data.([fingerNames{i} '_Spike']) = spikeCounts;
        data.([fingerNames{i} '_Angle']) = angles;
    end

    % Save to CSV
    writetable(data, outputPath);

    fprintf('Sample data created: %s\n', outputPath);
    fprintf('Records: %d\n', numRecords);
    fprintf('Time range: 0 - %d seconds\n', totalTime);

    % Display preview
    fprintf('\nData preview:\n');
    disp(head(data, 5));
end

function y = smooth(x, span)
    % Simple moving average smoothing
    n = length(x);
    y = zeros(size(x));
    halfSpan = floor(span / 2);

    for i = 1:n
        startIdx = max(1, i - halfSpan);
        endIdx = min(n, i + halfSpan);
        y(i) = mean(x(startIdx:endIdx));
    end
end
