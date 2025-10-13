# Proximity Alert - 근접 경고 시스템

## 프로젝트 개요

카메라 영상에서 사람이 접근하는지 실시간으로 감지하여 거리에 따라 경고를 제공하는 모바일 앱입니다.

### 핵심 기능
- **실시간 사람 감지**: ML Kit Object Detection 사용
- **거리 측정**: 카메라 기반 거리 추정
- **2단계 경고 시스템**:
  - 5m 이내: 1차 경고 (주황색 + 짧은 진동)
  - 3m 이내: 2차 경고 (빨간색 + 강한 진동)
- **크로스 플랫폼**: iOS/Android 지원

## 기술 스택

- **프레임워크**: Flutter
- **사람 감지**: Google ML Kit Object Detection
- **거리 측정**: 현재 - 바운딩 박스 기반 추정 / 계획 - ARCore/ARKit Depth API
- **카메라**: camera 패키지
- **알림**: vibration, flutter_local_notifications

## 프로젝트 구조

```
lib/
├── main.dart                          # 앱 진입점, 권한 처리
├── screens/
│   └── proximity_alert_screen.dart    # 메인 화면, 감지 로직 통합
├── services/
│   ├── person_detector.dart           # ML Kit 사람 감지
│   └── distance_estimator.dart        # 거리 추정 알고리즘
└── widgets/
    └── alert_overlay.dart             # 경고 UI 및 진동
```

## 성능 최적화

- **15fps ML 처리**: 배터리 절약을 위해 66ms마다 프레임 처리
- **스트림 모드**: ML Kit를 Stream 모드로 실행하여 연속 감지 최적화
- **조건부 고해상도**: 사람 감지 시에만 높은 정밀도 적용 (향후 ARCore 통합 시)

## 현재 상태

✅ 완료:
- Flutter 프로젝트 세팅
- 필수 패키지 통합
- iOS/Android 권한 설정
- 카메라 프리뷰 UI
- ML Kit 사람 감지 (15fps)
- 거리 추정 알고리즘 (기본)
- 2단계 경고 시스템

🔄 다음 단계:
- ARCore/ARKit Depth API 통합
- 거리 측정 정확도 개선
- 배터리 최적화 고도화
- 실제 디바이스 테스트 및 캘리브레이션
