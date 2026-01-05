# Neural Robot Hand Control System

MATLAB GUI application for controlling a robotic hand using neural spike signals from TDT system.

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                Neural Robot Hand Control System              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   TDT System ──▶ MATLAB GUI ──▶ Arduino Mega ──▶ Servos    │
│   (59 channels)   (Processing)    (PWM 2-6)     (5 fingers) │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Features

- **Real-time Mode**: Process live neural data from TDT system
- **CSV Mode**: Replay recorded spike data from CSV files
- **5-Finger Control**: Individual servo control for each finger
- **Visual Monitoring**: Real-time display of spike counts and angles
- **Data Logging**: Automatic CSV logging of sessions

## Hardware Requirements

- Arduino Mega 2560
- 5x Servo motors (connected to PWM pins 2, 3, 4, 5, 6)
- TDT System (for real-time mode)
- External 5V power supply for servos (recommended)

## Software Requirements

- MATLAB R2020a or later
- TDT SDK (for real-time mode)
- Arduino IDE (for firmware upload)

## Installation

1. Clone this repository
2. Upload `Arduino/robot_hand/robot_hand.ino` to Arduino Mega
3. Add MATLAB folder to MATLAB path
4. Run `runRobotHand` to start the GUI

## Usage

### Quick Start
```matlab
>> cd MATLAB
>> runRobotHand
```

### Create Sample Data
```matlab
>> createSampleData
```

## File Structure

```
NeuralRobotHand/
├── MATLAB/
│   ├── RobotHandGUI.m      # Main GUI application
│   ├── SpikeProcessor.m    # TDT data processing
│   ├── ArduinoComm.m       # Arduino serial communication
│   ├── CSVHandler.m        # CSV read/write handler
│   ├── runRobotHand.m      # Launcher script
│   └── createSampleData.m  # Sample data generator
├── Arduino/
│   └── robot_hand/
│       └── robot_hand.ino  # Arduino firmware
└── data/
    └── (log files)
```

## Electrode Configuration

| Finger | Electrode Set | Channels |
|--------|--------------|----------|
| Thumb  | Set 1 | 5-16 |
| Index  | Set 2 | 17-28 |
| Middle | Set 3 | 29-40 |
| Ring   | Set 4 | 41-52 |
| Pinky  | Set 5 | 53-59, 1-4 |

## Communication Protocol

MATLAB sends angle commands to Arduino:
```
"A1,A2,A3,A4,A5\n"
```
where A1-A5 are angles (0-180) for each finger.

Arduino responds with:
```
"OK\n"
```

## License

MIT License
