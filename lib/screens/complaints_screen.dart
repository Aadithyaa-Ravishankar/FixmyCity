import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import '../services/media_capture_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/geocoding_service.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  XFile? _capturedPhoto;
  XFile? _capturedVideo;
  String? _audioRecordingPath;
  bool _isRecording = false;
  VideoPlayerController? _videoController;

  String _selectedCategory = 'Road';
  bool _isSubmitting = false;
  Position? _currentLocation;
  bool _isLoadingLocation = false;
  String? _locationError;
  String _address = 'Loading location...';
  bool _isLoadingAddress = true;

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
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
      _isLoadingAddress = true;
      _address = 'Loading location...';
    });

    try {
      final position = await LocationService.getCurrentLocation();
      setState(() {
        _currentLocation = position;
        _isLoadingLocation = false;
        if (position == null) {
          _locationError = 'Unable to get current location. Please enable location services.';
          _isLoadingAddress = false;
          _address = 'Location not available';
        }
      });
      
      // Load address if we have coordinates
      if (position != null) {
        await _loadAddress();
      }
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
        _locationError = 'Error getting location: $e';
        _isLoadingAddress = false;
        _address = 'Location unavailable';
      });
    }
  }

  Future<void> _loadAddress() async {
    if (_currentLocation == null) return;
    
    try {
      final address = await GeocodingService.getAddressFromCoordinates(
        _currentLocation!.latitude, 
        _currentLocation!.longitude
      );
      
      if (mounted) {
        setState(() {
          _address = address;
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _address = 'Address unavailable';
          _isLoadingAddress = false;
        });
      }
    }
  }

  Future<String?> _uploadFile(XFile file, String bucket) async {
    try {
      final supabase = Supabase.instance.client;
      final bytes = await file.readAsBytes();
      final fileExt = file.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      await supabase.storage
          .from(bucket)
          .uploadBinary(fileName, bytes);
      
      // Get the public URL for the uploaded file
      final publicUrl = supabase.storage
          .from(bucket)
          .getPublicUrl(fileName);
      
      return publicUrl;
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
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
      
      // Upload files to Supabase storage
      String? photoUrl;
      String? videoUrl;
      String? audioUrl;
      
      if (_capturedPhoto != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading photo...')),
        );
        photoUrl = await _uploadFile(_capturedPhoto!, 'Images');
        if (photoUrl == null) {
          throw Exception('Failed to upload photo');
        }
      }
      
      if (_capturedVideo != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading video...')),
        );
        videoUrl = await _uploadFile(_capturedVideo!, 'Videos');
        if (videoUrl == null) {
          throw Exception('Failed to upload video');
        }
      }
      
      if (_audioRecordingPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading audio...')),
        );
        // For audio files, we need to create an XFile from the path
        final audioFile = XFile(_audioRecordingPath!);
        audioUrl = await _uploadFile(audioFile, 'Audios');
        if (audioUrl == null) {
          throw Exception('Failed to upload audio');
        }
      }

      // Check if we have current location
      if (_currentLocation == null) {
        throw Exception('Location not available. Please enable location services.');
      }

      await supabase.from('complaints').insert({
        'user_id': user.id,
        'location_lat': _currentLocation!.latitude,
        'location_long': _currentLocation!.longitude,
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'voice_url': audioUrl,
        'video_url': videoUrl,
        'picture_url': photoUrl,
        'complaint_status': 'pending',
      });

      // Clear form
      _descriptionController.clear();
      setState(() {
        _selectedCategory = 'Road';
        _capturedPhoto = null;
        _capturedVideo = null;
        _audioRecordingPath = null;
        _isRecording = false;
      });
      
      // Dispose video controller after successful submission
      _videoController?.dispose();
      _videoController = null;

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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: Stack(
        children: [
          // Main content with padding for floating app bar
          Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 86),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 86),
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
                  border: Border.all(color: AppTheme.getBorderLight(context)),
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
                    
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      'Help make your city better by reporting civic issues',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.getTextSecondary(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Category Selection
              Text(
                'Category *',
                style: AppTheme.labelLarge.copyWith(
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.getSurfaceColor(context),
                  borderRadius: AppTheme.mediumRadius,
                  border: Border.all(color: AppTheme.getBorderLight(context)),
                  boxShadow: const [AppTheme.cardShadow],
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: AppTheme.spacingM, vertical: AppTheme.spacingM),
                    prefixIcon: Icon(Icons.category_outlined, color: AppTheme.primaryColor),
                  ),
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.getTextPrimary(context),
                  ),
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
              Text(
                'Description *',
                style: AppTheme.labelLarge.copyWith(
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.getSurfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.getBorderLight(context)),
                ),
                child: TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Describe the issue in detail...',
                    hintStyle: TextStyle(color: AppTheme.getTextSecondary(context)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Icon(Icons.description_outlined, color: AppTheme.primaryColor),
                    ),
                  ),
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
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
              Text(
                'Location *',
                style: AppTheme.labelLarge.copyWith(
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.getSurfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.getBorderLight(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isLoadingLocation 
                            ? Icons.location_searching
                            : _currentLocation != null 
                              ? Icons.location_on 
                              : Icons.location_off,
                          color: _isLoadingLocation 
                            ? Colors.orange
                            : _currentLocation != null 
                              ? Colors.green 
                              : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_isLoadingLocation) ...[
                                Text(
                                  'Getting current location...',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ] else if (_currentLocation != null) ...[
                                if (_isLoadingAddress) ...[
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: Colors.green,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Loading address...',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  Text(
                                    _address,
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  'Coordinates: ${_currentLocation!.latitude.toStringAsFixed(4)}, ${_currentLocation!.longitude.toStringAsFixed(4)}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  _locationError ?? 'Location not available',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_currentLocation == null && !_isLoadingLocation) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _getCurrentLocation,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry Location'),
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
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Media Capture (Optional)
              Text(
                'Media (Optional)',
                style: AppTheme.labelLarge.copyWith(
                  color: AppTheme.getTextPrimary(context),
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
                  borderRadius: AppTheme.mediumRadius,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withBlue(255),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isSubmitting ? null : _submitComplaint,
                    borderRadius: AppTheme.mediumRadius,
                    child: Container(
                      padding: const EdgeInsets.all(AppTheme.spacingL),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _isSubmitting
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                          const SizedBox(width: AppTheme.spacingM),
                          Text(
                            _isSubmitting ? 'Submitting...' : 'Submit Complaint',
                            style: AppTheme.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          // Floating pill-shaped app bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: AppTheme.largeRadius,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Report an Issue',
                    style: AppTheme.headingMedium.copyWith(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
        // Dispose previous controller if exists
        _videoController?.dispose();
        
        // Initialize new video controller
        _videoController = VideoPlayerController.file(File(video.path));
        await _videoController!.initialize();
        
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
        color: AppTheme.getSurfaceColor(context),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.getBorderLight(context)),
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
                    color: AppTheme.getTextPrimary(context),
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
              // Show video preview for video files, otherwise show file info
              if (title == 'Video' && _videoController != null && _videoController!.value.isInitialized) ...[
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: AppTheme.smallRadius,
                    border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
                  ),
                  child: ClipRRect(
                    borderRadius: AppTheme.smallRadius,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () {
                              setState(() {
                                if (_videoController!.value.isPlaying) {
                                  _videoController!.pause();
                                } else {
                                  _videoController!.play();
                                }
                              });
                            },
                            icon: Icon(
                              _videoController!.value.isPlaying 
                                ? Icons.pause 
                                : Icons.play_arrow,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
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
        color: AppTheme.getSurfaceColor(context),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.getBorderLight(context)),
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
                    color: AppTheme.getTextPrimary(context),
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
          ],
        ),
      ),
    );
  }
}
