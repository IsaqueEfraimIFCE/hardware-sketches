#include <Arduino.h>
#include "BluetoothSerial.h"

#if !defined(ESP32)
#error "This sketch is for ESP32 boards only."
#endif

BluetoothSerial SerialBT;

const char* DEVICE_NAME = "SenseCV_ESP32";

const int TOUCH_PINS[] = {
  4,   // T0
  13,  // T4
  14,  // T6
  27,  // T7
  33,  // T8
  32   // T9
};

const int NUM_TOUCH_PINS = sizeof(TOUCH_PINS) / sizeof(TOUCH_PINS[0]);

const int TOUCH_THRESHOLD = 40;
const int LOOP_DELAY_MS = 100;

int readTouchPressed() {
  for (int i = 0; i < NUM_TOUCH_PINS; i++) {
    int touchValue = touchRead(TOUCH_PINS[i]);

    if (touchValue < TOUCH_THRESHOLD) {
      return 1;
    }
  }

  return 0;
}

void setup() {
  Serial.begin(115200);
  SerialBT.begin(DEVICE_NAME);
}

void loop() {
  int touchPressed = readTouchPressed();

  Serial.println(touchPressed);
  SerialBT.println(touchPressed);

  delay(LOOP_DELAY_MS);
}
