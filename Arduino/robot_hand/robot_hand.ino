/*
 * 로봇 손 컨트롤러 - Arduino Mega 펌웨어
 *
 * 신경 스파이크 데이터를 기반으로 5개의 서보모터를 제어
 * MATLAB에서 각도 데이터를 시리얼로 수신
 *
 * 하드웨어:
 *   - Arduino Mega 2560
 *   - 5개 서보모터 (PWM 핀 2-6)
 *   - 외부 5V 전원 공급 권장
 *
 * 통신 프로토콜:
 *   - Baud rate: 115200
 *   - 입력 형식: "A1,A2,A3,A4,A5\n" (각 손가락 각도 0-180)
 *   - 응답: "OK\n" (성공), "ERROR:message\n" (실패)
 *
 * 핀 배치:
 *   핀 2: 엄지 서보
 *   핀 3: 검지 서보
 *   핀 4: 중지 서보
 *   핀 5: 약지 서보
 *   핀 6: 소지 서보
 */

#include <Servo.h>

// ============================================
// 설정값
// ============================================

#define NUM_SERVOS 5  // 서보 개수 (손가락 5개)

// 서보 PWM 핀 (시리얼 충돌 방지를 위해 핀 2-6 사용)
const int SERVO_PINS[NUM_SERVOS] = {2, 3, 4, 5, 6};

// 손가락 이름 (디버깅용)
const char* FINGER_NAMES[NUM_SERVOS] = {"Thumb", "Index", "Middle", "Ring", "Pinky"};

// 각도 제한
#define MIN_ANGLE 0    // 최소 각도
#define MAX_ANGLE 180  // 최대 각도

// 시리얼 통신 설정
#define BAUD_RATE 115200      // 통신 속도
#define MAX_INPUT_LENGTH 64   // 입력 버퍼 크기

// 부드러운 움직임 설정
#define SMOOTH_MOVE_ENABLED true  // 부드러운 움직임 활성화
#define SMOOTH_MOVE_STEP 5        // 한 번에 움직이는 각도
#define SMOOTH_MOVE_DELAY 15      // 움직임 간격 (밀리초)

// ============================================
// 전역 변수
// ============================================

Servo servos[NUM_SERVOS];                      // 서보 객체 배열
int currentAngles[NUM_SERVOS] = {0, 0, 0, 0, 0};  // 현재 각도
int targetAngles[NUM_SERVOS] = {0, 0, 0, 0, 0};   // 목표 각도

char inputBuffer[MAX_INPUT_LENGTH];  // 시리얼 입력 버퍼
int inputIndex = 0;                  // 버퍼 인덱스

// ============================================
// 초기화
// ============================================

void setup() {
  // 시리얼 통신 시작
  Serial.begin(BAUD_RATE);

  // 시리얼 연결 대기
  while (!Serial) {
    delay(10);
  }

  // 서보 초기화 (확장 펄스 범위: 500-2500us)
  // attach 전에 write로 초기 위치 설정 (점프 방지)
  for (int i = 0; i < NUM_SERVOS; i++) {
    servos[i].write(0);  // 0도에서 시작
    servos[i].attach(SERVO_PINS[i], 500, 2500);
    currentAngles[i] = 0;
    targetAngles[i] = 0;
  }

  // 시작 메시지
  Serial.println("Robot Hand Controller Ready");
  Serial.println("Waiting for commands...");

  // 시작 테스트 동작
  testStartup();
}

// ============================================
// 메인 루프
// ============================================

void loop() {
  // 시리얼 데이터 수신 처리
  while (Serial.available() > 0) {
    char c = Serial.read();

    if (c == '\n' || c == '\r') {
      // 명령어 끝 (줄바꿈 문자)
      if (inputIndex > 0) {
        inputBuffer[inputIndex] = '\0';  // 문자열 종료
        processCommand(inputBuffer);      // 명령어 처리
        inputIndex = 0;                   // 버퍼 초기화
      }
    } else if (inputIndex < MAX_INPUT_LENGTH - 1) {
      inputBuffer[inputIndex++] = c;  // 버퍼에 문자 추가
    }
  }

  // 부드러운 움직임 업데이트
  if (SMOOTH_MOVE_ENABLED) {
    updateServoPositions();
  }
}

// ============================================
// 명령어 처리
// ============================================

void processCommand(const char* cmd) {
  // TEST 명령어 확인
  if (strcmp(cmd, "TEST") == 0) {
    testServoRange();
    return;
  }

  // 쉼표로 구분된 각도 값 파싱
  int angles[NUM_SERVOS];
  int parsed = parseAngles(cmd, angles);

  // 파싱된 각도 개수 확인
  if (parsed != NUM_SERVOS) {
    Serial.print("ERROR:Expected ");
    Serial.print(NUM_SERVOS);
    Serial.print(" angles, got ");
    Serial.println(parsed);
    return;
  }

  // 각도 4배 스케일링 및 적용
  for (int i = 0; i < NUM_SERVOS; i++) {
    angles[i] = angles[i] * 4;  // 4배 스케일링 (MATLAB 값이 작아서)
    angles[i] = constrain(angles[i], MIN_ANGLE, MAX_ANGLE);  // 범위 제한
    targetAngles[i] = angles[i];  // 목표 각도 설정

    // 부드러운 움직임이 비활성화면 즉시 이동
    if (!SMOOTH_MOVE_ENABLED) {
      servos[i].write(angles[i]);
      currentAngles[i] = angles[i];
    }
  }

  // 확인 응답 전송
  Serial.println("OK");
}

// 각도 문자열 파싱 함수
int parseAngles(const char* cmd, int* angles) {
  int count = 0;
  const char* ptr = cmd;

  while (count < NUM_SERVOS && *ptr != '\0') {
    // 공백 건너뛰기
    while (*ptr == ' ' || *ptr == '\t') ptr++;

    if (*ptr == '\0') break;

    // 숫자 파싱
    int value = 0;
    int negative = 0;

    if (*ptr == '-') {
      negative = 1;
      ptr++;
    }

    while (*ptr >= '0' && *ptr <= '9') {
      value = value * 10 + (*ptr - '0');
      ptr++;
    }

    if (negative) value = -value;

    angles[count++] = value;

    // 쉼표 건너뛰기
    if (*ptr == ',') ptr++;
  }

  return count;  // 파싱된 개수 반환
}

// ============================================
// 부드러운 움직임
// ============================================

void updateServoPositions() {
  static unsigned long lastUpdate = 0;
  unsigned long now = millis();

  // 일정 간격으로만 업데이트
  if (now - lastUpdate < SMOOTH_MOVE_DELAY) {
    return;
  }
  lastUpdate = now;

  // 각 서보를 목표 각도로 점진적 이동
  for (int i = 0; i < NUM_SERVOS; i++) {
    if (currentAngles[i] != targetAngles[i]) {
      int diff = targetAngles[i] - currentAngles[i];
      int step = constrain(diff, -SMOOTH_MOVE_STEP, SMOOTH_MOVE_STEP);

      currentAngles[i] += step;
      servos[i].write(currentAngles[i]);
    }
  }
}

// 지정 위치로 이동 함수
void moveToPosition(int* angles, bool smooth) {
  if (smooth) {
    // 부드러운 움직임: 목표만 설정
    for (int i = 0; i < NUM_SERVOS; i++) {
      targetAngles[i] = constrain(angles[i], MIN_ANGLE, MAX_ANGLE);
    }
  } else {
    // 즉시 이동
    for (int i = 0; i < NUM_SERVOS; i++) {
      int angle = constrain(angles[i], MIN_ANGLE, MAX_ANGLE);
      servos[i].write(angle);
      currentAngles[i] = angle;
      targetAngles[i] = angle;
    }
  }
}

// ============================================
// 유틸리티 함수
// ============================================

// 시작 테스트 동작
void testStartup() {
  delay(500);

  // 손가락 순차적으로 살짝 움직임
  for (int i = 0; i < NUM_SERVOS; i++) {
    servos[i].write(MAX_ANGLE - 20);
    delay(100);
  }

  delay(300);

  // 원위치 복귀
  for (int i = 0; i < NUM_SERVOS; i++) {
    servos[i].write(MAX_ANGLE);
  }

  delay(200);
}

// 홈 위치로 이동
void homePosition() {
  for (int i = 0; i < NUM_SERVOS; i++) {
    targetAngles[i] = MAX_ANGLE;
    if (!SMOOTH_MOVE_ENABLED) {
      servos[i].write(MAX_ANGLE);
      currentAngles[i] = MAX_ANGLE;
    }
  }
}

// 그립 동작 (0-100% 강도)
void gripPosition(int strength) {
  int angle = map(strength, 0, 100, MIN_ANGLE, MAX_ANGLE);

  for (int i = 0; i < NUM_SERVOS; i++) {
    targetAngles[i] = angle;
    if (!SMOOTH_MOVE_ENABLED) {
      servos[i].write(angle);
      currentAngles[i] = angle;
    }
  }
}

// ============================================
// 디버그 함수
// ============================================

// 현재 상태 출력
void printStatus() {
  Serial.println("=== Servo Status ===");
  for (int i = 0; i < NUM_SERVOS; i++) {
    Serial.print(FINGER_NAMES[i]);
    Serial.print(": current=");
    Serial.print(currentAngles[i]);
    Serial.print(", target=");
    Serial.println(targetAngles[i]);
  }
}

// 서보 범위 테스트
void testServoRange() {
  Serial.println("=== Servo Range Test ===");
  Serial.println("Testing 0 -> 180 degrees (inverted)...");
  Serial.println("Watch servos and note good range.");

  // 0도에서 180도까지 테스트 (서보는 반전)
  for (int angle = 0; angle <= 180; angle += 10) {
    Serial.print("Angle: ");
    Serial.println(angle);

    for (int i = 0; i < NUM_SERVOS; i++) {
      servos[i].write(180 - angle);
    }
    delay(500);
  }

  delay(1000);

  // 90도로 복귀
  Serial.println("Returning to 90 degrees...");
  for (int i = 0; i < NUM_SERVOS; i++) {
    servos[i].write(90);
    currentAngles[i] = 90;
    targetAngles[i] = 90;
  }

  Serial.println("=== Test Complete ===");
}
