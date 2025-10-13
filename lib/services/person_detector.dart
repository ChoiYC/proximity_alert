import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PersonDetector {
  PoseDetector? _poseDetector;

  Future<void> initialize() async {
    final options = PoseDetectorOptions(
      mode: PoseDetectionMode.single,
    );

    _poseDetector = PoseDetector(options: options);
    debugPrint('✅ PoseDetector initialized');
  }

  Future<List<Pose>> detectPerson(InputImage inputImage) async {
    if (_poseDetector == null) {
      debugPrint('⚠️ PoseDetector is null!');
      return [];
    }

    try {
      debugPrint('🔍 Processing image for poses...');
      final poses = await _poseDetector!.processImage(inputImage);
      debugPrint('📦 Found ${poses.length} poses');

      // Log pose details
      for (var i = 0; i < poses.length; i++) {
        final pose = poses[i];
        final landmarkCount = pose.landmarks.length;
        debugPrint('  Pose $i: $landmarkCount landmarks detected');

        // Check if we have key body landmarks
        final nose = pose.landmarks[PoseLandmarkType.nose];
        final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
        final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

        if (nose != null && leftShoulder != null && rightShoulder != null) {
          debugPrint('    ✅ Valid person pose detected');
        }
      }

      debugPrint('👤 Person detections: ${poses.length}');
      return poses;
    } catch (e) {
      debugPrint('❌ Error detecting person: $e');
      return [];
    }
  }

  void dispose() {
    _poseDetector?.close();
  }
}
