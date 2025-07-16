import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'emotiv_ble_manager.dart';

// For Android only
class BackgroundService {
  static EmotivBLEManager? _bleManager;
  static ServiceInstance? _serviceInstance;
  
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();
    
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'eeg_data_channel',
        initialNotificationTitle: 'EEG Data Collection',
        initialNotificationContent: 'Collecting EEG data...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
      ),
    );
  }
  
  static void onStart(ServiceInstance service) async {
    print("Background service started");
    _serviceInstance = service;
    
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
    }
    
    // Initialize your BLE manager in the background service
    _bleManager = EmotivBLEManager();
    
    // Listen for commands from main app
    service.on('startScanning').listen((event) async {
      await _bleManager?.startScanning();
    });
    
    service.on('connectToDevice').listen((event) async {
      final deviceName = event?['deviceName'] as String?;
      if (deviceName != null) {
        await _bleManager?.connectToDeviceByName(deviceName);
      }
    });
    
    service.on('setCustomDirectory').listen((event) async {
      final directoryPath = event?['directoryPath'] as String?;
      _bleManager?.setCustomSaveDirectory(directoryPath);
    });
    
    service.on('disconnect').listen((event) async {
      await _bleManager?.disconnect();
    });
    
    service.on('stopService').listen((event) async {
      await _bleManager?.disconnect();
      _bleManager?.dispose();
      _bleManager = null;
      service.stopSelf();
    });
    
    // Update notification with status
    _bleManager?.statusStream.listen((status) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "EEG Data Collection",
          content: status,
        );
      }
    });
  }
  
  static Future<void> startBackgroundCollection() async {
    final service = FlutterBackgroundService();
    await service.startService();
  }
  
  static Future<void> stopBackgroundCollection() async {
    final service = FlutterBackgroundService();
    service.invoke("stopService");
  }
  
  // Methods to communicate with background service
  static Future<void> startScanning() async {
    final service = FlutterBackgroundService();
    service.invoke("startScanning");
  }
  
  static Future<void> connectToDevice(String deviceName) async {
    final service = FlutterBackgroundService();
    service.invoke("connectToDevice", {"deviceName": deviceName});
  }
  
  static Future<void> setCustomDirectory(String? directoryPath) async {
    final service = FlutterBackgroundService();
    service.invoke("setCustomDirectory", {"directoryPath": directoryPath});
  }
  
  static Future<void> disconnect() async {
    final service = FlutterBackgroundService();
    service.invoke("disconnect");
  }
}

class BatteryOptimization {
  static Future<void> requestBatteryOptimizationExemption() async {
    // Request to ignore battery optimizations
    await Permission.ignoreBatteryOptimizations.request();
  }
}
