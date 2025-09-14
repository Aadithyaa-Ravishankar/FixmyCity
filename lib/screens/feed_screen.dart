import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _complaints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _fetchComplaints();
  }

  Future<void> _initializeLocation() async {
    await LocationService.getCurrentLocation();
  }

  Future<void> _fetchComplaints() async {
    try {
      final response = await _supabase
          .from('complaints')
          .select('*')
          .order('created_at', ascending: false);

      print('Fetched ${response.length} complaints from database');
      for (var complaint in response) {
        print('Complaint ${complaint['complaint_id']}: lat=${complaint['location_lat']}, long=${complaint['location_long']}');
      }

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
          : RefreshIndicator(
              onRefresh: _refreshComplaints,
              child: _complaints.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.report_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No complaints yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Be the first to report an issue!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _complaints.length,
                      itemBuilder: (context, index) {
                        final complaint = _complaints[index];
                        return ComplaintPostCard(complaint: complaint);
                      },
                    ),
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

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
    _loadAddress();
    _calculateDistance();
  }

  void _calculateDistance() {
    final lat = widget.complaint['location_lat'] as double?;
    final lon = widget.complaint['location_long'] as double?;
    
    if (lat != null && lon != null) {
      final distance = LocationService.getDistanceFromCurrent(lat, lon);
      setState(() {
        _distance = distance;
      });
    }
  }

  Future<void> _loadAddress() async {
    try {
      final lat = widget.complaint['location_lat'] as double?;
      final lon = widget.complaint['location_long'] as double?;
      
      if (lat != null && lon != null) {
        final address = await GeocodingService.getAddressFromCoordinates(lat, lon);
        if (mounted) {
          setState(() {
            _address = address;
            _isLoadingAddress = false;
          });
        }
      } else {
        setState(() {
          _address = 'Location not available';
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      if (mounted) {
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

      // Count likes and dislikes
      int likes = 0;
      int dislikes = 0;
      bool userLiked = false;
      bool userDisliked = false;

      for (var verification in response) {
        if (verification['verified_true'] == true) {
          likes++;
          if (verification['user_id'] == currentUser.id) {
            userLiked = true;
          }
        }
        if (verification['verified_false'] == true) {
          dislikes++;
          if (verification['user_id'] == currentUser.id) {
            userDisliked = true;
          }
        }
      }

      setState(() {
        _likeCount = likes;
        _dislikeCount = dislikes;
        _isLiked = userLiked;
        _isDisliked = userDisliked;
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

        // Add like
        await _supabase.from('verification').insert({
          'user_id': currentUser.id,
          'complaint_id': widget.complaint['complaint_id'],
          'verified_true': true,
          'verified_false': false,
          'severity': 3, // Default severity
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
          });
        }

        // Add dislike
        await _supabase.from('verification').insert({
          'user_id': currentUser.id,
          'complaint_id': widget.complaint['complaint_id'],
          'verified_true': false,
          'verified_false': true,
          'severity': 1, // Low severity for dislike
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
                          Text(
                            userName,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• $timeAgo',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
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

          // Media (Image/Video) - Placeholder for now
          if (widget.complaint['picture_url'] != null || widget.complaint['video_url'] != null)
            Container(
              margin: const EdgeInsets.all(16),
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Media content',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
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
