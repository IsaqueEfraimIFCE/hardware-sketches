#include "SoftwareSerial.h"
#include "DFRobotDFPlayerMini.h"

SoftwareSerial mySoftwareSerial(10, 11); // RX, TX
DFRobotDFPlayerMini myDFPlayer;

const int B2 = 2; // LOW -> play(1) ; HIGH -> play(2)
const int B3 = 3; // LOW -> play(3)
const int B4 = 4; // LOW -> play(5)
const int B5 = 5; // LOW -> play(7)
const int B6 = 6; // LOW -> play(9)
const int B7 = 7; // LOW -> play(11)
const int B8 = 8; // LOW -> play(13)
const int B9 = 9; // LOW -> play(15)

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
  {B2, 1, "pino 2: pressionou -> 0001",  2, "pino 2: soltou -> 0002", HIGH, HIGH, 0},
  {B3, 3, "pino 3: pressionou -> 0003",  4, "pino 3: soltou -> 0004", HIGH, HIGH, 0},
  {B4, 5, "pino 4: pressionou -> 0005",  6, "pino 4: soltou -> 0006", HIGH, HIGH, 0},
  {B5, 7, "pino 5: pressionou -> 0007",  8, "pino 5: soltou -> 0008", HIGH, HIGH, 0},
  {B6, 9, "pino 6: pressionou -> 0009",  10, "pino 6: soltou -> 00010", HIGH, HIGH, 0},
  {B7, 11, "pino 7: pressionou -> 00011",  12, "pino 7: soltou -> 0012", HIGH, HIGH, 0},
  {B8, 13, "pino 8: pressionou -> 00013",  14, "pino 8: soltou -> 0014", HIGH, HIGH, 0},
  {B9, 15, "pino 9: pressionou -> 00015",  16, "pino 9: soltou -> 0016", HIGH, HIGH, 0},
   
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
