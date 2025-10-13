# 다음 작업 계획

## 🎯 우선순위 높음 (내일 작업)

### 1. ARCore/ARKit Depth API 통합 ⭐⭐⭐
**목적**: 정확한 거리 측정

#### Android (ARCore)
- [ ] ARCore Session 초기화
- [ ] Depth 이미지 획득 설정
- [ ] ML Kit 바운딩 박스 좌표 → Depth 매핑
- [ ] 저전력/고정밀 모드 전환 로직
  - 기본: Low-resolution depth
  - 사람 감지 시: High-resolution depth

**파일**: `lib/services/arcore_depth_service.dart` (신규)

#### iOS (ARKit)
- [ ] ARSession 설정 (LiDAR Scene Depth)
- [ ] Depth map에서 거리 추출
- [ ] People Occlusion API 연동 (선택사항)
- [ ] 저전력/고정밀 모드 전환

**파일**: `lib/services/arkit_depth_service.dart` (신규)

#### 통합
- [ ] 플랫폼별 Depth 서비스 추상화
- [ ] `distance_estimator.dart`에서 AR Depth 우선 사용
- [ ] Fallback: AR 미지원 시 기존 바운딩 박스 방식

**예상 시간**: 4-6시간

---

### 2. 실제 디바이스 테스트 및 캘리브레이션 ⭐⭐⭐
**목적**: 거리 측정 정확도 검증 및 개선

- [ ] Android 기기에서 빌드 및 실행
  - `flutter run --release`
  - ARCore 지원 기기 필요 (Android 7.0+, 2018년 이후)

- [ ] iOS 기기에서 빌드 및 실행
  - iPhone 6s 이상
  - LiDAR 기기 (iPhone 12 Pro+) 선호

- [ ] 거리 캘리브레이션
  - 실제 3m, 5m, 7m 거리에서 측정
  - `calibrationFactor` 값 조정 (distance_estimator.dart)
  - ARCore/ARKit depth 정확도 검증

- [ ] 성능 측정
  - FPS 실제 측정
  - 배터리 소모율 (1시간 사용 시 %)
  - 경고 지연 시간 측정

**예상 시간**: 2-3시간

---

### 3. 오탐지 방지 개선 ⭐⭐
**목적**: 포스터, 마네킹 등 잘못된 감지 줄이기

- [ ] 연속 프레임 검증
  ```dart
  // 최근 N프레임 중 M프레임 이상 감지 시만 경고
  class DetectionBuffer {
    List<bool> detections = [];
    bool isConfirmed() => detections.where((d) => d).length >= 3; // 5프레임 중 3회
  }
  ```

- [ ] 움직임 감지 추가
  - 바운딩 박스 위치 변화 추적
  - 정지된 객체는 경고 안함 (선택사항)

- [ ] ML Kit 신뢰도 임계값 조정
  - 현재 50% → 70%로 상향 테스트

**파일**: `lib/services/detection_filter.dart` (신규)

**예상 시간**: 1-2시간

---

## 🔧 우선순위 중간 (이번 주)

### 4. 배터리 최적화
- [ ] 화면 꺼질 때 감지 일시정지
  - `WidgetsBindingObserver` 사용
  - `didChangeAppLifecycleState` 처리

- [ ] 적응형 프레임레이트
  - 사람 없을 때: 5fps
  - 사람 감지 시: 15fps
  - 경고 상태: 30fps

- [ ] Wake Lock 관리
  - 사용자 설정으로 "화면 항상 켜짐" 토글

**예상 시간**: 2시간

---

### 5. UI/UX 개선
- [ ] 설정 화면 추가
  - 거리 임계값 조정 (5m, 3m → 사용자 커스텀)
  - 진동 강도 조절
  - 경고음 추가 옵션

- [ ] 통계 화면
  - 오늘 감지된 사람 수
  - 평균 거리
  - 사용 시간

- [ ] 다크/라이트 모드 대응
  - 현재 다크 모드만 지원

**예상 시간**: 3시간

---

### 6. 알림 시스템 강화
- [ ] 경고음 추가
  - 5m: 부드러운 경고음
  - 3m: 긴급 경고음
  - 무음 모드에서도 작동 (선택사항)

- [ ] TTS (Text-to-Speech) 옵션
  - "3미터 접근" 음성 경고

- [ ] 햅틱 패턴 다양화
  - iOS Haptic Feedback API 사용

**예상 시간**: 2시간

---

## 📚 우선순위 낮음 (향후)

### 7. 고급 기능
- [ ] 다중 사람 추적
  - 가장 가까운 사람 우선 표시
  - 화면에 여러 바운딩 박스 표시

- [ ] 방향 감지
  - 사람이 접근 중인지, 멀어지는지 판단
  - 접근 속도 계산 (m/s)

- [ ] 위험 구역 설정
  - 화면에 가상 경계선 그리기
  - 침입 시 즉시 경고

---

### 8. 데이터 저장 및 분석
- [ ] SQLite로 감지 기록 저장
  - 시간, 거리, 지속시간

- [ ] 차트/그래프 표시
  - 시간대별 감지 패턴
  - fl_chart 패키지 사용

---

### 9. 추가 플랫폼
- [ ] 태블릿 UI 최적화
- [ ] 웹 버전 (WebRTC 사용)

---

## ✅ 내일의 목표 (2025-10-08)

### Morning (오전)
1. ✅ ARCore Depth API 통합 시작
   - arcore_depth_service.dart 작성
   - Android 기본 depth 획득 코드

2. ✅ iOS ARKit Depth API 추가
   - arkit_depth_service.dart 작성
   - Platform channel 필요 시 구현

### Afternoon (오후)
3. ✅ 실제 디바이스 빌드 및 테스트
   - Android 기기 연결
   - 실제 거리 측정 테스트

4. ✅ 캘리브레이션 및 오탐지 방지
   - calibrationFactor 조정
   - 연속 프레임 검증 추가

### Evening (저녁)
5. ✅ 문서 업데이트
   - 테스트 결과 정리
   - 알려진 이슈 기록

---

## 🚨 잠재적 문제점 및 대응

### ARCore/ARKit 미지원 기기
**대응**:
- Fallback을 바운딩 박스 방식으로 유지
- 앱 시작 시 AR 지원 확인
- 미지원 시 "제한된 정확도" 경고 표시

### 배터리 소모 과다
**대응**:
- 적응형 프레임레이트 적용
- 사용자에게 배터리 세이버 경고

### 실내 조명 문제
**대응**:
- 저조도에서 카메라 ISO 자동 조정
- 감도 떨어질 때 사용자에게 알림

### 개인정보 보호
**대응**:
- 카메라 이미지 저장 안함
- 처리 후 즉시 폐기
- 개인정보 처리방침 작성 (배포 시)

---

## 📖 참고 자료

- [ARCore Depth API](https://developers.google.com/ar/develop/depth)
- [ARKit Scene Depth](https://developer.apple.com/documentation/arkit/arscenedepthdata)
- [ML Kit Object Detection](https://developers.google.com/ml-kit/vision/object-detection)
- [Flutter Camera Plugin](https://pub.dev/packages/camera)
