% runRobotHand.m - Neural Robot Hand Controller Launcher
%
% This script launches the Robot Hand Control GUI
%
% Usage:
%   >> runRobotHand
%
% Requirements:
%   - MATLAB R2020a or later (for App Designer components)
%   - TDT SDK (for real-time mode)
%   - Arduino with robot_hand.ino firmware (for hardware control)

function varargout = runRobotHand()
    % Get project directories
    currentDir = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(currentDir);

    % Add MATLAB folder to path
    addpath(currentDir);

    % Try to find and load TDT SDK
    tdtPath = findTDTSDK(projectRoot);
    if ~isempty(tdtPath)
        addpath(genpath(tdtPath));
        fprintf('TDT SDK loaded from: %s\n', tdtPath);
    else
        fprintf('TDT SDK not found. Real-time mode will be disabled.\n');
        fprintf('Place TDTSDK folder in project directory or add to MATLAB path.\n');
    end

    % Launch GUI
    fprintf('Starting Neural Robot Hand Controller...\n');
    app = RobotHandGUI();

    % Return handle if requested
    if nargout > 0
        varargout{1} = app;
    end
end

function sdkPath = findTDTSDK(projectRoot)
    % Auto-detect TDT SDK path
    sdkPath = '';

    % Get home directory (cross-platform)
    if ispc
        homeDir = getenv('USERPROFILE');
    else
        homeDir = getenv('HOME');
    end

    % Search locations (in order of priority)
    searchPaths = {
        fullfile(projectRoot, 'TDTSDK'),                           % Project folder
        fullfile(projectRoot, '..', 'TDTSDK'),                     % Parent folder
        fullfile(projectRoot, '..', 'Matlab data', 'TDTSDK'),      % Sibling Matlab data
        fullfile(userpath, 'TDTSDK'),                              % MATLAB userpath
        fullfile(homeDir, 'Desktop', 'Matlab data', 'TDTSDK'),     % Desktop
        fullfile(homeDir, 'Documents', 'MATLAB', 'TDTSDK'),        % Documents
        fullfile(homeDir, 'TDTSDK'),                               % Home
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
        tdtFile = which('TDTbin2mat');
        sdkPath = fileparts(fileparts(tdtFile));  % Go up two levels
    end
end
