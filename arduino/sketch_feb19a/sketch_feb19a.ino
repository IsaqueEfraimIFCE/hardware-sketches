#include <ESP8266WiFi.h>
#include <WebSocketsClient.h>

const char* ssid = "iphone";
const char* password = "12345678";

// WebSocket server
const char* ws_host = "echo.websocket.org"; // exemplo
const uint16_t ws_port = 80;
const char* ws_path = "/";

WebSocketsClient webSocket;

void webSocketEvent(WStype_t type, uint8_t * payload, size_t length) {

  switch(type) {
    case WStype_DISCONNECTED:
      Serial.println("[WS] Desconectado");
      break;

    case WStype_CONNECTED:
      Serial.println("[WS] Conectado ao servidor");
      webSocket.sendTXT("ESP-01 conectado!");
      break;

    case WStype_TEXT:
      Serial.printf("[WS] Recebido: %s\n", payload);
      break;

    case WStype_BIN:
      Serial.println("[WS] Dados binários recebidos");
      break;

    case WStype_ERROR:
      Serial.println("[WS] Erro");
      break;

    default:
      break;
  }
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println();
  Serial.println("Conectando ao WiFi...");

  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\nWiFi conectado!");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());

  // Configura WebSocket
  webSocket.begin(ws_host, ws_port, ws_path);

  // Opcional (reconexão automática)
  webSocket.setReconnectInterval(5000);

  // Callback de eventos
  webSocket.onEvent(webSocketEvent);
}

void loop() {
  webSocket.loop();

  // Exemplo: envia mensagem a cada 10s
  static unsigned long lastSend = 0;

  if (millis() - lastSend > 10000) {
    lastSend = millis();
    webSocket.sendTXT("Ping do ESP-01");
  }
}
