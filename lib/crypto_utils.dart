import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';

class CryptoUtils {
  static const int hidDataLen = 16;
  static const double multiplier = 0.5128205128205129;
  
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
}

