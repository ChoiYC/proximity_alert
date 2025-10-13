import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../screens/proximity_alert_screen.dart';

class AlertOverlay extends StatefulWidget {
  final AlertLevel alertLevel;
  final double? distance;

  const AlertOverlay({
    super.key,
    required this.alertLevel,
    this.distance,
  });

  @override
  State<AlertOverlay> createState() => _AlertOverlayState();
}

class _AlertOverlayState extends State<AlertOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  AlertLevel? _lastAlertLevel;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void didUpdateWidget(AlertOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.alertLevel != oldWidget.alertLevel) {
      _handleAlertChange();
    }
  }

  void _handleAlertChange() {
    debugPrint('🔔 AlertOverlay: handleAlertChange - level: ${widget.alertLevel}, last: $_lastAlertLevel');

    if (widget.alertLevel == AlertLevel.none) {
      _animationController.reverse();
    } else {
      _animationController.forward();

      // Trigger alert (vibration + sound) on new alert
      if (_lastAlertLevel != widget.alertLevel) {
        debugPrint('🔊 Triggering alert for ${widget.alertLevel}');
        _triggerAlert();
      }
    }

    _lastAlertLevel = widget.alertLevel;
  }

  Future<void> _triggerAlert() async {
    // Play sound
    if (widget.alertLevel == AlertLevel.warning3m) {
      // Critical alert: alarm sound
      FlutterRingtonePlayer().play(
        android: AndroidSounds.alarm,
        ios: const IosSound(1023),
        looping: false,
        volume: 1.0,
      );
    } else if (widget.alertLevel == AlertLevel.warning5m) {
      // Warning alert: notification sound
      FlutterRingtonePlayer().play(
        android: AndroidSounds.notification,
        ios: const IosSound(1007),
        looping: false,
        volume: 0.7,
      );
    }

    // Vibrate
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      if (widget.alertLevel == AlertLevel.warning3m) {
        // Strong vibration for 3m warning
        Vibration.vibrate(duration: 500, amplitude: 255);
      } else if (widget.alertLevel == AlertLevel.warning5m) {
        // Light vibration for 5m warning
        Vibration.vibrate(duration: 200, amplitude: 128);
      }
    }
  }

  Color _getAlertColor() {
    switch (widget.alertLevel) {
      case AlertLevel.warning3m:
        return Colors.red;
      case AlertLevel.warning5m:
        return Colors.orange;
      case AlertLevel.none:
        return Colors.transparent;
    }
  }

  String _getAlertText() {
    switch (widget.alertLevel) {
      case AlertLevel.warning3m:
        return 'CRITICAL WARNING';
      case AlertLevel.warning5m:
        return 'WARNING';
      case AlertLevel.none:
        return '';
    }
  }

  IconData _getAlertIcon() {
    switch (widget.alertLevel) {
      case AlertLevel.warning3m:
        return Icons.error;
      case AlertLevel.warning5m:
        return Icons.warning;
      case AlertLevel.none:
        return Icons.check_circle;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.alertLevel == AlertLevel.none) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _animationController.value,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _getAlertColor(),
                width: 8,
              ),
            ),
            child: Column(
              children: [
                // Top alert banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  color: _getAlertColor().withValues(alpha: 0.9),
                  child: Column(
                    children: [
                      Icon(
                        _getAlertIcon(),
                        color: Colors.white,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getAlertText(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.distance != null)
                        Text(
                          'Person at ${widget.distance!.toStringAsFixed(1)}m',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                // Bottom instructions
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.black54,
                  child: Text(
                    widget.alertLevel == AlertLevel.warning3m
                        ? 'PERSON TOO CLOSE - IMMEDIATE ACTION REQUIRED'
                        : 'Person approaching - Stay alert',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
