import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:lsl_flutter/lsl_flutter.dart';
import 'crypto_utils.dart';
import 'eeg_file_writer.dart';

class EmotivBLEManager {
	// UUIDs from your Swift code
	static const String deviceNameUuid = "81072F40-9F3D-11E3-A9DC-0002A5D5C51B";
	static const String transferEEGDataUuid = "81072F41-9F3D-11E3-A9DC-0002A5D5C51B"; // UUID of the main data stream with ID 0x10
	static const String transferMemsUuid = "81072F42-9F3D-11E3-A9DC-0002A5D5C51B"; // UUID of the gyro/other? data stream with ID 0x20


// service.characteristics[0].uuid.toString().toUpperCase()
// "2A00"
// service.characteristics[1].uuid.toString().toUpperCase()
// "2A01"
// service.characteristics[2].uuid.toString().toUpperCase()
// "2A04"
// service.characteristics[3].uuid.toString().toUpperCase()
// "2AA6"

	static const int readSize = 32;

	BluetoothDevice? _emotivDevice;
	BluetoothCharacteristic? _eegDataCharacteristic;
	BluetoothCharacteristic? _memsDataCharacteristic;

	final bool _shouldAutoConnectToFirst = false;
	bool _isConnected = false;
	bool _isScanning = false;
	
	// Add this field to store discovered devices
	List<BluetoothDevice> _discoveredDevices = [];

	// Stream controllers for data
	final StreamController<List<double>> _eegDataController = StreamController<List<double>>.broadcast();
	final StreamController<Uint8List> _memsDataController = StreamController<Uint8List>.broadcast();
	final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
	final StreamController<String> _statusController = StreamController<String>.broadcast();
	// Add a stream controller for found devices
	final StreamController<List<String>> _foundDevicesController = StreamController<List<String>>.broadcast();

	// File writer instance
	EEGFileWriter? _fileWriter;

	// Add this field
	String? _customSaveDirectory;

	// Getters for streams
	Stream<List<double>> get eegDataStream => _eegDataController.stream;
	Stream<Uint8List> get memsDataStream => _memsDataController.stream;
	Stream<bool> get connectionStream => _connectionController.stream;
	Stream<String> get statusStream => _statusController.stream;
	Stream<List<String>> get foundDevicesStream => _foundDevicesController.stream;

	bool get isConnected => _isConnected;
	bool get isScanning => _isScanning;

	// Add method to set custom directory
	void setCustomSaveDirectory(String? directoryPath) {
		print("EmotivBLEManager: Updating custom save directory directoryPath: ${directoryPath}");
		_customSaveDirectory = directoryPath;
	}

	Future<void> _initializeFileWriter() async {
		try {
		// Dispose existing file writer if any
		await _fileWriter?.dispose();

		// Create new file writer with custom directory
		_fileWriter = EEGFileWriter(
			onStatusUpdate: _updateStatus,
			customDirectoryPath: _customSaveDirectory, // Pass custom directory
		);

		// Initialize the file writer
		final success = await _fileWriter!.initialize();

		if (!success) {
			_updateStatus("EmotivBLEManager: Failed to initialize file writer");
			_fileWriter = null;
		}

		} catch (e) {
			_updateStatus("EmotivBLEManager: Error initializing file writer: $e");
			_fileWriter = null;
		}
	}

	Future<void> startScanning() async {
		if (_isScanning) return;

		_isScanning = true;
		_updateStatus("EmotivBLEManager: Starting scan for Emotiv devices...");
		
		// Clear previous discoveries
		_discoveredDevices.clear();

		try {
		// Start scanning for devices with the specific service UUID
		await FlutterBluePlus.startScan(
			withServices: [Guid(deviceNameUuid)],
			timeout: const Duration(seconds: 30),
		);

		// Listen for scan results
		FlutterBluePlus.scanResults.listen((results) {
			// Store the actual devices
			_discoveredDevices = results
				.map((result) => result.device)
				.where((device) => device.platformName.isNotEmpty)
				.toList();
			
			// Extract device names for your list
			List<String> deviceNames = _discoveredDevices
				.map((device) => device.platformName)
				.toList();
			
			// Update your UI with the found devices
			_updateFoundDevices(deviceNames);		

			for (ScanResult result in results) {
				_updateStatus("Found device: ${result.device.platformName}");
				print("EmotivBLEManager: Found device: ${result.device.platformName} (${result.device.remoteId})");

				// Connect to the first Emotiv device found
				if (_shouldAutoConnectToFirst && result.device.platformName.isNotEmpty) {
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
	
	// Add this new method
	Future<void> connectToDeviceByName(String deviceName) async {
		try {
		  // Find the device with the matching name
		  final device = _discoveredDevices.firstWhere(
			(device) => device.platformName == deviceName,
			orElse: () => throw Exception('Device not found: $deviceName'),
		  );
		  
		  // Stop scanning before connecting
		  if (_isScanning) {
			await stopScanning();
		  }
		  
		  // Connect to the found device
		  await connectToDevice(device);
		  
		} catch (e) {
		  _updateStatus("Failed to connect to $deviceName: $e");
		  throw e; // Re-throw so the UI can handle it
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

          if (characteristic.uuid.toString().toUpperCase() == transferEEGDataUuid.toUpperCase()) {
            _eegDataCharacteristic = characteristic;
            await _setupEEGDataCharacteristic(characteristic);
          } else if (characteristic.uuid.toString().toUpperCase() == transferMemsUuid.toUpperCase()) {
            _memsDataCharacteristic = characteristic;
            await _setupMemsCharacteristic(characteristic);
          }
				}
			}

			_updateStatus("Setup complete - receiving data");

		} catch (e) {
			_updateStatus("Error discovering services: $e");
		}
	}

	Future<void> _setupEEGDataCharacteristic(BluetoothCharacteristic characteristic) async {
		try {
			// Enable notifications
			await characteristic.setNotifyValue(true);

			// Listen for data
			characteristic.lastValueStream.listen((data) {
				if (data.isNotEmpty) {
				  _processEEGData(Uint8List.fromList(data));
				}
			});

			// Write configuration data (equivalent to your Swift code) -- I think this is to indicate to the headset that we are connected.
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


	void _processEEGData(Uint8List data) {
		if (!_validateData(data)) return;

		// Decrypt and decode the data
		final decodedValues = CryptoUtils.decryptToDoubleList(data);

		if (decodedValues.isNotEmpty) {
      _eegDataController.add(decodedValues);
      print("EEG Data: ${decodedValues.take(5).join(', ')}..."); // Print first 5 values

      // Write to file using the file writer
      _fileWriter?.writeEEGData(decodedValues);
		}
	}

	bool _validateData(Uint8List data) {
		if (data.length < readSize) {
      print("EmotivBLEManager: Data size too small: ${data.length}");
      return false;
		}
		return true;
	}

	void _handleDisconnection() {
		_isConnected = false;
		_emotivDevice = null;
		_eegDataCharacteristic = null;
		_memsDataCharacteristic = null;
		_connectionController.add(false);
		_updateStatus("Disconnected - closing file and restarting scan...");

		// Close file writer immediately to prevent timer conflicts
		_closeFileWriter();

		// // Optionally restart scanning
		// Future.delayed(const Duration(seconds: 2), () {
		//   if (!_isConnected) { // Only restart if still disconnected
		//     startScanning();
		//   }
		// });

	}

	Future<void> _closeFileWriter() async {
		if (_fileWriter != null) {
		  await _fileWriter!.dispose();
		  _fileWriter = null;
		}
	}

	void _updateStatus(String status) {
    print(status);
    _statusController.add(status);
	}

	void _updateFoundDevices(List<String> devices) {
		// Add this method to update found devices
		_foundDevicesController.add(devices);
	}


  Future<void> disconnect() async {
	if (_emotivDevice != null && _isConnected) {
	  await _emotivDevice!.disconnect();
	}
	else {
	  await _closeFileWriter();
	}
  }

	void dispose() {
		_closeFileWriter();
		_eegDataController.close();
		_memsDataController.close();
		_connectionController.close();
		_statusController.close();
		_foundDevicesController.close();
	}

  // Utility method to get current file info
  Future<Map<String, dynamic>?> getFileInfo() async {
	return await _fileWriter?.getFileInfo();
  }

  // Additional utility methods for file writer
  String? get currentFilePath => _fileWriter?.filePath;
  bool get isFileWriterInitialized => _fileWriter?.isInitialized ?? false;
  int get bufferedLines => _fileWriter?.bufferedLines ?? 0;

  // Force flush any buffered data
  void flushFileBuffer() {
	_fileWriter?.flush();
  }

}
