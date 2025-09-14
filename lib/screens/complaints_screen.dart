import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import '../services/media_capture_service.dart';
import '../services/auth_service.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  XFile? _capturedPhoto;
  XFile? _capturedVideo;
  String? _audioRecordingPath;
  bool _isRecording = false;

  String _selectedCategory = 'Road';
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Road',
    'Water',
    'Electricity',
    'Waste',
    'Traffic',
    'Street Light',
    'Drainage',
    'Public Transport',
    'Other'
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    MediaCaptureService.dispose();
    super.dispose();
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = AuthService.getCurrentUser();
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to submit a complaint'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final supabase = Supabase.instance.client;
      
      // For now, we'll store file paths as URLs in the database
      // In a production app, you'd upload these files to storage first
      String? photoUrl;
      String? videoUrl;
      String? audioUrl;
      
      if (_capturedPhoto != null) {
        photoUrl = _capturedPhoto!.path;
      }
      
      if (_capturedVideo != null) {
        videoUrl = _capturedVideo!.path;
      }
      
      if (_audioRecordingPath != null) {
        audioUrl = _audioRecordingPath;
      }

      await supabase.from('complaints').insert({
        'user_id': user.id,
        'location_lat': double.tryParse(_latitudeController.text) ?? 0.0,
        'location_long': double.tryParse(_longitudeController.text) ?? 0.0,
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'voice_url': audioUrl,
        'video_url': videoUrl,
        'picture_url': photoUrl,
        'complaint_status': 'pending',
      });

      // Clear form
      _descriptionController.clear();
      _latitudeController.clear();
      _longitudeController.clear();
      setState(() {
        _selectedCategory = 'Road';
        _capturedPhoto = null;
        _capturedVideo = null;
        _audioRecordingPath = null;
        _isRecording = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complaint submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting complaint: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _getCurrentLocation() {
    // Placeholder for getting current location
    // In a real app, you would use location services
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location services not implemented yet'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Report Issue',
          style: AppTheme.headingSmall.copyWith(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryColor.withOpacity(0.1), AppTheme.primaryLight.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: AppTheme.largeRadius,
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Icon(
                        Icons.report_problem_outlined,
                        size: 32,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    Text(
                      'Report an Issue',
                      style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryColor),
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      'Help make your city better by reporting civic issues',
                      style: AppTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Category Selection
              Text(
                'Category *',
                style: AppTheme.labelLarge,
              ),
              const SizedBox(height: AppTheme.spacingS),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: AppTheme.mediumRadius,
                  border: Border.all(color: AppTheme.borderLight),
                  boxShadow: const [AppTheme.cardShadow],
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: AppTheme.spacingM, vertical: AppTheme.spacingM),
                    prefixIcon: Icon(Icons.category_outlined, color: AppTheme.primaryColor),
                  ),
                  style: AppTheme.bodyLarge,
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Description
              const Text(
                'Description *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Describe the issue in detail...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Icon(Icons.description_outlined, color: Colors.blue),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please provide a description';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Location Section
              const Text(
                'Location *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextFormField(
                        controller: _latitudeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          hintText: '12.9716',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                          prefixIcon: Icon(Icons.location_on_outlined, color: Colors.blue),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextFormField(
                        controller: _longitudeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          hintText: '77.5946',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('Get Current Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Media Capture (Optional)
              const Text(
                'Media (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              
              // Photo Capture
              _buildMediaCaptureCard(
                title: 'Photo',
                icon: Icons.camera_alt,
                capturedFile: _capturedPhoto,
                onCapture: _capturePhoto,
                onRemove: () => setState(() => _capturedPhoto = null),
              ),
              const SizedBox(height: 12),

              // Video Capture
              _buildMediaCaptureCard(
                title: 'Video',
                icon: Icons.videocam,
                capturedFile: _capturedVideo,
                onCapture: _recordVideo,
                onRemove: () => setState(() => _capturedVideo = null),
              ),
              const SizedBox(height: 12),

              // Audio Recording
              _buildAudioRecordingCard(),
              const SizedBox(height: 32),

              // Submit Button
              Container(
                decoration: BoxDecoration(
                  borderRadius: AppTheme.largeRadius,
                  gradient: AppTheme.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitComplaint,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingL),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.largeRadius,
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Submit Complaint',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Photo capture method
  Future<void> _capturePhoto() async {
    try {
      final photo = await MediaCaptureService.capturePhoto();
      if (photo != null) {
        setState(() {
          _capturedPhoto = photo;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo captured successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing photo: $e')),
      );
    }
  }

  // Video recording method
  Future<void> _recordVideo() async {
    try {
      final video = await MediaCaptureService.recordVideo();
      if (video != null) {
        setState(() {
          _capturedVideo = video;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video recorded successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recording video: $e')),
      );
    }
  }

  // Start audio recording
  Future<void> _startAudioRecording() async {
    try {
      final tempDir = await MediaCaptureService.getTempDirectory();
      final fileName = MediaCaptureService.generateFileName('m4a');
      final filePath = '$tempDir/$fileName';
      
      await MediaCaptureService.startAudioRecording(filePath);
      setState(() {
        _isRecording = true;
        _audioRecordingPath = filePath;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording started...')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting recording: $e')),
      );
    }
  }

  // Stop audio recording
  Future<void> _stopAudioRecording() async {
    try {
      final recordedPath = await MediaCaptureService.stopAudioRecording();
      setState(() {
        _isRecording = false;
        _audioRecordingPath = recordedPath;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording stopped successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error stopping recording: $e')),
      );
    }
  }

  // Build media capture card widget
  Widget _buildMediaCaptureCard({
    required String title,
    required IconData icon,
    required XFile? capturedFile,
    required VoidCallback onCapture,
    required VoidCallback onRemove,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (capturedFile != null)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, color: AppTheme.errorColor),
                    iconSize: 20,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (capturedFile != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: AppTheme.smallRadius,
                  border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.successColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Captured: ${capturedFile.name}',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onCapture,
                  icon: Icon(icon, size: 18),
                  label: Text('Capture $title'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    foregroundColor: AppTheme.primaryColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.smallRadius,
                      side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Build audio recording card widget
  Widget _buildAudioRecordingCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mic, color: AppTheme.primaryColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Audio Recording',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_audioRecordingPath != null && !_isRecording)
                  IconButton(
                    onPressed: () => setState(() => _audioRecordingPath = null),
                    icon: const Icon(Icons.close, color: AppTheme.errorColor),
                    iconSize: 20,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_audioRecordingPath != null && !_isRecording) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: AppTheme.smallRadius,
                  border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.successColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Audio recorded successfully',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_isRecording) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: AppTheme.smallRadius,
                  border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.errorColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recording in progress...',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.errorColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _stopAudioRecording,
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('Stop Recording'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.smallRadius,
                    ),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startAudioRecording,
                  icon: const Icon(Icons.mic, size: 18),
                  label: const Text('Start Recording'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    foregroundColor: AppTheme.primaryColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.smallRadius,
                      side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
