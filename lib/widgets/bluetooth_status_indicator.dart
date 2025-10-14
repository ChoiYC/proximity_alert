import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/bluetooth_service.dart';
import '../screens/bluetooth_settings_screen.dart';

/// Widget that displays Bluetooth connection status
class BluetoothStatusIndicator extends StatelessWidget {
  const BluetoothStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final bluetoothService = ESP32BluetoothService();

    return AnimatedBuilder(
      animation: bluetoothService,
      builder: (context, child) {
        final isConnected = bluetoothService.isConnected;
        final device = bluetoothService.connectedDevice;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BluetoothSettingsScreen(),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isConnected ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isConnected ? Colors.green : Colors.grey,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bluetooth icon with animation
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                    color: isConnected ? Colors.green : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
                // Status text
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isConnected ? 'ESP32 Connected' : 'Not Connected',
                        style: TextStyle(
                          color: isConnected ? Colors.green : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (isConnected && device != null)
                        Text(
                          device.platformName.isNotEmpty
                              ? device.platformName
                              : device.remoteId.toString().substring(0, 8),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Settings icon
                Icon(
                  Icons.settings,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Compact Bluetooth status indicator for app bar
class BluetoothStatusAppBarIndicator extends StatelessWidget {
  const BluetoothStatusAppBarIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final bluetoothService = ESP32BluetoothService();

    return AnimatedBuilder(
      animation: bluetoothService,
      builder: (context, child) {
        final isConnected = bluetoothService.isConnected;

        return IconButton(
          icon: Stack(
            children: [
              Icon(
                isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                color: isConnected ? Colors.green : Colors.white,
              ),
              if (isConnected)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BluetoothSettingsScreen(),
              ),
            );
          },
          tooltip: isConnected ? 'ESP32 Connected' : 'Bluetooth Disconnected',
        );
      },
    );
  }
}

/// Animated pulsing indicator for connected state
class PulsingBluetoothIndicator extends StatefulWidget {
  const PulsingBluetoothIndicator({super.key});

  @override
  State<PulsingBluetoothIndicator> createState() => _PulsingBluetoothIndicatorState();
}

class _PulsingBluetoothIndicatorState extends State<PulsingBluetoothIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bluetoothService = ESP32BluetoothService();

    return AnimatedBuilder(
      animation: Listenable.merge([bluetoothService, _animation]),
      builder: (context, child) {
        final isConnected = bluetoothService.isConnected;

        if (!isConnected) {
          return const SizedBox.shrink();
        }

        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
