# ESP32-C3 Firmware - TeslaGuard Proximity Sensor

Tesla Charging Guard 앱과 통신하는 Seeed Studio XIAO ESP32C3 펌웨어입니다.

## 하드웨어 요구사항

- **보드**: Seeed Studio XIAO ESP32C3
- **LED**: 3개 (GPIO2, GPIO3, GPIO4에 연결)
- **저항**: 220Ω × 3개 (LED용)

## 배선도

```
ESP32C3        LED1 (빨강)
GPIO2 ----[220Ω]----LED----GND

ESP32C3        LED2 (주황)
GPIO3 ----[220Ω]----LED----GND

ESP32C3        LED3 (노랑)
GPIO4 ----[220Ω]----LED----GND
```

## Arduino IDE 설정

1. **보드 매니저 URL 추가**:
   - `파일` → `환경설정` → `추가적인 보드 매니저 URLs`
   - 추가: `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`

2. **보드 설치**:
   - `도구` → `보드` → `보드 매니저`
   - "esp32" 검색 및 설치

3. **보드 선택**:
   - `도구` → `보드` → `ESP32 Arduino` → `XIAO_ESP32C3`

4. **포트 선택**:
   - `도구` → `포트` → (연결된 COM 포트 선택)

## 업로드 방법

1. Arduino IDE에서 `TeslaGuard_Sensor.ino` 파일 열기
2. 보드와 포트 선택 확인
3. 업로드 버튼 클릭 (→)
4. 시리얼 모니터 열기 (115200 baud)

## BLE 프로토콜

### 서비스 UUID
```
4fafc201-1fb5-459e-8fcc-c5c9c331914b
```

### Characteristic UUID
```
beb5483e-36e1-4688-b7f5-ea07361b26a8
```

### LED 제어 명령

| 명령 | 바이트 | 설명 |
|------|--------|------|
| LED OFF | `[0xFF, 0]` | 모든 LED 끄기 |
| 느린 깜빡임 | `[0xFF, 1]` | 1초 간격 (3-5m 경고) |
| 빠른 깜빡임 | `[0xFF, 2]` | 0.5초 간격 (3m 이내 경고) |

## 동작 방식

1. **전원 ON**: BLE 광고 시작 (Device Name: "TeslaGuard-Sensor")
2. **앱 연결**: Flutter 앱이 BLE로 연결
3. **사람 감지**:
   - 5m 이내 감지 시 → LED 1초 간격 깜빡임 + 경고음
   - 3m 이내 감지 시 → LED 0.5초 간격 빠른 깜빡임 + 빠른 경고음
4. **감지 종료**: LED 자동 OFF

## 시리얼 모니터 출력 예시

```
========================================
🚀 TeslaGuard BLE Sensor Starting...
========================================
📡 Initializing BLE...
🔧 Creating BLE Server...
🔧 Creating BLE Service...
🔧 Creating BLE Characteristic...
▶️  Starting service...
📢 Starting BLE advertising...
========================================
✅ BLE ADVERTISING STARTED SUCCESSFULLY!
========================================
📱 Device Name: TeslaGuard-Sensor
📱 MAC Address: XX:XX:XX:XX:XX:XX
========================================
💡 LED Pins: GPIO2, GPIO3, GPIO4
========================================
⏳ Waiting for connection from app...
========================================
✅ Device Connected!
💡 LED Command Received: SLOW (1s interval)
💡 LEDs ON
💡 LEDs OFF
💡 LEDs ON
```

## 트러블슈팅

### 업로드 실패
- 보드가 제대로 연결되었는지 확인
- COM 포트가 올바르게 선택되었는지 확인
- 업로드 중 BOOT 버튼을 누르고 있기

### BLE 연결 안됨
- 시리얼 모니터에서 "ADVERTISING" 메시지 확인
- 앱에서 위치 권한 허용 확인
- Bluetooth가 켜져 있는지 확인

### LED가 안 켜짐
- 배선 확인 (LED 극성, 저항값)
- GPIO 핀 번호 확인
- 시리얼 모니터에서 "LED Command Received" 메시지 확인

## 버전 히스토리

- **v1.0** (2025-10-14): 초기 버전 - BLE + LED 제어
