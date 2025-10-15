import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../services/person_detector.dart';
import '../services/distance_estimator.dart';
import '../services/image_cropper.dart';
import '../services/multi_device_bluetooth_service.dart';
import '../models/device_position.dart';
import '../widgets/alert_overlay.dart';
import '../screens/multi_device_bluetooth_settings_screen.dart';

enum AlertLevel {
  none,
  warning5m,
  warning3m,
}

class ProximityAlertScreen extends StatefulWidget {
  final CameraDescription camera;

  const ProximityAlertScreen({super.key, required this.camera});

  @override
  State<ProximityAlertScreen> createState() => _ProximityAlertScreenState();
}

class _ProximityAlertScreenState extends State<ProximityAlertScreen> {
  CameraController? _cameraController;
  PersonDetector? _personDetector;
  DistanceEstimator? _distanceEstimator;
  ImageCropper? _imageCropper;

  bool _isProcessing = false;
  bool _isInitialized = false;
  AlertLevel _currentAlert = AlertLevel.none;
  double? _detectedDistance;
  int _frameCount = 0;
  DateTime? _lastFpsUpdate;
  DateTime? _lastProcessedFrame;  // Track last processed frame time for throttling
  double _currentFps = 0.0;
  String? _lastDetectedImagePath;  // 마지막 감지된 이미지 경로

  // Temporal filtering to reduce false positives
  int _consecutiveDetections = 0;
  int _consecutiveNonDetections = 0;
  static const int _requiredConsecutiveDetections = 2;  // Need 2 frames in a row
  static const int _requiredConsecutiveNonDetections = 2;  // Need 2 frames without detection to clear
  static const Duration _processingInterval = Duration(milliseconds: 1000);  // Process 1 frame per second

  // Auto-off timer: turn off alert if no detection for 10 seconds
  DateTime? _lastDetectionTime;
  static const Duration _autoOffDuration = Duration(seconds: 10);
  Timer? _autoOffCheckTimer;

  // Alert timer for sound and LED
  Timer? _alertTimer;
  final _bluetoothService = MultiDeviceBluetoothService();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeDetectors();
    _initializeBluetooth();
    _startAutoOffCheckTimer();
  }

  /// Start timer to check for auto-off (10 seconds without detection)
  void _startAutoOffCheckTimer() {
    _autoOffCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lastDetectionTime != null && _currentAlert != AlertLevel.none) {
        final timeSinceLastDetection = DateTime.now().difference(_lastDetectionTime!);

        if (timeSinceLastDetection >= _autoOffDuration) {
          debugPrint('⏰ No detection for ${_autoOffDuration.inSeconds}s - turning off alert');

          if (mounted) {
            setState(() {
              _detectedDistance = null;
              _currentAlert = AlertLevel.none;
              _lastDetectedImagePath = null;
            });
          }

          _stopAlertTimer();
          _lastDetectionTime = null;
        }
      }
    });
  }

  Future<void> _initializeBluetooth() async {
    final bluetoothService = MultiDeviceBluetoothService();
    await bluetoothService.initialize();
  }

  Future<void> _initializeCamera() async {
    _cameraController = CameraController(
      widget.camera,
      ResolutionPreset.low,  // Low resolution for better performance
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _lastFpsUpdate = DateTime.now();
          _lastProcessedFrame = DateTime.now();
        });

        // Start periodic capture (1 FPS for stable performance)
        // Using longer intervals to reduce impact on preview smoothness
        Timer.periodic(const Duration(milliseconds: 1500), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          _captureAndProcessAsync();
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  /// Capture and process frame asynchronously with minimal UI blocking
  Future<void> _captureAndProcessAsync() async {
    // Skip if already processing
    if (_isProcessing || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _isProcessing = true;
    final now = DateTime.now();
    _frameCount++;

    // Update FPS counter
    if (_lastFpsUpdate != null) {
      final elapsed = now.difference(_lastFpsUpdate!).inMilliseconds;
      if (elapsed >= 1000) {
        _currentFps = _frameCount / (elapsed / 1000);
        _frameCount = 0;
        _lastFpsUpdate = now;
        debugPrint('📊 Detection rate: ${_currentFps.toStringAsFixed(1)}/sec');
      }
    }

    try {
      // Take picture - this is the blocking part (~300-500ms)
      final image = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);

      // Run ML detection
      final detections = await _personDetector!.detectPerson(inputImage);

      if (detections.isNotEmpty) {
        // Validate pose
        final pose = detections.first;
        if (!_imageCropper!.isValidPose(pose)) {
          _consecutiveDetections = 0;
          _consecutiveNonDetections++;

          if (_consecutiveNonDetections >= _requiredConsecutiveNonDetections) {
            if (mounted) {
              setState(() {
                _detectedDistance = null;
                _currentAlert = AlertLevel.none;
                _lastDetectedImagePath = null;
              });
            }
          }
          return;
        }

        // Valid detection
        _consecutiveDetections++;
        _consecutiveNonDetections = 0;

        final distance = await _distanceEstimator!.estimateDistance(
          pose,
          _cameraController!,
        );

        // Crop image to show detected person
        final croppedImagePath = await _imageCropper!.cropToPerson(image.path, pose);

        // Update UI after consecutive detections
        if (_consecutiveDetections >= _requiredConsecutiveDetections) {
          // Update last detection time for auto-off timer
          _lastDetectionTime = DateTime.now();

          if (mounted) {
            setState(() {
              _detectedDistance = distance;
              _lastDetectedImagePath = croppedImagePath;
              _updateAlertLevel(distance);
            });
          }
        }
      } else {
        _consecutiveDetections = 0;
        _consecutiveNonDetections++;

        if (_consecutiveNonDetections >= _requiredConsecutiveNonDetections) {
          if (mounted) {
            setState(() {
              _detectedDistance = null;
              _currentAlert = AlertLevel.none;
              _lastDetectedImagePath = null;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error processing frame: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _initializeDetectors() async {
    _personDetector = PersonDetector();
    await _personDetector!.initialize();

    _distanceEstimator = DistanceEstimator();
    _imageCropper = ImageCropper();
  }


  void _updateAlertLevel(double distance) {
    AlertLevel newLevel;
    if (distance <= 3.0) {
      newLevel = AlertLevel.warning3m;
    } else if (distance <= 5.0) {
      newLevel = AlertLevel.warning5m;
    } else {
      newLevel = AlertLevel.none;
    }

    if (newLevel != _currentAlert) {
      debugPrint('🚨 Alert level changed: $_currentAlert → $newLevel (distance: ${distance.toStringAsFixed(2)}m)');
      _currentAlert = newLevel;

      // Start or stop alert timer based on alert level
      _stopAlertTimer();
      if (newLevel != AlertLevel.none) {
        _startAlertTimer(newLevel);
      } else {
        // Turn off LEDs when no alert
        _bluetoothService.sendLEDBlinkToAll(0);
      }
    }
  }

  /// Start alert timer for sound and LED
  void _startAlertTimer(AlertLevel level) {
    Duration interval;
    int ledBlinkMode;

    if (level == AlertLevel.warning3m) {
      // 3m 이내: 0.5초 간격
      interval = const Duration(milliseconds: 500);
      ledBlinkMode = 2; // Fast blink
      debugPrint('🔴 Starting fast alert (0.5s interval)');
    } else {
      // 3m 이상 5m 이내: 1초 간격
      interval = const Duration(milliseconds: 1000);
      ledBlinkMode = 1; // Slow blink
      debugPrint('🟠 Starting slow alert (1s interval)');
    }

    // Send initial LED command
    _bluetoothService.sendLEDBlinkToAll(ledBlinkMode);

    // Play alert sound and repeat
    _alertTimer = Timer.periodic(interval, (timer) {
      // Play beep sound
      FlutterRingtonePlayer().play(
        android: AndroidSounds.notification,
        ios: IosSounds.glass,
        looping: false,
        volume: 0.3,
        asAlarm: false,
      );
    });

    // Play initial beep immediately
    FlutterRingtonePlayer().play(
      android: AndroidSounds.notification,
      ios: IosSounds.glass,
      looping: false,
      volume: 0.3,
      asAlarm: false,
    );
  }

  /// Stop alert timer
  void _stopAlertTimer() {
    if (_alertTimer != null) {
      debugPrint('⏹️ Stopping alert timer');
      _alertTimer?.cancel();
      _alertTimer = null;

      // Turn off LEDs
      _bluetoothService.sendLEDBlinkToAll(0);
    }
  }

  @override
  void dispose() {
    _stopAlertTimer();
    _autoOffCheckTimer?.cancel();
    _cameraController?.dispose();
    _personDetector?.dispose();
    _distanceEstimator?.dispose();
    _imageCropper?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _cameraController == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          Center(
            child: CameraPreview(_cameraController!),
          ),

          // Alert overlay
          AlertOverlay(
            alertLevel: _currentAlert,
            distance: _detectedDistance,
          ),

          // Device buttons at camera corners
          // Left bottom button (row 1, col 0) -> Top left corner
          Positioned(
            top: 20,
            left: 20,
            child: _buildCornerDeviceButton(1, 0),
          ),
          
          // Right bottom button (row 1, col 1) -> Top right corner
          Positioned(
            top: 20,
            right: 20,
            child: _buildCornerDeviceButton(1, 1),
          ),
          
          // Left top button (row 0, col 0) -> Bottom left corner
          Positioned(
            bottom: 100,
            left: 20,
            child: _buildCornerDeviceButton(0, 0),
          ),
          
          // Right top button (row 0, col 1) -> Bottom right corner
          Positioned(
            bottom: 100,
            right: 20,
            child: _buildCornerDeviceButton(0, 1),
          ),

          // Debug info
          Positioned(
            top: 180,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detection: ${_currentFps.toStringAsFixed(1)}/sec',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  if (_detectedDistance != null)
                    Text(
                      'Distance: ${_detectedDistance!.toStringAsFixed(2)}m',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
          ),

          // LED Test buttons - bottom left
          Positioned(
            bottom: 50,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'LED Test',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      debugPrint('🔵 TEST: Sending LED OFF command');
                      _bluetoothService.sendLEDBlinkToAll(0);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      minimumSize: const Size(80, 36),
                    ),
                    child: const Text('OFF', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 4),
                  ElevatedButton(
                    onPressed: () {
                      debugPrint('🟠 TEST: Sending LED SLOW command');
                      _bluetoothService.sendLEDBlinkToAll(1);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      minimumSize: const Size(80, 36),
                    ),
                    child: const Text('SLOW', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 4),
                  ElevatedButton(
                    onPressed: () {
                      debugPrint('🔴 TEST: Sending LED FAST command');
                      _bluetoothService.sendLEDBlinkToAll(2);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size(80, 36),
                    ),
                    child: const Text('FAST', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),

          // Detected person image (zoomed in) - bottom right
          if (_lastDetectedImagePath != null)
            Positioned(
              bottom: 50,
              right: 16,
              child: Container(
                width: 150,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _currentAlert == AlertLevel.warning3m
                        ? Colors.red
                        : _currentAlert == AlertLevel.warning5m
                            ? Colors.orange
                            : Colors.green,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(_lastDetectedImagePath!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Icon(Icons.error, color: Colors.white),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCornerDeviceButton(int row, int col) {
    final bluetoothService = MultiDeviceBluetoothService();
    
    return AnimatedBuilder(
      animation: bluetoothService,
      builder: (context, child) {
        final position = bluetoothService.getDeviceAt(row, col);
        
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MultiDeviceBluetoothSettingsScreen(),
              ),
            );
          },
          child: Container(
            width: 50,
            height: 50,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
              border: Border.all(
                color: _getDeviceStatusColor(position),
                width: 2,
              ),
            ),
            child: Icon(
              _getDeviceStatusIcon(position),
              color: _getDeviceStatusColor(position),
              size: 20,
            ),
          ),
        );
      },
    );
  }

  Color _getDeviceStatusColor(DevicePosition position) {
    if (!position.hasDevice) {
      return Colors.grey;
    } else if (!position.isConnected) {
      return Colors.orange;
    } else {
      if (position.alertLevel != null && position.alertLevel! > 0) {
        switch (position.alertLevel) {
          case 1:
            return Colors.yellow;
          case 2:
            return Colors.orange;
          case 3:
            return Colors.red;
          default:
            return Colors.green;
        }
      } else {
        return Colors.green;
      }
    }
  }

  IconData _getDeviceStatusIcon(DevicePosition position) {
    if (!position.hasDevice) {
      return Icons.add;
    } else if (!position.isConnected) {
      return Icons.bluetooth_disabled;
    } else {
      if (position.alertLevel != null && position.alertLevel! > 0) {
        return Icons.warning;
      } else {
        return Icons.bluetooth_connected;
      }
    }
  }
}
