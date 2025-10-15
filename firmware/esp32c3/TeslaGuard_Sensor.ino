#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// UUIDs for BLE service and characteristic
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// LED pins - XIAO_ESP32C3 보드의 핀 이름 사용
// XIAO ESP32C3 핀 매핑:
// D0 = GPIO 2, D1 = GPIO 3, D2 = GPIO 4
// D3 = GPIO 5, D4 = GPIO 6, D5 = GPIO 7
#define LED1_PIN D0  // GPIO 2
#define LED2_PIN D1  // GPIO 3
#define LED3_PIN D2  // GPIO 4

// Piezo buzzer pin for sound alert
#define BUZZER_PIN D3  // GPIO 5 - 피에조 스피커 제어

// SLOW 모드: 낮은 주파수와 높은 주파수를 교대로 (사이렌 효과)
#define BUZZER_FREQ_SLOW_LOW  1500  // 1.5kHz
#define BUZZER_FREQ_SLOW_HIGH 2500  // 2.5kHz
#define BUZZER_SLOW_INTERVAL  500   // 500ms마다 주파수 변경

// FAST 모드: 더 빠른 주파수 변조
#define BUZZER_FREQ_FAST_LOW  2000  // 2kHz
#define BUZZER_FREQ_FAST_HIGH 4000  // 4kHz
#define BUZZER_FAST_INTERVAL  250   // 250ms마다 주파수 변경

BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// LED control variables
int ledBlinkMode = 0;  // 0=off, 1=slow(1s), 2=fast(0.5s)
unsigned long lastBlinkTime = 0;
bool ledState = false;
int currentLedIndex = 0;  // For sequential LED pattern (0, 1, 2)

// Buzzer frequency modulation variables
unsigned long lastBuzzerFreqChange = 0;
bool buzzerHighFreq = false;  // false=low freq, true=high freq

// Connection callbacks
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("========================================");
      Serial.println("✅ Device Connected!");
      Serial.println("========================================");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("========================================");
      Serial.println("❌ Device Disconnected!");
      Serial.println("========================================");

      // Turn off all LEDs and buzzer on disconnect
      digitalWrite(LED1_PIN, LOW);
      digitalWrite(LED2_PIN, LOW);
      digitalWrite(LED3_PIN, LOW);
      noTone(BUZZER_PIN);  // 피에조 스피커 OFF
      ledBlinkMode = 0;
      currentLedIndex = 0;  // Reset sequential index
      buzzerHighFreq = false;  // Reset buzzer state
    }
};

// Characteristic write callback
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      std::string value = pCharacteristic->getValue();

      Serial.println("========================================");
      Serial.print("📥 BLE Data Received: ");
      Serial.print(value.length());
      Serial.println(" bytes");

      // Print raw bytes in hex
      Serial.print("   Raw data: ");
      for (int i = 0; i < value.length(); i++) {
        Serial.print("0x");
        if ((uint8_t)value[i] < 0x10) Serial.print("0");
        Serial.print((uint8_t)value[i], HEX);
        if (i < value.length() - 1) Serial.print(" ");
      }
      Serial.println();

      if (value.length() >= 2) {
        // Check for LED command marker (0xFF)
        if ((uint8_t)value[0] == 0xFF) {
          ledBlinkMode = (uint8_t)value[1];

          Serial.println("🔍 Command Type: LED CONTROL");
          Serial.print("   Marker: 0x");
          Serial.println((uint8_t)value[0], HEX);
          Serial.print("   Mode: ");
          Serial.print(ledBlinkMode);
          Serial.print(" - ");

          if (ledBlinkMode == 0) {
            Serial.println("OFF");
            // Turn off all LEDs and buzzer immediately
            digitalWrite(LED1_PIN, LOW);
            digitalWrite(LED2_PIN, LOW);
            digitalWrite(LED3_PIN, LOW);
            noTone(BUZZER_PIN);  // 피에조 스피커 OFF
            ledState = false;
            currentLedIndex = 0;  // Reset sequential index
            buzzerHighFreq = false;  // Reset buzzer state
            Serial.println("   ✅ LEDs turned OFF");
            Serial.println("   ✅ Buzzer OFF");
          } else if (ledBlinkMode == 1) {
            Serial.println("SLOW (1s interval) - Sequential");
            currentLedIndex = 0;  // Reset sequential index
            buzzerHighFreq = false;  // Start with low frequency
            tone(BUZZER_PIN, BUZZER_FREQ_SLOW_LOW);  // 1.5kHz로 시작
            lastBuzzerFreqChange = millis();
            Serial.println("   ✅ LED blink mode set to SLOW (LED1 → LED2 → LED3)");
            Serial.println("   ✅ Buzzer ON (1.5kHz-2.5kHz siren)");
          } else if (ledBlinkMode == 2) {
            Serial.println("FAST (0.5s interval) - All Together");
            buzzerHighFreq = false;  // Start with low frequency
            tone(BUZZER_PIN, BUZZER_FREQ_FAST_LOW);  // 2kHz로 시작
            lastBuzzerFreqChange = millis();
            Serial.println("   ✅ LED blink mode set to FAST (All LEDs blink)");
            Serial.println("   ✅ Buzzer ON (2kHz-4kHz siren)");
          } else {
            Serial.print("UNKNOWN (");
            Serial.print(ledBlinkMode);
            Serial.println(")");
            Serial.println("   ⚠️  Invalid mode value");
          }

          lastBlinkTime = millis();
        } else {
          // Other commands (future use)
          Serial.println("🔍 Command Type: OTHER");
          Serial.print("   Data: ");
          for (int i = 0; i < value.length(); i++) {
            Serial.print((uint8_t)value[i], HEX);
            Serial.print(" ");
          }
          Serial.println();
        }
      } else {
        Serial.println("⚠️  Invalid data length (need at least 2 bytes)");
      }
      Serial.println("========================================");
    }
};

void setup() {
  Serial.begin(115200);
  delay(2000);  // Wait for serial monitor

  // Initialize LED pins
  pinMode(LED1_PIN, OUTPUT);
  pinMode(LED2_PIN, OUTPUT);
  pinMode(LED3_PIN, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);

  // Turn off all LEDs and buzzer initially
  digitalWrite(LED1_PIN, LOW);
  digitalWrite(LED2_PIN, LOW);
  digitalWrite(LED3_PIN, LOW);
  noTone(BUZZER_PIN);  // 피에조 스피커 OFF

  Serial.println("\n\n");
  Serial.println("========================================");
  Serial.println("🚀 TeslaGuard BLE Sensor Starting...");
  Serial.println("========================================");

  // Initialize BLE
  Serial.println("📡 Initializing BLE...");
  BLEDevice::init("TeslaGuard-Sensor");

  // Create BLE Server
  Serial.println("🔧 Creating BLE Server...");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create BLE Service
  Serial.println("🔧 Creating BLE Service...");
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create BLE Characteristic
  Serial.println("🔧 Creating BLE Characteristic...");
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ   |
                      BLECharacteristic::PROPERTY_WRITE  |
                      BLECharacteristic::PROPERTY_NOTIFY |
                      BLECharacteristic::PROPERTY_INDICATE
                    );

  // Add descriptor for notifications
  pCharacteristic->addDescriptor(new BLE2902());
  pCharacteristic->setCallbacks(new MyCallbacks());

  // Start the service
  Serial.println("▶️  Starting service...");
  pService->start();

  // Start advertising
  Serial.println("📢 Starting BLE advertising...");
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);

  BLEDevice::startAdvertising();

  Serial.println("========================================");
  Serial.println("✅ BLE ADVERTISING STARTED SUCCESSFULLY!");
  Serial.println("========================================");
  Serial.println("📱 Device Name: TeslaGuard-Sensor");
  Serial.print("📱 MAC Address: ");
  Serial.println(BLEDevice::getAddress().toString().c_str());
  Serial.println("========================================");
  Serial.println("💡 LED Pins: D0(GPIO2), D1(GPIO3), D2(GPIO4)");
  Serial.println("🔊 Buzzer Pin: D3(GPIO5) - Piezo speaker");
  Serial.println("========================================");

  // LED and Buzzer hardware test
  Serial.println("🧪 Testing LED and Buzzer hardware...");
  Serial.println("   Turning all LEDs ON and Buzzer beep for 2 seconds...");
  digitalWrite(LED1_PIN, HIGH);
  digitalWrite(LED2_PIN, HIGH);
  digitalWrite(LED3_PIN, HIGH);
  tone(BUZZER_PIN, 2000);  // 2kHz 테스트 톤
  delay(2000);

  Serial.println("   Turning all LEDs and Buzzer OFF...");
  digitalWrite(LED1_PIN, LOW);
  digitalWrite(LED2_PIN, LOW);
  digitalWrite(LED3_PIN, LOW);
  noTone(BUZZER_PIN);
  delay(500);

  Serial.println("✅ LED and Buzzer hardware test complete!");
  Serial.println("   If LEDs didn't light up, check:");
  Serial.println("   1. LED polarity (long leg = +, short leg = -)");
  Serial.println("   2. Resistor (220Ω-1kΩ) in series with each LED");
  Serial.println("   3. GND connection to ESP32C3 GND pin");
  Serial.println("   If Buzzer didn't sound, check:");
  Serial.println("   1. Piezo buzzer + pin connected to D3 (GPIO5)");
  Serial.println("   2. Piezo buzzer - pin connected to ESP32C3 GND");
  Serial.println("========================================");
  Serial.println("⏳ Waiting for connection from app...");
  Serial.println("========================================");
}

void updateLEDs() {
  if (ledBlinkMode == 0) {
    // LEDs off
    return;
  }

  // Determine blink interval
  unsigned long blinkInterval = (ledBlinkMode == 1) ? 1000 : 500;  // 1s or 0.5s

  // Check if it's time to toggle/switch
  if (millis() - lastBlinkTime >= blinkInterval) {
    if (ledBlinkMode == 1) {
      // Mode 1: SLOW - Sequential pattern (3m+)
      // Turn off all LEDs first
      digitalWrite(LED1_PIN, LOW);
      digitalWrite(LED2_PIN, LOW);
      digitalWrite(LED3_PIN, LOW);

      // Turn on current LED
      if (currentLedIndex == 0) {
        digitalWrite(LED1_PIN, HIGH);
      } else if (currentLedIndex == 1) {
        digitalWrite(LED2_PIN, HIGH);
      } else if (currentLedIndex == 2) {
        digitalWrite(LED3_PIN, HIGH);
      }

      // Move to next LED
      currentLedIndex = (currentLedIndex + 1) % 3;

      // Debug output
      unsigned long currentTime = millis();
      Serial.print("[");
      Serial.print(currentTime / 1000);
      Serial.print(".");
      Serial.print(currentTime % 1000);
      Serial.print("s] 💡 LED Sequential: LED");
      Serial.print(currentLedIndex == 0 ? 3 : currentLedIndex);  // Show which LED just turned on
      Serial.println(" ON");

    } else if (ledBlinkMode == 2) {
      // Mode 2: FAST - All LEDs blink together (3m-)
      ledState = !ledState;

      // Toggle all 3 LEDs simultaneously
      digitalWrite(LED1_PIN, ledState ? HIGH : LOW);
      digitalWrite(LED2_PIN, ledState ? HIGH : LOW);
      digitalWrite(LED3_PIN, ledState ? HIGH : LOW);

      // Debug output
      unsigned long currentTime = millis();
      Serial.print("[");
      Serial.print(currentTime / 1000);
      Serial.print(".");
      Serial.print(currentTime % 1000);
      Serial.print("s] 💡 All LEDs: ");
      Serial.println(ledState ? "ON (FAST)" : "OFF");
    }

    lastBlinkTime = millis();
  }
}

void updateBuzzer() {
  if (ledBlinkMode == 0) {
    // Buzzer off
    return;
  }

  // Determine frequency change interval based on mode
  unsigned long freqInterval;
  int lowFreq, highFreq;

  if (ledBlinkMode == 1) {
    // SLOW mode
    freqInterval = BUZZER_SLOW_INTERVAL;  // 500ms
    lowFreq = BUZZER_FREQ_SLOW_LOW;
    highFreq = BUZZER_FREQ_SLOW_HIGH;
  } else {
    // FAST mode
    freqInterval = BUZZER_FAST_INTERVAL;  // 250ms
    lowFreq = BUZZER_FREQ_FAST_LOW;
    highFreq = BUZZER_FREQ_FAST_HIGH;
  }

  // Check if it's time to change frequency
  if (millis() - lastBuzzerFreqChange >= freqInterval) {
    buzzerHighFreq = !buzzerHighFreq;  // Toggle between high and low

    int newFreq = buzzerHighFreq ? highFreq : lowFreq;
    tone(BUZZER_PIN, newFreq);

    // Debug output
    unsigned long currentTime = millis();
    Serial.print("[");
    Serial.print(currentTime / 1000);
    Serial.print(".");
    Serial.print(currentTime % 1000);
    Serial.print("s] 🔊 Buzzer: ");
    Serial.print(newFreq);
    Serial.print("Hz (");
    Serial.print(buzzerHighFreq ? "HIGH" : "LOW");
    Serial.println(")");

    lastBuzzerFreqChange = millis();
  }
}

void loop() {
  // Handle connection state changes
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
    Serial.println("🔗 Connection established and stable");
  }

  // Handle disconnection
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    Serial.println("🔄 Restarting advertising after disconnection...");
    oldDeviceConnected = deviceConnected;
  }

  // Update LED blinking and buzzer frequency
  if (deviceConnected) {
    updateLEDs();
    updateBuzzer();
  }

  // Status update every 5 seconds when not connected
  static unsigned long lastStatusUpdate = 0;
  if (!deviceConnected && (millis() - lastStatusUpdate > 5000)) {
    Serial.println("💤 Still waiting for connection... (Advertising active)");
    lastStatusUpdate = millis();
  }

  delay(10);  // Small delay to prevent WDT reset
}
