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

function runRobotHand()
    % Add current directory to path
    currentDir = fileparts(mfilename('fullpath'));
    addpath(currentDir);

    % Check for TDT SDK
    tdtPath = '/Users/seongmin/Desktop/Matlab data/TDTSDK';
    if exist(tdtPath, 'dir')
        addpath(genpath(tdtPath));
        fprintf('TDT SDK loaded from: %s\n', tdtPath);
    else
        warning('TDT SDK not found. Real-time mode will not work.');
    end

    % Launch GUI
    fprintf('Starting Neural Robot Hand Controller...\n');
    app = RobotHandGUI();

    % Return handle if requested
    if nargout > 0
        varargout{1} = app;
    end
end
