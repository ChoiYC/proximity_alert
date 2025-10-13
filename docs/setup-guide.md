# 설정 및 실행 가이드

## 사전 요구사항

### 1. 개발 환경
- **Flutter SDK**: 3.35.5 이상 (stable channel)
- **Dart SDK**: 3.9.2 이상
- **Git**: 버전 관리용

### 2. 플랫폼별 도구

#### Android 개발
- **Android Studio**: 2020.3 이상
- **Android SDK**: API Level 24 이상
- **Java JDK**: 11 이상
- **ARCore 지원 기기**: [지원 목록](https://developers.google.com/ar/devices)

#### iOS 개발
- **macOS**: Catalina 이상
- **Xcode**: 14 이상
- **CocoaPods**: 1.11 이상
- **iOS 기기**: iPhone 6s 이상 (실제 기기 필요)

---

## 설치 단계

### 1. Flutter 설치 (이미 완료)

현재 설치된 Flutter 확인:
```bash
export PATH="$PATH:/c/flutter/bin"
flutter --version
```

출력 예시:
```
Flutter 3.35.5 • channel stable
Dart 3.9.2
```

### 2. 프로젝트 클론 및 의존성 설치

```bash
cd C:\MYCLAUDE_PROJECT\CM\TeslaChargingGuard\proximity_alert
flutter pub get
```

### 3. 플랫폼별 설정

#### Android 설정

1. **Android Studio에서 프로젝트 열기**
   ```bash
   android/
   ```

2. **Gradle Sync 실행**
   - Tools → Android → Sync Project with Gradle Files

3. **에뮬레이터 생성** (테스트용, ARCore는 실제 기기 필요)
   ```bash
   flutter emulators --create
   ```

4. **ARCore APK 설치** (실제 기기에서)
   - Google Play Store → "Google Play Services for AR" 설치

#### iOS 설정

1. **CocoaPods 설치** (macOS)
   ```bash
   sudo gem install cocoapods
   ```

2. **iOS 의존성 설치**
   ```bash
   cd ios
   pod install
   ```

3. **Xcode에서 프로젝트 열기**
   ```bash
   open ios/Runner.xcworkspace
   ```

4. **Signing & Capabilities 설정**
   - Team 선택
   - Bundle Identifier 변경 (필요 시)

---

## 실행 방법

### 1. 연결된 기기 확인

```bash
flutter devices
```

출력 예시:
```
Android SDK built for x86 (mobile) • emulator-5554 • android-x86
iPhone 13 Pro (mobile)             • 00008101-001234567890 • ios
```

### 2. 디버그 모드 실행

```bash
# 자동으로 연결된 기기 선택
flutter run

# 특정 기기 선택
flutter run -d <device-id>

# 예시: Android 기기
flutter run -d emulator-5554
```

### 3. 릴리즈 모드 실행 (성능 테스트용)

```bash
flutter run --release
```

**주의**: 릴리즈 모드에서는 Hot Reload 불가

---

## 빌드 방법

### Android APK 빌드

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# Split APKs (크기 최적화)
flutter build apk --split-per-abi
```

출력 위치:
```
build/app/outputs/flutter-apk/app-release.apk
```

### iOS 빌드

```bash
# Debug
flutter build ios --debug

# Release (TestFlight/App Store용)
flutter build ios --release
```

**주의**: iOS 빌드는 macOS와 Xcode 필수

---

## 트러블슈팅

### 문제 1: "Camera permission denied"

**원인**: 카메라 권한 거부

**해결**:
```bash
# Android
adb shell pm grant com.example.proximity_alert android.permission.CAMERA

# iOS
설정 → 개인정보 보호 → 카메라 → proximity_alert 활성화
```

---

### 문제 2: "ARCore not supported"

**원인**: ARCore 미지원 기기 또는 미설치

**해결**:
1. [ARCore 지원 기기 목록](https://developers.google.com/ar/devices) 확인
2. Google Play Store → "Google Play Services for AR" 설치
3. 앱 재시작

---

### 문제 3: "ML Kit initialization failed"

**원인**: Google Play Services 오래됨

**해결**:
```bash
# Google Play Services 업데이트
Play Store → 내 앱 → Google Play Services → 업데이트
```

---

### 문제 4: Flutter 빌드 오류

**증상**:
```
Gradle build failed
```

**해결**:
```bash
# Gradle 캐시 정리
cd android
./gradlew clean

# Flutter 캐시 정리
flutter clean
flutter pub get

# 재빌드
flutter run
```

---

### 문제 5: iOS Podfile 오류

**증상**:
```
CocoaPods not installed
```

**해결**:
```bash
sudo gem install cocoapods
cd ios
pod install
```

---

## 성능 프로파일링

### 1. FPS 측정

앱 실행 중 디버그 오버레이 표시:
```bash
flutter run --profile
```

화면 좌상단에 FPS 표시됨

### 2. 메모리 사용량 확인

```bash
# Android
adb shell dumpsys meminfo com.example.proximity_alert

# DevTools 사용
flutter pub global activate devtools
flutter pub global run devtools
```

### 3. 배터리 소모 측정

**Android**:
```bash
# 배터리 통계 초기화
adb shell dumpsys batterystats --reset

# 앱 1시간 사용 후
adb shell dumpsys batterystats com.example.proximity_alert
```

**iOS**:
- Xcode → Instruments → Energy Log

---

## 테스트 실행

### 단위 테스트
```bash
flutter test
```

### 통합 테스트 (향후)
```bash
flutter drive --target=test_driver/app.dart
```

---

## 코드 분석

### Lint 검사
```bash
flutter analyze
```

현재 상태: ✅ No issues found!

### 포맷팅
```bash
# 전체 코드 포맷팅
flutter format lib/

# 특정 파일
flutter format lib/main.dart
```

---

## 디버깅 팁

### 1. 로그 확인

**실시간 로그**:
```bash
# Android
adb logcat | grep flutter

# iOS
flutter logs
```

**앱 내 로그**:
```dart
debugPrint('Distance: ${distance}m');  // lib/ 코드에서
```

### 2. Hot Reload

코드 변경 후:
```
터미널에서 'r' 입력 또는
VS Code: Cmd+S (저장 시 자동)
```

### 3. DevTools 사용

```bash
flutter pub global activate devtools
flutter pub global run devtools

# 앱 실행 중 연결
flutter run
# 터미널에 표시되는 DevTools URL 열기
```

**주요 기능**:
- Widget Inspector: UI 계층 구조 확인
- Timeline: 프레임 렌더링 분석
- Memory: 메모리 누수 탐지

---

## 환경 변수 설정

### PATH 영구 추가 (Windows)

1. **시스템 환경 변수 편집**
   ```
   제어판 → 시스템 → 고급 시스템 설정 → 환경 변수
   ```

2. **Path에 추가**
   ```
   C:\flutter\bin
   ```

3. **확인**
   ```bash
   # 새 터미널 열고
   flutter --version
   ```

---

## 권장 IDE 설정

### VS Code

**확장 프로그램**:
- Flutter
- Dart
- Dart Data Class Generator (선택)

**settings.json**:
```json
{
  "dart.flutterSdkPath": "C:/flutter",
  "dart.lineLength": 80,
  "editor.formatOnSave": true,
  "editor.rulers": [80]
}
```

### Android Studio

**플러그인**:
- Flutter
- Dart

**설정**:
- File → Settings → Languages & Frameworks → Flutter
- Flutter SDK path: `C:\flutter`

---

## 배포 준비

### Android (Google Play)

1. **서명 키 생성**
   ```bash
   keytool -genkey -v -keystore ~/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key
   ```

2. **android/key.properties 생성**
   ```properties
   storePassword=<password>
   keyPassword=<password>
   keyAlias=key
   storeFile=<path-to-key.jks>
   ```

3. **build.gradle 수정** (이미 설정됨)

4. **빌드**
   ```bash
   flutter build appbundle --release
   ```

### iOS (App Store)

1. **Apple Developer 계정 필요**
2. **Xcode에서 Archive**
3. **TestFlight 또는 App Store Connect 업로드**

---

## 추가 리소스

- [Flutter 공식 문서](https://docs.flutter.dev)
- [ML Kit 문서](https://developers.google.com/ml-kit)
- [ARCore 시작 가이드](https://developers.google.com/ar/develop/flutter)
- [ARKit 문서](https://developer.apple.com/arkit)

---

## 지원

이슈 발생 시:
1. `flutter doctor -v` 실행하여 환경 확인
2. `flutter analyze` 실행하여 코드 검사
3. 로그 수집: `flutter logs > logs.txt`
4. GitHub Issues 또는 팀 채널에 보고
