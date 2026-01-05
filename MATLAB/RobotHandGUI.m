classdef RobotHandGUI < handle
    % RobotHandGUI - Neural Robot Hand Control System GUI
    % MATLAB GUI Application for controlling a robot hand using neural signals
    %
    % Usage:
    %   app = RobotHandGUI();
    %
    % Modes:
    %   1. Real-time mode: Process TDT neural data in real-time
    %   2. CSV mode: Replay recorded spike data from CSV files

    properties (Access = public)
        % UI Components
        Figure
        ModePanel
        ControlPanel
        FingerPanel
        TimelinePanel
        LogPanel

        % Mode selection
        RealtimeRadio
        CSVRadio
        CSVFileButton
        CSVFilePath

        % Control buttons
        StartButton
        PauseButton
        StopButton
        ResetButton

        % Arduino connection
        PortDropdown
        ConnectionStatus

        % Finger display components (5 fingers)
        FingerBars
        FingerAngleLabels
        FingerSpikeLabels
        FingerNames = {'Thumb', 'Index', 'Middle', 'Ring', 'Pinky'};
        FingerNamesKR = {'Thumb', 'Index', 'Middle', 'Ring', 'Pinky'};

        % Timeline components
        ProgressBar
        TimeLabel
        ProgressLabel

        % Log display
        LogTextArea

        % Processing objects
        SpikeProc       % SpikeProcessor instance
        ArduinoConn     % ArduinoComm instance
        CSVHandler      % CSVHandler instance

        % State variables
        IsRunning = false
        IsPaused = false
        CurrentMode = 'realtime'  % 'realtime' or 'csv'
        CurrentTime = 0
        TotalTime = 420           % Default 7 minutes
        WindowSize = 5            % 5 second window
        UpdateInterval = 0.1      % 아두이노 전송 간격 (초)

        % Timer for real-time processing
        ProcessingTimer

        % Data storage
        CurrentAngles = [0, 0, 0, 0, 0]
        CurrentSpikes = [0, 0, 0, 0, 0]

        % Settings (paths are auto-detected)
        SDKPath = ''
        DataPath = ''
        ProjectRoot = ''
    end

    methods (Access = public)
        function obj = RobotHandGUI()
            % Constructor - Create and display the GUI

            % Set project root (where this file is located)
            obj.ProjectRoot = fileparts(fileparts(mfilename('fullpath')));

            % Auto-detect TDT SDK path
            obj.SDKPath = obj.findTDTSDK();

            obj.createFigure();
            obj.createModePanel();
            obj.createControlPanel();
            obj.createFingerPanel();
            obj.createTimelinePanel();
            obj.createLogPanel();

            % Initialize processing objects
            obj.initializeProcessors();

            % Add TDT SDK to path
            if ~isempty(obj.SDKPath) && exist(obj.SDKPath, 'dir')
                addpath(genpath(obj.SDKPath));
                obj.addLog(['TDT SDK loaded: ', obj.SDKPath]);
            else
                obj.addLog('Warning: TDT SDK not found. Real-time mode disabled.');
                obj.addLog('Set SDK path manually or place TDTSDK folder in project.');
            end

            obj.addLog('Neural Robot Hand Controller initialized');
            obj.addLog('Select mode and press Start to begin');
        end

        function delete(obj)
            % Destructor - Clean up resources
            obj.stopProcessing();
            if ~isempty(obj.ArduinoConn)
                obj.ArduinoConn.disconnect();
            end
            if isvalid(obj.Figure)
                delete(obj.Figure);
            end
        end
    end

    methods (Access = private)
        function createFigure(obj)
            % Create main figure window
            obj.Figure = uifigure('Name', 'Neural Robot Hand Controller', ...
                'Position', [100, 100, 900, 700], ...
                'CloseRequestFcn', @(~,~) obj.onClose());
        end

        function createModePanel(obj)
            % Create mode selection panel
            obj.ModePanel = uipanel(obj.Figure, ...
                'Title', 'Mode Selection', ...
                'Position', [20, 600, 860, 80]);

            % Radio buttons for mode selection
            bg = uibuttongroup(obj.ModePanel, ...
                'Position', [10, 10, 300, 50], ...
                'BorderType', 'none', ...
                'SelectionChangedFcn', @(~,e) obj.onModeChange(e));

            obj.RealtimeRadio = uiradiobutton(bg, ...
                'Text', 'Real-time Mode', ...
                'Position', [10, 15, 120, 22], ...
                'Value', true);

            obj.CSVRadio = uiradiobutton(bg, ...
                'Text', 'CSV Mode', ...
                'Position', [140, 15, 100, 22]);

            % CSV file selection
            obj.CSVFileButton = uibutton(obj.ModePanel, ...
                'Text', 'Select CSV File...', ...
                'Position', [320, 25, 150, 30], ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) obj.selectCSVFile());

            obj.CSVFilePath = uilabel(obj.ModePanel, ...
                'Text', 'No file selected', ...
                'Position', [480, 25, 360, 30], ...
                'FontColor', [0.5, 0.5, 0.5]);
        end

        function createControlPanel(obj)
            % Create control panel with buttons and Arduino connection
            obj.ControlPanel = uipanel(obj.Figure, ...
                'Title', 'Control', ...
                'Position', [20, 520, 860, 70]);

            % Control buttons
            obj.StartButton = uibutton(obj.ControlPanel, ...
                'Text', 'Start', ...
                'Position', [20, 15, 80, 35], ...
                'BackgroundColor', [0.3, 0.7, 0.3], ...
                'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~,~) obj.startProcessing());

            obj.PauseButton = uibutton(obj.ControlPanel, ...
                'Text', 'Pause', ...
                'Position', [110, 15, 80, 35], ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) obj.pauseProcessing());

            obj.StopButton = uibutton(obj.ControlPanel, ...
                'Text', 'Stop', ...
                'Position', [200, 15, 80, 35], ...
                'BackgroundColor', [0.8, 0.3, 0.3], ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) obj.stopProcessing());

            obj.ResetButton = uibutton(obj.ControlPanel, ...
                'Text', 'Reset', ...
                'Position', [290, 15, 80, 35], ...
                'ButtonPushedFcn', @(~,~) obj.resetSystem());

            % Arduino connection
            uilabel(obj.ControlPanel, ...
                'Text', 'Arduino Port:', ...
                'Position', [450, 20, 80, 22]);

            % Get available serial ports
            ports = obj.getAvailablePorts();
            if isempty(ports)
                ports = {'No ports'};
            end

            obj.PortDropdown = uidropdown(obj.ControlPanel, ...
                'Items', ports, ...
                'Position', [540, 18, 150, 26], ...
                'ValueChangedFcn', @(~,~) obj.onPortChange());

            obj.ConnectionStatus = uilabel(obj.ControlPanel, ...
                'Text', 'Disconnected', ...
                'Position', [700, 20, 140, 22], ...
                'FontColor', [0.8, 0.2, 0.2], ...
                'FontWeight', 'bold');
        end

        function createFingerPanel(obj)
            % Create finger status display panel
            obj.FingerPanel = uipanel(obj.Figure, ...
                'Title', 'Finger Status', ...
                'Position', [20, 280, 860, 230]);

            obj.FingerBars = gobjects(5, 1);
            obj.FingerAngleLabels = gobjects(5, 1);
            obj.FingerSpikeLabels = gobjects(5, 1);

            barWidth = 100;
            barHeight = 120;
            spacing = 160;
            startX = 50;

            colors = [
                0.9, 0.5, 0.2;   % Thumb - Orange
                0.4, 0.7, 0.4;   % Index - Green
                0.6, 0.5, 0.8;   % Middle - Purple
                0.9, 0.85, 0.3;  % Ring - Yellow
                0.4, 0.6, 0.9;   % Pinky - Blue
            ];

            for i = 1:5
                xPos = startX + (i-1) * spacing;

                % Finger name label
                uilabel(obj.FingerPanel, ...
                    'Text', obj.FingerNames{i}, ...
                    'Position', [xPos, 175, barWidth, 20], ...
                    'HorizontalAlignment', 'center', ...
                    'FontWeight', 'bold', ...
                    'FontSize', 12);

                % Background bar (gray)
                uipanel(obj.FingerPanel, ...
                    'Position', [xPos, 50, barWidth, barHeight], ...
                    'BackgroundColor', [0.9, 0.9, 0.9], ...
                    'BorderType', 'line');

                % Active bar (colored) - initially 0 height
                obj.FingerBars(i) = uipanel(obj.FingerPanel, ...
                    'Position', [xPos, 50, barWidth, 1], ...
                    'BackgroundColor', colors(i,:), ...
                    'BorderType', 'none');

                % Angle label
                obj.FingerAngleLabels(i) = uilabel(obj.FingerPanel, ...
                    'Text', '0', ...
                    'Position', [xPos, 25, barWidth, 22], ...
                    'HorizontalAlignment', 'center', ...
                    'FontSize', 14, ...
                    'FontWeight', 'bold');

                % Spike count label
                obj.FingerSpikeLabels(i) = uilabel(obj.FingerPanel, ...
                    'Text', '0 spikes', ...
                    'Position', [xPos, 5, barWidth, 18], ...
                    'HorizontalAlignment', 'center', ...
                    'FontSize', 10, ...
                    'FontColor', [0.4, 0.4, 0.4]);
            end
        end

        function createTimelinePanel(obj)
            % Create timeline/progress panel
            obj.TimelinePanel = uipanel(obj.Figure, ...
                'Title', 'Timeline', ...
                'Position', [20, 200, 860, 70]);

            % Progress bar background
            uipanel(obj.TimelinePanel, ...
                'Position', [20, 25, 700, 25], ...
                'BackgroundColor', [0.85, 0.85, 0.85], ...
                'BorderType', 'line');

            % Progress bar fill
            obj.ProgressBar = uipanel(obj.TimelinePanel, ...
                'Position', [20, 25, 1, 25], ...
                'BackgroundColor', [0.3, 0.6, 0.9], ...
                'BorderType', 'none');

            % Time label
            obj.TimeLabel = uilabel(obj.TimelinePanel, ...
                'Text', 'Current: 0s / 420s', ...
                'Position', [730, 30, 120, 20], ...
                'FontSize', 10);

            % Progress percentage
            obj.ProgressLabel = uilabel(obj.TimelinePanel, ...
                'Text', '0.0%', ...
                'Position', [730, 10, 100, 20], ...
                'FontSize', 10, ...
                'FontColor', [0.4, 0.4, 0.4]);
        end

        function createLogPanel(obj)
            % Create log display panel
            obj.LogPanel = uipanel(obj.Figure, ...
                'Title', 'Log', ...
                'Position', [20, 20, 860, 170]);

            obj.LogTextArea = uitextarea(obj.LogPanel, ...
                'Position', [10, 10, 840, 135], ...
                'Editable', 'off', ...
                'FontName', 'Courier New', ...
                'FontSize', 10);
        end

        function initializeProcessors(obj)
            % Initialize processing objects
            obj.SpikeProc = SpikeProcessor();
            obj.ArduinoConn = ArduinoComm();
            obj.CSVHandler = CSVHandler();
        end

        function ports = getAvailablePorts(~)
            % Get list of available serial ports
            try
                portInfo = serialportlist("available");
                if isempty(portInfo)
                    ports = {'No ports available'};
                else
                    ports = cellstr(portInfo);
                end
            catch
                ports = {'COM1', 'COM2', 'COM3', 'COM4', 'COM5'};
            end
        end

        function onModeChange(obj, event)
            % Handle mode selection change
            if event.NewValue == obj.RealtimeRadio
                obj.CurrentMode = 'realtime';
                obj.CSVFileButton.Enable = 'off';
                obj.addLog('Switched to Real-time mode');
            else
                obj.CurrentMode = 'csv';
                obj.CSVFileButton.Enable = 'on';
                obj.addLog('Switched to CSV mode');
            end
        end

        function selectCSVFile(obj)
            % Open file dialog to select Excel file
            [file, path] = uigetfile('*.xlsx', 'Select Spike Data Excel');
            if file ~= 0
                obj.CSVFilePath.Text = fullfile(path, file);
                obj.CSVFilePath.FontColor = [0, 0, 0];
                obj.addLog(['Excel file selected: ', file]);

                % Load Excel data
                try
                    obj.CSVHandler.loadFile(fullfile(path, file));
                    obj.TotalTime = obj.CSVHandler.getTotalTime();
                    obj.addLog(sprintf('Excel loaded: %d records, %.1f seconds', ...
                        obj.CSVHandler.getRecordCount(), obj.TotalTime));
                catch ME
                    obj.addLog(['Error loading Excel: ', ME.message]);
                end
            end
        end

        function onPortChange(obj)
            % Handle port selection change
            port = obj.PortDropdown.Value;
            if ~contains(port, 'No port')
                obj.addLog(['Selected port: ', port]);
            end
        end

        function startProcessing(obj)
            % Start data processing
            if obj.IsRunning
                return;
            end

            % Connect to Arduino
            port = obj.PortDropdown.Value;
            if ~contains(port, 'No port')
                try
                    obj.ArduinoConn.connect(port);
                    obj.ConnectionStatus.Text = 'Connected';
                    obj.ConnectionStatus.FontColor = [0.2, 0.7, 0.2];
                    obj.addLog(['Arduino connected on ', port]);
                catch ME
                    obj.addLog(['Arduino connection failed: ', ME.message]);
                    obj.ConnectionStatus.Text = 'Failed';
                    obj.ConnectionStatus.FontColor = [0.8, 0.2, 0.2];
                end
            end

            obj.IsRunning = true;
            obj.IsPaused = false;

            % Update UI
            obj.StartButton.Enable = 'off';
            obj.PauseButton.Enable = 'on';
            obj.StopButton.Enable = 'on';
            obj.RealtimeRadio.Enable = 'off';
            obj.CSVRadio.Enable = 'off';

            obj.addLog(['Processing started - ', obj.CurrentMode, ' mode']);

            % Start timer for periodic updates
            obj.ProcessingTimer = timer(...
                'ExecutionMode', 'fixedRate', ...
                'Period', obj.UpdateInterval, ...
                'TimerFcn', @(~,~) obj.processUpdate());
            start(obj.ProcessingTimer);
        end

        function pauseProcessing(obj)
            % Pause/Resume processing
            if ~obj.IsRunning
                return;
            end

            obj.IsPaused = ~obj.IsPaused;

            if obj.IsPaused
                obj.PauseButton.Text = 'Resume';
                obj.addLog('Processing paused');
            else
                obj.PauseButton.Text = 'Pause';
                obj.addLog('Processing resumed');
            end
        end

        function stopProcessing(obj)
            % Stop data processing
            if ~isempty(obj.ProcessingTimer) && isvalid(obj.ProcessingTimer)
                stop(obj.ProcessingTimer);
                delete(obj.ProcessingTimer);
            end

            obj.IsRunning = false;
            obj.IsPaused = false;

            % Update UI
            obj.StartButton.Enable = 'on';
            obj.PauseButton.Enable = 'off';
            obj.PauseButton.Text = 'Pause';
            obj.StopButton.Enable = 'off';
            obj.RealtimeRadio.Enable = 'on';
            obj.CSVRadio.Enable = 'on';

            % Save log to CSV if in realtime mode
            if strcmp(obj.CurrentMode, 'realtime')
                logPath = obj.getLogPath();
                obj.CSVHandler.saveToFile(logPath);
                obj.addLog(['Log saved to ', logPath]);
            end

            obj.addLog('Processing stopped');
        end

        function resetSystem(obj)
            % Reset system to initial state
            obj.stopProcessing();
            obj.CurrentTime = 0;
            obj.CurrentAngles = [0, 0, 0, 0, 0];
            obj.CurrentSpikes = [0, 0, 0, 0, 0];

            % Reset Arduino to home position
            if obj.ArduinoConn.IsConnected
                obj.ArduinoConn.sendAngles([0, 0, 0, 0, 0]);
            end

            % Update display
            obj.updateFingerDisplay();
            obj.updateTimeline();

            obj.addLog('System reset');
        end

        function processUpdate(obj)
            % Process one update cycle
            if obj.IsPaused
                return;
            end

            if strcmp(obj.CurrentMode, 'realtime')
                obj.processRealtimeData();
            else
                obj.processCSVData();
            end

            % Update time
            obj.CurrentTime = obj.CurrentTime + obj.UpdateInterval;

            if obj.CurrentTime >= obj.TotalTime
                obj.stopProcessing();
                obj.addLog('Processing completed');
                return;
            end

            % Update displays
            obj.updateFingerDisplay();
            obj.updateTimeline();

            % Send to Arduino
            if obj.ArduinoConn.IsConnected
                obj.ArduinoConn.sendAngles(obj.CurrentAngles);
                obj.addLog('Sent to Arduino');
            else
                obj.addLog('Arduino not connected!');
            end

            % Log current state
            angleStr = sprintf('%d, %d, %d, %d, %d', ...
                obj.CurrentAngles(1), obj.CurrentAngles(2), ...
                obj.CurrentAngles(3), obj.CurrentAngles(4), obj.CurrentAngles(5));
            obj.addLog(sprintf('Window %.0f: Angles = [%s]', ...
                obj.CurrentTime/obj.WindowSize, angleStr));

            % Save to CSV log
            obj.CSVHandler.addRecord(obj.CurrentTime, obj.CurrentSpikes, obj.CurrentAngles);
        end

        function processRealtimeData(obj)
            % Process real-time TDT data
            try
                % Get spike counts from SpikeProcessor
                t1 = max(0, obj.CurrentTime - obj.WindowSize);
                t2 = obj.CurrentTime;

                [spikeCounts, angles] = obj.SpikeProc.processWindow(t1, t2);

                obj.CurrentSpikes = spikeCounts;
                obj.CurrentAngles = angles;
            catch ME
                obj.addLog(['Error in realtime processing: ', ME.message]);
                % Use dummy data for testing
                obj.CurrentSpikes = randi([100, 1500], 1, 5);
                obj.CurrentAngles = obj.SpikeProc.spikesToAngles(obj.CurrentSpikes);
            end
        end

        function processCSVData(obj)
            % Process data from CSV file
            try
                [spikeCounts, angles] = obj.CSVHandler.getDataAtTime(obj.CurrentTime);
                obj.CurrentSpikes = spikeCounts;
                obj.CurrentAngles = angles;
            catch ME
                obj.addLog(['Error reading CSV: ', ME.message]);
            end
        end

        function updateFingerDisplay(obj)
            % Update finger status bars and labels
            maxAngle = 180;
            barHeight = 120;

            for i = 1:5
                % Update bar height based on angle
                heightRatio = obj.CurrentAngles(i) / maxAngle;
                newHeight = max(1, barHeight * heightRatio);

                pos = obj.FingerBars(i).Position;
                obj.FingerBars(i).Position = [pos(1), pos(2), pos(3), newHeight];

                % Update labels
                obj.FingerAngleLabels(i).Text = sprintf('%d', round(obj.CurrentAngles(i)));
                obj.FingerSpikeLabels(i).Text = sprintf('%d spikes', obj.CurrentSpikes(i));
            end

            drawnow limitrate;
        end

        function updateTimeline(obj)
            % Update timeline progress display
            progress = obj.CurrentTime / obj.TotalTime;
            maxWidth = 700;

            pos = obj.ProgressBar.Position;
            obj.ProgressBar.Position = [pos(1), pos(2), max(1, maxWidth * progress), pos(4)];

            obj.TimeLabel.Text = sprintf('Current: %.0fs / %.0fs', obj.CurrentTime, obj.TotalTime);
            obj.ProgressLabel.Text = sprintf('%.1f%%', progress * 100);

            drawnow limitrate;
        end

        function addLog(obj, message)
            % Add message to log display
            timestamp = datestr(now, 'HH:MM:SS');
            newLine = sprintf('[%s] %s', timestamp, message);

            currentLog = obj.LogTextArea.Value;
            if isempty(currentLog) || (iscell(currentLog) && isempty(currentLog{1}))
                obj.LogTextArea.Value = {newLine};
            else
                obj.LogTextArea.Value = [{newLine}; currentLog];
            end

            % Keep only last 100 lines
            if length(obj.LogTextArea.Value) > 100
                obj.LogTextArea.Value = obj.LogTextArea.Value(1:100);
            end

            drawnow limitrate;
        end

        function onClose(obj)
            % Handle window close
            obj.stopProcessing();
            if ~isempty(obj.ArduinoConn)
                obj.ArduinoConn.disconnect();
            end
            delete(obj.Figure);
        end

        function sdkPath = findTDTSDK(obj)
            % Auto-detect TDT SDK path
            % Searches in common locations (cross-platform)

            sdkPath = '';

            % Get home directory (cross-platform)
            if ispc
                homeDir = getenv('USERPROFILE');
            else
                homeDir = getenv('HOME');
            end

            % Search locations (in order of priority)
            searchPaths = {
                fullfile(obj.ProjectRoot, 'TDTSDK'),                    % Project folder
                fullfile(obj.ProjectRoot, '..', 'TDTSDK'),              % Parent folder
                fullfile(obj.ProjectRoot, '..', 'Matlab data', 'TDTSDK'), % Sibling folder
                fullfile(userpath, 'TDTSDK'),                           % MATLAB userpath
                fullfile(homeDir, 'Desktop', 'Matlab data', 'TDTSDK'),  % Desktop
                fullfile(homeDir, 'Documents', 'MATLAB', 'TDTSDK'),     % Documents
                fullfile(homeDir, 'TDTSDK'),                            % Home
            };

            % Add Windows-specific paths
            if ispc
                searchPaths{end+1} = 'C:\TDT\TDTSDK';
                searchPaths{end+1} = 'C:\Users\Public\Documents\TDT\TDTSDK';
            end

            for i = 1:length(searchPaths)
                if exist(searchPaths{i}, 'dir')
                    % Verify it's actually TDT SDK by checking for key file
                    if exist(fullfile(searchPaths{i}, 'TDTbin2mat', 'TDTbin2mat.m'), 'file')
                        sdkPath = searchPaths{i};
                        return;
                    end
                end
            end

            % Check if already on MATLAB path
            if exist('TDTbin2mat', 'file') == 2
                sdkPath = fileparts(which('TDTbin2mat'));
                sdkPath = fileparts(sdkPath);  % Go up one level
            end
        end

        function logPath = getLogPath(obj)
            % Get full path for log file
            logPath = fullfile(obj.ProjectRoot, 'data', 'robot_hand_log.csv');
        end
    end
end
