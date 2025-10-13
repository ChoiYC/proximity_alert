# 시스템 아키텍처

## 전체 구조

```
┌─────────────────────────────────────────────────────────┐
│                   Proximity Alert App                    │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │         proximity_alert_screen.dart            │    │
│  │  (Main Screen - Orchestration Layer)           │    │
│  │                                                 │    │
│  │  • 카메라 초기화 및 관리                        │    │
│  │  • 15fps 타이머로 프레임 처리 트리거            │    │
│  │  • 서비스 레이어 조율                           │    │
│  └─────────────┬───────────────────┬───────────────┘    │
│                │                   │                     │
│                ▼                   ▼                     │
│  ┌──────────────────────┐  ┌──────────────────────┐    │
│  │  person_detector.dart │  │ distance_estimator   │    │
│  │  (ML Kit Service)     │  │      .dart           │    │
│  │                       │  │  (Distance Service)  │    │
│  │  • 객체 감지          │  │                      │    │
│  │  • 사람 필터링        │  │  • 바운딩 박스 분석  │    │
│  │  • Stream 모드        │  │  • Pinhole 모델      │    │
│  └──────────────────────┘  └──────────────────────┘    │
│                │                   │                     │
│                └───────┬───────────┘                     │
│                        ▼                                 │
│              ┌──────────────────┐                        │
│              │  alert_overlay   │                        │
│              │      .dart       │                        │
│              │  (UI Widget)     │                        │
│              │                  │                        │
│              │  • 시각적 경고   │                        │
│              │  • 진동 제어     │                        │
│              │  • 애니메이션    │                        │
│              └──────────────────┘                        │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## 데이터 흐름

### 1. 초기화 단계
```
main.dart
  ├─> Permission.camera.request()
  ├─> availableCameras()
  └─> ProximityAlertScreen(camera)
       ├─> CameraController.initialize()
       ├─> PersonDetector.initialize()
       └─> DistanceEstimator 생성
```

### 2. 실시간 처리 루프 (15fps)
```
Timer.periodic(66ms)
  ├─> _processFrame()
       ├─> CameraController.takePicture()
       ├─> InputImage.fromFilePath()
       │
       ├─> PersonDetector.detectPerson()
       │    ├─> ObjectDetector.processImage()
       │    ├─> Filter: "person" OR "human"
       │    └─> Return: List<DetectedObject>
       │
       ├─> DistanceEstimator.estimateDistance()
       │    ├─> boundingBox.height 추출
       │    ├─> distance = (1.7 × imageHeight) / (objectHeight × 1.5)
       │    └─> Return: distance (0.5m ~ 15.0m)
       │
       └─> _updateAlertLevel()
            ├─> distance <= 3.0m → AlertLevel.warning3m
            ├─> distance <= 5.0m → AlertLevel.warning5m
            └─> setState() → UI 업데이트
```

### 3. 경고 시스템
```
AlertOverlay
  ├─> didUpdateWidget()
  │    └─> alertLevel 변경 감지
  │
  ├─> _handleAlertChange()
  │    ├─> AnimationController.forward()
  │    └─> _triggerVibration()
  │         ├─> warning3m: 500ms, amplitude 255
  │         └─> warning5m: 200ms, amplitude 128
  │
  └─> build()
       ├─> 테두리 색상: red/orange
       ├─> 상단 배너: 아이콘 + 경고문
       └─> 하단 안내: 행동 지침
```

---

## 주요 클래스 상세

### ProximityAlertScreen
**책임**:
- 카메라 생명주기 관리
- 프레임 처리 타이머 관리
- 서비스 레이어 조율

**상태 변수**:
```dart
CameraController? _cameraController;
PersonDetector? _personDetector;
DistanceEstimator? _distanceEstimator;
AlertLevel _currentAlert;
double? _detectedDistance;
bool _isProcessing;        // 동시 처리 방지
int _frameCount;           // FPS 계산용
```

**주요 메서드**:
- `_initializeCamera()`: 카메라 초기화 + 타이머 시작
- `_processFrame()`: 단일 프레임 처리 파이프라인
- `_updateAlertLevel()`: 거리 → 경고 레벨 매핑

---

### PersonDetector
**책임**:
- ML Kit Object Detection 래퍼
- 사람 객체만 필터링

**설정**:
```dart
ObjectDetectorOptions(
  mode: DetectionMode.stream,     // 연속 처리 최적화
  classifyObjects: true,           // 레이블 분류 활성화
  multipleObjects: true,           // 다중 객체 감지
)
```

**필터링 로직**:
```dart
obj.labels.any((label) =>
  (label.text.contains('person') ||
   label.text.contains('human')) &&
  label.confidence > 0.5
)
```

---

### DistanceEstimator
**책임**:
- 바운딩 박스 기반 거리 계산
- Pinhole camera model 적용

**핵심 알고리즘**:
```
Pinhole Camera Model:
  distance = (realHeight × focalLength × imageHeight) /
             (objectHeight × sensorHeight)

단순화:
  distance = (realHeight × imageHeight) /
             (objectHeight × calibrationFactor)

변수:
  - realHeight: 1.7m (평균 인체 키)
  - imageHeight: 카메라 프리뷰 높이 (픽셀)
  - objectHeight: 바운딩 박스 높이 (픽셀)
  - calibrationFactor: 1.5 (실험적 보정값)
```

**제한사항**:
- 카메라 각도가 수평이라고 가정
- 사람이 서있다고 가정 (앉아있으면 부정확)
- 실제 키가 1.7m에서 벗어나면 오차 발생

**향후 개선**: ARCore/ARKit Depth로 교체 예정

---

### AlertOverlay
**책임**:
- 경고 시각화
- 진동 피드백
- 애니메이션 관리

**애니메이션**:
```dart
AnimationController(
  duration: 500ms,
  vsync: this,
)

// Fade in/out으로 부드러운 전환
Opacity(opacity: _animationController.value)
```

**진동 패턴**:
```dart
warning3m:
  - duration: 500ms
  - amplitude: 255 (최대)
  - 의미: 즉각 행동 필요

warning5m:
  - duration: 200ms
  - amplitude: 128 (중간)
  - 의미: 주의 필요
```

---

## 성능 최적화 전략

### 1. 프레임 처리 최적화
```dart
// 동시 처리 방지 플래그
if (_isProcessing) return;
_isProcessing = true;

try {
  // 처리 로직
} finally {
  _isProcessing = false;
}
```

**이유**:
- ML Kit 처리가 66ms 이상 걸릴 수 있음
- 중복 처리 방지로 CPU 부담 감소

---

### 2. 이미지 해상도 관리
```dart
CameraController(
  camera,
  ResolutionPreset.high,        // 정확도 우선
  imageFormatGroup: ImageFormatGroup.yuv420,  // ML Kit 최적화
)
```

**트레이드오프**:
- High resolution: 더 정확한 감지 vs 더 많은 처리 시간
- 향후: 적응형 해상도 (사람 없을 때 낮춤)

---

### 3. ML Kit Stream 모드
```dart
DetectionMode.stream  // vs single
```

**장점**:
- 연속 프레임 처리에 최적화
- 내부 캐싱으로 성능 향상
- 프레임 간 연관성 활용

---

## 메모리 관리

### dispose 체인
```dart
ProximityAlertScreen.dispose()
  ├─> _detectionTimer?.cancel()
  ├─> _cameraController?.dispose()
  ├─> _personDetector?.dispose()
  │    └─> ObjectDetector.close()
  └─> _distanceEstimator?.dispose()
```

**중요**:
- 카메라 리소스는 명시적으로 해제 필수
- ML Kit 모델도 메모리 해제 필요
- 타이머 누수 방지

---

## 에러 처리

### 카메라 초기화 실패
```dart
try {
  await _cameraController!.initialize();
} catch (e) {
  debugPrint('Error initializing camera: $e');
  // UI에 에러 표시 (향후 추가)
}
```

### ML Kit 처리 오류
```dart
try {
  final objects = await _objectDetector!.processImage(inputImage);
} catch (e) {
  debugPrint('Error detecting person: $e');
  return [];  // 빈 결과 반환
}
```

**전략**: Graceful degradation
- 오류 발생 시 앱 크래시 방지
- 빈 결과 반환으로 계속 실행

---

## 플랫폼별 차이점

### Android
- **ARCore 필수**: minSdk 24, AR 카메라 feature
- **권한**: Manifest에 명시적 선언
- **Depth**: ARCore Depth API (향후)

### iOS
- **ARKit**: iOS 11+, iPhone 6s+
- **권한**: Info.plist에 Usage Description
- **Depth**: ARKit SceneDepth (LiDAR 기기에서 최고)

---

## 향후 아키텍처 변경 (ARCore/ARKit 통합)

### 새로운 레이어 추가
```
proximity_alert_screen.dart
  ├─> PersonDetector (ML Kit)
  ├─> ARDepthService (신규)
  │    ├─> ARCoreDepthService (Android)
  │    └─> ARKitDepthService (iOS)
  └─> AlertOverlay
```

### 통합 전략
```dart
class ARDepthService {
  // 플랫폼별 구현 추상화
  Future<double?> getDepthAt(Point2D position);
}

// distance_estimator에서:
distance = await _arDepthService?.getDepthAt(center)
           ?? _fallbackEstimate(boundingBox);
```

**목표**:
- AR 지원 시 정확한 depth 사용
- 미지원 시 기존 바운딩 박스 방식 유지

---

## 테스트 전략

### 단위 테스트
- [ ] `DistanceEstimator`: 다양한 바운딩 박스 크기로 테스트
- [ ] `PersonDetector`: Mock ML Kit 결과로 필터링 검증

### 통합 테스트
- [ ] 카메라 초기화 → 감지 → 경고 전체 플로우

### 실제 디바이스 테스트
- [ ] 3m, 5m, 7m 실제 거리 측정
- [ ] 다양한 조명 환경
- [ ] 배터리 소모 측정

---

## 의존성 그래프

```
main.dart
  └─> proximity_alert_screen.dart
       ├─> camera (^0.11.0)
       ├─> person_detector.dart
       │    └─> google_mlkit_object_detection (^0.13.0)
       ├─> distance_estimator.dart
       │    └─> vector_math (^2.1.4)
       └─> alert_overlay.dart
            └─> vibration (^2.0.0)

플랫폼별:
  Android:
    ├─> arcore_flutter_plugin (^0.1.0)
    └─> permission_handler (^11.3.1)

  iOS:
    └─> 네이티브 ARKit (별도 구현 필요)
```

---

## 보안 고려사항

### 개인정보
- ✅ 카메라 이미지 저장 안함
- ✅ 처리 후 즉시 메모리 해제
- ⚠️ 향후: 통계 저장 시 익명화 필요

### 권한
- ✅ 런타임 권한 요청
- ✅ 거부 시 대체 UI 제공
- ⚠️ 향후: 권한 재요청 로직 추가

---

## 확장성

### 멀티 카메라 지원
```dart
// 향후: 후면/전면 카메라 전환
cameras.where((c) => c.lensDirection == CameraLensDirection.back)
```

### 다국어 지원
```dart
// 향후: i18n 패키지 사용
Text(AppLocalizations.of(context).warningMessage)
```

### 클라우드 동기화
- 감지 기록을 Firebase에 저장
- 여러 기기 간 설정 동기화
