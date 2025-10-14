import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/device_position.dart';
import '../services/multi_device_bluetooth_service.dart';

/// Dialog for connecting a device to a specific position
class DeviceConnectionDialog extends StatefulWidget {
  final int row;
  final int col;
  final DevicePosition? existingPosition;

  const DeviceConnectionDialog({
    super.key,
    required this.row,
    required this.col,
    this.existingPosition,
  });

  @override
  State<DeviceConnectionDialog> createState() => _DeviceConnectionDialogState();
}

class _DeviceConnectionDialogState extends State<DeviceConnectionDialog> {
  final MultiDeviceBluetoothService _bluetoothService = MultiDeviceBluetoothService();
  bool _isBluetoothOn = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _checkBluetoothState();
    _listenToBluetoothState();
  }

  @override
  void dispose() {
    // CRITICAL: Stop scanning when dialog closes!
    _bluetoothService.stopScan();
    super.dispose();
  }

  Future<void> _checkBluetoothState() async {
    final state = await FlutterBluePlus.adapterState.first;
    setState(() {
      _isBluetoothOn = state == BluetoothAdapterState.on;
    });
  }

  void _listenToBluetoothState() {
    FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() {
          _isBluetoothOn = state == BluetoothAdapterState.on;
        });
      }
    });
  }

  Future<void> _requestBluetoothPermissions() async {
    final permissions = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ];

    for (var permission in permissions) {
      if (await permission.isDenied) {
        await permission.request();
      }
    }
  }

  Future<void> _startScan() async {
    await _requestBluetoothPermissions();

    if (!_isBluetoothOn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please turn on Bluetooth')),
        );
      }
      return;
    }

    await _bluetoothService.startScan();
  }

  String _getPositionLabel() {
    const rowLabels = ['Front', 'Rear'];
    const colLabels = ['Left', 'Right'];
    return '${rowLabels[widget.row]} ${colLabels[widget.col]}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Connect Device',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Position: ${_getPositionLabel()}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Current device (if exists)
            if (widget.existingPosition?.hasDevice ?? false)
              Card(
                color: Colors.blue.shade50,
                child: ListTile(
                  leading: Icon(
                    widget.existingPosition!.isConnected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    color: widget.existingPosition!.isConnected
                        ? Colors.green
                        : Colors.orange,
                  ),
                  title: Text(widget.existingPosition!.deviceName ?? 'ESP32-C3'),
                  subtitle: Text(
                    widget.existingPosition!.deviceId ?? '',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await _bluetoothService.removeDeviceFromPosition(
                        widget.row,
                        widget.col,
                      );
                      if (mounted) {
                        Navigator.pop(context, true);
                      }
                    },
                  ),
                ),
              ),

            if (widget.existingPosition?.hasDevice ?? false)
              const Divider(height: 32),

            // Scan button and results (wrapped in AnimatedBuilder to update button state)
            Expanded(
              child: AnimatedBuilder(
                animation: _bluetoothService,
                builder: (context, child) {
                  return Column(
                    children: [
                      // Scan button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _bluetoothService.isScanning ? null : _startScan,
                          icon: _bluetoothService.isScanning
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.search),
                          label: Text(
                            _bluetoothService.isScanning ? 'Scanning...' : 'Scan for Devices',
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Scan results
                      Expanded(
                        child: _buildScanResults(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanResults() {
    // DEBUG: Print all scan results
    print('📡 Total scan results: ${_bluetoothService.scanResults.length}');
    for (var result in _bluetoothService.scanResults) {
      print('  Device: ${result.device.platformName} (${result.device.remoteId}) RSSI: ${result.rssi}');
    }

    // Filter to show only TeslaGuard devices that are NOT already connected
    final filteredResults = _bluetoothService.scanResults.where((result) {
      final name = result.device.platformName.toLowerCase();
      final isTeslaGuard = name.contains('teslaguard') || name.contains('tesla');

      if (!isTeslaGuard) return false;

      // Check if device is already connected to ANY position
      final isAlreadyUsed = _bluetoothService.devicePositions.any(
        (pos) => pos.deviceId == result.device.remoteId.toString(),
      );

      print('  Device: "$name" (${result.device.remoteId}) -> TeslaGuard: $isTeslaGuard, AlreadyUsed: $isAlreadyUsed');

      // Only show if it's a TeslaGuard device AND not already used
      return isTeslaGuard && !isAlreadyUsed;
    }).toList();

    print('🔍 Filtered results: ${filteredResults.length}');

    if (filteredResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_searching,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _bluetoothService.isScanning
                  ? 'Searching for TeslaGuard devices...'
                  : 'No TeslaGuard devices found',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              _bluetoothService.isScanning
                  ? 'Make sure ESP32 is powered on'
                  : 'Tap "Scan for Devices" to start',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            // DEBUG: Show total scan count
            Text(
              'Found ${_bluetoothService.scanResults.length} total devices',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredResults.length,
      itemBuilder: (context, index) {
        final result = filteredResults[index];
        final device = result.device;
        final rssi = result.rssi;

        final deviceName = device.platformName.isNotEmpty
            ? device.platformName
            : 'Unknown Device';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Icon(
              Icons.bluetooth,
              color: rssi > -70 ? Colors.blue : Colors.grey,
            ),
            title: Text(deviceName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.remoteId.toString(),
                  style: const TextStyle(fontSize: 11),
                ),
                Text(
                  'Signal: $rssi dBm',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
            trailing: _isConnecting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : ElevatedButton(
                    onPressed: () async {
                      setState(() => _isConnecting = true);

                      final success = await _bluetoothService
                          .connectDeviceToPosition(
                        device,
                        widget.row,
                        widget.col,
                      );

                      if (mounted) {
                        setState(() => _isConnecting = false);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Connected to $deviceName at ${_getPositionLabel()}'
                                  : 'Failed to connect to $deviceName',
                            ),
                            backgroundColor:
                                success ? Colors.green : Colors.red,
                          ),
                        );

                        if (success) {
                          Navigator.pop(context, true);
                        }
                      }
                    },
                    child: const Text('Connect'),
                  ),
          ),
        );
      },
    );
  }
}

/// Show device connection dialog
Future<bool?> showDeviceConnectionDialog(
  BuildContext context,
  int row,
  int col,
  DevicePosition? existingPosition,
) {
  return showDialog<bool>(
    context: context,
    builder: (context) => DeviceConnectionDialog(
      row: row,
      col: col,
      existingPosition: existingPosition,
    ),
  );
}
