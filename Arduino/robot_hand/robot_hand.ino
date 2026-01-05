/*
 * Robot Hand Controller - Arduino Mega Firmware
 *
 * Controls 5 servo motors for a robotic hand based on
 * neural spike data from MATLAB
 *
 * Hardware:
 *   - Arduino Mega 2560
 *   - 5x Servo motors connected to PWM pins 2-6
 *   - External 5V power supply for servos (recommended)
 *
 * Communication Protocol:
 *   - Baud rate: 115200
 *   - Input format: "A1,A2,A3,A4,A5\n"
 *     where A1-A5 are angles (0-180) for each finger
 *   - Response: "OK\n" on success, "ERROR:message\n" on failure
 *
 * Pin Assignment:
 *   Pin 2: Thumb servo
 *   Pin 3: Index finger servo
 *   Pin 4: Middle finger servo
 *   Pin 5: Ring finger servo
 *   Pin 6: Pinky servo
 *
 * Note: Pins 0,1 are reserved for Serial communication (TX/RX)
 */

#include <Servo.h>

// ============================================
// Configuration
// ============================================

// Number of servos (fingers)
#define NUM_SERVOS 5

// Servo PWM pins (using pins 2-6 to avoid Serial conflict)
const int SERVO_PINS[NUM_SERVOS] = {2, 3, 4, 5, 6};

// Finger names (for debugging)
const char* FINGER_NAMES[NUM_SERVOS] = {"Thumb", "Index", "Middle", "Ring", "Pinky"};

// Angle limits
#define MIN_ANGLE 0
#define MAX_ANGLE 180

// Serial communication
#define BAUD_RATE 115200
#define MAX_INPUT_LENGTH 64

// Smooth movement settings
#define SMOOTH_MOVE_ENABLED true
#define SMOOTH_MOVE_STEP 5      // Degrees per step
#define SMOOTH_MOVE_DELAY 15    // Milliseconds between steps

// ============================================
// Global Variables
// ============================================

Servo servos[NUM_SERVOS];
int currentAngles[NUM_SERVOS] = {0, 0, 0, 0, 0};
int targetAngles[NUM_SERVOS] = {0, 0, 0, 0, 0};

char inputBuffer[MAX_INPUT_LENGTH];
int inputIndex = 0;

// ============================================
// Setup
// ============================================

void setup() {
  // Initialize serial communication
  Serial.begin(BAUD_RATE);

  // Wait for serial connection
  while (!Serial) {
    delay(10);
  }

  // Initialize servos
  for (int i = 0; i < NUM_SERVOS; i++) {
    servos[i].attach(SERVO_PINS[i]);
    servos[i].write(0);  // Start at home position
    currentAngles[i] = 0;
    targetAngles[i] = 0;
  }

  // Startup message
  Serial.println("Robot Hand Controller Ready");
  Serial.println("Waiting for commands...");

  // Brief startup indication
  testStartup();
}

// ============================================
// Main Loop
// ============================================

void loop() {
  // Process incoming serial data
  while (Serial.available() > 0) {
    char c = Serial.read();

    if (c == '\n' || c == '\r') {
      // End of command
      if (inputIndex > 0) {
        inputBuffer[inputIndex] = '\0';
        processCommand(inputBuffer);
        inputIndex = 0;
      }
    } else if (inputIndex < MAX_INPUT_LENGTH - 1) {
      inputBuffer[inputIndex++] = c;
    }
  }

  // Update servo positions (smooth movement)
  if (SMOOTH_MOVE_ENABLED) {
    updateServoPositions();
  }
}

// ============================================
// Command Processing
// ============================================

void processCommand(const char* cmd) {
  // Parse comma-separated angle values
  int angles[NUM_SERVOS];
  int parsed = parseAngles(cmd, angles);

  if (parsed != NUM_SERVOS) {
    Serial.print("ERROR:Expected ");
    Serial.print(NUM_SERVOS);
    Serial.print(" angles, got ");
    Serial.println(parsed);
    return;
  }

  // Validate and apply angles
  for (int i = 0; i < NUM_SERVOS; i++) {
    angles[i] = constrain(angles[i], MIN_ANGLE, MAX_ANGLE);
    targetAngles[i] = angles[i];

    if (!SMOOTH_MOVE_ENABLED) {
      servos[i].write(angles[i]);
      currentAngles[i] = angles[i];
    }
  }

  // Send confirmation
  Serial.println("OK");

  // Debug output
  #ifdef DEBUG
  Serial.print("Angles: ");
  for (int i = 0; i < NUM_SERVOS; i++) {
    Serial.print(FINGER_NAMES[i]);
    Serial.print("=");
    Serial.print(angles[i]);
    if (i < NUM_SERVOS - 1) Serial.print(", ");
  }
  Serial.println();
  #endif
}

int parseAngles(const char* cmd, int* angles) {
  int count = 0;
  const char* ptr = cmd;

  while (count < NUM_SERVOS && *ptr != '\0') {
    // Skip whitespace
    while (*ptr == ' ' || *ptr == '\t') ptr++;

    if (*ptr == '\0') break;

    // Parse number
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

    // Skip comma
    if (*ptr == ',') ptr++;
  }

  return count;
}

// ============================================
// Smooth Movement
// ============================================

void updateServoPositions() {
  static unsigned long lastUpdate = 0;
  unsigned long now = millis();

  if (now - lastUpdate < SMOOTH_MOVE_DELAY) {
    return;
  }
  lastUpdate = now;

  for (int i = 0; i < NUM_SERVOS; i++) {
    if (currentAngles[i] != targetAngles[i]) {
      int diff = targetAngles[i] - currentAngles[i];
      int step = constrain(diff, -SMOOTH_MOVE_STEP, SMOOTH_MOVE_STEP);

      currentAngles[i] += step;
      servos[i].write(currentAngles[i]);
    }
  }
}

void moveToPosition(int* angles, bool smooth) {
  if (smooth) {
    // Set targets for smooth movement
    for (int i = 0; i < NUM_SERVOS; i++) {
      targetAngles[i] = constrain(angles[i], MIN_ANGLE, MAX_ANGLE);
    }
  } else {
    // Immediate movement
    for (int i = 0; i < NUM_SERVOS; i++) {
      int angle = constrain(angles[i], MIN_ANGLE, MAX_ANGLE);
      servos[i].write(angle);
      currentAngles[i] = angle;
      targetAngles[i] = angle;
    }
  }
}

// ============================================
// Utility Functions
// ============================================

void testStartup() {
  // Brief test movement on startup
  delay(500);

  // Small wave motion
  for (int i = 0; i < NUM_SERVOS; i++) {
    servos[i].write(30);
    delay(100);
  }

  delay(300);

  // Return to home
  for (int i = 0; i < NUM_SERVOS; i++) {
    servos[i].write(0);
  }

  delay(200);
}

void homePosition() {
  // Move all servos to home (0 degrees)
  for (int i = 0; i < NUM_SERVOS; i++) {
    targetAngles[i] = 0;
    if (!SMOOTH_MOVE_ENABLED) {
      servos[i].write(0);
      currentAngles[i] = 0;
    }
  }
}

void gripPosition(int strength) {
  // Grip motion (0-100% strength)
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
// Debug Functions
// ============================================

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
