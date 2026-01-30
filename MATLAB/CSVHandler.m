classdef CSVHandler < handle
    % CSVHandler - Excel File Read/Write Handler
    % Manages reading spike data from Excel and writing log files
    %
    % Excel Format:
    %   Time, Thumb_Spike, Thumb_Angle, Index_Spike, Index_Angle, ...
    %   0,    342,         30,          1254,        120,         ...
    %   5,    287,         20,          1189,        110,         ...
    %
    % Usage:
    %   csv = CSVHandler();
    %   csv.loadFile('spike_data.xlsx');
    %   [spikes, angles] = csv.getDataAtTime(10);
    %   csv.saveToFile('output_log.xlsx');

    properties (Access = public)
        % File paths
        InputFilePath = ''
        OutputFilePath = ''

        % Data storage
        Data = []           % Table with all CSV data
        TimeColumn = []     % Time values
        SpikeData = []      % Nx5 matrix of spike counts
        AngleData = []      % Nx5 matrix of angles

        % Recording buffer for logging
        RecordBuffer = []   % Struct array for recording

        % Column names
        FingerNames = {'Thumb', 'Index', 'Middle', 'Ring', 'Pinky'}

        % Status
        IsLoaded = false
        RecordCount = 0
    end

    methods (Access = public)
        function obj = CSVHandler()
            % Constructor
            obj.RecordBuffer = struct('Time', {}, ...
                'Thumb_Spike', {}, 'Thumb_Angle', {}, ...
                'Index_Spike', {}, 'Index_Angle', {}, ...
                'Middle_Spike', {}, 'Middle_Angle', {}, ...
                'Ring_Spike', {}, 'Ring_Angle', {}, ...
                'Pinky_Spike', {}, 'Pinky_Angle', {});
        end

        function success = loadFile(obj, filePath)
            % Load CSV file
            success = false;

            if ~exist(filePath, 'file')
                error('File not found: %s', filePath);
            end

            try
                obj.Data = readtable(filePath);
                obj.InputFilePath = filePath;

                % Extract columns
                obj.parseData();

                obj.IsLoaded = true;
                obj.RecordCount = height(obj.Data);
                success = true;

                fprintf('Loaded %d records from %s\n', obj.RecordCount, filePath);

            catch ME
                error('Failed to load Excel: %s', ME.message);
            end
        end

        function [spikeCounts, angles] = getDataAtTime(obj, targetTime)
            % Get spike counts and angles for a specific time
            % Uses nearest neighbor interpolation

            if ~obj.IsLoaded
                error('No CSV file loaded. Call loadFile() first.');
            end

            spikeCounts = zeros(1, 5);
            angles = zeros(1, 5);

            % Find nearest time index
            [~, idx] = min(abs(obj.TimeColumn - targetTime));

            if idx > 0 && idx <= length(obj.TimeColumn)
                spikeCounts = obj.SpikeData(idx, :);
                angles = obj.AngleData(idx, :);
            end
        end

        function [spikeCounts, angles] = getDataAtIndex(obj, index)
            % Get data at specific index
            if ~obj.IsLoaded || index < 1 || index > obj.RecordCount
                spikeCounts = zeros(1, 5);
                angles = zeros(1, 5);
                return;
            end

            spikeCounts = obj.SpikeData(index, :);
            angles = obj.AngleData(index, :);
        end

        function totalTime = getTotalTime(obj)
            % Get total time span of the data
            if obj.IsLoaded && ~isempty(obj.TimeColumn)
                totalTime = max(obj.TimeColumn);
            else
                totalTime = 0;
            end
        end

        function count = getRecordCount(obj)
            % Get number of records
            count = obj.RecordCount;
        end

        function addRecord(obj, time, spikeCounts, angles)
            % Add a new record to the buffer (for logging)
            newRecord = struct();
            newRecord.Time = time;
            newRecord.Thumb_Spike = spikeCounts(1);
            newRecord.Thumb_Angle = angles(1);
            newRecord.Index_Spike = spikeCounts(2);
            newRecord.Index_Angle = angles(2);
            newRecord.Middle_Spike = spikeCounts(3);
            newRecord.Middle_Angle = angles(3);
            newRecord.Ring_Spike = spikeCounts(4);
            newRecord.Ring_Angle = angles(4);
            newRecord.Pinky_Spike = spikeCounts(5);
            newRecord.Pinky_Angle = angles(5);

            obj.RecordBuffer(end + 1) = newRecord;
        end

        function clearBuffer(obj)
            % Clear the recording buffer
            obj.RecordBuffer = struct('Time', {}, ...
                'Thumb_Spike', {}, 'Thumb_Angle', {}, ...
                'Index_Spike', {}, 'Index_Angle', {}, ...
                'Middle_Spike', {}, 'Middle_Angle', {}, ...
                'Ring_Spike', {}, 'Ring_Angle', {}, ...
                'Pinky_Spike', {}, 'Pinky_Angle', {});
        end

        function success = saveToFile(obj, filePath)
            % Save recording buffer to CSV file
            success = false;

            if isempty(obj.RecordBuffer)
                warning('No data to save');
                return;
            end

            try
                % Ensure directory exists
                [parentDir, ~, ~] = fileparts(filePath);
                if ~isempty(parentDir) && ~exist(parentDir, 'dir')
                    mkdir(parentDir);
                end

                % Convert struct array to table
                T = struct2table(obj.RecordBuffer);

                % Write to file
                writetable(T, filePath);
                obj.OutputFilePath = filePath;

                fprintf('Saved %d records to %s\n', length(obj.RecordBuffer), filePath);
                success = true;

            catch ME
                warning('Failed to save Excel: %s', ME.message);
            end
        end

        function success = exportFromSpikeProcessor(obj, spikeProc, t1, t2, windowSize, outputPath)
            % Export spike data from SpikeProcessor to CSV
            % Useful for creating CSV files from TDT data

            success = false;

            timeSteps = t1:windowSize:t2;
            obj.clearBuffer();

            for t = timeSteps
                tEnd = min(t + windowSize, t2);
                [spikes, angles] = spikeProc.processWindow(t, tEnd);
                obj.addRecord(t, spikes, angles);
            end

            success = obj.saveToFile(outputPath);
        end

        function displaySummary(obj)
            % Display summary of loaded data
            if ~obj.IsLoaded
                fprintf('No data loaded.\n');
                return;
            end

            fprintf('\n=== Excel Data Summary ===\n');
            fprintf('File: %s\n', obj.InputFilePath);
            fprintf('Records: %d\n', obj.RecordCount);
            fprintf('Time range: %.1f - %.1f seconds\n', ...
                min(obj.TimeColumn), max(obj.TimeColumn));

            fprintf('\nSpike count ranges:\n');
            for i = 1:5
                fprintf('  %s: %d - %d\n', obj.FingerNames{i}, ...
                    min(obj.SpikeData(:, i)), max(obj.SpikeData(:, i)));
            end

            fprintf('\nAngle ranges:\n');
            for i = 1:5
                fprintf('  %s: %d - %d degrees\n', obj.FingerNames{i}, ...
                    min(obj.AngleData(:, i)), max(obj.AngleData(:, i)));
            end
        end
    end

    methods (Access = private)
        function parseData(obj)
            % Parse loaded data table into arrays

            varNames = obj.Data.Properties.VariableNames;

            % Find time column
            timeColIdx = find(strcmpi(varNames, 'Time') | ...
                strcmpi(varNames, 'TimeStart_s') | ...
                strcmpi(varNames, 'Timestamp'), 1);

            if isempty(timeColIdx)
                % Assume first column is time
                timeColIdx = 1;
            end

            obj.TimeColumn = obj.Data{:, timeColIdx};

            % Initialize data arrays
            numRows = height(obj.Data);
            obj.SpikeData = zeros(numRows, 5);
            obj.AngleData = zeros(numRows, 5);

            % Try to find spike and angle columns for each finger
            for i = 1:5
                fingerName = obj.FingerNames{i};

                % Look for spike column
                spikeCol = find(contains(varNames, [fingerName '_Spike'], 'IgnoreCase', true) | ...
                    contains(varNames, [fingerName 'Spike'], 'IgnoreCase', true) | ...
                    strcmpi(varNames, sprintf('Set%d_SpikeCount', i)), 1);

                if ~isempty(spikeCol)
                    obj.SpikeData(:, i) = obj.Data{:, spikeCol};
                end

                % Look for angle column
                angleCol = find(contains(varNames, [fingerName '_Angle'], 'IgnoreCase', true) | ...
                    contains(varNames, [fingerName 'Angle'], 'IgnoreCase', true), 1);

                if ~isempty(angleCol)
                    obj.AngleData(:, i) = obj.Data{:, angleCol};
                end
            end

            % If no angle data found, compute from spikes
            if all(obj.AngleData(:) == 0) && any(obj.SpikeData(:) > 0)
                obj.AngleData = obj.computeAnglesFromSpikes(obj.SpikeData);
            end
        end

        function angles = computeAnglesFromSpikes(~, spikes)
            % Convert spike counts to angles using linear mapping
            % 180 = extended (펴기), 0 = flexed (굽히기)
            minSpikes = 0;
            maxSpikes = 2000;
            maxAngle = 180;

            normalized = (spikes - minSpikes) / (maxSpikes - minSpikes);
            normalized = max(0, min(1, normalized));
            angles = round((1 - normalized) * maxAngle);
        end
    end

    methods (Static)
        function createSampleExcel(filePath)
            % Create a sample Excel file for testing

            numRecords = 84;  % 420 seconds / 5 second intervals
            times = (0:numRecords-1)' * 5;

            % Generate random spike counts
            rng(42);  % For reproducibility
            spikeRanges = [200, 800; 400, 1500; 300, 1000; 100, 600; 300, 1200];

            data = table();
            data.Time = times;

            fingerNames = {'Thumb', 'Index', 'Middle', 'Ring', 'Pinky'};

            for i = 1:5
                spikeCounts = randi(spikeRanges(i, :), numRecords, 1);
                angles = round((spikeCounts - spikeRanges(i,1)) / ...
                    (spikeRanges(i,2) - spikeRanges(i,1)) * 180);
                angles = max(0, min(180, angles));

                data.([fingerNames{i} '_Spike']) = spikeCounts;
                data.([fingerNames{i} '_Angle']) = angles;
            end

            writetable(data, filePath);
            fprintf('Created sample Excel: %s\n', filePath);
        end
    end
end
