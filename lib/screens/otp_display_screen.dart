import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class OTPDisplayScreen extends StatelessWidget {
  final String identifier;
  final String otp;

  const OTPDisplayScreen({
    super.key,
    required this.identifier,
    required this.otp,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'OTP Code',
          style: AppTheme.headingSmall.copyWith(
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.message,
                  size: 80,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              
              Text(
                'Your OTP Code',
                style: AppTheme.headingLarge.copyWith(
                  color: AppTheme.getTextPrimary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              Text(
                'Sent to: $identifier',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // OTP Display
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: AppTheme.mediumRadius,
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Enter this code in the app:',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      otp,
                      style: AppTheme.headingLarge.copyWith(
                        fontSize: 36,
                        color: AppTheme.primaryColor,
                        letterSpacing: 8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: AppTheme.mediumRadius,
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This is a demo OTP. In production, this would be sent via SMS or email.',
                      style: AppTheme.bodySmall.copyWith(
                        color: Colors.orange,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Container(
                decoration: BoxDecoration(
                  borderRadius: AppTheme.largeRadius,
                  gradient: AppTheme.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      spreadRadius: 0,
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.largeRadius,
                    ),
                  ),
                  child: Text(
                    'Got it!',
                    style: AppTheme.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



