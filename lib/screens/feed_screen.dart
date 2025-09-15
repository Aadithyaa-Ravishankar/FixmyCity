import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
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

class _FeedScreenState extends State<FeedScreen> with TickerProviderStateMixin {
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

  // Scroll and animation variables
  final ScrollController _scrollController = ScrollController();
  AnimationController? _filterAnimationController;
  Animation<double>? _filterAnimation;
  bool _isFilterVisible = true;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _fetchComplaints();
    _setupScrollAnimation();
  }

  void _setupScrollAnimation() {
    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _filterAnimation = Tween<double>(
      begin: 0.0,
      end: -80.0,
    ).animate(CurvedAnimation(
      parent: _filterAnimationController!,
      curve: Curves.easeOut,
    ));

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final currentOffset = _scrollController.offset;
    final scrollDelta = currentOffset - _lastScrollOffset;

    // Debug print to see scroll behavior
    print('Scroll delta: $scrollDelta, Filter visible: $_isFilterVisible');

    if (scrollDelta > 5 && _isFilterVisible && currentOffset > 50) {
      // Scrolling down - hide filter
      print('Hiding filter');
      setState(() {
        _isFilterVisible = false;
      });
      _filterAnimationController?.forward();
    } else if (scrollDelta < -5 && !_isFilterVisible) {
      // Scrolling up - show filter
      print('Showing filter');
      setState(() {
        _isFilterVisible = true;
      });
      _filterAnimationController?.reverse();
    }

    _lastScrollOffset = currentOffset;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _filterAnimationController?.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    try {
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        print('Location initialized successfully');
      } else {
        print('Location permission denied or unavailable');
      }
    } catch (e) {
      print('Location initialization failed: $e');
    }
  }

  Future<void> _fetchComplaints() async {
    try {
      final response = await _supabase
          .from('complaints')
          .select('*')
          .order('created_at', ascending: false);
      
      // Get unique user IDs from complaints
      Set<String> userIds = response.map((complaint) => complaint['user_id'] as String).toSet();
      
      // Fetch user display names from auth.users table
      Map<String, String> userDisplayNames = {};
      
      if (userIds.isNotEmpty) {
        try {
          final profilesResponse = await _supabase
              .from('user_profiles')
              .select('id, display_name')
              .inFilter('id', userIds.toList());
          
          for (var profile in profilesResponse) {
            userDisplayNames[profile['id']] = profile['display_name'] ?? 'User';
          }
          
          // For users without profiles, use fallback
          for (String userId in userIds) {
            if (!userDisplayNames.containsKey(userId)) {
              userDisplayNames[userId] = 'User';
            }
          }
        } catch (e) {
          print('Failed to fetch user display names: $e');
          // Continue without display names - use fallback
          for (String userId in userIds) {
            userDisplayNames[userId] = 'User';
          }
        }
      }

      // For each complaint, assign the user display name
      List<Map<String, dynamic>> complaintsWithUsers = [];
      for (var complaint in response) {
        String userId = complaint['user_id'];
        String userName = userDisplayNames[userId] ?? 'User';
        
        complaintsWithUsers.add({
          ...complaint,
          'user_name': userName,
        });
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
      // Show message that location is required for filtering
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission required for distance filtering'),
          backgroundColor: Colors.orange,
        ),
      );
      setState(() {
        _filteredComplaints = _complaints; // Show all if no location
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
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: Stack(
        children: [
          // Main content with padding for floating app bar
          Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 86),
            child: _buildMainContent(),
          ),
          // Floating pill-shaped app bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: AppTheme.largeRadius,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'FixmyCity',
                      style: AppTheme.headingMedium.copyWith(
                        color: AppTheme.getTextPrimary(context),
                        fontSize: 20,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.getSurfaceColor(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.getBorderLight(context)),
                        boxShadow: const [AppTheme.cardShadow],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_list,
                            color: AppTheme.getTextSecondary(context),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<double>(
                              value: _selectedDistance,
                              onChanged: _onDistanceChanged,
                              dropdownColor: AppTheme.getSurfaceColor(context),
                              style: TextStyle(
                                color: AppTheme.getTextPrimary(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              icon: Icon(
                                Icons.keyboard_arrow_down,
                                color: AppTheme.getTextSecondary(context),
                                size: 12,
                              ),
                              items: _distanceOptions.map((option) {
                                return DropdownMenuItem<double>(
                                  value: option['value'],
                                  child: Text(
                                    option['label'],
                                    style: AppTheme.bodySmall.copyWith(
                                      color: AppTheme.getTextPrimary(context),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return _isLoading
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : RefreshIndicator(
            onRefresh: _refreshComplaints,
            child: _filteredComplaints.isEmpty
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 86),
                    children: [
                      // Empty state
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
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
                      ),
                    ],
                  )
                : ListView.builder(
                    itemCount: _filteredComplaints.length,
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 86),
                    itemBuilder: (context, index) {
                      final complaint = _filteredComplaints[index];
                      return ComplaintPostCard(
                        complaint: complaint,
                      );
                    },
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
  bool _isLoading = false;
  int _likeCount = 0;
  int _dislikeCount = 0;
  double? _averageSeverity;
  int? _userSeverityRating;
  final PageController _mediaPageController = PageController();
  int _currentMediaIndex = 0;
  String _address = 'Loading location...';
  bool _isLoadingAddress = true;
  String? _distance;
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
      final userLocation = LocationService.getCachedPosition();
      if (userLocation != null) {
        final distance = LocationService.getDistanceFromCurrent(lat, lon);
        if (mounted) {
          setState(() {
            _distance = distance;
          });
        }
      } else {
        // No user location available
        if (mounted) {
          setState(() {
            _distance = null;
          });
        }
      }
    } else {
      // Set distance to null if no coordinates available
      if (mounted) {
        setState(() {
          _distance = null;
        });
      }
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
              color: AppTheme.getSurfaceColor(context),
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
                              color: AppTheme.getTextPrimary(context),
                            ),
                          ),
                          Text(
                            _averageSeverity != null 
                                ? '${_averageSeverity!.toStringAsFixed(1)}/5 (${_severityVoteCount} votes)'
                                : 'No severity ratings yet',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.getTextSecondary(context),
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
                    color: AppTheme.getBackgroundColor(context),
                    borderRadius: AppTheme.mediumRadius,
                    border: Border.all(color: AppTheme.getBorderLight(context)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Your Rating',
                        style: AppTheme.labelLarge.copyWith(
                          color: AppTheme.getTextPrimary(context),
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
                        const SizedBox(height: 12),
                        // Rating buttons for updating existing rating
                        Wrap(
                          alignment: WrapAlignment.spaceEvenly,
                          spacing: 4,
                          children: List.generate(5, (index) {
                            int rating = index + 1;
                            bool isSelected = _userSeverityRating == rating;
                            return InkWell(
                              onTap: () => _updateSeverity(rating),
                              borderRadius: BorderRadius.circular(25),
                              child: Container(
                                width: 35,
                                height: 35,
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? _getSeverityColor(rating).withOpacity(0.2)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                    color: isSelected 
                                        ? _getSeverityColor(rating)
                                        : Colors.grey.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    rating.toString(),
                                    style: TextStyle(
                                      color: isSelected 
                                          ? _getSeverityColor(rating)
                                          : Colors.grey,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to update your rating',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.getTextSecondary(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ] else ...[
                        // Rating buttons (1-5) for users who haven't rated yet
                        if (_isLiked) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(5, (index) {
                              int rating = index + 1;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: InkWell(
                                    onTap: () => _updateSeverity(rating),
                                    borderRadius: BorderRadius.circular(18),
                                    child: Container(
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: Colors.grey.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          rating.toString(),
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tap a number to rate severity',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.getTextSecondary(context),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ] else ...[
                          Text(
                            'Like the complaint first to rate severity',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.getTextSecondary(context),
                            ),
                            textAlign: TextAlign.center,
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

    try {
      await _supabase
          .from('verification')
          .update({'severity': severity})
          .eq('user_id', currentUser.id)
          .eq('complaint_id', widget.complaint['complaint_id']);

      setState(() {
        _userSeverityRating = severity;
      });

      // Reload verification status to update average
      await _loadVerificationStatus();
      
      // Close the dialog if it's open
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error updating severity: $e');
    }
  }

  Future<void> _openInGoogleMaps() async {
    final latitude = widget.complaint['location_lat'];
    final longitude = widget.complaint['location_long'];
    
    if (latitude != null && longitude != null) {
      final url = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
      final uri = Uri.parse(url);
      
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        print('Error opening Google Maps: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open Google Maps'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location coordinates not available'),
            backgroundColor: Colors.orange,
          ),
        );
      }
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

  Widget _buildMediaSlider() {
    List<Widget> mediaItems = [];
    
    // Add image if available
    if (widget.complaint['picture_url'] != null) {
      mediaItems.add(ComplaintImageViewer(imageUrl: widget.complaint['picture_url']));
    }
    
    // Add video if available
    if (widget.complaint['video_url'] != null) {
      mediaItems.add(ComplaintVideoPlayer(videoUrl: widget.complaint['video_url']));
    }
    
    // If only one media item, don't use slider
    if (mediaItems.length == 1) {
      return Container(
        margin: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: mediaItems.first,
          ),
        ),
      );
    }
    
    // Use PageView for multiple media items
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: PageView.builder(
                    controller: _mediaPageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentMediaIndex = index;
                      });
                    },
                    itemCount: mediaItems.length,
                    itemBuilder: (context, index) {
                      return mediaItems[index];
                    },
                  ),
                ),
              ),
              // Media count indicator
              if (mediaItems.length > 1)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_currentMediaIndex + 1}/${mediaItems.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Page indicators below media
          if (mediaItems.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: mediaItems.asMap().entries.map((entry) {
                  return Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentMediaIndex == entry.key
                          ? AppTheme.primaryColor
                          : Colors.grey.withOpacity(0.4),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
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
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceColor(context),
        borderRadius: AppTheme.largeRadius,
        boxShadow: const [AppTheme.cardShadow],
        border: Border.all(color: AppTheme.getBorderLight(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 14,
                            color: AppTheme.getTextSecondary(context),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              userName,
                              style: TextStyle(
                                color: AppTheme.getTextPrimary(context),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          color: AppTheme.getTextSecondary(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _getStatusColor(status).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(status),
                        size: 12,
                        color: _getStatusColor(status),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Category
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              category ?? 'General Issue',
              style: AppTheme.labelLarge.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.getTextPrimary(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),

          // Description
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
            ),

          // Media (Image/Video)
          if (widget.complaint['picture_url'] != null || widget.complaint['video_url'] != null)
            _buildMediaSlider(),


          // Location info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                InkWell(
                  onTap: _openInGoogleMaps,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
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
                  ),
                ),
                if (_distance != null) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: _openInGoogleMaps,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.near_me_outlined,
                            size: 14,
                            color: Colors.blue[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _distance!,
                            style: TextStyle(
                              color: Colors.blue[600],
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Like/Dislike buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
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
                
                // Overall Severity display (clickable to rate/update)
                InkWell(
                  onTap: _showOverallSeverityDialog,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _averageSeverity != null 
                          ? _getSeverityColor(_averageSeverity!.round()).withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _averageSeverity != null 
                            ? _getSeverityColor(_averageSeverity!.round())
                            : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.analytics_outlined,
                          size: 16,
                          color: _averageSeverity != null 
                              ? _getSeverityColor(_averageSeverity!.round())
                              : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _averageSeverity != null 
                                ? '${_averageSeverity!.toStringAsFixed(1)}/5 (${_severityVoteCount})'
                                : 'No ratings',
                            style: TextStyle(
                              color: _averageSeverity != null 
                                  ? _getSeverityColor(_averageSeverity!.round())
                                  : Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
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

class ComplaintImageViewer extends StatelessWidget {
  final String imageUrl;

  const ComplaintImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[200],
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorWidget: (context, url, error) => Container(
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
        ),
      ),
    );
  }
}

class ComplaintVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const ComplaintVideoPlayer({super.key, required this.videoUrl});

  @override
  State<ComplaintVideoPlayer> createState() => _ComplaintVideoPlayerState();
}

class _ComplaintVideoPlayerState extends State<ComplaintVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
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
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
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
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.grey[200],
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: Stack(
        children: [
          VideoPlayer(_controller!),
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (_controller!.value.isPlaying) {
                    _controller!.pause();
                  } else {
                    _controller!.play();
                  }
                });
              },
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _controller!.value.isPlaying ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Icon(
                        _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Video progress indicator
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              _controller!,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: AppTheme.primaryColor,
                bufferedColor: Colors.grey.withOpacity(0.3),
                backgroundColor: Colors.grey.withOpacity(0.1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
