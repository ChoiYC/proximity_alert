import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/bluetooth_service.dart';

class BluetoothSettingsScreen extends StatefulWidget {
  const BluetoothSettingsScreen({super.key});

  @override
  State<BluetoothSettingsScreen> createState() => _BluetoothSettingsScreenState();
}

class _BluetoothSettingsScreenState extends State<BluetoothSettingsScreen> {
  final ESP32BluetoothService _bluetoothService = ESP32BluetoothService();
  bool _isBluetoothOn = false;

  @override
  void initState() {
    super.initState();
    _checkBluetoothState();
    _listenToBluetoothState();
  }

  Future<void> _checkBluetoothState() async {
    final state = await FlutterBluePlus.adapterState.first;
    setState(() {
      _isBluetoothOn = state == BluetoothAdapterState.on;
    });
  }

  void _listenToBluetoothState() {
    FlutterBluePlus.adapterState.listen((state) {
      setState(() {
        _isBluetoothOn = state == BluetoothAdapterState.on;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Settings'),
        backgroundColor: Colors.blue,
      ),
      body: AnimatedBuilder(
        animation: _bluetoothService,
        builder: (context, child) {
          return Column(
            children: [
              // Bluetooth status card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isBluetoothOn ? Colors.blue.shade50 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isBluetoothOn ? Colors.blue : Colors.grey,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bluetooth,
                      size: 40,
                      color: _isBluetoothOn ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bluetooth',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            _isBluetoothOn ? 'On' : 'Off',
                            style: TextStyle(
                              color: _isBluetoothOn ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isBluetoothOn)
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            // Try to request Bluetooth enable (Android only)
                            await FlutterBluePlus.turnOn();
                          } catch (e) {
                            // If turnOn() is not supported, show dialog to open settings
                            if (mounted) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Bluetooth Required'),
                                  content: const Text(
                                    'Please enable Bluetooth in your device settings to scan for devices.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        await openAppSettings();
                                      },
                                      child: const Text('Open Settings'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Enable'),
                      ),
                  ],
                ),
              ),

              // Connected device card
              if (_bluetoothService.connectedDevice != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 40),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connected Device',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              _bluetoothService.connectedDevice!.platformName.isNotEmpty
                                  ? _bluetoothService.connectedDevice!.platformName
                                  : 'Unknown Device',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _bluetoothService.connectedDevice!.remoteId.toString(),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () async {
                          await _bluetoothService.disconnect();
                        },
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Scan button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
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
                    label: Text(_bluetoothService.isScanning ? 'Scanning...' : 'Scan for Devices'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Scan results
              Expanded(
                child: _bluetoothService.scanResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bluetooth_searching, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No devices found',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap "Scan for Devices" to start',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _bluetoothService.scanResults.length,
                        itemBuilder: (context, index) {
                          final result = _bluetoothService.scanResults[index];
                          final device = result.device;
                          final rssi = result.rssi;

                          // Filter out devices with no name (optional)
                          final deviceName = device.platformName.isNotEmpty
                              ? device.platformName
                              : 'Unknown Device';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: Icon(
                                Icons.bluetooth,
                                color: rssi > -70 ? Colors.blue : Colors.grey,
                              ),
                              title: Text(deviceName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(device.remoteId.toString()),
                                  Text('Signal: $rssi dBm'),
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed: () async {
                                  final success = await _bluetoothService.connectToDevice(device);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? 'Connected to $deviceName'
                                              : 'Failed to connect to $deviceName',
                                        ),
                                        backgroundColor: success ? Colors.green : Colors.red,
                                      ),
                                    );
                                    if (success) {
                                      Navigator.pop(context);
                                    }
                                  }
                                },
                                child: const Text('Connect'),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
