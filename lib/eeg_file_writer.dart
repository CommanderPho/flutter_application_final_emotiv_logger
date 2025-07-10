import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class EEGFileWriter {
  File? _eegDataFile;
  IOSink? _eegDataSink;
  Timer? _flushTimer;
  final List<String> _writeBuffer = [];
  
  static const int _bufferSize = 100; // Buffer 100 entries before writing
  static const int _flushIntervalMs = 1000; // Flush every second
  
  bool _isInitialized = false;
  bool _isDisposed = false;
  
  // Callback for status updates
  final Function(String)? onStatusUpdate;
  
  EEGFileWriter({this.onStatusUpdate});
  
  /// Initialize the file writer with CSV header
  Future<bool> initialize() async {
    if (_isInitialized || _isDisposed) return false;
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'eeg_data_$timestamp.csv';
      
      print("Active App Directory: ${directory.path}");
      _eegDataFile = File('${directory.path}/$fileName');
      print("_eegDataFile: ${_eegDataFile?.path}");

      _eegDataSink = _eegDataFile!.openWrite();
      
      // Write CSV header
      _eegDataSink!.writeln('timestamp,channel_1,channel_2,channel_3,channel_4,channel_5,channel_6,channel_7,channel_8,channel_9,channel_10,channel_11,channel_12,channel_13,channel_14');
      
      // Setup periodic flush timer
      _flushTimer = Timer.periodic(Duration(milliseconds: _flushIntervalMs), (_) {
        _flushBuffer();
      });
      
      _isInitialized = true;
      _updateStatus("File writer initialized: $fileName");
      return true;
      
    } catch (e) {
      _updateStatus("Error initializing file writer: $e");
      return false;
    }
  }
  
  /// Write EEG data to file with buffering
  void writeEEGData(List<double> eegData) {
    if (!_isInitialized || _isDisposed || _eegDataSink == null) return;
    
    // Check if sink is still valid
    if (_eegDataSink!.done.isCompleted) {
      _updateStatus("Cannot write to closed file");
      return;
    }
    
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
      // Check if the sink is still valid before using it
      if (_eegDataSink!.done.isCompleted) {
        print("Sink is already closed, skipping flush");
        return;
      }
      
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
    
    _isDisposed = true;
    
    try {
      // Cancel the timer first to prevent it from running during cleanup
      _flushTimer?.cancel();
      _flushTimer = null;
      
      // Flush any remaining data only if sink is still valid
      if (_eegDataSink != null && !_eegDataSink!.done.isCompleted) {
        _flushBuffer();
        await _eegDataSink!.close();
      }
      
      _eegDataSink = null;
      _eegDataFile = null;
      _writeBuffer.clear();
      _isInitialized = false;
      
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
  
  void _updateStatus(String status) {
    print("EEGFileWriter: $status");
    onStatusUpdate?.call(status);
  }
}