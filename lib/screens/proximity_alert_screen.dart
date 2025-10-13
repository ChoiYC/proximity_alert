import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../services/person_detector.dart';
import '../services/distance_estimator.dart';
import '../services/image_cropper.dart';
import '../widgets/alert_overlay.dart';

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
  double _currentFps = 0.0;
  String? _lastDetectedImagePath;  // 마지막 감지된 이미지 경로

  // Temporal filtering to reduce false positives
  int _consecutiveDetections = 0;
  int _consecutiveNonDetections = 0;
  static const int _requiredConsecutiveDetections = 2;  // Need 2 frames in a row
  static const int _requiredConsecutiveNonDetections = 2;  // Need 2 frames without detection to clear

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeDetectors();
  }

  Future<void> _initializeCamera() async {
    _cameraController = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _lastFpsUpdate = DateTime.now();
        });

        // Start periodic capture (2 FPS for better performance)
        Timer.periodic(const Duration(milliseconds: 500), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          _captureAndProcess();
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _captureAndProcess() async {
    if (_isProcessing || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _isProcessing = true;
    _frameCount++;

    // Update FPS
    final now = DateTime.now();
    if (_lastFpsUpdate != null) {
      final elapsed = now.difference(_lastFpsUpdate!).inMilliseconds;
      if (elapsed >= 1000) {
        _currentFps = _frameCount / (elapsed / 1000);
        _frameCount = 0;
        _lastFpsUpdate = now;
        debugPrint('📊 FPS: ${_currentFps.toStringAsFixed(1)}');
      }
    }

    try {
      debugPrint('📸 Taking picture...');
      final startTime = DateTime.now();
      final image = await _cameraController!.takePicture();
      final captureTime = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('✅ Picture taken in ${captureTime}ms: ${image.path}');

      final inputImage = InputImage.fromFilePath(image.path);
      debugPrint('🖼️ InputImage created from: ${image.path}');

      final detectionStartTime = DateTime.now();
      final detections = await _personDetector!.detectPerson(inputImage);
      final detectionTime = DateTime.now().difference(detectionStartTime).inMilliseconds;
      debugPrint('⏱️ Detection took ${detectionTime}ms');

      if (detections.isNotEmpty) {
        debugPrint('🎯 Processing ${detections.length} person detection(s)');

        // Validate pose to reduce false positives
        final pose = detections.first;
        if (!_imageCropper!.isValidPose(pose)) {
          debugPrint('⚠️ Pose validation failed - likely false positive');
          _consecutiveDetections = 0;
          _consecutiveNonDetections++;

          // Clear alert only after consecutive non-detections
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

        // Valid detection found - increment consecutive counter
        _consecutiveDetections++;
        _consecutiveNonDetections = 0;
        debugPrint('📊 Consecutive detections: $_consecutiveDetections/$_requiredConsecutiveDetections');

        final distance = await _distanceEstimator!.estimateDistance(
          pose,
          _cameraController!,
        );
        debugPrint('📏 Estimated distance: ${distance.toStringAsFixed(2)}m');

        // Crop image to show only the detected person
        final croppedPath = await _imageCropper!.cropToPerson(image.path, pose);

        // Only trigger alert after consecutive detections
        if (_consecutiveDetections >= _requiredConsecutiveDetections) {
          debugPrint('✅ Confirmed person after $_consecutiveDetections consecutive frames');
          if (mounted) {
            setState(() {
              _detectedDistance = distance;
              _lastDetectedImagePath = croppedPath ?? image.path;  // Use cropped image or fallback to original
              _updateAlertLevel(distance);
            });
          }
        } else {
          debugPrint('⏳ Waiting for more consecutive detections before alerting...');
        }
      } else {
        debugPrint('⚠️ No person detections');
        _consecutiveDetections = 0;
        _consecutiveNonDetections++;

        // Clear alert only after consecutive non-detections
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
      final totalTime = DateTime.now().difference(now).inMilliseconds;
      debugPrint('⏱️ Total processing time: ${totalTime}ms');
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

          // Debug info
          Positioned(
            top: 50,
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
                    'FPS: ${_currentFps.toStringAsFixed(1)}',
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

          // 오른쪽 위 - 감지된 사람 이미지
          if (_lastDetectedImagePath != null)
            Positioned(
              top: 50,
              right: 16,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _currentAlert == AlertLevel.warning3m
                        ? Colors.red
                        : _currentAlert == AlertLevel.warning5m
                            ? Colors.orange
                            : Colors.white,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(12),
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
}
