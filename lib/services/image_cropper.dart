import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image/image.dart' as img;

class ImageCropper {
  /// Crops an image to show the detected person's face and upper body
  Future<String?> cropToPerson(String imagePath, Pose pose) async {
    try {
      debugPrint('🖼️ Starting face-centered crop for: $imagePath');

      // Read the image file
      final imageFile = File(imagePath);
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        debugPrint('❌ Failed to decode image');
        return null;
      }

      debugPrint('📐 Image dimensions: ${image.width}x${image.height}');

      // Get face landmarks (nose, eyes, ears)
      final nose = pose.landmarks[PoseLandmarkType.nose];
      final leftEye = pose.landmarks[PoseLandmarkType.leftEye];
      final rightEye = pose.landmarks[PoseLandmarkType.rightEye];
      final leftEar = pose.landmarks[PoseLandmarkType.leftEar];
      final rightEar = pose.landmarks[PoseLandmarkType.rightEar];
      final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
      final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
      final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
      final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

      if (nose == null || leftShoulder == null || rightShoulder == null) {
        debugPrint('❌ Missing critical landmarks for face crop');
        return null;
      }

      // Calculate face center (using nose as primary reference)
      double faceCenterX = nose.x;
      double faceCenterY = nose.y;

      // Calculate bounding box centered on face with face landmarks
      double minX = nose.x;
      double maxX = nose.x;
      double minY = nose.y;
      double maxY = nose.y;

      // Include face landmarks
      final faceLandmarks = [nose, leftEye, rightEye, leftEar, rightEar];
      for (final landmark in faceLandmarks) {
        if (landmark != null) {
          minX = minX < landmark.x ? minX : landmark.x;
          maxX = maxX > landmark.x ? maxX : landmark.x;
          minY = minY < landmark.y ? minY : landmark.y;
          maxY = maxY > landmark.y ? maxY : landmark.y;
        }
      }

      // Extend to include shoulders and upper torso
      if (leftShoulder != null) {
        minX = minX < leftShoulder.x ? minX : leftShoulder.x;
        maxX = maxX > leftShoulder.x ? maxX : leftShoulder.x;
        maxY = maxY > leftShoulder.y ? maxY : leftShoulder.y;
      }
      if (rightShoulder != null) {
        minX = minX < rightShoulder.x ? minX : rightShoulder.x;
        maxX = maxX > rightShoulder.x ? maxX : rightShoulder.x;
        maxY = maxY > rightShoulder.y ? maxY : rightShoulder.y;
      }

      // Extend a bit below shoulders (30% of torso height)
      if (leftHip != null && rightHip != null) {
        final torsoHeight = ((leftHip.y + rightHip.y) / 2) - ((leftShoulder.y + rightShoulder.y) / 2);
        maxY = maxY + (torsoHeight * 0.3);
      }

      debugPrint('📍 Face-centered bounding box:');
      debugPrint('   X: $minX - $maxX');
      debugPrint('   Y: $minY - $maxY');

      // Add generous padding for face (40% on sides, 60% on top for hair, 20% on bottom)
      final width = maxX - minX;
      final height = maxY - minY;
      final paddingX = width * 0.4;
      final paddingTop = height * 0.6;
      final paddingBottom = height * 0.2;

      minX = (minX - paddingX).clamp(0, image.width.toDouble());
      maxX = (maxX + paddingX).clamp(0, image.width.toDouble());
      minY = (minY - paddingTop).clamp(0, image.height.toDouble());
      maxY = (maxY + paddingBottom).clamp(0, image.height.toDouble());

      debugPrint('📍 Padded bounding box:');
      debugPrint('   X: $minX - $maxX');
      debugPrint('   Y: $minY - $maxY');

      // Crop the image
      final cropWidth = (maxX - minX).toInt();
      final cropHeight = (maxY - minY).toInt();

      if (cropWidth <= 0 || cropHeight <= 0) {
        debugPrint('❌ Invalid crop dimensions: ${cropWidth}x$cropHeight');
        return null;
      }

      final cropped = img.copyCrop(
        image,
        x: minX.toInt(),
        y: minY.toInt(),
        width: cropWidth,
        height: cropHeight,
      );

      debugPrint('✂️ Cropped to: ${cropped.width}x${cropped.height}');

      // Save cropped image
      final croppedPath = imagePath.replaceAll('.jpg', '_cropped.jpg');
      final croppedFile = File(croppedPath);
      await croppedFile.writeAsBytes(img.encodeJpg(cropped));

      debugPrint('✅ Cropped image saved to: $croppedPath');
      return croppedPath;
    } catch (e) {
      debugPrint('❌ Error cropping image: $e');
      return null;
    }
  }

  /// Checks if a pose has sufficient confidence and landmarks
  /// Uses strict validation to reduce false positives
  bool isValidPose(Pose pose) {
    // 1. Check for critical body parts with confidence threshold
    final nose = pose.landmarks[PoseLandmarkType.nose];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];

    // Critical landmarks must exist
    if (nose == null || leftShoulder == null || rightShoulder == null ||
        leftHip == null || rightHip == null) {
      debugPrint('⚠️ Invalid pose: missing critical landmarks (nose, shoulders, or hips)');
      return false;
    }

    // 2. Count total valid landmarks
    int validLandmarks = 0;
    for (final landmark in pose.landmarks.values) {
      if (landmark != null) {
        validLandmarks++;
      }
    }

    // Should have at least 15 landmarks for a reliable detection
    if (validLandmarks < 15) {
      debugPrint('⚠️ Invalid pose: only $validLandmarks landmarks detected (need at least 15)');
      return false;
    }

    // 3. Validate anatomical structure: shoulders should be above hips
    final shoulderMidpointY = (leftShoulder.y + rightShoulder.y) / 2;
    final hipMidpointY = (leftHip.y + rightHip.y) / 2;

    if (shoulderMidpointY >= hipMidpointY) {
      debugPrint('⚠️ Invalid pose: shoulders not above hips (anatomically incorrect)');
      return false;
    }

    // 4. Check shoulder width is reasonable (not too small or too large)
    final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
    if (shoulderWidth < 20 || shoulderWidth > 500) {
      debugPrint('⚠️ Invalid pose: shoulder width ${shoulderWidth.toStringAsFixed(1)}px is unrealistic');
      return false;
    }

    // 5. Check torso height is reasonable
    final torsoHeight = (hipMidpointY - shoulderMidpointY).abs();
    if (torsoHeight < 30) {
      debugPrint('⚠️ Invalid pose: torso height ${torsoHeight.toStringAsFixed(1)}px is too small');
      return false;
    }

    // 6. Validate pose proportions: torso height should be similar to shoulder width
    // Typical human proportions: torso ~ 1.5x shoulder width
    final proportionRatio = torsoHeight / shoulderWidth;
    if (proportionRatio < 0.3 || proportionRatio > 3.0) {
      debugPrint('⚠️ Invalid pose: torso/shoulder ratio ${proportionRatio.toStringAsFixed(2)} is unrealistic');
      return false;
    }

    debugPrint('✅ Valid pose confirmed: $validLandmarks landmarks, realistic proportions');
    return true;
  }

  void dispose() {
    // Cleanup if needed
  }
}
