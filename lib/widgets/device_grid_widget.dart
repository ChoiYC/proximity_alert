import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/device_position.dart';
import '../services/multi_device_bluetooth_service.dart';

/// 2x2 grid widget for displaying device positions (4 doors)
class DeviceGridWidget extends StatelessWidget {
  final Function(int row, int col)? onDotTap;
  final bool showLabels;
  final double dotSize;

  const DeviceGridWidget({
    super.key,
    this.onDotTap,
    this.showLabels = false,
    this.dotSize = 60,
  });

  @override
  Widget build(BuildContext context) {
    final bluetoothService = MultiDeviceBluetoothService();

    return AnimatedBuilder(
      animation: bluetoothService,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int row = 0; row < 2; row++)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (int col = 0; col < 2; col++)
                    _buildDeviceDot(
                      context,
                      bluetoothService.getDeviceAt(row, col),
                      row,
                      col,
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildDeviceDot(BuildContext context, DevicePosition position, int row, int col) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => onDotTap?.call(row, col),
            child: _DeviceDotAnimated(
              position: position,
              size: dotSize,
            ),
          ),
          if (showLabels && position.hasDevice)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                position.deviceName ?? 'ESP32',
                style: const TextStyle(fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

/// Animated device dot with connection status
class _DeviceDotAnimated extends StatefulWidget {
  final DevicePosition position;
  final double size;

  const _DeviceDotAnimated({
    required this.position,
    required this.size,
  });

  @override
  State<_DeviceDotAnimated> createState() => _DeviceDotAnimatedState();
}

class _DeviceDotAnimatedState extends State<_DeviceDotAnimated>
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
    _animation = Tween<double>(begin: 0.7, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.position;

    // Determine dot color based on state
    Color dotColor;
    Color borderColor;
    IconData? icon;

    if (!position.hasDevice) {
      // No device assigned
      dotColor = Colors.grey.shade300;
      borderColor = Colors.grey.shade400;
      icon = Icons.add;
    } else if (!position.isConnected) {
      // Device assigned but not connected
      dotColor = Colors.orange.shade100;
      borderColor = Colors.orange;
      icon = Icons.bluetooth_disabled;
    } else {
      // Device connected
      if (position.alertLevel != null && position.alertLevel! > 0) {
        // Alert active
        switch (position.alertLevel) {
          case 1:
            dotColor = Colors.yellow;
            borderColor = Colors.orange;
            break;
          case 2:
            dotColor = Colors.orange;
            borderColor = Colors.deepOrange;
            break;
          case 3:
            dotColor = Colors.red;
            borderColor = Colors.red.shade900;
            break;
          default:
            dotColor = Colors.green.shade100;
            borderColor = Colors.green;
        }
        icon = Icons.warning;
      } else {
        // Connected, no alert
        dotColor = Colors.green.shade100;
        borderColor = Colors.green;
        icon = Icons.bluetooth_connected;
      }
    }

    Widget dotWidget = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 3),
        boxShadow: [
          if (position.isConnected)
            BoxShadow(
              color: borderColor.withOpacity(0.5),
              blurRadius: 8,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Icon(
        icon,
        color: borderColor,
        size: widget.size * 0.4,
      ),
    );

    // Add pulsing animation for connected devices
    if (position.isConnected) {
      return AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.scale(
            scale: _animation.value,
            child: child,
          );
        },
        child: dotWidget,
      );
    }

    return dotWidget;
  }
}

/// Compact device grid for displaying in header
class CompactDeviceGrid extends StatelessWidget {
  final Function(int row, int col)? onDotTap;
  final double dotSize;

  const CompactDeviceGrid({
    super.key,
    this.onDotTap,
    this.dotSize = 30,
  });

  @override
  Widget build(BuildContext context) {
    return DeviceGridWidget(
      onDotTap: onDotTap,
      showLabels: false,
      dotSize: dotSize,
    );
  }
}
