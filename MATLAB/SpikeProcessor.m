classdef SpikeProcessor < handle
    % SpikeProcessor - TDT Neural Data Processing Class
    % Processes neural spike data from TDT system and converts to finger angles
    %
    % Usage:
    %   proc = SpikeProcessor();
    %   proc.setDataPath('/path/to/tdt/data');
    %   [spikes, angles] = proc.processWindow(t1, t2);

    properties (Access = public)
        % TDT Data settings
        BlockPath = ''
        StoreName = 'Wav1'
        NumChannels = 59

        % Electrode sets for each finger (based on user code)
        ElectrodeSets = {
            [5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 16]              % Set 1: Thumb
            [17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28]      % Set 2: Index
            [29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40]      % Set 3: Middle
            [41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52]      % Set 4: Ring
            [53, 54, 55, 56, 57, 58, 59, 1, 2, 3, 4, 5]           % Set 5: Pinky
        }

        % Spike detection parameters
        StdMultiplier = 6
        FilterBand = [500, 3000]
        NotchFreqs = [60, 120]

        % Angle conversion parameters
        MinSpikes = 0       % Minimum spike count (maps to 0 degrees)
        MaxSpikes = 2000    % Maximum spike count (maps to 180 degrees)
        MaxAngle = 180      % Maximum servo angle

        % Cached spike data
        SpikeData

        % Ignore channels
        IgnoreChannels = []

        % Real-time / offline mode
        IsRealtime = false
        SynapseAPI           % For real-time TDT access
    end

    methods (Access = public)
        function obj = SpikeProcessor()
            % Constructor
            obj.SpikeData = cell(obj.NumChannels, 1);
        end

        function setDataPath(obj, blockPath)
            % Set TDT data block path
            obj.BlockPath = blockPath;
            fprintf('Data path set to: %s\n', blockPath);
        end

        function setStoreName(obj, storeName)
            % Set TDT store name
            obj.StoreName = storeName;
        end

        function setIgnoreChannels(obj, channels)
            % Set channels to ignore
            obj.IgnoreChannels = channels;
        end

        function enableRealtime(obj, synapseIP)
            % Enable real-time mode with Synapse connection
            obj.IsRealtime = true;
            try
                % Connect to Synapse
                obj.SynapseAPI = SynapseAPI('syn');
                obj.SynapseAPI.connect(synapseIP);
                fprintf('Connected to Synapse at %s\n', synapseIP);
            catch ME
                warning('Could not connect to Synapse: %s', ME.message);
                obj.IsRealtime = false;
            end
        end

        function loadAllData(obj, t1, t2)
            % Load and process spike data for all channels
            % t1, t2: time range in seconds

            if isempty(obj.BlockPath) && ~obj.IsRealtime
                error('Data path not set. Call setDataPath() first.');
            end

            fprintf('Loading spike data from %.1f to %.1f seconds...\n', t1, t2);

            for ch = 1:obj.NumChannels
                if ismember(ch, obj.IgnoreChannels)
                    obj.SpikeData{ch} = [];
                    continue;
                end

                try
                    obj.SpikeData{ch} = obj.detectSpikes(ch, t1, t2);
                catch ME
                    fprintf('Error processing channel %d: %s\n', ch, ME.message);
                    obj.SpikeData{ch} = [];
                end
            end

            fprintf('Spike detection complete.\n');
        end

        function [spikeCounts, angles] = processWindow(obj, t1, t2)
            % Process a time window and return spike counts and angles
            % t1, t2: time window in seconds
            % Returns:
            %   spikeCounts: 1x5 array of spike counts per finger
            %   angles: 1x5 array of servo angles per finger

            spikeCounts = zeros(1, 5);

            % Count spikes for each electrode set
            for setIdx = 1:5
                channels = obj.ElectrodeSets{setIdx};

                % Filter valid channels
                validChannels = [];
                for ch = channels
                    if ch >= 1 && ch <= obj.NumChannels && ~ismember(ch, obj.IgnoreChannels)
                        validChannels = [validChannels, ch];
                    end
                end

                totalSpikes = 0;
                for ch = validChannels
                    try
                        if obj.IsRealtime
                            % Real-time: get current spike data
                            spikeTimesInWindow = obj.getRealtimeSpikes(ch, t1, t2);
                        else
                            % Offline: detect spikes in window
                            spikeTimesInWindow = obj.detectSpikes(ch, t1, t2);
                        end
                        if ~isempty(spikeTimesInWindow)
                            totalSpikes = totalSpikes + length(spikeTimesInWindow);
                        end
                    catch
                        % Skip failed channels
                    end
                end

                spikeCounts(setIdx) = totalSpikes;
            end

            % Convert spike counts to angles
            angles = obj.spikesToAngles(spikeCounts);
        end

        function angles = spikesToAngles(obj, spikeCounts)
            % Convert spike counts to servo angles
            % Linear mapping from [MinSpikes, MaxSpikes] to [MaxAngle, 0]
            % 180 = extended (펴기), 0 = flexed (굽히기)

            angles = zeros(1, 5);
            for i = 1:5
                % Normalize spike count
                normalizedCount = (spikeCounts(i) - obj.MinSpikes) / (obj.MaxSpikes - obj.MinSpikes);
                normalizedCount = max(0, min(1, normalizedCount));  % Clamp to [0, 1]

                % Map to angle (inverted: more spikes = lower angle = more flexed)
                angles(i) = round((1 - normalizedCount) * obj.MaxAngle);
            end
        end

        function setAngleMapping(obj, minSpikes, maxSpikes, maxAngle)
            % Configure spike-to-angle mapping parameters
            obj.MinSpikes = minSpikes;
            obj.MaxSpikes = maxSpikes;
            obj.MaxAngle = maxAngle;
        end

        function spikeTimes = detectSpikes(obj, channel, t1, t2)
            % Detect spikes in a channel for given time range
            % Uses TDT SDK functions

            spikeTimes = [];

            % Validate channel
            if channel < 1 || channel > obj.NumChannels
                return;
            end

            if ismember(channel, obj.IgnoreChannels)
                return;
            end

            if obj.IsRealtime
                spikeTimes = obj.getRealtimeSpikes(channel, t1, t2);
                return;
            end

            try
                % Load raw data from TDT
                data = TDTbin2mat(obj.BlockPath, ...
                    'STORE', obj.StoreName, ...
                    'CHANNEL', channel, ...
                    'T1', t1, ...
                    'T2', t2);

                % Check if data is valid
                if ~isfield(data, 'streams') || ~isfield(data.streams, obj.StoreName)
                    return;
                end

                % Apply bandpass filter
                filteredData = TDTdigitalfilter(data, obj.StoreName, ...
                    obj.FilterBand, 'NOTCH', obj.NotchFreqs);

                % Threshold-based spike detection
                threshData = TDTthresh(filteredData, obj.StoreName, ...
                    'MODE', 'auto', ...
                    'NPTS', 50, ...
                    'POLARITY', -1, ...
                    'TAU', 5, ...
                    'STD', obj.StdMultiplier, ...
                    'OVERLAP', 0);

                % Extract spike times
                if isfield(threshData, 'snips') && isfield(threshData.snips, 'Snip') && isfield(threshData.snips.Snip, 'ts')
                    spikeTimes = threshData.snips.Snip.ts';
                end

            catch ME
                % Silently skip failed channels (don't spam warnings)
            end
        end

        function spikeTimes = getRealtimeSpikes(obj, channel, t1, t2)
            % Get spike data in real-time from Synapse
            try
                % Use SynapseLive or SynapseAPI
                data = obj.SynapseAPI.getSnip(obj.StoreName, channel, t1, t2);
                if ~isempty(data) && isfield(data, 'ts')
                    spikeTimes = data.ts;
                else
                    spikeTimes = [];
                end
            catch
                spikeTimes = [];
            end
        end

        function summary = getChannelSummary(obj)
            % Get summary statistics for all channels
            summary = struct();
            summary.TotalSpikes = zeros(obj.NumChannels, 1);
            summary.MeanRate = zeros(obj.NumChannels, 1);

            for ch = 1:obj.NumChannels
                if ~isempty(obj.SpikeData{ch})
                    summary.TotalSpikes(ch) = length(obj.SpikeData{ch});
                end
            end
        end

        function setSpikeCounts = getSetSpikeCounts(obj, t1, t2)
            % Get spike counts organized by electrode set
            setSpikeCounts = zeros(5, 1);

            for setIdx = 1:5
                channels = obj.ElectrodeSets{setIdx};
                channels = channels(channels <= obj.NumChannels);
                channels = setdiff(channels, obj.IgnoreChannels);

                for ch = channels
                    if ~isempty(obj.SpikeData{ch})
                        spikes = obj.SpikeData{ch};
                        spikesInWindow = sum(spikes >= t1 & spikes <= t2);
                        setSpikeCounts(setIdx) = setSpikeCounts(setIdx) + spikesInWindow;
                    end
                end
            end
        end
    end

    methods (Access = private)
        function validateChannel(obj, channel)
            % Validate channel number
            if channel < 1 || channel > obj.NumChannels
                error('Invalid channel number: %d (must be 1-%d)', channel, obj.NumChannels);
            end
        end
    end

    methods (Static)
        function angles = demoSpikesToAngles(spikeCounts)
            % Static demo function for spike-to-angle conversion
            % For testing without TDT hardware
            % 180 = extended (펴기), 0 = flexed (굽히기)
            minSpikes = 0;
            maxSpikes = 2000;
            maxAngle = 180;

            angles = zeros(1, 5);
            for i = 1:5
                normalizedCount = (spikeCounts(i) - minSpikes) / (maxSpikes - minSpikes);
                normalizedCount = max(0, min(1, normalizedCount));
                angles(i) = round((1 - normalizedCount) * maxAngle);
            end
        end
    end
end
