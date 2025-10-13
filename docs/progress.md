# 프로젝트 진행 상황

## 2025-10-07

### ✅ 완료된 작업

#### 1. 개발 환경 설정
- Flutter SDK 설치 (v3.35.5, stable channel)
- 프로젝트 생성: `proximity_alert`
- Windows 환경에서 Flutter 설정 완료

#### 2. 패키지 통합
다음 패키지들을 `pubspec.yaml`에 추가하고 설치:

```yaml
camera: ^0.11.0+2                          # 카메라 접근
google_mlkit_object_detection: ^0.13.0     # 사람 감지
arcore_flutter_plugin: ^0.1.0              # ARCore (Android)
permission_handler: ^11.3.1                # 권한 관리
vibration: ^2.0.0                          # 진동 알림
flutter_local_notifications: ^18.0.1       # 알림
vector_math: ^2.1.4                        # 수학 연산
```

#### 3. 플랫폼별 권한 설정

**Android** (`android/app/src/main/AndroidManifest.xml`):
- 카메라, 진동, WAKE_LOCK, 알림 권한 추가
- ARCore 필수 설정 (minSdk 24)
- AR 카메라 feature 선언

**iOS** (`ios/Runner/Info.plist`):
- NSCameraUsageDescription 추가
- embedded_views_preview 활성화

#### 4. 핵심 기능 구현

##### 4.1 사람 감지 서비스 (`lib/services/person_detector.dart`)
- ML Kit ObjectDetector를 Stream 모드로 초기화
- "person" 또는 "human" 레이블 필터링
- 신뢰도 50% 이상 감지만 처리
- 다중 객체 감지 지원

##### 4.2 거리 추정 서비스 (`lib/services/distance_estimator.dart`)
- Pinhole camera model 기반 거리 계산
- 평균 인체 키: 1.7m
- 바운딩 박스 높이를 이용한 추정
- 거리 범위: 0.5m ~ 15m

**계산 공식**:
```
distance = (실제키 × 이미지높이) / (객체높이픽셀 × 보정상수)
```

##### 4.3 메인 화면 (`lib/screens/proximity_alert_screen.dart`)
- 카메라 초기화 및 프리뷰
- 15fps (66ms 간격) 프레임 처리
- 사람 감지 → 거리 추정 → 경고 레벨 판단 파이프라인
- 실시간 FPS 및 거리 표시 (디버그용)

**경고 레벨 로직**:
- `distance <= 3.0m` → 2차 경고 (CRITICAL)
- `distance <= 5.0m` → 1차 경고 (WARNING)
- `distance > 5.0m` → 경고 없음

##### 4.4 경고 UI (`lib/widgets/alert_overlay.dart`)
- 2단계 경고 시각화:
  - 5m: 주황색 테두리 + "WARNING"
  - 3m: 빨간색 테두리 + "CRITICAL WARNING"
- 진동 피드백:
  - 5m: 200ms, 약한 진동 (amplitude 128)
  - 3m: 500ms, 강한 진동 (amplitude 255)
- 애니메이션: 500ms fade in/out
- 거리 표시 및 행동 안내 메시지

##### 4.5 메인 앱 (`lib/main.dart`)
- 권한 요청 플로우
- 카메라 없을 시 Permission Denied 화면
- 설정 페이지로 이동 버튼 제공

#### 5. 코드 품질
- Flutter analyze 통과 (0 issues)
- 기본 위젯 테스트 작성
- Dead code 제거
- Lint 규칙 준수

### 🎯 주요 의사결정

#### 거리 측정 방식
**선택**: ML Kit 기본 추정 + 향후 ARCore/ARKit 통합
**이유**:
1. ARCore/ARKit 초기화 지연 (1-2초) 문제 회피
2. 저전력 모드에서 ML만 실행, 사람 감지 시 AR 활성화
3. 단계적 구현 가능

#### 프레임 처리 속도
**선택**: ML Kit 15fps
**이유**:
1. 배터리 소모 최소화
2. 사람 접근 감지에 충분한 반응 속도
3. 실시간성과 효율성 균형

#### Flutter vs React Native
**선택**: Flutter
**이유**:
1. 카메라/AR 같은 고성능 작업에 유리
2. ML Kit 공식 패키지 지원
3. 네이티브에 가까운 성능

### 📊 성능 목표

| 항목 | 목표 | 현재 상태 |
|------|------|-----------|
| ML 처리 속도 | 15fps | ✅ 구현됨 |
| 거리 정확도 | ±0.5m | ⏳ 캘리브레이션 필요 |
| 배터리 소모 | <20%/hour | 🔄 테스트 필요 |
| 감지 범위 | 0.5m ~ 8m | ✅ 0.5m ~ 15m |
| 경고 지연 | <200ms | 🔄 측정 필요 |

### ⚠️ 알려진 제한사항

1. **거리 정확도**: 현재 바운딩 박스 기반 추정은 근사치
   - 실제 ARCore/ARKit Depth API 통합 필요
   - 캘리브레이션 상수 조정 필요

2. **사람 vs 물체 구분**: ML Kit가 완벽하지 않음
   - 포스터, 마네킹 등 오감지 가능
   - 연속 프레임 검증 로직 추가 권장

3. **백그라운드 실행**: 모바일 OS 제한
   - 앱이 포그라운드에 있어야 작동
   - 화면 항상 켜짐 모드 필요

4. **테스트 환경**:
   - 실제 기기에서만 카메라/AR 테스트 가능
   - 에뮬레이터는 제한적

### 📝 코드 메트릭

- **총 파일 수**: 130개 (Flutter 기본 포함)
- **작성한 코드**:
  - `lib/`: 5개 파일 (~400 lines)
  - `docs/`: 문서화
- **외부 패키지**: 7개 주요 패키지
- **플랫폼 설정**: Android/iOS 각 2개 파일 수정
