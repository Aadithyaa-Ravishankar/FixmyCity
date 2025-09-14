import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'feed_screen.dart';
import 'complaints_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const FeedScreen(),
    const ComplaintsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: Stack(
        children: [
          _screens[_currentIndex],
          // Floating bottom navigation bar
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Container(
              height: 70,
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
                border: Border.all(
                  color: AppTheme.getBorderLight(context),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(0, Icons.home_outlined, Icons.home, 'Feed'),
                  _buildNavItem(1, Icons.add_circle_outline, Icons.add_circle, 'Report'),
                  _buildNavItem(2, Icons.person_outline, Icons.person, 'Profile'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Container(
        width: MediaQuery.of(context).size.width / 3 - 16,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: AppTheme.largeRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected 
                  ? AppTheme.primaryColor 
                  : AppTheme.getTextTertiary(context),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: isSelected 
                    ? AppTheme.primaryColor 
                    : AppTheme.getTextTertiary(context),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



