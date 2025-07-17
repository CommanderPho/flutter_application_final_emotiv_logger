import 'package:flutter/services.dart';

class BackgroundHandler {
  static const MethodChannel _channel = MethodChannel('background_handler');
  
  static Future<void> requestBackgroundProcessing() async {
    try {
      await _channel.invokeMethod('requestBackgroundProcessing');
    } catch (e) {
      print('Error requesting background processing: $e');
    }
  }
}