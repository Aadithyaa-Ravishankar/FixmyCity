import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class MediaCaptureService {
  static final ImagePicker _picker = ImagePicker();
  static final AudioRecorder _audioRecorder = AudioRecorder();
  
  // Request camera permission
  static Future<bool> requestCameraPermission() async {
    if (kIsWeb) {
      // For web, we'll use the browser's built-in permissions
      return true;
    }
    
    final status = await Permission.camera.request();
    return status == PermissionStatus.granted;
  }
  
  // Request microphone permission
  static Future<bool> requestMicrophonePermission() async {
    if (kIsWeb) {
      // For web, we'll use the browser's built-in permissions
      return true;
    }
    
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }
  
  // Capture photo from camera
  static Future<XFile?> capturePhoto() async {
    try {
      final hasPermission = await requestCameraPermission();
      if (!hasPermission) {
        throw Exception('Camera permission denied');
      }
      
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      
      return photo;
    } catch (e) {
      print('Error capturing photo: $e');
      rethrow;
    }
  }
  
  // Record video from camera
  static Future<XFile?> recordVideo() async {
    try {
      final hasPermission = await requestCameraPermission();
      if (!hasPermission) {
        throw Exception('Camera permission denied');
      }
      
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 2), // Limit to 2 minutes
      );
      
      return video;
    } catch (e) {
      print('Error recording video: $e');
      rethrow;
    }
  }
  
  // Start audio recording
  static Future<void> startAudioRecording(String filePath) async {
    try {
      final hasPermission = await requestMicrophonePermission();
      if (!hasPermission) {
        throw Exception('Microphone permission denied');
      }
      
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );
    } catch (e) {
      print('Error starting audio recording: $e');
      rethrow;
    }
  }
  
  // Stop audio recording
  static Future<String?> stopAudioRecording() async {
    try {
      final path = await _audioRecorder.stop();
      return path;
    } catch (e) {
      print('Error stopping audio recording: $e');
      rethrow;
    }
  }
  
  // Check if currently recording
  static Future<bool> isRecording() async {
    return await _audioRecorder.isRecording();
  }
  
  // Get temporary directory for storing media files
  static Future<String> getTempDirectory() async {
    if (kIsWeb) {
      return '/tmp'; // Web fallback
    }
    
    final directory = await getTemporaryDirectory();
    return directory.path;
  }
  
  // Generate unique filename
  static String generateFileName(String extension) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'media_$timestamp.$extension';
  }
  
  // Get file size in MB
  static Future<double> getFileSizeInMB(String filePath) async {
    if (kIsWeb) {
      return 0.0; // Web fallback
    }
    
    final file = File(filePath);
    if (await file.exists()) {
      final bytes = await file.length();
      return bytes / (1024 * 1024);
    }
    return 0.0;
  }
  
  // Dispose resources
  static Future<void> dispose() async {
    await _audioRecorder.dispose();
  }
}
