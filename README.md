# Neural Robot Hand Control System

TDT 신경 신호를 이용한 로봇 손 제어 MATLAB GUI 애플리케이션

---

## 목차

1. [시스템 개요](#시스템-개요)
2. [요구사항](#요구사항)
3. [설치 방법](#설치-방법)
4. [하드웨어 연결](#하드웨어-연결)
5. [사용 방법](#사용-방법)
6. [설정 및 커스터마이징](#설정-및-커스터마이징)
7. [파일 구조](#파일-구조)
8. [문제 해결](#문제-해결)
9. [개발자 가이드](#개발자-가이드)

---

## 시스템 개요

### 전체 구조

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Neural Robot Hand Control System                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────┐ │
│   │ TDT System  │───▶│ MATLAB GUI  │───▶│Arduino Mega │───▶│ Servos  │ │
│   │ (59 channels)│    │ (Processing)│    │ (PWM 2-6)   │    │(5 fingers)│
│   └─────────────┘    └─────────────┘    └─────────────┘    └─────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 두 가지 동작 모드

| 모드 | 설명 | 용도 |
|------|------|------|
| **실시간 모드** | TDT 시스템에서 실시간 신경 데이터 처리 | 실제 실험 |
| **CSV 모드** | 저장된 CSV 파일에서 데이터 재생 | 테스트/시연 |

### 데이터 처리 파이프라인

```
TDT 59채널 ──▶ 5초 윈도우 버퍼링 ──▶ 전극세트별 그룹핑 ──▶ 스파이크 카운트 ──▶ 각도 변환

┌────────────────────────────────────────────────────────────┐
│  Set 1 (Ch 5-16)    → 342 spikes  → 30°  (엄지/Thumb)     │
│  Set 2 (Ch 17-28)   → 1254 spikes → 120° (검지/Index)     │
│  Set 3 (Ch 29-40)   → 521 spikes  → 50°  (중지/Middle)    │
│  Set 4 (Ch 41-52)   → 45 spikes   → 0°   (약지/Ring)      │
│  Set 5 (Ch 53-59,1-4) → 812 spikes → 80° (소지/Pinky)     │
└────────────────────────────────────────────────────────────┘
```

---

## 요구사항

### 하드웨어

| 구성품 | 사양 | 비고 |
|--------|------|------|
| Arduino Mega 2560 | 정품 또는 호환보드 | USB 케이블 포함 |
| 서보 모터 | SG90 또는 MG996R x 5개 | 각 손가락용 |
| 외부 전원 | 5V 2A 이상 | 서보 전류 부족 방지 |
| TDT 시스템 | RZ2/RZ5 등 | 실시간 모드용 (선택) |
| 점퍼 와이어 | 수-수 타입 | 연결용 |

### 소프트웨어

| 소프트웨어 | 버전 | 용도 |
|-----------|------|------|
| MATLAB | R2020a 이상 | GUI 실행 |
| Arduino IDE | 1.8.x 또는 2.x | 펌웨어 업로드 |
| TDT SDK | 최신 버전 | 실시간 모드 (선택) |

### 지원 운영체제

- **Windows** 10/11
- **macOS** 10.15 이상
- **Linux** (Ubuntu 20.04 이상)

---

## 설치 방법

### 1단계: 프로젝트 다운로드

```bash
# Git 사용시
git clone https://github.com/your-username/NeuralRobotHand.git

# 또는 ZIP 다운로드 후 압축 해제
```

### 2단계: Arduino 펌웨어 업로드

1. **Arduino IDE 실행**

2. **펌웨어 파일 열기**
   ```
   파일 → 열기 → NeuralRobotHand/Arduino/robot_hand/robot_hand.ino
   ```

3. **보드 설정**
   ```
   도구 → 보드 → Arduino Mega or Mega 2560
   도구 → 포트 → (연결된 포트 선택)
   ```

4. **업로드**
   - 업로드 버튼(→) 클릭
   - "업로드 완료" 메시지 확인

### 3단계: TDT SDK 설치 (실시간 모드용)

TDT SDK를 다음 중 한 곳에 배치:

| 우선순위 | 경로 (자동 검색) |
|---------|------------------|
| 1 | `NeuralRobotHand/TDTSDK/` |
| 2 | `NeuralRobotHand/../TDTSDK/` |
| 3 | MATLAB userpath (`userpath` 명령으로 확인) |
| 4 | `~/Desktop/Matlab data/TDTSDK/` |
| 5 | `~/Documents/MATLAB/TDTSDK/` |
| 6 | Windows: `C:\TDT\TDTSDK\` |

### 4단계: MATLAB에서 실행

```matlab
% 프로젝트 폴더로 이동
cd '/path/to/NeuralRobotHand/MATLAB'

% GUI 실행
runRobotHand
```

---

## 하드웨어 연결

### Arduino Mega 핀 배치

```
                    Arduino Mega 2560
               ┌──────────────────────────┐
               │                          │
   USB ────────┤  USB                     │
   (PC 연결)    │                          │
               │  Pin 2  ─────────────────────▶ 서보 1 (엄지/Thumb)  - 주황선
               │  Pin 3  ─────────────────────▶ 서보 2 (검지/Index)  - 주황선
               │  Pin 4  ─────────────────────▶ 서보 3 (중지/Middle) - 주황선
               │  Pin 5  ─────────────────────▶ 서보 4 (약지/Ring)   - 주황선
               │  Pin 6  ─────────────────────▶ 서보 5 (소지/Pinky)  - 주황선
               │                          │
               │  GND ────────────────────────▶ 서보 GND (공통) - 갈색선
               │  5V  ────────────────────────▶ 서보 VCC (공통) - 빨간선
               │                          │
               └──────────────────────────┘
```

### 서보 모터 연결 (SG90 기준)

| 서보 와이어 색상 | 연결 위치 |
|-----------------|----------|
| 주황색 (Signal) | Arduino PWM 핀 (2-6) |
| 빨간색 (VCC) | 5V 전원 |
| 갈색 (GND) | GND |

### 외부 전원 사용 (권장)

```
┌─────────────┐     ┌─────────────────────────────┐
│  5V 어댑터   │────▶│  서보 VCC (빨간선 모두 연결)  │
│  (2A 이상)   │     │  서보 GND (갈색선 모두 연결)  │
└─────────────┘     └─────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Arduino GND와    │
                    │ 외부전원 GND 연결 │ ◀── 중요!
                    └─────────────────┘
```

---

## 사용 방법

### GUI 실행

```matlab
% MATLAB 명령창에서
cd '/path/to/NeuralRobotHand/MATLAB'
runRobotHand
```

### GUI 화면 구성

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Neural Robot Hand Controller                                     [─][□][X]│
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─ 모드 선택 ────────────────────────────────────────────────────────┐ │
│  │  (●) 실시간 모드    ( ) CSV 모드      [CSV 파일 선택...]           │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ┌─ 제어 ─────────────────────────────────────────────────────────────┐ │
│  │  [▶ Start] [⏸ Pause] [⏹ Stop] [↺ Reset]   포트: [COM3 ▼] 연결됨   │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ┌─ 손가락 상태 ──────────────────────────────────────────────────────┐ │
│  │   Thumb    Index    Middle    Ring     Pinky                       │ │
│  │   ┌──┐     ┌──┐     ┌──┐     ┌──┐     ┌──┐                        │ │
│  │   │▓▓│     │▓▓│     │▓▓│     │  │     │▓▓│    ← 각도 바           │ │
│  │   └──┘     └──┘     └──┘     └──┘     └──┘                        │ │
│  │   30°      120°      50°       0°      80°                         │ │
│  │   342 spk  1254 spk  521 spk  45 spk  812 spk                      │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ┌─ 타임라인 ─────────────────────────────────────────────────────────┐ │
│  │  ▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   35s / 420s   8.3%      │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ┌─ 로그 ─────────────────────────────────────────────────────────────┐ │
│  │  [14:32:07] Angles: 30, 120, 50, 0, 80 → Arduino 전송 완료         │ │
│  │  [14:32:05] Processing started - realtime mode                     │ │
│  │  [14:32:03] Arduino connected on COM3                              │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

### 모드 1: 실시간 모드 (Real-time Mode)

TDT 시스템에서 실시간 신경 데이터를 처리합니다.

1. **Arduino 연결**
   - 포트 드롭다운에서 Arduino 포트 선택
   - Windows: `COM3`, `COM4` 등
   - macOS: `/dev/cu.usbmodem*`

2. **모드 선택**
   - "실시간 모드" 라디오 버튼 선택

3. **시작**
   - `Start` 버튼 클릭
   - TDT 데이터 수집 및 처리 시작

4. **모니터링**
   - 손가락 상태 패널에서 실시간 각도 확인
   - 로그 패널에서 처리 상태 확인

5. **정지**
   - `Stop` 버튼 클릭
   - 로그가 자동으로 `data/robot_hand_log.csv`에 저장됨

### 모드 2: CSV 모드 (Playback Mode)

저장된 CSV 파일의 데이터를 재생합니다.

1. **모드 선택**
   - "CSV 모드" 라디오 버튼 선택

2. **CSV 파일 선택**
   - `CSV 파일 선택...` 버튼 클릭
   - 스파이크 데이터가 포함된 CSV 파일 선택

3. **Arduino 연결** (선택사항)
   - 실제 로봇 손을 제어하려면 포트 선택
   - 시뮬레이션만 하려면 연결 없이 진행 가능

4. **재생**
   - `Start` 버튼 클릭
   - CSV 데이터가 순차적으로 재생됨

### 샘플 데이터 생성

테스트용 CSV 파일을 생성합니다:

```matlab
% 기본 위치에 샘플 데이터 생성
createSampleData

% 또는 경로 지정
createSampleData('C:\Users\사용자\data\test_data.csv')
```

생성되는 CSV 형식:
```csv
Time,Thumb_Spike,Thumb_Angle,Index_Spike,Index_Angle,...
0,342,30,1254,120,...
5,287,20,1189,110,...
10,401,40,1312,130,...
```

### 버튼 기능

| 버튼 | 기능 |
|------|------|
| **Start** | 데이터 처리 시작 |
| **Pause** | 일시정지/재개 |
| **Stop** | 처리 중지 및 로그 저장 |
| **Reset** | 시스템 초기화 (모든 서보 0도) |

---

## 설정 및 커스터마이징

### 스파이크-각도 변환 설정

`SpikeProcessor.m`에서 변환 파라미터 수정:

```matlab
% 스파이크 카운트 범위
obj.MinSpikes = 0;      % 최소 스파이크 (0도에 매핑)
obj.MaxSpikes = 2000;   % 최대 스파이크 (180도에 매핑)
obj.MaxAngle = 180;     % 최대 서보 각도
```

### 전극 세트 구성

`SpikeProcessor.m`에서 전극 그룹 수정:

```matlab
obj.ElectrodeSets = {
    [5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 16]           % Set 1: Thumb
    [17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28]   % Set 2: Index
    [29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40]   % Set 3: Middle
    [41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52]   % Set 4: Ring
    [53, 54, 55, 56, 57, 58, 59, 1, 2, 3, 4]           % Set 5: Pinky
};
```

### 타이밍 설정

`RobotHandGUI.m`에서 수정:

```matlab
obj.TotalTime = 420;        % 총 실행 시간 (초)
obj.WindowSize = 5;         % 데이터 윈도우 크기 (초)
obj.UpdateInterval = 2;     % 업데이트 주기 (초)
```

### Arduino 서보 핀 변경

`robot_hand.ino`에서 수정:

```cpp
const int SERVO_PINS[NUM_SERVOS] = {2, 3, 4, 5, 6};  // PWM 핀 번호
```

### 부드러운 움직임 설정

`robot_hand.ino`에서 수정:

```cpp
#define SMOOTH_MOVE_ENABLED true   // 부드러운 움직임 활성화
#define SMOOTH_MOVE_STEP 5         // 스텝당 각도 변화
#define SMOOTH_MOVE_DELAY 15       // 스텝 간 지연 (ms)
```

---

## 파일 구조

```
NeuralRobotHand/
│
├── MATLAB/                          # MATLAB 소스 코드
│   ├── RobotHandGUI.m              # 메인 GUI 클래스
│   ├── SpikeProcessor.m            # TDT 스파이크 처리
│   ├── ArduinoComm.m               # Arduino 시리얼 통신
│   ├── CSVHandler.m                # CSV 파일 처리
│   ├── runRobotHand.m              # 런처 스크립트
│   └── createSampleData.m          # 샘플 데이터 생성기
│
├── Arduino/                         # Arduino 펌웨어
│   └── robot_hand/
│       └── robot_hand.ino          # 서보 제어 펌웨어
│
├── data/                            # 데이터 저장 폴더
│   └── (로그 파일들)
│
├── TDTSDK/                          # TDT SDK (선택, 여기에 배치 가능)
│
├── .gitignore
└── README.md                        # 이 문서
```

---

## 문제 해결

### Arduino 연결 문제

| 증상 | 해결 방법 |
|------|----------|
| 포트가 보이지 않음 | USB 케이블 확인, 드라이버 설치 |
| "포트 열기 실패" | 다른 프로그램에서 포트 사용 중인지 확인 |
| 연결 후 응답 없음 | Arduino 리셋 버튼 누르기, 펌웨어 재업로드 |

**Windows 드라이버 설치:**
1. 장치 관리자 열기
2. "포트(COM & LPT)" 확인
3. 드라이버가 없으면 [Arduino 드라이버](https://www.arduino.cc/en/Guide/DriverInstallation) 설치

**macOS 권한 문제:**
```bash
# 시리얼 포트 권한 확인
ls -la /dev/cu.usbmodem*
```

### TDT SDK 문제

| 증상 | 해결 방법 |
|------|----------|
| "TDT SDK not found" | SDK를 올바른 경로에 배치 |
| 함수를 찾을 수 없음 | `addpath(genpath('TDTSDK경로'))` 실행 |
| 실시간 데이터 없음 | Synapse 소프트웨어 실행 중인지 확인 |

### 서보 모터 문제

| 증상 | 해결 방법 |
|------|----------|
| 서보가 떨림 | 외부 전원 사용, 전류 부족 |
| 일부 서보만 작동 | 핀 연결 확인, 펌웨어의 핀 번호 확인 |
| 각도가 부정확함 | 서보 캘리브레이션 필요 |

### MATLAB 오류

| 오류 | 해결 방법 |
|------|----------|
| "Undefined function" | `addpath` 확인, 파일 위치 확인 |
| "serialport not found" | MATLAB R2019b 이상 필요 |
| GUI가 열리지 않음 | `uifigure` 지원 버전 확인 (R2016a+) |

---

## 개발자 가이드

### 클래스 구조

```
RobotHandGUI (메인 GUI)
    ├── SpikeProcessor (신호 처리)
    ├── ArduinoComm (하드웨어 통신)
    └── CSVHandler (파일 I/O)
```

### SpikeProcessor 사용법

```matlab
% 인스턴스 생성
proc = SpikeProcessor();

% TDT 데이터 경로 설정
proc.setDataPath('/path/to/tdt/block');

% 시간 윈도우 처리
[spikeCounts, angles] = proc.processWindow(t1, t2);
% spikeCounts: 1x5 배열 (각 손가락의 스파이크 수)
% angles: 1x5 배열 (각 손가락의 각도, 0-180)

% 스파이크를 각도로 변환
angles = proc.spikesToAngles(spikeCounts);
```

### ArduinoComm 사용법

```matlab
% 인스턴스 생성
arduino = ArduinoComm();

% 연결
arduino.connect('COM3');        % Windows
arduino.connect('/dev/cu.usbmodem1101');  % macOS

% 각도 전송
arduino.sendAngles([30, 120, 50, 0, 80]);

% 단일 손가락 제어
arduino.sendSingleAngle(2, 90);  % 검지를 90도로

% 부드러운 움직임
arduino.smoothMove([45, 90, 45, 0, 45], 1.0, 20);

% 연결 해제
arduino.disconnect();
```

### CSVHandler 사용법

```matlab
% 인스턴스 생성
csv = CSVHandler();

% CSV 파일 로드
csv.loadFile('spike_data.csv');

% 특정 시간의 데이터 가져오기
[spikes, angles] = csv.getDataAtTime(15);

% 레코드 추가 (로깅용)
csv.addRecord(currentTime, spikeCounts, angles);

% 파일로 저장
csv.saveToFile('output_log.csv');
```

### 통신 프로토콜

**MATLAB → Arduino:**
```
형식: "A1,A2,A3,A4,A5\n"
예시: "30,120,50,0,80\n"
```

**Arduino → MATLAB:**
```
성공: "OK\n"
오류: "ERROR:message\n"
```

### 확장 가이드

**새로운 손가락 추가:**
1. `SpikeProcessor.m`의 `ElectrodeSets`에 새 전극 세트 추가
2. `RobotHandGUI.m`의 `FingerNames` 업데이트
3. `robot_hand.ino`의 `NUM_SERVOS`와 `SERVO_PINS` 수정

**다른 신호 처리 알고리즘 적용:**
1. `SpikeProcessor.m`의 `processWindow` 메서드 수정
2. 또는 새 프로세서 클래스 생성

---

## 라이선스

MIT License

---

## 문의

문제가 있거나 기능 요청이 있으시면 GitHub Issues를 이용해 주세요.
