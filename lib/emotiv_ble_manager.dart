import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:lsl_flutter/lsl_flutter.dart';
import 'crypto_utils.dart';

class EmotivBLEManager {
  // UUIDs from your Swift code
  static const String deviceNameUuid = "81072F40-9F3D-11E3-A9DC-0002A5D5C51B";
  static const String transferDataUuid = "81072F41-9F3D-11E3-A9DC-0002A5D5C51B";
  static const String transferMemsUuid = "81072F42-9F3D-11E3-A9DC-0002A5D5C51B";
  
  static const int readSize = 32;
  
  BluetoothDevice? _emotivDevice;
  BluetoothCharacteristic? _dataCharacteristic;
  BluetoothCharacteristic? _memsCharacteristic;
  
  bool _isConnected = false;
  bool _isScanning = false;
  
  // Stream controllers for data
  final StreamController<List<double>> _eegDataController = StreamController<List<double>>.broadcast();
  final StreamController<Uint8List> _memsDataController = StreamController<Uint8List>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();
  
  // File writing related variables
  File? _eegDataFile;
  IOSink? _eegDataSink;
  Timer? _flushTimer;
  final List<String> _writeBuffer = [];
  static const int _bufferSize = 100; // Buffer 100 entries before writing
  static const int _flushIntervalMs = 1000; // Flush every second
  
  // Getters for streams
  Stream<List<double>> get eegDataStream => _eegDataController.stream;
  Stream<Uint8List> get memsDataStream => _memsDataController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<String> get statusStream => _statusController.stream;
  
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  
  Future<void> startScanning() async {
    if (_isScanning) return;
    
    _isScanning = true;
    _updateStatus("Starting scan for Emotiv devices...");
    
    try {
      // Start scanning for devices with the specific service UUID
      await FlutterBluePlus.startScan(
        withServices: [Guid(deviceNameUuid)],
        timeout: const Duration(seconds: 30),
      );
      
      // Listen for scan results
      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          _updateStatus("Found device: ${result.device.platformName}");
          print("Found device: ${result.device.platformName} (${result.device.remoteId})");
          
          // Connect to the first Emotiv device found
          if (result.device.platformName.isNotEmpty) {
            stopScanning();
            connectToDevice(result.device);
            break;
          }
        }
      });
      
    } catch (e) {
      _updateStatus("Error starting scan: $e");
      _isScanning = false;
    }
  }
  
  Future<void> stopScanning() async {
    if (!_isScanning) return;
    
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    _updateStatus("Stopped scanning");
  }
  
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      _updateStatus("Connecting to ${device.platformName}...");
      
      await device.connect(timeout: const Duration(seconds: 15));
      _emotivDevice = device;
      _isConnected = true;
      _connectionController.add(true);
      
      _updateStatus("Connected to ${device.platformName}");
      
      // Initialize file writer after successful connection
      await _initializeFileWriter();
      
      // Listen for disconnection
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnection();
        }
      });
      
      // Discover services
      await _discoverServices();
      
    } catch (e) {
      _updateStatus("Failed to connect: $e");
      _isConnected = false;
      _connectionController.add(false);
    }
  }
  
  Future<void> _discoverServices() async {
    if (_emotivDevice == null) return;
    
    try {
      _updateStatus("Discovering services...");
      
      List<BluetoothService> services = await _emotivDevice!.discoverServices();
      
      for (BluetoothService service in services) {
        print("Discovered service: ${service.uuid}");
        
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          print("Discovered characteristic: ${characteristic.uuid}");
          
          if (characteristic.uuid.toString().toUpperCase() == transferDataUuid.toUpperCase()) {
            _dataCharacteristic = characteristic;
            await _setupDataCharacteristic(characteristic);
          } else if (characteristic.uuid.toString().toUpperCase() == transferMemsUuid.toUpperCase()) {
            _memsCharacteristic = characteristic;
            await _setupMemsCharacteristic(characteristic);
          }
        }
      }
      
      _updateStatus("Setup complete - receiving data");
      
    } catch (e) {
      _updateStatus("Error discovering services: $e");
    }
  }
  
  Future<void> _setupDataCharacteristic(BluetoothCharacteristic characteristic) async {
    try {
      // Enable notifications
      await characteristic.setNotifyValue(true);
      
      // Listen for data
      characteristic.lastValueStream.listen((data) {
        if (data.isNotEmpty) {
          _processEEGData(Uint8List.fromList(data));
        }
      });
      
      // Write configuration data (equivalent to your Swift code)
      if (characteristic.properties.write) {
        final configData = Uint8List.fromList([0x01, 0x00]); // 0x0001 as little-endian
        await characteristic.write(configData, withoutResponse: false);
      }
      
      _updateStatus("Data characteristic configured");
      
    } catch (e) {
      _updateStatus("Error setting up data characteristic: $e");
    }
  }
  
  Future<void> _setupMemsCharacteristic(BluetoothCharacteristic characteristic) async {
    try {
      await characteristic.setNotifyValue(true);
      
      characteristic.lastValueStream.listen((data) {
        if (data.isNotEmpty) {
          _memsDataController.add(Uint8List.fromList(data));
        }
      });
      
      _updateStatus("MEMS characteristic configured");
      
    } catch (e) {
      _updateStatus("Error setting up MEMS characteristic: $e");
    }
  }
  
  Future<void> _initializeFileWriter() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'eeg_data_$timestamp.csv';
      
      _eegDataFile = File('${directory.path}/$fileName');
      _eegDataSink = _eegDataFile!.openWrite();
      
      // Write CSV header
      _eegDataSink!.writeln('timestamp,channel_1,channel_2,channel_3,channel_4,channel_5,channel_6,channel_7,channel_8,channel_9,channel_10,channel_11,channel_12,channel_13,channel_14');
      
      // Setup periodic flush timer
      _flushTimer = Timer.periodic(Duration(milliseconds: _flushIntervalMs), (_) {
        _flushBuffer();
      });
      
      _updateStatus("File writer initialized: $fileName");
      
    } catch (e) {
      _updateStatus("Error initializing file writer: $e");
    }
  }
  
  void _processEEGData(Uint8List data) {
    if (!_validateData(data)) return;
    
    // Decrypt and decode the data
    final decodedValues = CryptoUtils.decryptToDoubleList(data);
    
    if (decodedValues.isNotEmpty) {
      _eegDataController.add(decodedValues);
      print("EEG Data: ${decodedValues.take(5).join(', ')}..."); // Print first 5 values
      
      // Write to file
      _writeEEGDataToFile(decodedValues);
    }
  }
  
  void _writeEEGDataToFile(List<double> eegData) {
    if (_eegDataSink == null) return;
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final csvLine = '$timestamp,${eegData.join(',')}';
      
      // Add to buffer
      _writeBuffer.add(csvLine);
      
      // Write buffer if it's full
      if (_writeBuffer.length >= _bufferSize) {
        _flushBuffer();
      }
      
    } catch (e) {
      _updateStatus("Error writing EEG data to file: $e");
    }
  }
  
  void _flushBuffer() {
    if (_eegDataSink == null || _writeBuffer.isEmpty) return;
    
    try {
      for (String line in _writeBuffer) {
        _eegDataSink!.writeln(line);
      }
      _eegDataSink!.flush();
      _writeBuffer.clear();
      
    } catch (e) {
      _updateStatus("Error flushing buffer: $e");
    }
  }
  
  Future<void> _closeFileWriter() async {
    try {
      _flushTimer?.cancel();
      _flushTimer = null;
      
      // Flush any remaining data
      _flushBuffer();
      
      await _eegDataSink?.close();
      _eegDataSink = null;
      _eegDataFile = null;
      
      _updateStatus("File writer closed");
      
    } catch (e) {
      _updateStatus("Error closing file writer: $e");
    }
  }
  
  bool _validateData(Uint8List data) {
    if (data.length < readSize) {
      print("Data size too small: ${data.length}");
      return false;
    }
    return true;
  }
  
  void _handleDisconnection() {
    _isConnected = false;
    _emotivDevice = null;
    _dataCharacteristic = null;
    _memsCharacteristic = null;
    _connectionController.add(false);
    _updateStatus("Disconnected - restarting scan...");
    
    // Close file writer
    _closeFileWriter();
    
    // Optionally restart scanning
    Future.delayed(const Duration(seconds: 2), () {
      startScanning();
    });
  }
  
  void _updateStatus(String status) {
    print(status);
    _statusController.add(status);
  }
  
  Future<void> disconnect() async {
    if (_emotivDevice != null && _isConnected) {
      await _emotivDevice!.disconnect();
    }
    await _closeFileWriter();
  }
  
  void dispose() {
    _closeFileWriter();
    _eegDataController.close();
    _memsDataController.close();
    _connectionController.close();
    _statusController.close();
  }
  
  // Utility method to get current file info
  Future<Map<String, dynamic>?> getFileInfo() async {
    if (_eegDataFile == null) return null;
    
    try {
      final stat = await _eegDataFile!.stat();
      return {
        'path': _eegDataFile!.path,
        'size': stat.size,
        'modified': stat.modified.toIso8601String(),
      };
    } catch (e) {
      return null;
    }
  }
}
