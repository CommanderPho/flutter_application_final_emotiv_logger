import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';

class CryptoUtils {
  static const int hidDataLen = 16;
  static const double multiplier = 0.5128205128205129;
  
  // Motion data decoding constants based on emotiv_lsl implementation
  static const double _accScale = 1.0 / 16384.0;  // ±2g range for accelerometer
  static const double _gyroScale = 1.0 / 131.0;   // ±250 deg/s range for gyroscope
  
  static String decryptRawPacket(Uint8List data) {
    try {
      // Device-specific 16-byte AES key (same as your Objective-C code)
      final keyString = '6566565666756557';
      final key = Key.fromUtf8(keyString.padRight(16, '0').substring(0, 16));
      
      final encrypter = Encrypter(AES(key, mode: AESMode.ecb, padding: null));
      
      final List<double> results = [];
      
      // Process data in 16-byte chunks
      for (int c = 0; c < data.length && c < hidDataLen; c += 16) {
        final endIndex = (c + 16 > data.length) ? data.length : c + 16;
        final chunk = data.sublist(c, endIndex);
        
        // Pad chunk to 16 bytes if necessary
        final paddedChunk = Uint8List(16);
        paddedChunk.setRange(0, chunk.length, chunk);
        
        final encrypted = Encrypted(paddedChunk);
        final decrypted = encrypter.decryptBytes(encrypted);
        
        // Process decrypted chunk in pairs
        for (int i = 0; i < decrypted.length - 1; i += 2) {
          int tmpVal = (decrypted[i + 1] << 8) | decrypted[i];
          double rawVal = (tmpVal * multiplier) * 0.25;
          results.add(rawVal);
        }
      }
      
      return results.map((v) => v.toStringAsFixed(6)).join(',');
    } catch (e) {
      print('Decryption error: $e');
      return '';
    }
  }
  
  static List<double> decryptToDoubleList(Uint8List data) {
    try {
      final keyString = '6566565666756557';
      final key = Key.fromUtf8(keyString.padRight(16, '0').substring(0, 16));
      
      final encrypter = Encrypter(AES(key, mode: AESMode.ecb, padding: null));
      
      final List<double> results = [];
      
      for (int c = 0; c < data.length && c < hidDataLen; c += 16) {
        final endIndex = (c + 16 > data.length) ? data.length : c + 16;
        final chunk = data.sublist(c, endIndex);
        
        final paddedChunk = Uint8List(16);
        paddedChunk.setRange(0, chunk.length, chunk);
        
        final encrypted = Encrypted(paddedChunk);
        final decrypted = encrypter.decryptBytes(encrypted);
        
        for (int i = 0; i < decrypted.length - 1; i += 2) {
          int tmpVal = (decrypted[i + 1] << 8) | decrypted[i];
          double rawVal = (tmpVal * multiplier) * 0.25;
          results.add(rawVal);
        }
      }
      
      return results;
    } catch (e) {
      print('Decryption error: $e');
      return [];
    }
  }
  
  /// Decode motion sensor data from gyro/accelerometer packet
  /// Based on emotiv_lsl implementation for EPOC X IMU (ICM-20948)
  /// Returns [AccX, AccY, AccZ, GyroX, GyroY, GyroZ]
  static List<double> decodeMotionData(Uint8List data) {
    try {
      // Motion data positions in EPOC X packet (based on CyKit gyroDATA)
      final motionPositions = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 30, 31];
      
      final motionData = <double>[];
      for (int i = 0; i < motionPositions.length; i += 2) {
        if (i + 1 < motionPositions.length) {
          final pos1 = motionPositions[i];
          final pos2 = motionPositions[i + 1];
          if (pos1 < data.length && pos2 < data.length) {
            // Use EPOC+ gyro conversion formula from CyKit
            final value = (8191.88296790168 + (data[pos1] * 1.00343814821)) + 
                         ((data[pos2] - 128.00001) * 64.00318037383);
            motionData.add(value);
          }
        }
      }
      
      // Return first 6 values as [AccX, AccY, AccZ, GyroX, GyroY, GyroZ]
      // Scale to appropriate units (g for accelerometer, deg/s for gyro)
      if (motionData.length >= 6) {
        return [
          motionData[0] * _accScale,  // AccX
          motionData[1] * _accScale,  // AccY  
          motionData[2] * _accScale,  // AccZ
          motionData[3] * _gyroScale, // GyroX
          motionData[4] * _gyroScale, // GyroY
          motionData[5] * _gyroScale  // GyroZ
        ];
      }
      
      return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]; // Return zeros if not enough data
    } catch (e) {
      print('Motion data decoding error: $e');
      return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    }
  }
}

