classdef ArduinoComm < handle
    % ArduinoComm - Arduino Serial Communication Class
    % Handles serial communication with Arduino Mega for servo control
    %
    % Protocol:
    %   MATLAB sends: "A1,A2,A3,A4,A5\n" where A1-A5 are angles (0-180)
    %   Arduino responds: "OK\n" on success
    %
    % Note: Arduino Mega uses PWM pins 2,3,4,5,6 for servos
    %       (pins 0,1 are reserved for Serial communication)
    %
    % Usage:
    %   arduino = ArduinoComm();
    %   arduino.connect('/dev/cu.usbmodem1101');
    %   arduino.sendAngles([30, 120, 50, 0, 80]);
    %   arduino.disconnect();

    properties (Access = public)
        SerialPort           % Serial port object
        PortName = ''        % Current port name
        BaudRate = 115200    % Communication baud rate
        IsConnected = false  % Connection status
        Timeout = 2          % Communication timeout (seconds)

        % Servo configuration
        NumServos = 5
        MinAngle = 0
        MaxAngle = 180

        % Last sent angles
        LastAngles = [0, 0, 0, 0, 0]

        % Communication settings
        Terminator = newline
        ResponseTimeout = 1
    end

    events
        Connected
        Disconnected
        AnglesSent
        Error
    end

    methods (Access = public)
        function obj = ArduinoComm()
            % Constructor
            obj.LastAngles = zeros(1, obj.NumServos);
        end

        function delete(obj)
            % Destructor - ensure clean disconnect
            obj.disconnect();
        end

        function success = connect(obj, portName)
            % Connect to Arduino on specified port
            % portName: e.g., '/dev/cu.usbmodem1101' or 'COM3'

            success = false;

            if obj.IsConnected
                obj.disconnect();
            end

            try
                % Create serial port connection
                obj.SerialPort = serialport(portName, obj.BaudRate);
                configureTerminator(obj.SerialPort, "LF");
                obj.SerialPort.Timeout = obj.Timeout;

                obj.PortName = portName;
                obj.IsConnected = true;

                % Wait for Arduino to reset
                pause(2);

                % Flush any startup messages
                obj.flushInput();

                % Send initial position (all zeros)
                obj.sendAngles(zeros(1, obj.NumServos));

                fprintf('Connected to Arduino on %s\n', portName);
                notify(obj, 'Connected');
                success = true;

            catch ME
                obj.IsConnected = false;
                obj.PortName = '';
                error('Failed to connect to %s: %s', portName, ME.message);
            end
        end

        function disconnect(obj)
            % Disconnect from Arduino
            if obj.IsConnected && ~isempty(obj.SerialPort)
                try
                    % Send home position before disconnecting
                    obj.sendAngles(zeros(1, obj.NumServos));
                    pause(0.5);

                    % Clear and close serial port
                    flush(obj.SerialPort);
                    delete(obj.SerialPort);
                catch
                    % Ignore errors during cleanup
                end
            end

            obj.SerialPort = [];
            obj.IsConnected = false;
            obj.PortName = '';

            fprintf('Disconnected from Arduino\n');
            notify(obj, 'Disconnected');
        end

        function success = sendAngles(obj, angles)
            % Send angles to Arduino
            % angles: 1x5 array of angles [thumb, index, middle, ring, pinky]

            success = false;

            if ~obj.IsConnected
                warning('Not connected to Arduino');
                return;
            end

            if length(angles) ~= obj.NumServos
                error('Expected %d angles, got %d', obj.NumServos, length(angles));
            end

            % Validate and clamp angles
            angles = obj.validateAngles(angles);

            % Format command string: "A1,A2,A3,A4,A5\n"
            cmdStr = sprintf('%d,%d,%d,%d,%d', ...
                angles(1), angles(2), angles(3), angles(4), angles(5));

            try
                % Send command
                writeline(obj.SerialPort, cmdStr);

                % Wait for response (optional)
                if obj.SerialPort.NumBytesAvailable > 0
                    response = readline(obj.SerialPort);
                    if contains(response, 'OK')
                        success = true;
                    end
                else
                    success = true;  % Assume success if no response required
                end

                obj.LastAngles = angles;
                notify(obj, 'AnglesSent');

            catch ME
                warning('Failed to send angles: %s', ME.message);
                notify(obj, 'Error');
            end
        end

        function success = sendSingleAngle(obj, fingerIndex, angle)
            % Send angle for a single finger
            % fingerIndex: 1-5 (thumb to pinky)
            % angle: 0-180

            if fingerIndex < 1 || fingerIndex > obj.NumServos
                error('Invalid finger index: %d (must be 1-%d)', fingerIndex, obj.NumServos);
            end

            angles = obj.LastAngles;
            angles(fingerIndex) = angle;
            success = obj.sendAngles(angles);
        end

        function smoothMove(obj, targetAngles, duration, steps)
            % Smoothly move to target angles
            % targetAngles: target positions
            % duration: total movement time (seconds)
            % steps: number of intermediate steps

            if nargin < 4
                steps = 10;
            end
            if nargin < 3
                duration = 1.0;
            end

            startAngles = obj.LastAngles;
            stepDelay = duration / steps;

            for i = 1:steps
                t = i / steps;
                currentAngles = startAngles + t * (targetAngles - startAngles);
                obj.sendAngles(round(currentAngles));
                pause(stepDelay);
            end
        end

        function home(obj)
            % Move all servos to home position (0 degrees)
            obj.sendAngles(zeros(1, obj.NumServos));
        end

        function grip(obj, strength)
            % Perform gripping motion
            % strength: 0.0 to 1.0

            if nargin < 2
                strength = 1.0;
            end

            angles = round(strength * obj.MaxAngle * ones(1, obj.NumServos));
            obj.sendAngles(angles);
        end

        function openHand(obj)
            % Open hand (all fingers extended)
            obj.home();
        end

        function closeHand(obj)
            % Close hand (all fingers flexed)
            obj.grip(1.0);
        end

        function testConnection(obj)
            % Test connection with simple servo movements
            fprintf('Testing servo connection...\n');

            % Test each finger
            for i = 1:obj.NumServos
                fprintf('Testing finger %d...\n', i);
                obj.sendSingleAngle(i, 45);
                pause(0.5);
                obj.sendSingleAngle(i, 0);
                pause(0.5);
            end

            fprintf('Test complete.\n');
        end

        function ports = listAvailablePorts(~)
            % List all available serial ports
            try
                ports = serialportlist("available");
                if isempty(ports)
                    ports = {};
                    fprintf('No serial ports available.\n');
                else
                    fprintf('Available ports:\n');
                    for i = 1:length(ports)
                        fprintf('  %s\n', ports(i));
                    end
                end
            catch
                ports = {};
                fprintf('Error listing serial ports.\n');
            end
        end
    end

    methods (Access = private)
        function angles = validateAngles(obj, angles)
            % Validate and clamp angle values
            angles = round(angles);
            angles = max(obj.MinAngle, min(obj.MaxAngle, angles));
        end

        function flushInput(obj)
            % Clear input buffer
            if ~isempty(obj.SerialPort) && obj.IsConnected
                try
                    flush(obj.SerialPort);
                catch
                    % Ignore flush errors
                end
            end
        end

        function response = readResponse(obj)
            % Read response from Arduino
            response = '';
            if obj.SerialPort.NumBytesAvailable > 0
                try
                    response = readline(obj.SerialPort);
                catch
                    response = '';
                end
            end
        end
    end

    methods (Static)
        function demo()
            % Demo function - simulates sending angles without hardware
            fprintf('ArduinoComm Demo Mode\n');
            fprintf('=====================\n');

            angles = [30, 120, 50, 0, 80];
            fprintf('Would send angles: ');
            fprintf('%d, ', angles(1:4));
            fprintf('%d\n', angles(5));

            fprintf('Command string: "%d,%d,%d,%d,%d"\n', ...
                angles(1), angles(2), angles(3), angles(4), angles(5));
        end
    end
end
