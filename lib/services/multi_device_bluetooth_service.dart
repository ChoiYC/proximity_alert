import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_position.dart';

/// Service for managing multiple ESP32-C3 devices in a 2x2 grid
class MultiDeviceBluetoothService extends ChangeNotifier {
  static final MultiDeviceBluetoothService _instance = MultiDeviceBluetoothService._internal();
  factory MultiDeviceBluetoothService() => _instance;
  MultiDeviceBluetoothService._internal() {
    _initializeGrid();
  }

  // 2x2 grid of device positions (4 positions total - one for each door)
  final List<DevicePosition> _devicePositions = [];

  // Map of device ID to connection state subscriptions
  final Map<String, StreamSubscription<BluetoothConnectionState>> _connectionSubscriptions = {};

  // Scanning state
  bool _isScanning = false;
  List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  // Preferences key
  static const String _devicePositionsKey = 'device_positions_grid';

  // Getters
  List<DevicePosition> get devicePositions => List.unmodifiable(_devicePositions);
  bool get isScanning => _isScanning;
  List<ScanResult> get scanResults => _scanResults;

  /// Get device at specific position
  DevicePosition getDeviceAt(int row, int col) {
    return _devicePositions.firstWhere(
      (pos) => pos.row == row && pos.col == col,
      orElse: () => DevicePosition(row: row, col: col),
    );
  }

  /// Get all connected devices
  List<DevicePosition> get connectedDevices {
    return _devicePositions.where((pos) => pos.isConnected).toList();
  }

  /// Get device count
  int get assignedDeviceCount {
    return _devicePositions.where((pos) => pos.hasDevice).length;
  }

  /// Initialize 2x2 grid
  void _initializeGrid() {
    for (int row = 0; row < 2; row++) {
      for (int col = 0; col < 2; col++) {
        _devicePositions.add(DevicePosition(row: row, col: col));
      }
    }
  }

  /// Initialize the service and load saved positions
  Future<void> initialize() async {
    // Check if Bluetooth is supported
    if (await FlutterBluePlus.isSupported == false) {
      debugPrint('Bluetooth not supported by this device');
      return;
    }

    // Load saved device positions
    await _loadDevicePositions();

    // Try to reconnect to previously connected devices
    await _tryAutoReconnectAll();
  }

  /// Load device positions from storage
  Future<void> _loadDevicePositions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString(_devicePositionsKey);

      if (savedData != null) {
        final List<dynamic> jsonList = json.decode(savedData);

        for (var jsonItem in jsonList) {
          final position = DevicePosition.fromJson(jsonItem);
          final index = position.index;

          if (index >= 0 && index < _devicePositions.length) {
            _devicePositions[index] = position;
          }
        }

        debugPrint('Loaded ${jsonList.length} device positions from storage');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading device positions: $e');
    }
  }

  /// Save device positions to storage
  Future<void> _saveDevicePositions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final positions = _devicePositions
          .where((pos) => pos.hasDevice)
          .map((pos) => pos.toJson())
          .toList();

      await prefs.setString(_devicePositionsKey, json.encode(positions));
      debugPrint('Saved ${positions.length} device positions');
    } catch (e) {
      debugPrint('Error saving device positions: $e');
    }
  }

  /// Try to reconnect to all previously connected devices
  Future<void> _tryAutoReconnectAll() async {
    for (var position in _devicePositions.where((p) => p.hasDevice)) {
      try {
        if (position.deviceId != null) {
          final device = BluetoothDevice.fromId(position.deviceId!);
          await connectDeviceToPosition(device, position.row, position.col);
        }
      } catch (e) {
        debugPrint('Auto-reconnect failed for ${position.positionLabel}: $e');
      }
    }
  }

  /// Start scanning for Bluetooth devices
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    try {
      debugPrint('🔵 Starting BLE scan...');

      // CRITICAL: Stop any existing scan first!
      await stopScan();

      // Check Bluetooth adapter state
      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        debugPrint('❌ Bluetooth is not on');
        return;
      }

      _isScanning = true;
      _scanResults.clear();
      notifyListeners();

      // Listen to scan results BEFORE starting scan
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        debugPrint('📡 Scan results updated: ${results.length} devices');
        _scanResults = results;
        notifyListeners();
      });

      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: false,
      );

      debugPrint('✅ BLE scan started (timeout: ${timeout.inSeconds}s)');

      // Wait for scan to complete
      await Future.delayed(timeout);
      await stopScan();
      debugPrint('⏱️ Scan timeout reached, stopping...');
    } catch (e) {
      debugPrint('❌ Error scanning: $e');
      await stopScan(); // Ensure scan is stopped on error
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    try {
      debugPrint('🛑 Stopping BLE scan...');

      // Cancel subscription first
      await _scanSubscription?.cancel();
      _scanSubscription = null;

      // Stop the actual scan
      await FlutterBluePlus.stopScan();

      _isScanning = false;
      notifyListeners();

      debugPrint('✅ BLE scan stopped successfully');
    } catch (e) {
      debugPrint('⚠️ Error stopping scan: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Connect a device to a specific position
  Future<bool> connectDeviceToPosition(
    BluetoothDevice device,
    int row,
    int col,
  ) async {
    try {
      final index = row * 2 + col;

      debugPrint('🔗 connectDeviceToPosition called:');
      debugPrint('   row=$row, col=$col, calculated index=$index');
      debugPrint('   _devicePositions.length=${_devicePositions.length}');

      if (index < 0 || index >= _devicePositions.length) {
        debugPrint('❌ Invalid position: row=$row, col=$col, index=$index');
        return false;
      }

      debugPrint('🔗 Connecting ${device.platformName} to ${_devicePositions[index].positionLabel}');
      debugPrint('   Device ID: ${device.remoteId}');

      // Check if device is already connected elsewhere
      final existingPosition = _devicePositions.firstWhere(
        (pos) => pos.deviceId == device.remoteId.toString(),
        orElse: () => DevicePosition(row: -1, col: -1),
      );

      if (existingPosition.row != -1) {
        debugPrint('Device already connected at ${existingPosition.positionLabel}');
        // Disconnect from previous position
        await disconnectPosition(existingPosition.row, existingPosition.col);
      }

      // Connect to device
      debugPrint('   Attempting BLE connection (timeout: 15s)...');
      try {
        await device.connect(
          timeout: const Duration(seconds: 15),
          autoConnect: false,
        );
        debugPrint('   ✅ BLE connection successful');
      } catch (connectError) {
        debugPrint('   ❌ BLE connection failed: $connectError');
        debugPrint('   Device may need to be reset or is still in connected state');
        rethrow;  // Re-throw to be caught by outer try-catch
      }

      // Create updated position
      final updatedPosition = _devicePositions[index].copyWith(
        deviceId: device.remoteId.toString(),
        deviceName: device.platformName.isNotEmpty ? device.platformName : 'ESP32-C3',
        device: device,
        connectionState: BluetoothConnectionState.connected,
      );

      _devicePositions[index] = updatedPosition;

      // Listen to connection state changes
      final subscription = device.connectionState.listen((state) {
        _onConnectionStateChanged(row, col, state);
      });

      _connectionSubscriptions[device.remoteId.toString()] = subscription;

      // Save positions
      await _saveDevicePositions();

      notifyListeners();

      debugPrint('✅ Connected ${device.platformName} to ${updatedPosition.positionLabel}');

      // Debug: Print all device positions
      debugPrint('📊 Current device positions:');
      for (var pos in _devicePositions) {
        debugPrint('   [${pos.row},${pos.col}] ${pos.positionLabel}: ${pos.hasDevice ? pos.deviceName : "Empty"} ${pos.hasDevice ? "(${pos.deviceId})" : ""}');
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error connecting device: $e');
      notifyListeners();
      return false;
    }
  }

  /// Handle connection state changes
  void _onConnectionStateChanged(int row, int col, BluetoothConnectionState state) {
    final index = row * 2 + col;
    if (index >= 0 && index < _devicePositions.length) {
      _devicePositions[index] = _devicePositions[index].copyWith(
        connectionState: state,
      );

      debugPrint('Connection state changed for ${_devicePositions[index].positionLabel}: $state');
      notifyListeners();
    }
  }

  /// Disconnect device at specific position
  Future<void> disconnectPosition(int row, int col) async {
    final index = row * 2 + col;
    if (index < 0 || index >= _devicePositions.length) return;

    final position = _devicePositions[index];

    try {
      debugPrint('🔌 Disconnecting device at ${position.positionLabel}');
      debugPrint('   Device ID: ${position.deviceId}');
      debugPrint('   Device Name: ${position.deviceName}');

      // Cancel subscription FIRST to prevent state change notifications during disconnect
      if (position.deviceId != null) {
        debugPrint('   Canceling connection subscription...');
        await _connectionSubscriptions[position.deviceId]?.cancel();
        _connectionSubscriptions.remove(position.deviceId);
      }

      // Now disconnect the device
      if (position.device != null) {
        debugPrint('   Calling device.disconnect()...');
        try {
          await position.device!.disconnect();
          debugPrint('   ✅ Device disconnected successfully');
        } catch (disconnectError) {
          debugPrint('   ⚠️ Disconnect error (may be already disconnected): $disconnectError');
        }

        // Add delay to allow Bluetooth stack to fully clean up
        await Future.delayed(const Duration(milliseconds: 500));
        debugPrint('   ⏱️ Cleanup delay completed');
      }

      debugPrint('✅ Fully disconnected from ${position.positionLabel}');
    } catch (e) {
      debugPrint('❌ Error disconnecting from ${position.positionLabel}: $e');
      debugPrint('   Stack trace: ${StackTrace.current}');
    }
  }

  /// Remove device from position
  Future<void> removeDeviceFromPosition(int row, int col) async {
    debugPrint('🗑️ Removing device from position: row=$row, col=$col');

    // First disconnect the device (which includes cleanup delay)
    await disconnectPosition(row, col);

    final index = row * 2 + col;
    if (index >= 0 && index < _devicePositions.length) {
      debugPrint('   Creating new empty DevicePosition...');

      // Create a completely new DevicePosition (this clears all references)
      _devicePositions[index] = DevicePosition(row: row, col: col);

      // Save to storage
      await _saveDevicePositions();

      // Notify listeners
      notifyListeners();

      debugPrint('✅ Device removed successfully from position [$row,$col]');
    }
  }

  /// Send alert command to device at position
  Future<bool> sendAlertToPosition(int row, int col, int alertLevel) async {
    final index = row * 2 + col;
    if (index < 0 || index >= _devicePositions.length) return false;

    final position = _devicePositions[index];

    if (position.device == null || !position.isConnected) {
      debugPrint('Device not connected at ${position.positionLabel}');
      return false;
    }

    try {
      // Update alert level in position
      _devicePositions[index] = position.copyWith(alertLevel: alertLevel);
      notifyListeners();

      // Send command to ESP32-C3
      // Format: [alertLevel] (0-3: none, level1, level2, level3)
      final data = [alertLevel];

      final services = await position.device!.discoverServices();

      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            await characteristic.write(data);
            debugPrint('✅ Sent alert level $alertLevel to ${position.positionLabel}');
            return true;
          }
        }
      }

      debugPrint('❌ No writable characteristic found for ${position.positionLabel}');
      return false;
    } catch (e) {
      debugPrint('❌ Error sending alert to ${position.positionLabel}: $e');
      return false;
    }
  }

  /// Subscribe to proximity data from device
  Future<void> subscribeToProximityData(int row, int col, Function(double distance) onData) async {
    final index = row * 2 + col;
    if (index < 0 || index >= _devicePositions.length) return;

    final position = _devicePositions[index];

    if (position.device == null || !position.isConnected) {
      debugPrint('Device not connected at ${position.positionLabel}');
      return;
    }

    try {
      final services = await position.device!.discoverServices();

      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);

            characteristic.lastValueStream.listen((value) {
              if (value.isNotEmpty) {
                // Assuming distance is sent as float (4 bytes)
                // Adjust parsing based on your ESP32-C3 implementation
                try {
                  final distance = value[0].toDouble() / 100.0; // Example: cm to m

                  // Update position with proximity data
                  _devicePositions[index] = position.copyWith(
                    proximityDistance: distance,
                  );

                  onData(distance);
                  notifyListeners();
                } catch (e) {
                  debugPrint('Error parsing proximity data: $e');
                }
              }
            });

            debugPrint('✅ Subscribed to proximity data from ${position.positionLabel}');
            return;
          }
        }
      }

      debugPrint('❌ No notifiable characteristic found for ${position.positionLabel}');
    } catch (e) {
      debugPrint('❌ Error subscribing to proximity data: $e');
    }
  }

  /// Disconnect all devices
  Future<void> disconnectAll() async {
    debugPrint('🔌 Disconnecting all devices...');
    for (int i = 0; i < _devicePositions.length; i++) {
      final row = i ~/ 2;  // Fixed: 2x2 grid (was ~/ 3)
      final col = i % 2;   // Fixed: 2x2 grid (was % 3)
      await disconnectPosition(row, col);
    }

    notifyListeners();
    debugPrint('✅ All devices disconnected');
  }

  @override
  void dispose() {
    disconnectAll();
    _scanSubscription?.cancel();
    super.dispose();
  }
}
