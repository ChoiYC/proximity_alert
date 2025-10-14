import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../services/person_detector.dart';
import '../services/distance_estimator.dart';
import '../services/image_cropper.dart';
import '../services/multi_device_bluetooth_service.dart';
import '../widgets/alert_overlay.dart';
import '../widgets/device_grid_widget.dart';
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

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeDetectors();
    _initializeBluetooth();
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

        // Update UI after consecutive detections
        if (_consecutiveDetections >= _requiredConsecutiveDetections) {
          if (mounted) {
            setState(() {
              _detectedDistance = distance;
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
    }
  }

  @override
  void dispose() {
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

          // Device grid at top
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MultiDeviceBluetoothSettingsScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const CompactDeviceGrid(dotSize: 35),
                ),
              ),
            ),
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
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                ],
              ),
            ),
          ),

          // Note: Image display removed for performance when using image stream
          // Image capture from stream can be added later if needed
        ],
      ),
    );
  }
}
