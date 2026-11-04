#include "SoftwareSerial.h"
#include "DFRobotDFPlayerMini.h"

SoftwareSerial mySoftwareSerial(10, 11); // RX, TX
DFRobotDFPlayerMini myDFPlayer;

const int B6 = 6; // LOW -> play(2) ; HIGH -> play(4)
const int B7 = 7; // LOW -> play(1)
const int B8 = 8; // LOW -> play(3)

const unsigned long debounceMs = 30;

struct Btn {
  int pin;

  // faixa ao pressionar (HIGH -> LOW)
  int trackPress;
  const char* msgPress;

  // faixa ao soltar (LOW -> HIGH)  (-1 = não usar)
  int trackRelease;
  const char* msgRelease;

  int lastStable;
  int lastReading;
  unsigned long lastChangeMs;
};

Btn btns[] = {
  // pin, trackPress, msgPress,   trackRelease, msgRelease,      lastStable,lastReading,lastChangeMs
  {B6, 2, "pino 6: pressionou -> 0002",  4, "pino 6: soltou -> 0004", HIGH, HIGH, 0},
  {B7, 1, "pino 7: pressionou -> 0001", -1, nullptr,             HIGH, HIGH, 0},
  {B8, 3, "pino 8: pressionou -> 0003", -1, nullptr,             HIGH, HIGH, 0},
};

const int N = sizeof(btns) / sizeof(btns[0]);

void setup() {
  Serial.begin(9600);
  mySoftwareSerial.begin(9600);

  for (int i = 0; i < N; i++) {
    pinMode(btns[i].pin, INPUT_PULLUP);
  }

  if (!myDFPlayer.begin(mySoftwareSerial)) {
    Serial.println("Erro no DFPlayer");
    while (true);
  }

  myDFPlayer.volume(25);
}

void loop() {
  int trackToPlay = -1;
  const char* msgToPrint = nullptr;
  unsigned long newestEventTime = 0;

  for (int i = 0; i < N; i++) {
    int reading = digitalRead(btns[i].pin);

    // marca tempo de mudança para debounce
    if (reading != btns[i].lastReading) {
      btns[i].lastChangeMs = millis();
      btns[i].lastReading = reading;
    }

    // estado estabilizado?
    if (millis() - btns[i].lastChangeMs > debounceMs) {
      if (reading != btns[i].lastStable) {

        unsigned long eventTime = millis();

        // Evento: pressionou (HIGH -> LOW)
        if (btns[i].lastStable == HIGH && reading == LOW) {
          if (btns[i].trackPress != -1 && eventTime >= newestEventTime) {
            newestEventTime = eventTime;
            trackToPlay = btns[i].trackPress;
            msgToPrint = btns[i].msgPress;
          }
        }

        // Evento: soltou (LOW -> HIGH)
        if (btns[i].lastStable == LOW && reading == HIGH) {
          if (btns[i].trackRelease != -1 && eventTime >= newestEventTime) {
            newestEventTime = eventTime;
            trackToPlay = btns[i].trackRelease;
            msgToPrint = btns[i].msgRelease;
          }
        }

        btns[i].lastStable = reading;
      }
    }
  }

  if (trackToPlay != -1) {
    myDFPlayer.stop();
    delay(20);              // respiro para troca limpa
    myDFPlayer.play(trackToPlay);
    if (msgToPrint) Serial.println(msgToPrint);
  }
}
