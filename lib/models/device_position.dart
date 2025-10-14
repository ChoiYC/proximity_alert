import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Model for storing device position and connection info
class DevicePosition {
  final int row;
  final int col;
  final String? deviceId;
  final String? deviceName;
  BluetoothDevice? device;
  BluetoothConnectionState connectionState;

  // Sensor data (for future use)
  double? proximityDistance;
  int? alertLevel; // 0: none, 1: level1 (5m), 2: level2 (3m), 3: level3 (1m)

  DevicePosition({
    required this.row,
    required this.col,
    this.deviceId,
    this.deviceName,
    this.device,
    this.connectionState = BluetoothConnectionState.disconnected,
    this.proximityDistance,
    this.alertLevel = 0,
  });

  /// Create from JSON
  factory DevicePosition.fromJson(Map<String, dynamic> json) {
    return DevicePosition(
      row: json['row'] as int,
      col: json['col'] as int,
      deviceId: json['deviceId'] as String?,
      deviceName: json['deviceName'] as String?,
      alertLevel: json['alertLevel'] as int? ?? 0,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'row': row,
      'col': col,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'alertLevel': alertLevel,
    };
  }

  /// Create a copy with updated values
  DevicePosition copyWith({
    int? row,
    int? col,
    String? deviceId,
    String? deviceName,
    BluetoothDevice? device,
    BluetoothConnectionState? connectionState,
    double? proximityDistance,
    int? alertLevel,
  }) {
    return DevicePosition(
      row: row ?? this.row,
      col: col ?? this.col,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      device: device ?? this.device,
      connectionState: connectionState ?? this.connectionState,
      proximityDistance: proximityDistance ?? this.proximityDistance,
      alertLevel: alertLevel ?? this.alertLevel,
    );
  }

  /// Get position index (0-3 for 2x2 grid)
  int get index => row * 2 + col;

  /// Check if device is assigned
  bool get hasDevice => deviceId != null;

  /// Check if device is connected
  bool get isConnected => connectionState == BluetoothConnectionState.connected;

  /// Get position label (e.g., "Front Left", "Rear Right")
  String get positionLabel {
    const rowLabels = ['Front', 'Rear'];
    const colLabels = ['Left', 'Right'];
    return '${rowLabels[row]} ${colLabels[col]}';
  }
}
