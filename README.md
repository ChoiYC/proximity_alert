# Proximity Alert - 근접 경고 시스템

카메라를 통해 접근하는 사람을 실시간으로 감지하고 거리에 따라 경고를 제공하는 Flutter 앱입니다.

## ⚡ 빠른 시작

```bash
# 의존성 설치
flutter pub get

# 실행
flutter run
```

## 🎯 핵심 기능

- **실시간 사람 감지**: Google ML Kit Object Detection
- **거리 측정**: 카메라 기반 거리 추정 (향후 ARCore/ARKit 통합)
- **2단계 경고**:
  - 🟠 5m 이내: 1차 경고 (주황색 + 짧은 진동)
  - 🔴 3m 이내: 2차 경고 (빨간색 + 강한 진동)
- **크로스 플랫폼**: iOS/Android 지원

## 📱 지원 플랫폼

- **Android**: API 24+ (Android 7.0+)
- **iOS**: iOS 11+ (iPhone 6s+)

## 🏗️ 기술 스택

- Flutter 3.35.5
- ML Kit Object Detection
- ARCore/ARKit (계획)
- Camera Package

## 📚 문서

상세한 정보는 `docs/` 폴더를 참고하세요:

- **[docs/index.md](./docs/index.md)** - 문서 목차 및 가이드
- **[docs/README.md](./docs/README.md)** - 프로젝트 개요
- **[docs/progress.md](./docs/progress.md)** - 진행 상황 (2025-10-07)
- **[docs/next-steps.md](./docs/next-steps.md)** - 다음 작업 계획
- **[docs/architecture.md](./docs/architecture.md)** - 시스템 아키텍처
- **[docs/setup-guide.md](./docs/setup-guide.md)** - 설치 및 실행 가이드

## 🚀 프로젝트 구조

```
lib/
├── main.dart                       # 앱 진입점
├── screens/
│   └── proximity_alert_screen.dart # 메인 화면
├── services/
│   ├── person_detector.dart        # ML Kit 사람 감지
│   └── distance_estimator.dart     # 거리 추정
└── widgets/
    └── alert_overlay.dart          # 경고 UI
```

## ✅ 현재 상태

- ✅ Flutter 프로젝트 세팅
- ✅ ML Kit 사람 감지 (15fps)
- ✅ 거리 추정 알고리즘
- ✅ 2단계 경고 시스템
- 🔄 ARCore/ARKit Depth API 통합 (다음 단계)

## 🔜 다음 단계

1. ARCore/ARKit Depth API 통합
2. 실제 디바이스 테스트 및 캘리브레이션
3. 오탐지 방지 개선
4. 배터리 최적화

자세한 계획은 [docs/next-steps.md](./docs/next-steps.md)를 참고하세요.

## 📄 라이선스

MIT License

## 📧 문의

이슈 또는 질문이 있으시면 GitHub Issues를 이용해주세요.

---

**마지막 업데이트**: 2025-10-07
