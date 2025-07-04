import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'emotiv_ble_manager.dart';
import 'dart:async';

void main() {
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
      home: const EmotivHomePage(),
    );
  }
}

class EmotivHomePage extends StatefulWidget {
  const EmotivHomePage({super.key});

  @override
  State<EmotivHomePage> createState() => _EmotivHomePageState();
}

class _EmotivHomePageState extends State<EmotivHomePage> {
  final EmotivBLEManager _bleManager = EmotivBLEManager();
  List<double> _latestEEGData = [];
  String _statusMessage = "Ready to connect";
  bool _isConnected = false;
  late StreamSubscription _eegSubscription;
  late StreamSubscription _statusSubscription;
  late StreamSubscription _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
    _setupStreamListeners();
  }

  void _setupStreamListeners() {
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

    _connectionSubscription = _bleManager.connectionStream.listen((connected) {
      setState(() {
        _isConnected = connected;
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
    Map<Permission, PermissionStatus> permissions = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();

    bool allGranted = permissions.values.every((status) => status.isGranted);
    if (!allGranted) {
      setState(() {
        _statusMessage = "Bluetooth permissions required";
      });
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

  @override
  void dispose() {
    _eegSubscription.cancel();
    _statusSubscription.cancel();
    _connectionSubscription.cancel();
    _bleManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emotiv BLE LSL Logger'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
            
            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConnected ? null : _startScanning,
                    icon: const Icon(Icons.search),
                    label: Text(_bleManager.isScanning ? 'Scanning...' : 'Start Scan'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConnected ? _disconnect : _stopScanning,
                    icon: Icon(_isConnected ? Icons.bluetooth_disabled : Icons.stop),
                    label: Text(_isConnected ? 'Disconnect' : 'Stop Scan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isConnected ? Colors.red : null,
                      foregroundColor: _isConnected ? Colors.white : null,
                    ),
                  ),
                ),
              ],
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




// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       theme: ThemeData(
//         // This is the theme of your application.
//         //
//         // TRY THIS: Try running your application with "flutter run". You'll see
//         // the application has a purple toolbar. Then, without quitting the app,
//         // try changing the seedColor in the colorScheme below to Colors.green
//         // and then invoke "hot reload" (save your changes or press the "hot
//         // reload" button in a Flutter-supported IDE, or press "r" if you used
//         // the command line to start the app).
//         //
//         // Notice that the counter didn't reset back to zero; the application
//         // state is not lost during the reload. To reset the state, use hot
//         // restart instead.
//         //
//         // This works for code too, not just values: Most code changes can be
//         // tested with just a hot reload.
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
//       ),
//       home: const MyHomePage(title: 'Flutter Demo Home Page'),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});

//   // This widget is the home page of your application. It is stateful, meaning
//   // that it has a State object (defined below) that contains fields that affect
//   // how it looks.

//   // This class is the configuration for the state. It holds the values (in this
//   // case the title) provided by the parent (in this case the App widget) and
//   // used by the build method of the State. Fields in a Widget subclass are
//   // always marked "final".

//   final String title;

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   int _counter = 0;

//   void _incrementCounter() {
//     setState(() {
//       // This call to setState tells the Flutter framework that something has
//       // changed in this State, which causes it to rerun the build method below
//       // so that the display can reflect the updated values. If we changed
//       // _counter without calling setState(), then the build method would not be
//       // called again, and so nothing would appear to happen.
//       _counter++;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     // This method is rerun every time setState is called, for instance as done
//     // by the _incrementCounter method above.
//     //
//     // The Flutter framework has been optimized to make rerunning build methods
//     // fast, so that you can just rebuild anything that needs updating rather
//     // than having to individually change instances of widgets.
//     return Scaffold(
//       appBar: AppBar(
//         // TRY THIS: Try changing the color here to a specific color (to
//         // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
//         // change color while the other colors stay the same.
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//         // Here we take the value from the MyHomePage object that was created by
//         // the App.build method, and use it to set our appbar title.
//         title: Text(widget.title),
//       ),
//       body: Center(
//         // Center is a layout widget. It takes a single child and positions it
//         // in the middle of the parent.
//         child: Column(
//           // Column is also a layout widget. It takes a list of children and
//           // arranges them vertically. By default, it sizes itself to fit its
//           // children horizontally, and tries to be as tall as its parent.
//           //
//           // Column has various properties to control how it sizes itself and
//           // how it positions its children. Here we use mainAxisAlignment to
//           // center the children vertically; the main axis here is the vertical
//           // axis because Columns are vertical (the cross axis would be
//           // horizontal).
//           //
//           // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
//           // action in the IDE, or press "p" in the console), to see the
//           // wireframe for each widget.
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             const Text('You have pushed the button this many times:'),
//             Text(
//               '$_counter',
//               style: Theme.of(context).textTheme.headlineMedium,
//             ),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _incrementCounter,
//         tooltip: 'Increment',
//         child: const Icon(Icons.add),
//       ), // This trailing comma makes auto-formatting nicer for build methods.
//     );
//   }
// }
