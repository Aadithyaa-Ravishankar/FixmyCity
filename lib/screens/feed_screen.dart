import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';
import '../widgets/severity_rating_dialog.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _complaints = [];
  List<Map<String, dynamic>> _filteredComplaints = [];
  bool _isLoading = true;
  double? _selectedDistance = 1000; // Default 1km in meters, null for 'All'
  
  final List<Map<String, dynamic>> _distanceOptions = [
    {'label': 'All', 'value': null},
    {'label': '250m', 'value': 250.0},
    {'label': '500m', 'value': 500.0},
    {'label': '1km', 'value': 1000.0},
  ];

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _fetchComplaints();
  }

  Future<void> _initializeLocation() async {
    final position = await LocationService.getCurrentLocation();
    if (position != null) {
      print('Location initialized: ${position.latitude}, ${position.longitude}');
      // Recalculate distances for all complaints after getting location
      setState(() {
        // This will trigger a rebuild and recalculate distances
      });
    } else {
      print('Failed to get location');
      // Show user-friendly message about location
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Enable location services to see distances to complaints'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () {
                // This would open app settings, but requires additional setup
                print('Open location settings');
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _fetchComplaints() async {
    try {
      final response = await _supabase
          .from('complaints')
          .select('*')
          .order('created_at', ascending: false);
      

      // Get user profiles for all complaints in one query
      final userIds = response.map((c) => c['user_id']).where((id) => id != null).toSet().toList();
      Map<String, String> userProfiles = {};
      
      if (userIds.isNotEmpty) {
        try {
          final profilesResponse = await _supabase
              .from('user_profiles')
              .select('id, display_name')
              .inFilter('id', userIds);
          
          for (var profile in profilesResponse) {
            userProfiles[profile['id']] = profile['display_name'] ?? 'Anonymous User';
          }
        } catch (e) {
          print('Failed to fetch user profiles: $e');
        }
      }

      // For each complaint, assign the user name
      List<Map<String, dynamic>> complaintsWithUsers = [];
      final currentUser = _supabase.auth.currentUser;
      
      for (var complaint in response) {
        final userId = complaint['user_id'];
        
        // If it's the current user's complaint, use their info
        if (currentUser != null && userId == currentUser.id) {
          // Use display_name if available, otherwise fall back to email username
          final displayName = currentUser.userMetadata?['display_name'] as String?;
          complaint['user_name'] = displayName ?? currentUser.email?.split('@')[0] ?? 'You';
          complaint['user_email'] = currentUser.email;
        } else {
          // For other users, use the fetched profile data
          complaint['user_name'] = userProfiles[userId] ?? 'Anonymous User';
          complaint['user_email'] = null;
        }
        
        complaintsWithUsers.add(complaint);
      }


      setState(() {
        _complaints = complaintsWithUsers;
        _isLoading = false;
      });
      
      // Apply distance filter after fetching complaints
      _applyDistanceFilter();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading complaints: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshComplaints() async {
    setState(() {
      _isLoading = true;
    });
    await _fetchComplaints();
  }
  
  void _applyDistanceFilter() {
    // If 'All' is selected, show all complaints
    if (_selectedDistance == null) {
      setState(() {
        _filteredComplaints = _complaints;
      });
      return;
    }
    
    final userLocation = LocationService.getCachedPosition();
    if (userLocation == null) {
      setState(() {
        _filteredComplaints = _complaints;
      });
      return;
    }
    
    final filteredList = _complaints.where((complaint) {
      final complaintLat = complaint['location_lat']?.toDouble() ?? 0.0;
      final complaintLng = complaint['location_long']?.toDouble() ?? 0.0;
      
      if (complaintLat == 0.0 && complaintLng == 0.0) {
        return false; // Skip complaints without valid coordinates
      }
      
      final distance = LocationService.calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        complaintLat,
        complaintLng,
      );
      
      // Convert distance from km to meters for comparison
      return (distance * 1000) <= _selectedDistance!;
    }).toList();
    
    setState(() {
      _filteredComplaints = filteredList;
    });
  }
  
  void _onDistanceChanged(double? newDistance) {
    setState(() {
      _selectedDistance = newDistance;
    });
    _applyDistanceFilter();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'FixmyCity',
          style: AppTheme.headingMedium.copyWith(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                // Distance Filter Section
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: AppTheme.largeRadius,
                    boxShadow: [AppTheme.cardShadow],
                    border: Border.all(color: AppTheme.borderLight.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.filter_list,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Filter by distance:',
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: AppTheme.borderLight),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<double>(
                              value: _selectedDistance,
                              onChanged: _onDistanceChanged,
                              isExpanded: true,
                              dropdownColor: AppTheme.surfaceColor,
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                              icon: Icon(
                                Icons.keyboard_arrow_down,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                              items: _distanceOptions.map((option) {
                                return DropdownMenuItem<double>(
                                  value: option['value'],
                                  child: Text(
                                    option['label'],
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _selectedDistance == null 
                              ? '${_filteredComplaints.length} total'
                              : '${_filteredComplaints.length} nearby',
                          style: AppTheme.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Feed Content
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshComplaints,
                    child: _filteredComplaints.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.report_outlined,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _complaints.isEmpty ? 'No complaints yet' : 'No complaints in selected area',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _complaints.isEmpty ? 'Be the first to report an issue!' : 'Try increasing the distance filter',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredComplaints.length,
                            padding: const EdgeInsets.all(16),
                            itemBuilder: (context, index) {
                              final complaint = _filteredComplaints[index];
                              return ComplaintPostCard(
                                key: ValueKey(complaint['complaint_id']),
                                complaint: complaint,
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

class ComplaintPostCard extends StatefulWidget {
  final Map<String, dynamic> complaint;

  const ComplaintPostCard({super.key, required this.complaint});

  @override
  State<ComplaintPostCard> createState() => _ComplaintPostCardState();
}

class _ComplaintPostCardState extends State<ComplaintPostCard> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLiked = false;
  bool _isDisliked = false;
  int _likeCount = 0;
  int _dislikeCount = 0;
  bool _isLoading = false;
  String _address = 'Loading location...';
  bool _isLoadingAddress = true;
  String? _distance;
  int? _userSeverityRating;
  double? _averageSeverity;
  int _severityVoteCount = 0;

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
    _loadAddress();
    _calculateDistance();
  }

  @override
  void didUpdateWidget(ComplaintPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the complaint changed, reload the data
    if (oldWidget.complaint['complaint_id'] != widget.complaint['complaint_id']) {
      _loadVerificationStatus();
      _loadAddress();
      _calculateDistance();
    }
  }

  void _calculateDistance() {
    final lat = widget.complaint['location_lat'] as double?;
    final lon = widget.complaint['location_long'] as double?;
    
    if (lat != null && lon != null) {
      final distance = LocationService.getDistanceFromCurrent(lat, lon);
      if (mounted) {
        setState(() {
          _distance = distance;
        });
      }
      print('Distance calculated for complaint: $distance');
    } else {
      print('No coordinates available for complaint');
    }
  }

  Future<void> _loadAddress() async {
    try {
      final lat = widget.complaint['location_lat'] as double?;
      final lon = widget.complaint['location_long'] as double?;
      final complaintId = widget.complaint['complaint_id'];
      
      if (lat != null && lon != null) {
        final address = await GeocodingService.getAddressFromCoordinates(lat, lon);
        // Only update if this widget is still mounted and for the same complaint
        if (mounted && widget.complaint['complaint_id'] == complaintId) {
          setState(() {
            _address = address;
            _isLoadingAddress = false;
          });
        }
      } else {
        if (mounted && widget.complaint['complaint_id'] == complaintId) {
          setState(() {
            _address = 'Location not available';
            _isLoadingAddress = false;
          });
        }
      }
    } catch (e) {
      if (mounted && widget.complaint['complaint_id'] == widget.complaint['complaint_id']) {
        setState(() {
          _address = 'Location unavailable';
          _isLoadingAddress = false;
        });
      }
    }
  }

  Future<void> _loadVerificationStatus() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      // Get verification data for this complaint
      final response = await _supabase
          .from('verification')
          .select('*')
          .eq('complaint_id', widget.complaint['complaint_id']);

      // Count likes and dislikes, calculate average severity
      int likes = 0;
      int dislikes = 0;
      bool userLiked = false;
      bool userDisliked = false;
      List<int> severityRatings = [];

      for (var verification in response) {
        if (verification['verified_true'] == true) {
          likes++;
          if (verification['user_id'] == currentUser.id) {
            userLiked = true;
            _userSeverityRating = verification['severity'];
          }
        }
        if (verification['verified_false'] == true) {
          dislikes++;
          if (verification['user_id'] == currentUser.id) {
            userDisliked = true;
            _userSeverityRating = verification['severity'];
          }
        }
        
        // Collect severity ratings for average calculation
        if (verification['severity'] != null) {
          severityRatings.add(verification['severity'] as int);
        }
      }

      // Calculate average severity
      double? avgSeverity;
      if (severityRatings.isNotEmpty) {
        avgSeverity = severityRatings.reduce((a, b) => a + b) / severityRatings.length;
      }

      setState(() {
        _likeCount = likes;
        _dislikeCount = dislikes;
        _isLiked = userLiked;
        _isDisliked = userDisliked;
        _averageSeverity = avgSeverity;
        _severityVoteCount = severityRatings.length;
      });
    } catch (e) {
      print('Error loading verification status: $e');
    }
  }

  Future<void> _toggleLike() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLiked) {
        // Remove like
        await _supabase
            .from('verification')
            .delete()
            .eq('user_id', currentUser.id)
            .eq('complaint_id', widget.complaint['complaint_id'])
            .eq('verified_true', true);
        
        setState(() {
          _isLiked = false;
          _likeCount--;
          _userSeverityRating = null;
        });
      } else {
        // Remove dislike if exists
        if (_isDisliked) {
          await _supabase
              .from('verification')
              .delete()
              .eq('user_id', currentUser.id)
              .eq('complaint_id', widget.complaint['complaint_id'])
              .eq('verified_false', true);
          
          setState(() {
            _isDisliked = false;
            _dislikeCount--;
          });
        }

        // Add like without severity (default to null)
        await _supabase.from('verification').insert({
          'user_id': currentUser.id,
          'complaint_id': widget.complaint['complaint_id'],
          'verified_true': true,
          'verified_false': false,
          'severity': null,
        });

        setState(() {
          _isLiked = true;
          _likeCount++;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating like: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  Future<void> _toggleDislike() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isDisliked) {
        // Remove dislike
        await _supabase
            .from('verification')
            .delete()
            .eq('user_id', currentUser.id)
            .eq('complaint_id', widget.complaint['complaint_id'])
            .eq('verified_false', true);
        
        setState(() {
          _isDisliked = false;
          _dislikeCount--;
          _userSeverityRating = null;
        });
      } else {
        // Remove like if exists
        if (_isLiked) {
          await _supabase
              .from('verification')
              .delete()
              .eq('user_id', currentUser.id)
              .eq('complaint_id', widget.complaint['complaint_id'])
              .eq('verified_true', true);
          
          setState(() {
            _isLiked = false;
            _likeCount--;
            _userSeverityRating = null;
          });
        }

        // Add dislike without severity (default to null)
        await _supabase.from('verification').insert({
          'user_id': currentUser.id,
          'complaint_id': widget.complaint['complaint_id'],
          'verified_true': false,
          'verified_false': true,
          'severity': null,
        });

        setState(() {
          _isDisliked = true;
          _dislikeCount++;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating dislike: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _rateSeverity() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    // Only show severity dialog if user has liked (not disliked)
    if (!_isLiked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please like the complaint first to rate severity'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => SeverityRatingDialog(
          isLike: _isLiked,
          onRatingSubmitted: (severity) => _updateSeverity(severity),
        ),
      );
    }
  }

  Future<void> _showOverallSeverityDialog() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: AppTheme.largeRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _averageSeverity != null 
                            ? _getSeverityColor(_averageSeverity!.round()).withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.analytics_outlined,
                        color: _averageSeverity != null 
                            ? _getSeverityColor(_averageSeverity!.round())
                            : Colors.grey,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Overall Severity',
                            style: AppTheme.headingSmall.copyWith(
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            _averageSeverity != null 
                                ? '${_averageSeverity!.toStringAsFixed(1)}/5 (${_severityVoteCount} votes)'
                                : 'No severity ratings yet',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // User's rating status
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: AppTheme.mediumRadius,
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Your Rating',
                        style: AppTheme.labelLarge.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_userSeverityRating != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.star,
                              color: _getSeverityColor(_userSeverityRating!),
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$_userSeverityRating/5',
                              style: TextStyle(
                                color: _getSeverityColor(_userSeverityRating!),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _rateSeverity();
                          },
                          child: Text('Update Rating'),
                        ),
                      ] else ...[
                        Text(
                          (_isLiked || _isDisliked) 
                              ? 'You haven\'t rated severity yet'
                              : 'Like or dislike first to rate severity',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_isLiked || _isDisliked) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _rateSeverity();
                            },
                            child: Text('Rate Severity'),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Close button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Future<void> _updateSeverity(int severity) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Update the existing verification record with severity
      await _supabase
          .from('verification')
          .update({'severity': severity})
          .eq('user_id', currentUser.id)
          .eq('complaint_id', widget.complaint['complaint_id']);

      setState(() {
        _userSeverityRating = severity;
      });

      // Reload verification status to update average severity
      await _loadVerificationStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Severity rating updated: $severity/5'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating severity: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule;
      case 'in_progress':
        return Icons.work_outline;
      case 'resolved':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  String _getCategoryIcon(String? category) {
    if (category == null) return '🏙️';
    switch (category.toLowerCase()) {
      case 'road':
        return '🛣️';
      case 'water':
        return '💧';
      case 'electricity':
        return '⚡';
      case 'waste':
        return '🗑️';
      case 'traffic':
        return '🚦';
      default:
        return '🏙️';
    }
  }

  Color _getSeverityColor(int severity) {
    switch (severity) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.lightGreen;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.deepOrange;
      case 5:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.complaint['complaint_status'] ?? 'pending';
    final category = widget.complaint['category'];
    final description = widget.complaint['description'] ?? '';
    final createdAt = DateTime.parse(widget.complaint['created_at']);
    final timeAgo = _getTimeAgo(createdAt);
    final userName = widget.complaint['user_name'] ?? 'Anonymous';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM, vertical: AppTheme.spacingS),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.largeRadius,
        boxShadow: const [AppTheme.cardShadow],
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: AppTheme.smallRadius,
                  ),
                  child: Text(
                    _getCategoryIcon(category),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category ?? 'General Issue',
                        style: AppTheme.labelLarge,
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              userName,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• $timeAgo',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(status).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(status),
                        size: 14,
                        color: _getStatusColor(status),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Description
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),

          // Media (Image/Video)
          if (widget.complaint['picture_url'] != null)
            Container(
              margin: const EdgeInsets.all(16),
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.complaint['picture_url'],
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Failed to load image',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Video Player
          if (widget.complaint['video_url'] != null)
            Container(
              margin: const EdgeInsets.all(16),
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: VideoPlayerWidget(
                  videoUrl: widget.complaint['video_url'],
                ),
              ),
            ),

          // Location info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _isLoadingAddress
                          ? Row(
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Loading location...',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              _address,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ],
                ),
                if (_distance != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.near_me_outlined,
                        size: 14,
                        color: Colors.blue[600],
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _distance!,
                          style: TextStyle(
                            color: Colors.blue[600],
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Like/Dislike buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Like button
                InkWell(
                  onTap: _isLoading ? null : _toggleLike,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isLiked ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isLiked ? Colors.green : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                          size: 16,
                          color: _isLiked ? Colors.green : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _likeCount.toString(),
                          style: TextStyle(
                            color: _isLiked ? Colors.green : Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Severity rating button (only show if user has liked, not disliked)
                if (_isLiked && !_isLoading)
                  InkWell(
                    onTap: _rateSeverity,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _userSeverityRating != null 
                            ? _getSeverityColor(_userSeverityRating!).withOpacity(0.1)
                            : AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _userSeverityRating != null 
                              ? _getSeverityColor(_userSeverityRating!)
                              : AppTheme.primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _userSeverityRating != null ? Icons.star : Icons.star_outline,
                            size: 16,
                            color: _userSeverityRating != null 
                                ? _getSeverityColor(_userSeverityRating!)
                                : AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _userSeverityRating != null 
                                ? '$_userSeverityRating/5'
                                : 'Rate',
                            style: TextStyle(
                              color: _userSeverityRating != null 
                                  ? _getSeverityColor(_userSeverityRating!)
                                  : AppTheme.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                if (_isLiked && !_isLoading) const SizedBox(width: 12),
                
                // Dislike button
                InkWell(
                  onTap: _isLoading ? null : _toggleDislike,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isDisliked ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isDisliked ? Colors.red : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                          size: 16,
                          color: _isDisliked ? Colors.red : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _dislikeCount.toString(),
                          style: TextStyle(
                            color: _isDisliked ? Colors.red : Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                
                const Spacer(),
                
                // Loading indicator
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

// Video Player Widget for Feed Screen
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({super.key, required this.videoUrl});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller!.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.grey,
              ),
              SizedBox(height: 8),
              Text(
                'Failed to load video',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: () {
              setState(() {
                if (_controller!.value.isPlaying) {
                  _controller!.pause();
                } else {
                  _controller!.play();
                }
              });
            },
            icon: Icon(
              _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ],
    );
  }
}
