import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isSignupMode = false;
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isSignupMode) {
        await _handleSignup();
      } else {
        await _handleLogin();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogin() async {
    // Always send OTP for login instead of trying password first
    final result = await AuthService.sendOTPToEmail(_emailController.text);
    _navigateToOTP('email', _emailController.text, result);
  }

  Future<void> _handleSignup() async {
    final result = await AuthService.sendOTPToEmail(
      _emailController.text, 
      displayName: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null
    );
    _navigateToOTP('email', _emailController.text, result);
  }

  void _navigateToOTP(String type, String identifier, Map<String, dynamic> result) {
    // For email OTP, use default 5 minutes
    final timeLeft = 5; // Default OTP expiry time
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('OTP sent to your email! Valid for $timeLeft minutes.'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
    
    Navigator.pushNamed(
      context,
      '/otp',
      arguments: {
        'type': type,
        'identifier': identifier,
        'otp_id': result['otp_id'] ?? 'supabase_native',
        'expires_at': DateTime.now().add(const Duration(minutes: 5)),
        'is_signup': _isSignupMode,
        'name': _nameController.text,
      },
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  // Logo and Title
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_city,
                      size: 60,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to FixmyCity',
                    style: AppTheme.headingLarge.copyWith(
                      color: AppTheme.getTextPrimary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignupMode ? 'Create your account' : 'Sign in to continue',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.getTextSecondary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Login/Signup Toggle
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _isSignupMode = false;
                              });
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: !_isSignupMode ? AppTheme.primaryColor : Colors.transparent,
                              foregroundColor: !_isSignupMode ? Colors.white : AppTheme.getTextSecondary(context),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _isSignupMode = true;
                              });
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: _isSignupMode ? AppTheme.primaryColor : Colors.transparent,
                              foregroundColor: _isSignupMode ? Colors.white : AppTheme.getTextSecondary(context),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Sign Up', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Email Authentication Header
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.05),
                      borderRadius: AppTheme.mediumRadius,
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: AppTheme.smallRadius,
                          ),
                          child: const Icon(
                            Icons.email_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Email Authentication',
                                style: AppTheme.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.getTextPrimary(context),
                                ),
                              ),
                              Text(
                                'Secure login with email verification',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Name Field (for signup)
                  if (_isSignupMode) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.getSurfaceColor(context),
                        borderRadius: AppTheme.largeRadius,
                        boxShadow: const [AppTheme.cardShadow],
                        border: Border.all(color: AppTheme.getBorderLight(context)),
                      ),
                      child: TextFormField(
                        controller: _nameController,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          labelStyle: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.getTextSecondary(context),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: AppTheme.largeRadius,
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: AppTheme.largeRadius,
                            borderSide: BorderSide(color: AppTheme.getBorderLight(context)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppTheme.largeRadius,
                            borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: AppTheme.getBackgroundColor(context),
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(12),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: AppTheme.smallRadius,
                            ),
                            child: const Icon(Icons.person_outline, color: AppTheme.primaryColor, size: 20),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        ),
                        validator: (value) {
                          if (_isSignupMode && (value == null || value.isEmpty)) {
                            return 'Please enter your full name';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Email Field
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.getSurfaceColor(context),
                      borderRadius: AppTheme.largeRadius,
                      boxShadow: const [AppTheme.cardShadow],
                      border: Border.all(color: AppTheme.getBorderLight(context)),
                    ),
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        labelStyle: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.getTextSecondary(context),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: AppTheme.largeRadius,
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppTheme.largeRadius,
                          borderSide: BorderSide(color: AppTheme.getBorderLight(context)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AppTheme.largeRadius,
                          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                        ),
                        filled: true,
                        fillColor: AppTheme.getBackgroundColor(context),
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: AppTheme.smallRadius,
                          ),
                          child: const Icon(Icons.email_outlined, color: AppTheme.primaryColor, size: 20),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.getSurfaceColor(context),
                      borderRadius: AppTheme.largeRadius,
                      boxShadow: const [AppTheme.cardShadow],
                      border: Border.all(color: AppTheme.getBorderLight(context)),
                    ),
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.getTextSecondary(context),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: AppTheme.largeRadius,
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppTheme.largeRadius,
                          borderSide: BorderSide(color: AppTheme.getBorderLight(context)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AppTheme.largeRadius,
                          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                        ),
                        filled: true,
                        fillColor: AppTheme.getBackgroundColor(context),
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: AppTheme.smallRadius,
                          ),
                          child: const Icon(Icons.lock_outline, color: AppTheme.primaryColor, size: 20),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppTheme.getTextSecondary(context),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Auth Button
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
                      onPressed: _isLoading ? null : _handleAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.largeRadius,
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _isSignupMode ? 'Create Account' : 'Sign In',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Additional Info
                  if (_isSignupMode)
                    Text(
                      'By creating an account, you agree to our Terms of Service and Privacy Policy.',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.getTextSecondary(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
