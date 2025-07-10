import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class EEGFileWriter {
  File? _eegDataFile;
  IOSink? _eegDataSink;
  Timer? _flushTimer;
  final List<String> _writeBuffer = [];
  
  static const int _bufferSize = 100; // Buffer 100 entries before writing
  static const int _flushIntervalMs = 3000; // Flush every second
  
  bool _isInitialized = false;
  bool _isDisposed = false;
  
  // Callback for status updates
  final Function(String)? onStatusUpdate;
  
  // Custom directory path
  final String? customDirectoryPath;
  
  EEGFileWriter({
    this.onStatusUpdate,
    this.customDirectoryPath, // Add this parameter
  });
  
  /// Initialize the file writer with CSV header
  Future<bool> initialize() async {
    if (_isInitialized || _isDisposed) return false;
    
    try {
      Directory targetDirectory;
      
      // Use custom directory if provided, otherwise use app documents directory
      if (customDirectoryPath != null && customDirectoryPath!.isNotEmpty) {
        targetDirectory = Directory(customDirectoryPath!);
        
        // Create the directory if it doesn't exist
        if (!await targetDirectory.exists()) {
          try {
            await targetDirectory.create(recursive: true);
            _updateStatus("Created directory: ${targetDirectory.path}");
          } catch (e) {
            _updateStatus("Error creating directory: $e");
            return false;
          }
        }
        
        // Verify we can write to the directory
        if (!await _canWriteToDirectory(targetDirectory)) {
          _updateStatus("Cannot write to directory: ${targetDirectory.path}");
          return false;
        }
        
      } else {
        // Use default app documents directory
        targetDirectory = await getApplicationDocumentsDirectory();
      }
      
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'eeg_data_$timestamp.csv';
      
      print("Target Directory: ${targetDirectory.path}");
      _eegDataFile = File('${targetDirectory.path}/$fileName');
      print("EEG Data File: ${_eegDataFile?.path}");

      _eegDataSink = _eegDataFile!.openWrite();
      
      // Write CSV header
      _eegDataSink!.writeln('timestamp,channel_1,channel_2,channel_3,channel_4,channel_5,channel_6,channel_7,channel_8,channel_9,channel_10,channel_11,channel_12,channel_13,channel_14');
      
      // Setup periodic flush timer
      _flushTimer = Timer.periodic(Duration(milliseconds: _flushIntervalMs), (_) {
        _flushBuffer();
      });
      
      _isInitialized = true;
      _updateStatus("File writer initialized: $fileName in ${targetDirectory.path}");
      return true;
      
    } catch (e) {
      _updateStatus("Error initializing file writer: $e");
      return false;
    }
  }

  /// Check if we can write to the specified directory
  Future<bool> _canWriteToDirectory(Directory directory) async {
    try {
      final testFile = File('${directory.path}/.test_write');
      await testFile.writeAsString('test');
      await testFile.delete();
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Write EEG data to file with buffering
  void writeEEGData(List<double> eegData) {
    if (!_isInitialized || _isDisposed || _eegDataSink == null) return;
    
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


  /// Flush the buffer to file
  void _flushBuffer() {
    if (_eegDataSink == null || _writeBuffer.isEmpty || _isDisposed) return;
    
    try {
      for (String line in _writeBuffer) {
        _eegDataSink!.writeln(line);
      }
      _eegDataSink!.flush();
      _writeBuffer.clear();
      
    } catch (e) {
      _updateStatus("Error flushing buffer: $e");
      // If there's an error, stop the timer to prevent repeated errors
      _flushTimer?.cancel();
      _flushTimer = null;
    }
  }

  
  /// Force flush any remaining data
  void flush() {
    if (!_isDisposed) {
      _flushBuffer();
    }
  }
  
  /// Get information about the current file
  Future<Map<String, dynamic>?> getFileInfo() async {
    if (_eegDataFile == null || _isDisposed) return null;
    
    try {
      final stat = await _eegDataFile!.stat();
      return {
        'path': _eegDataFile!.path,
        'size': stat.size,
        'modified': stat.modified.toIso8601String(),
        'buffered_lines': _writeBuffer.length,
      };
    } catch (e) {
      return null;
    }
  }
  
  /// Get the current file path
  String? get filePath => _eegDataFile?.path;
  
  /// Check if the writer is initialized and ready
  bool get isInitialized => _isInitialized && !_isDisposed;
  
  /// Get the number of buffered lines waiting to be written
  int get bufferedLines => _writeBuffer.length;
  
  /// Close the file writer and cleanup resources
  Future<void> dispose() async {
    if (_isDisposed) return;
    print("EEGFileWriter.dispose(): closing EEG Data File: ${_eegDataFile?.path}");
    _isDisposed = true;
    
    try {
      // Cancel the timer first to prevent it from running during cleanup
      _flushTimer?.cancel();
      _flushTimer = null;
      
      // Flush any remaining data
      if (_eegDataSink != null) {
        _flushBuffer();
        await _eegDataSink!.close();
      }
      
      _eegDataSink = null;
      _eegDataFile = null;
      _writeBuffer.clear();
      _isInitialized = false;
      
      print("EEGFileWriter.dispose(): File writer closed");
      _updateStatus("File writer closed");
      
    } catch (e) {
      _updateStatus("Error closing file writer: $e");
      // Force cleanup even if there's an error
      _eegDataSink = null;
      _eegDataFile = null;
      _writeBuffer.clear();
      _isInitialized = false;
    }
  }

  /// Update the status message
  void _updateStatus(String status) {
    print("EEGFileWriter: $status");
    onStatusUpdate?.call(status);
  }
}