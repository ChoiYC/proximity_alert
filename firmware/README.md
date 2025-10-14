# TeslaGuard Firmware

Tesla Charging Guard 시스템의 하드웨어 펌웨어 모음입니다.

## 디렉토리 구조

```
firmware/
├── esp32c3/              # ESP32-C3 센서 펌웨어
│   ├── TeslaGuard_Sensor.ino
│   └── README.md
└── README.md            # 이 파일
```

## 지원 하드웨어

| 디바이스 | 설명 | 상태 |
|---------|------|------|
| **ESP32-C3** | BLE 센서 + LED 제어 | ✅ 완료 |

## 통신 프로토콜

모든 디바이스는 BLE (Bluetooth Low Energy)로 Flutter 앱과 통신합니다.

### BLE 서비스
- **Service UUID**: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- **Characteristic UUID**: `beb5483e-36e1-4688-b7f5-ea07361b26a8`

### 명령 프로토콜

| 명령 타입 | 포맷 | 설명 |
|----------|------|------|
| LED 제어 | `[0xFF, mode]` | mode: 0=off, 1=slow, 2=fast |
| 경고 레벨 | `[level]` | level: 0-3 (미래 확장용) |

## 개발 환경

- **Arduino IDE** 2.x 이상
- **ESP32 Board Package** 최신 버전

## 시작하기

각 디바이스별 상세 설명은 해당 디렉토리의 README.md를 참고하세요:

- [ESP32-C3 센서 가이드](./esp32c3/README.md)

## 기여하기

새로운 디바이스를 추가하거나 기존 펌웨어를 개선하려면:

1. 해당 디바이스 디렉토리 생성
2. 펌웨어 코드 및 README.md 작성
3. 이 파일의 "지원 하드웨어" 테이블 업데이트
4. Pull Request 생성

## 라이선스

이 프로젝트는 MIT 라이선스를 따릅니다.
