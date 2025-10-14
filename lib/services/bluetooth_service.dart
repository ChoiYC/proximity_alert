import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing Bluetooth connection to ESP32-C3 device
class ESP32BluetoothService extends ChangeNotifier {
  static final ESP32BluetoothService _instance = ESP32BluetoothService._internal();
  factory ESP32BluetoothService() => _instance;
  ESP32BluetoothService._internal();

  // Connection state
  BluetoothDevice? _connectedDevice;
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  bool _isScanning = false;
  List<ScanResult> _scanResults = [];

  // Stream subscriptions
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  // Preferences key
  static const String _lastDeviceIdKey = 'last_connected_device_id';

  // Getters
  BluetoothDevice? get connectedDevice => _connectedDevice;
  BluetoothConnectionState get connectionState => _connectionState;
  bool get isScanning => _isScanning;
  List<ScanResult> get scanResults => _scanResults;
  bool get isConnected => _connectionState == BluetoothConnectionState.connected;

  /// Initialize the Bluetooth service
  Future<void> initialize() async {
    // Check if Bluetooth is supported
    if (await FlutterBluePlus.isSupported == false) {
      debugPrint('Bluetooth not supported by this device');
      return;
    }

    // Try to auto-reconnect to last device
    await _tryAutoReconnect();
  }

  /// Try to reconnect to the last connected device
  Future<void> _tryAutoReconnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDeviceId = prefs.getString(_lastDeviceIdKey);

      if (lastDeviceId != null) {
        debugPrint('Attempting to reconnect to last device: $lastDeviceId');

        // Get system devices (already connected)
        final systemDevices = await FlutterBluePlus.systemDevices([]);
        for (var device in systemDevices) {
          if (device.remoteId.toString() == lastDeviceId) {
            await connectToDevice(device);
            return;
          }
        }

        // If not in system devices, try to connect directly
        final device = BluetoothDevice.fromId(lastDeviceId);
        await connectToDevice(device);
      }
    } catch (e) {
      debugPrint('Auto-reconnect failed: $e');
    }
  }

  /// Start scanning for Bluetooth devices
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    try {
      // Check Bluetooth adapter state
      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        debugPrint('Bluetooth is not on');
        return;
      }

      _isScanning = true;
      _scanResults.clear();
      notifyListeners();

      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: false,
      );

      // Listen to scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _scanResults = results;
        notifyListeners();
      });

      // Wait for scan to complete
      await Future.delayed(timeout);
      await stopScan();
    } catch (e) {
      debugPrint('Error scanning: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      _isScanning = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping scan: $e');
    }
  }

  /// Connect to a Bluetooth device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      debugPrint('Connecting to device: ${device.platformName}');

      // Cancel any existing connection
      await disconnect();

      // Connect with timeout
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      _connectedDevice = device;

      // Listen to connection state changes
      _connectionStateSubscription = device.connectionState.listen((state) {
        _connectionState = state;
        debugPrint('Connection state changed: $state');
        notifyListeners();

        // If disconnected unexpectedly, try to reconnect
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint('Device disconnected unexpectedly');
          _connectedDevice = null;
        }
      });

      // Save last connected device
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastDeviceIdKey, device.remoteId.toString());

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      _connectedDevice = null;
      _connectionState = BluetoothConnectionState.disconnected;
      notifyListeners();
      return false;
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    try {
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
        _connectedDevice = null;
        _connectionState = BluetoothConnectionState.disconnected;
        await _connectionStateSubscription?.cancel();
        _connectionStateSubscription = null;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    }
  }

  /// Send data to connected device
  Future<bool> sendData(List<int> data) async {
    if (_connectedDevice == null || !isConnected) {
      debugPrint('No device connected');
      return false;
    }

    try {
      // Discover services
      final services = await _connectedDevice!.discoverServices();

      // Find the UART service (common UUID for ESP32)
      // You may need to adjust this UUID based on your ESP32-C3 implementation
      for (var service in services) {
        // Look for characteristics that support write
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            await characteristic.write(data);
            debugPrint('Data sent successfully');
            return true;
          }
        }
      }

      debugPrint('No writable characteristic found');
      return false;
    } catch (e) {
      debugPrint('Error sending data: $e');
      return false;
    }
  }

  /// Read data from connected device
  Future<List<int>?> readData() async {
    if (_connectedDevice == null || !isConnected) {
      debugPrint('No device connected');
      return null;
    }

    try {
      // Discover services
      final services = await _connectedDevice!.discoverServices();

      // Find the UART service
      for (var service in services) {
        // Look for characteristics that support read
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.read) {
            final data = await characteristic.read();
            debugPrint('Data received: $data');
            return data;
          }
        }
      }

      debugPrint('No readable characteristic found');
      return null;
    } catch (e) {
      debugPrint('Error reading data: $e');
      return null;
    }
  }

  /// Subscribe to notifications from device
  Future<void> subscribeToNotifications(Function(List<int>) onData) async {
    if (_connectedDevice == null || !isConnected) {
      debugPrint('No device connected');
      return;
    }

    try {
      // Discover services
      final services = await _connectedDevice!.discoverServices();

      // Find characteristics that support notify
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify) {
            // Subscribe to notifications
            await characteristic.setNotifyValue(true);
            characteristic.lastValueStream.listen((value) {
              onData(value);
            });
            debugPrint('Subscribed to notifications');
            return;
          }
        }
      }

      debugPrint('No notifiable characteristic found');
    } catch (e) {
      debugPrint('Error subscribing to notifications: $e');
    }
  }

  /// Clear last connected device
  Future<void> clearLastDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastDeviceIdKey);
    } catch (e) {
      debugPrint('Error clearing last device: $e');
    }
  }

  @override
  void dispose() {
    disconnect();
    _scanSubscription?.cancel();
    super.dispose();
  }
}
