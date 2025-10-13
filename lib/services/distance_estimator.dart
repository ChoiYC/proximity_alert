import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:math' as math;

class DistanceEstimator {
  // Average human shoulder width in meters
  static const double averageShoulderWidth = 0.45;

  // Average human height in meters (fallback)
  static const double averageHumanHeight = 1.7;

  Future<double> estimateDistance(
    Pose pose,
    CameraController cameraController,
  ) async {
    // Get shoulder landmarks
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    // Get image dimensions
    final imageWidth = cameraController.value.previewSize?.width ?? 1080;
    final imageHeight = cameraController.value.previewSize?.height ?? 1920;

    double distance;

    if (leftShoulder != null && rightShoulder != null) {
      // Calculate shoulder width in pixels
      final shoulderWidthPixels = math.sqrt(
        math.pow(leftShoulder.x - rightShoulder.x, 2) +
            math.pow(leftShoulder.y - rightShoulder.y, 2),
      );

      // Estimate distance using shoulder width
      // distance = (realWidth * imageWidth) / (pixelWidth * calibrationFactor)
      const calibrationFactor = 2.0; // Adjust based on testing

      distance = (averageShoulderWidth * imageWidth) /
          (shoulderWidthPixels * calibrationFactor);

      print('📏 Shoulder width: ${shoulderWidthPixels.toStringAsFixed(1)}px → distance: ${distance.toStringAsFixed(2)}m');
    } else {
      // Fallback: use body height if shoulders not detected
      final nose = pose.landmarks[PoseLandmarkType.nose];
      final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
      final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

      if (nose != null && (leftAnkle != null || rightAnkle != null)) {
        final ankle = leftAnkle ?? rightAnkle!;
        final bodyHeightPixels = math.sqrt(
          math.pow(nose.x - ankle.x, 2) + math.pow(nose.y - ankle.y, 2),
        );

        const calibrationFactor = 1.5;
        distance = (averageHumanHeight * imageHeight) /
            (bodyHeightPixels * calibrationFactor);

        print('📏 Body height: ${bodyHeightPixels.toStringAsFixed(1)}px → distance: ${distance.toStringAsFixed(2)}m');
      } else {
        // Last resort: use a default medium distance
        distance = 5.0;
        print('⚠️ Unable to measure body dimensions, using default distance');
      }
    }

    // Clamp distance to reasonable range (0.5m - 15m)
    return math.max(0.5, math.min(15.0, distance));
  }

  void dispose() {
    // Cleanup if needed
  }
}
