import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:device_info_plus/device_info_plus.dart'; // Add this import
import 'package:path_provider/path_provider.dart'; // Add this too

class DirectoryHelper {
  /// Request storage permissions with better Android version handling
  static Future<bool> requestStoragePermission() async {
	if (Platform.isAndroid) {
	  try {
		// Check Android version
		final androidInfo = await DeviceInfoPlugin().androidInfo;
		final sdkInt = androidInfo.version.sdkInt;
		
		if (sdkInt >= 30) {
		  // Android 11+ (API 30+) - Need MANAGE_EXTERNAL_STORAGE
		  var status = await Permission.manageExternalStorage.status;
		  if (!status.isGranted) {
			status = await Permission.manageExternalStorage.request();
			if (!status.isGranted) {
			  // For Android 11+, we might need to open settings
			  await openAppSettings();
			  return false;
			}
		  }
		  return true;
		} else {
		  // Android 10 and below - Use regular storage permission
		  final permissions = await [
			Permission.storage,
		  ].request();
		  
		  return permissions.values.every((status) => 
			status.isGranted || status.isLimited);
		}
	  } catch (e) {
		print("Error requesting storage permission: $e");
		return false;
	  }
	}
	return true; // iOS doesn't need explicit permission for file picker
  }
  
  /// Check current permission status
  static Future<bool> hasStoragePermission() async {
	if (Platform.isAndroid) {
	  try {
		final androidInfo = await DeviceInfoPlugin().androidInfo;
		final sdkInt = androidInfo.version.sdkInt;
		
		if (sdkInt >= 30) {
		  return await Permission.manageExternalStorage.isGranted;
		} else {
		  return await Permission.storage.isGranted;
		}
	  } catch (e) {
		print("Error checking storage permission: $e");
		return false;
	  }
	}
	return true;
  }
  
  /// Let user select a directory
  static Future<String?> selectDirectory() async {
	try {
	  final String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
	  return selectedDirectory;
	} catch (e) {
	  print("Error selecting directory: $e");
	  return null;
	}
  }
  
  /// Get common external directories
  static Future<List<String>> getCommonDirectories() async {
	final List<String> directories = [];
	
	if (Platform.isAndroid) {
	  // Add common Android directories
	  directories.addAll([
		'/storage/emulated/0/Download',
		'/storage/emulated/0/Documents',
		'/storage/emulated/0/Music',
	  ]);
	} else if (Platform.isIOS) {
	  // iOS directories are more restricted
	  final documentsDir = await getApplicationDocumentsDirectory();
	  directories.add(documentsDir.path);
	}
	
	return directories;
  }
  
  /// Debug method to check permissions
  static Future<void> debugPermissions() async {
	print("=== Permission Debug Info ===");
	
	if (Platform.isAndroid) {
	  try {
		final androidInfo = await DeviceInfoPlugin().androidInfo;
		print("Android SDK: ${androidInfo.version.sdkInt}");
		
		final permissions = [
		  Permission.storage,
		  Permission.manageExternalStorage,
		];
		
		for (final permission in permissions) {
		  final status = await permission.status;
		  print("${permission.toString()}: ${status.toString()}");
		}
	  } catch (e) {
		print("Error in debug permissions: $e");
	  }
	}
	
	print("=== End Debug Info ===");
  }
}