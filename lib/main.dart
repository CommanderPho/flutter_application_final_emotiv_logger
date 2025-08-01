import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_emotiv_logger/directory_helper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'emotiv_ble_manager.dart';
import 'file_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const EmotivBLEApp());
}

class EmotivBLEApp extends StatelessWidget {
  const EmotivBLEApp({super.key});

  @override
  Widget build(BuildContext context) {
	return MaterialApp(
	  title: 'Emotiv BLE LSL Logger',
	  theme: ThemeData(
		primarySwatch: Colors.blue,
		useMaterial3: true,
	  ),
	  home: EmotivHomePage(storage: FileStorage.new(),),
	);
  }
}

class EmotivHomePage extends StatefulWidget {
  const EmotivHomePage({super.key, required this.storage});
  final FileStorage storage;

  @override
  State<EmotivHomePage> createState() => _EmotivHomePageState();
}

class _EmotivHomePageState extends State<EmotivHomePage> with WidgetsBindingObserver {
  final EmotivBLEManager _bleManager = EmotivBLEManager();
  List<double> _latestEEGData = [];
  String _statusMessage = "Ready to connect";
  bool _isConnected = false;
  late StreamSubscription _eegSubscription;
  late StreamSubscription _statusSubscription;
  late StreamSubscription _connectionSubscription;

  bool _useLSLStreams = false;

  // Add this field to store the selected directory
  String? _selectedDirectory; // "/storage/emulated/0/DATA/EEG"

  // Add these new state variables
  List<String> _foundDevices = [];
  String _connectedDeviceName = '';

  @override
  void initState() {
	super.initState();
	WidgetsBinding.instance.addObserver(this);
	_initializeBluetooth();
	_setupStreamListeners();
  }

  void _setupStreamListeners() {
	// Add this listener for found devices
	// Always listen for connection changes
	_connectionSubscription = _bleManager.connectionStream.listen((connected) {
		setState(() {
			_isConnected = connected;
		});
	});

	// Always listen for found devices
	_bleManager.foundDevicesStream.listen((devices) {
		setState(() {
			_foundDevices = devices;
		});
	});

	_eegSubscription = _bleManager.eegDataStream.listen((data) {
		setState(() {
			_latestEEGData = data;
		});
	});

	_statusSubscription = _bleManager.statusStream.listen((status) {
		setState(() {
			_statusMessage = status;
		});
	});
  }

  Future<void> _initializeBluetooth() async {
	// Request permissions
	await _requestPermissions();

	// Check if Bluetooth is available
	if (await FlutterBluePlus.isAvailable == false) {
	  setState(() {
		_statusMessage = "Bluetooth not available";
	  });
	  return;
	}

	// Check Bluetooth state
	FlutterBluePlus.adapterState.listen((state) {
	  if (state == BluetoothAdapterState.on) {
		setState(() {
		  _statusMessage = "Bluetooth ready";
		});
	  } else {
		setState(() {
		  _statusMessage = "Please enable Bluetooth";
		});
	  }
	});
  }

  Future<void> _requestPermissions() async {

  if (Platform.isAndroid || Platform.isIOS) {
      // MissingPluginException (MissingPluginException(No implementation found for method requestPermissions on channel flutter.baseflow.com/permissions/methods))
      Map<Permission, PermissionStatus> permissions = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.location,
        Permission.manageExternalStorage,
        Permission.storage,
      ].request();

      bool allGranted = permissions.values.every((status) => status.isGranted);
      if (!allGranted) {
        setState(() {
        _statusMessage = "Bluetooth permissions required";
        });
      }
    }
  }

  Future<void> _startScanning() async {
	await _bleManager.startScanning();
  }

  Future<void> _stopScanning() async {
	await _bleManager.stopScanning();
  }

  Future<void> _disconnect() async {
	await _bleManager.disconnect();
  }

Future<void> _toggleScanning() async {
	if (_bleManager.isScanning) {
		await _stopScanning();
	} else {
		await _startScanning();
	}
}

// Add this method to your _EmotivHomePageState class
Future<void> _connectToDeviceByName(String deviceName) async {
  try {
	await _bleManager.connectToDeviceByName(deviceName);
	
	// Update connected device name on successful connection
	setState(() {
	  _connectedDeviceName = deviceName;
	});
  } catch (e) {
	ScaffoldMessenger.of(context).showSnackBar(
	  SnackBar(
		content: Text('Failed to connect to $deviceName: $e'),
		backgroundColor: Colors.red,
	  ),
	);
  }
}

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
	super.didChangeAppLifecycleState(state);
	if (state == AppLifecycleState.inactive ||
		state == AppLifecycleState.paused ||
		state == AppLifecycleState.detached) {
	  // Flush buffered data when app goes to background
	  _bleManager.flushFileBuffer();
	}
  }

  @override
  void dispose() {
	WidgetsBinding.instance.removeObserver(this);
	_eegSubscription.cancel();
	_statusSubscription.cancel();
	_connectionSubscription.cancel();
	_bleManager.dispose();
	super.dispose();
  }

  // Add this method to navigate to settings
  Future<void> _openFileSettings() async {
	final result = await Navigator.push(
	  context,
	  MaterialPageRoute(
		builder: (context) => FileSettingsScreen(
		  _selectedDirectory,
		),
	  ),
	);

	// Handle the result if the user selected a new directory
	if (result != null && result is String) {
	  setState(() {
		 print("File settings return context result: ${result}");
		_selectedDirectory = result;
	  });

	  // Apply the new directory to your BLE manager
	  _bleManager.setCustomSaveDirectory(_selectedDirectory);

	  // Show confirmation
	  ScaffoldMessenger.of(context).showSnackBar(
		SnackBar(
		  content: Text('Save directory updated: $_selectedDirectory'),
		),
	  );
	}
  }

  @override
  Widget build(BuildContext context) {
	return Scaffold(
	  appBar: AppBar(
		title: const Text('Emotiv BLE LSL Logger'),
		backgroundColor: Theme.of(context).colorScheme.inversePrimary,
		actions: [
		  // Add settings button to app bar
		  IconButton(
			icon: const Icon(Icons.settings),
			onPressed: () => _openFileSettings(),
		  ),
		],
	  ),
	  body: Padding(
		padding: const EdgeInsets.all(16.0),
		child: Column(
		  crossAxisAlignment: CrossAxisAlignment.stretch,
		  children: [
			// Status Card
			Card(
			  child: Padding(
				padding: const EdgeInsets.all(16.0),
				child: Column(
				  crossAxisAlignment: CrossAxisAlignment.start,
				  children: [
					Text(
					  'Device Status',
					  style: Theme.of(context).textTheme.titleMedium,
					),
					const SizedBox(height: 8),
					Row(
					  children: [
						Icon(
						  _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
						  color: _isConnected ? Colors.green : Colors.red,
						),
						const SizedBox(width: 8),
						Expanded(
						  child: Text(
							_statusMessage,
							style: TextStyle(
							  color: _isConnected ? Colors.green : Colors.black87,
							),
						  ),
						),
					  ],
					),
				  ],
				),
			  ),
			),
			
			const SizedBox(height: 16),
			
			// Replace your existing control buttons with this:
			BluetoothControlWidget(
			  isConnected: _isConnected,
			  isScanning: _bleManager.isScanning,
			  connectedDeviceName: _connectedDeviceName,
			  foundDevices: _foundDevices,
			  onToggleScan: _toggleScanning,
			  onDisconnect: _disconnect,
			  onConnectToDevice: _connectToDeviceByName,
			),
			
			const SizedBox(height: 16),
			
			// EEG Data Display
			Expanded(
			  child: Card(
				child: Padding(
				  padding: const EdgeInsets.all(16.0),
				  child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
					  Text(
						'EEG Data Stream',
						style: Theme.of(context).textTheme.titleMedium,
					  ),
					  const SizedBox(height: 8),
					  if (_latestEEGData.isEmpty)
						const Expanded(
						  child: Center(
							child: Text(
							  'No data received yet...\nConnect to Emotiv device to see EEG data',
							  textAlign: TextAlign.center,
							  style: TextStyle(color: Colors.grey),
							),
						  ),
						)
					  else
						Expanded(
						  child: SingleChildScrollView(
							child: Column(
							  crossAxisAlignment: CrossAxisAlignment.start,
							  children: [
								Text(
								  'Latest Sample (${_latestEEGData.length} channels):',
								  style: const TextStyle(fontWeight: FontWeight.bold),
								),
								const SizedBox(height: 8),
								...List.generate(_latestEEGData.length, (index) {
								  return Padding(
									padding: const EdgeInsets.symmetric(vertical: 2.0),
									child: Row(
									  children: [
										SizedBox(
										  width: 80,
										  child: Text(
											'CH${index + 1}:',
											style: const TextStyle(fontWeight: FontWeight.w500),
										  ),
										),
										Expanded(
										  child: Container(
											padding: const EdgeInsets.symmetric(
											  horizontal: 8,
											  vertical: 4
											),
											decoration: BoxDecoration(
											  color: Colors.grey[100],
											  borderRadius: BorderRadius.circular(4),
											),
											child: Text(
											  _latestEEGData[index].toStringAsFixed(6),
											  style: const TextStyle(
												fontFamily: 'monospace',
												fontSize: 12,
											  ),
											),
										  ),
										),
									  ],
									),
								  );
								}),
							  ],
							),
						  ),
						),
					],
				  ),
				),
			  ),
			),
		  ],
		),
	  ),
	);
  }
}

///////////////////////////////////////////////////////////////////////////
// EEG Connections Widget
class ScannerWidget extends StatelessWidget { // Displays the result of scanning for bluetooth devices and discovered devices
	final bool isScanning;
	final VoidCallback onToggleScan;
	final List<String> foundDevices;
	final void Function(String deviceName) onConnectToDevice; // Add this

	const ScannerWidget({
		super.key,
		required this.isScanning,
		required this.onToggleScan,
		required this.foundDevices,
		required this.onConnectToDevice, // Add this
	});

	@override
	Widget build(BuildContext context) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
	// Scanning row
	Row(
			children: [
					const Text('Scanning:'),
					const Spacer(),
					ElevatedButton(
							onPressed: onToggleScan,
							child: Text(isScanning ? 'Stop' : 'Start'),
					),
			],
	),

	const SizedBox(height: 16),

	// Found headsets
	const Text('Found headsets:'),

	const SizedBox(height: 8),

	// Device list with connect buttons
	...foundDevices.map((device) => 
			Padding(
					padding: const EdgeInsets.symmetric(vertical: 4.0),
					child: Row(
							children: [
		Expanded(
				child: Text('• $device'),
		),
		ElevatedButton(
				onPressed: () => onConnectToDevice(device),
				child: const Text('Connect'),
		),
							],
					),
			),
	),
			],
		);
	}
}

class ConnectionWidget extends StatelessWidget { // Displays the name of the connected device and a disconnect button
	final String deviceName;
	final VoidCallback onDisconnect;

	const ConnectionWidget({
		super.key,
		required this.deviceName,
		required this.onDisconnect,
	});

	@override
	Widget build(BuildContext context) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
	// Connected row
	Row(
			children: [
					const Text('Connected:'),
					const Spacer(),
					ElevatedButton(
							onPressed: onDisconnect,
							child: const Text('Disconnect'),
					),
			],
	),

	const SizedBox(height: 8),

	// Device name
	Text(deviceName),
			],
		);
	}
}

class BluetoothControlWidget extends StatelessWidget { // Wraps the scanner and connection widgets based on scanning state and displays them based on the connection state
	final bool isConnected;
	final bool isScanning;
	final String connectedDeviceName;
	final List<String> foundDevices;
	final VoidCallback onToggleScan;
	final VoidCallback onDisconnect;
	final void Function(String deviceName) onConnectToDevice;

	const BluetoothControlWidget({
		super.key,
		required this.isConnected,
		required this.isScanning,
		required this.connectedDeviceName,
		required this.foundDevices,
		required this.onToggleScan,
		required this.onDisconnect,
		required this.onConnectToDevice,
	});

	@override
	Widget build(BuildContext context) {
		return isConnected
	? ConnectionWidget(
					deviceName: connectedDeviceName,
					onDisconnect: onDisconnect,
			)
	: ScannerWidget(
					isScanning: isScanning,
					onToggleScan: onToggleScan,
					foundDevices: foundDevices,
					onConnectToDevice: onConnectToDevice,
			);
	}
}

///////////////////////////////////////////////////////////////////////////
// Settings Screen
class FileSettingsScreen extends StatefulWidget {
	FileSettingsScreen(String? selectedDirectory);

	@override
	_FileSettingsScreenState createState() => _FileSettingsScreenState();
}

class _FileSettingsScreenState extends State<FileSettingsScreen> {
	String? _selectedDirectory;

	@override
	Widget build(BuildContext context) {
	return Scaffold(
			appBar: AppBar(title: Text('File Settings')),
			body: Column(
		children: [
				ListTile(
			title: Text('Save Directory'),
			subtitle: Text(_selectedDirectory ?? 'Default (App Documents)'),
			trailing: Icon(Icons.folder),
			onTap: () => _selectDirectory(context),
				),
				ElevatedButton(
			onPressed: () => _applySettings(context),
			child: Text('Apply Settings'),
				),
		],
			),
	);
	}

	Future<void> _selectDirectory(BuildContext context) async {
	try {
	// First check if we already have permission
	final hasPermission = await DirectoryHelper.hasStoragePermission();

	if (!hasPermission) {
			// Show dialog explaining why we need permission
			final shouldRequest = await showDialog<bool>(
		context: context,
		builder: (context) => AlertDialog(
				title: const Text('Storage Permission Required'),
				content: const Text(
			'This app needs storage permission to save EEG data files to your chosen directory. '
			'Please grant storage permission in the next dialog.',
				),
				actions: [
			TextButton(
					onPressed: () => Navigator.pop(context, false),
					child: const Text('Cancel'),
			),
			TextButton(
					onPressed: () => Navigator.pop(context, true),
					child: const Text('Grant Permission'),
			),
				],
		),
			);

			if (shouldRequest != true) return;

			// Request permission
			final granted = await DirectoryHelper.requestStoragePermission();
			if (!granted) {
		ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
			content: Text('Storage permission is required to select save directory'),
			action: SnackBarAction(
					label: 'Settings',
					onPressed: openAppSettings,
			),
				),
		);
		return;
			}
	}

	// Permission granted, now select directory
	final selectedDir = await DirectoryHelper.selectDirectory();
	if (selectedDir != null) {
			setState(() {
		_selectedDirectory = selectedDir;
			});

			ScaffoldMessenger.of(context).showSnackBar(
		SnackBar(
				content: Text('Directory selected: ${selectedDir.split('/').last}'),
		),
			);
	}

	} catch (e) {
	print("Error in _selectDirectory: $e");
	ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
		content: Text('Error selecting directory: $e'),
			),
	);
	}
}

	Future<void> _applySettings(BuildContext context) async {
	// Apply to your BLE manager
	// emotivBLEManager.setCustomSaveDirectory(_selectedDirectory);
	Navigator.pop(context, _selectedDirectory);

	}
}