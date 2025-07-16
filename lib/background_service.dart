import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'emotiv_ble_manager.dart';

// For Android only
class BackgroundService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();
    
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'eeg_data_channel',
        initialNotificationTitle: 'EEG Data Collection',
        initialNotificationContent: 'Collecting EEG data in background',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }
  
  static void onStart(ServiceInstance service) async {
    // Keep your EmotivBLEManager running here
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
    }
    
    // Continue BLE operations
    final bleManager = EmotivBLEManager();
    // ... initialize and start data collection
  }
  
  static bool onIosBackground(ServiceInstance service) {
    return true;
  }
}


// Android only
class WakeLockManager {
  // WakeLock is an Android system mechanism that prevents the device from going to sleep or entering power-saving modes that would interrupt your app's operation.
  static const MethodChannel _channel = MethodChannel('wake_lock');
  
  static Future<void> acquire() async {
    await _channel.invokeMethod('acquire');
  }
  
  static Future<void> release() async {
    await _channel.invokeMethod('release');
  }
}


class BatteryOptimization {
  static Future<void> requestBatteryOptimizationExemption() async {
    // Request to ignore battery optimizations
    await Permission.ignoreBatteryOptimizations.request();
  }
}
