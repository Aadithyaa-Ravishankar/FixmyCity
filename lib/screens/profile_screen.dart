import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  Map<String, dynamic>? _userStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    try {
      final user = AuthService.getCurrentUser();
      if (user != null) {
        // Get user's complaint statistics
        final complaints = await _supabase
            .from('complaints')
            .select('complaint_status')
            .eq('user_id', user.id);

        final totalComplaints = complaints.length;
        final pendingComplaints = complaints.where((c) => c['complaint_status'] == 'pending').length;
        final inProgressComplaints = complaints.where((c) => c['complaint_status'] == 'in_progress').length;
        final resolvedComplaints = complaints.where((c) => c['complaint_status'] == 'resolved').length;

        setState(() {
          _userStats = {
            'total': totalComplaints,
            'pending': pendingComplaints,
            'in_progress': inProgressComplaints,
            'resolved': resolvedComplaints,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.getCurrentUser();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: AppTheme.headingSmall.copyWith(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile Header
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingXL),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: AppTheme.extraLargeRadius,
                      boxShadow: const [AppTheme.elevatedShadow],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingL),
                        Text(
                          user?.userMetadata?['display_name'] ?? user?.email?.split('@')[0] ?? 'User',
                          style: AppTheme.headingMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        Text(
                          user?.email ?? 'No email',
                          style: AppTheme.bodyMedium.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Stats Cards
                  if (_userStats != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total',
                            _userStats!['total'].toString(),
                            Icons.report_outlined,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Pending',
                            _userStats!['pending'].toString(),
                            Icons.schedule,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'In Progress',
                            _userStats!['in_progress'].toString(),
                            Icons.work_outline,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Resolved',
                            _userStats!['resolved'].toString(),
                            Icons.check_circle_outline,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // User Information Card
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingL),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: AppTheme.largeRadius,
                      boxShadow: const [AppTheme.cardShadow],
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Information',
                          style: AppTheme.headingSmall,
                        ),
                        const SizedBox(height: 16),
                        if (user?.email != null)
                          _buildInfoRow(Icons.email_outlined, 'Email', user!.email!),
                        if (user?.phone != null) ...[
                          const SizedBox(height: 12),
                          _buildInfoRow(Icons.phone_outlined, 'Phone', user!.phone!),
                        ],
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.person_outline, 'User ID', user?.id ?? 'Unknown'),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.access_time_outlined,
                          'Member Since',
                          user?.createdAt != null
                              ? DateTime.parse(user!.createdAt!)
                                  .toString()
                                  .split(' ')[0]
                              : 'Unknown',
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.login_outlined,
                          'Last Sign In',
                          user?.lastSignInAt != null
                              ? DateTime.parse(user!.lastSignInAt!)
                                  .toString()
                                  .split('.')[0]
                              : 'Unknown',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingL),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: AppTheme.largeRadius,
                      boxShadow: const [AppTheme.cardShadow],
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Actions',
                          style: AppTheme.headingSmall,
                        ),
                        const SizedBox(height: 16),
                        _buildActionButton(
                          Icons.refresh,
                          'Refresh Stats',
                          Colors.blue,
                          () => _loadUserStats(),
                        ),
                        const SizedBox(height: 12),
                        _buildActionButton(
                          Icons.logout,
                          'Sign Out',
                          Colors.red,
                          _signOut,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.mediumRadius,
        boxShadow: const [AppTheme.cardShadow],
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: AppTheme.smallRadius,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            value,
            style: AppTheme.headingMedium.copyWith(color: color),
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            title,
            style: AppTheme.labelMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.labelMedium,
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                value,
                style: AppTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.mediumRadius,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: AppTheme.mediumRadius,
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 22,
            ),
            const SizedBox(width: AppTheme.spacingM),
            Text(
              label,
              style: AppTheme.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await AuthService.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
