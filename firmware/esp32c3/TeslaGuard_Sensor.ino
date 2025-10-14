#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// UUIDs for BLE service and characteristic
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// LED pins (Seeed Studio XIAO ESP32C3의 사용 가능한 GPIO)
#define LED1_PIN 2
#define LED2_PIN 3
#define LED3_PIN 4

BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// LED control variables
int ledBlinkMode = 0;  // 0=off, 1=slow(1s), 2=fast(0.5s)
unsigned long lastBlinkTime = 0;
bool ledState = false;

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

      // Turn off all LEDs on disconnect
      digitalWrite(LED1_PIN, LOW);
      digitalWrite(LED2_PIN, LOW);
      digitalWrite(LED3_PIN, LOW);
      ledBlinkMode = 0;
    }
};

// Characteristic write callback
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      std::string value = pCharacteristic->getValue();

      if (value.length() >= 2) {
        // Check for LED command marker (0xFF)
        if ((uint8_t)value[0] == 0xFF) {
          ledBlinkMode = (uint8_t)value[1];

          Serial.print("💡 LED Command Received: ");
          if (ledBlinkMode == 0) {
            Serial.println("OFF");
            // Turn off all LEDs immediately
            digitalWrite(LED1_PIN, LOW);
            digitalWrite(LED2_PIN, LOW);
            digitalWrite(LED3_PIN, LOW);
            ledState = false;
          } else if (ledBlinkMode == 1) {
            Serial.println("SLOW (1s interval)");
          } else if (ledBlinkMode == 2) {
            Serial.println("FAST (0.5s interval)");
          }

          lastBlinkTime = millis();
        } else {
          // Other commands (future use)
          Serial.print("📩 Received: ");
          for (int i = 0; i < value.length(); i++) {
            Serial.print((uint8_t)value[i], HEX);
            Serial.print(" ");
          }
          Serial.println();
        }
      }
    }
};

void setup() {
  Serial.begin(115200);
  delay(2000);  // Wait for serial monitor

  // Initialize LED pins
  pinMode(LED1_PIN, OUTPUT);
  pinMode(LED2_PIN, OUTPUT);
  pinMode(LED3_PIN, OUTPUT);

  // Turn off all LEDs initially
  digitalWrite(LED1_PIN, LOW);
  digitalWrite(LED2_PIN, LOW);
  digitalWrite(LED3_PIN, LOW);

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
  Serial.println("💡 LED Pins: GPIO2, GPIO3, GPIO4");
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

  // Check if it's time to toggle
  if (millis() - lastBlinkTime >= blinkInterval) {
    ledState = !ledState;

    // Update all 3 LEDs
    digitalWrite(LED1_PIN, ledState ? HIGH : LOW);
    digitalWrite(LED2_PIN, ledState ? HIGH : LOW);
    digitalWrite(LED3_PIN, ledState ? HIGH : LOW);

    lastBlinkTime = millis();

    // Debug output
    if (ledState) {
      Serial.println("💡 LEDs ON");
    } else {
      Serial.println("💡 LEDs OFF");
    }
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

  // Update LED blinking
  if (deviceConnected) {
    updateLEDs();
  }

  // Status update every 5 seconds when not connected
  static unsigned long lastStatusUpdate = 0;
  if (!deviceConnected && (millis() - lastStatusUpdate > 5000)) {
    Serial.println("💤 Still waiting for connection... (Advertising active)");
    lastStatusUpdate = millis();
  }

  delay(10);  // Small delay to prevent WDT reset
}
