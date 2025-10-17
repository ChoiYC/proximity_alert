import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/multi_device_bluetooth_service.dart';
import '../widgets/device_grid_widget.dart';
import '../widgets/device_connection_dialog.dart';

class MultiDeviceBluetoothSettingsScreen extends StatefulWidget {
  const MultiDeviceBluetoothSettingsScreen({super.key});

  @override
  State<MultiDeviceBluetoothSettingsScreen> createState() =>
      _MultiDeviceBluetoothSettingsScreenState();
}

class _MultiDeviceBluetoothSettingsScreenState
    extends State<MultiDeviceBluetoothSettingsScreen> {
  final MultiDeviceBluetoothService _bluetoothService = MultiDeviceBluetoothService();
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
      if (mounted) {
        setState(() {
          _isBluetoothOn = state == BluetoothAdapterState.on;
        });
      }
    });
  }

  Future<void> _handleDotTap(int row, int col) async {
    final position = _bluetoothService.getDeviceAt(row, col);

    // Debug: Print which position we're opening
    print('🔵 Opening dialog for position: row=$row, col=$col');
    print('   Position label: ${position.positionLabel}');
    print('   Has device: ${position.hasDevice}');
    if (position.hasDevice) {
      print('   Device ID: ${position.deviceId}');
      print('   Device name: ${position.deviceName}');
    }

    final result = await showDeviceConnectionDialog(
      context,
      row,
      col,
      position.hasDevice ? position : null,
    );

    if (result == true && mounted) {
      // Connection successful or device removed
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Grid Settings'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AnimatedBuilder(
          animation: _bluetoothService,
          builder: (context, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bluetooth status card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isBluetoothOn
                        ? Colors.blue.shade50
                        : Colors.grey.shade200,
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
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.blue,
                              ), 
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
                              await FlutterBluePlus.turnOn();
                            } catch (e) {
                              if (mounted) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Bluetooth Required'),
                                    content: const Text(
                                      'Please enable Bluetooth in your device settings.',
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

                const SizedBox(height: 24),

                // Device statistics
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Device Statistics',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              'Assigned',
                              _bluetoothService.assignedDeviceCount.toString(),
                              Colors.blue,
                            ),
                            _buildStatItem(
                              'Connected',
                              _bluetoothService.connectedDevices.length.toString(),
                              Colors.green,
                            ),
                            _buildStatItem(
                              'Available',
                              (4 - _bluetoothService.assignedDeviceCount).toString(),
                              Colors.grey,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tap any dot to connect or manage devices',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 3x3 Device Grid
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Device Grid',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.grey.shade700,
                          ), 
                          
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Front of Vehicle',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DeviceGridWidget(
                          onDotTap: _handleDotTap,
                          showLabels: true,
                          dotSize: 70,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Rear of Vehicle',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Legend
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Legend',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        _buildLegendItem(
                          Colors.grey.shade300,
                          Colors.grey.shade400,
                          Icons.add,
                          'No device assigned',
                        ),
                        _buildLegendItem(
                          Colors.orange.shade100,
                          Colors.orange,
                          Icons.bluetooth_disabled,
                          'Device assigned (not connected)',
                        ),
                        _buildLegendItem(
                          Colors.green.shade100,
                          Colors.green,
                          Icons.bluetooth_connected,
                          'Device connected (pulsing)',
                        ),
                        _buildLegendItem(
                          Colors.yellow,
                          Colors.orange,
                          Icons.warning,
                          'Alert Level 1 (5m)',
                        ),
                        _buildLegendItem(
                          Colors.orange,
                          Colors.deepOrange,
                          Icons.warning,
                          'Alert Level 2 (3m)',
                        ),
                        _buildLegendItem(
                          Colors.red,
                          Colors.red.shade900,
                          Icons.warning,
                          'Alert Level 3 (1m)',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color dotColor, Color borderColor, IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Icon(icon, color: borderColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
