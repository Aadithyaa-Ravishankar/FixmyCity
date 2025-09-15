import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class OTPVerificationScreen extends StatefulWidget {
  const OTPVerificationScreen({super.key});

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  String _type = '';
  String _identifier = '';
  DateTime? _expiresAt;
  String _otpStatus = 'pending';
  int _timeLeft = 0;
  StreamSubscription<Map<String, dynamic>>? _otpStatusSubscription;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // Get arguments passed from login screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          _type = args['type'] ?? '';
          _identifier = args['identifier'] ?? '';
          _expiresAt = args['expires_at'] as DateTime?;
        });
        
        // Start listening to real-time OTP status updates
        _startOTPStatusListener();
        
        
        // Start countdown timer
        _startCountdownTimer();
      }
    });
  }

  void _startOTPStatusListener() {
    _otpStatusSubscription = AuthService.getOTPStatusStream(_identifier).listen(
      (statusData) {
        if (mounted) {
          setState(() {
            _otpStatus = statusData['status'] ?? 'pending';
          });
        }
      },
      onError: (error) {
        print('OTP status stream error: $error');
      },
    );
  }


  void _startCountdownTimer() {
    _countdownTimer?.cancel(); // Cancel any existing timer
    if (_expiresAt != null) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          final now = DateTime.now();
          final difference = _expiresAt!.difference(now);
          
          if (difference.isNegative) {
            setState(() {
              _timeLeft = 0;
              _otpStatus = 'expired';
            });
            timer.cancel();
          } else {
            setState(() {
              _timeLeft = difference.inSeconds;
            });
          }
        } else {
          timer.cancel();
        }
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _otpStatusSubscription?.cancel();
    try {
      _otpController.dispose();
    } catch (e) {
      // Controller already disposed
    }
    super.dispose();
  }

  Future<void> _verifyOTP() async {
    if (!mounted) return;
    
    if (_otpController.text.length != 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid 6-digit code'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await AuthService.verifyEmailOTP(_identifier, _otpController.text);

      if (response['success'] == true) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        throw Exception('Verification failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendOTP() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AuthService.sendOTPToEmail(_identifier);
      
      // Update expiry time and restart countdown
      if (mounted) {
        setState(() {
          _expiresAt = result['expires_at'] as DateTime;
          _otpStatus = 'pending';
        });
        
        _startCountdownTimer();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New verification code sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor() {
    switch (_otpStatus) {
      case 'pending':
        return AppTheme.primaryColor;
      case 'verified':
        return Colors.green;
      case 'expired':
        return Colors.red;
      case 'failed':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (_otpStatus) {
      case 'pending':
        return Icons.access_time;
      case 'verified':
        return Icons.check_circle;
      case 'expired':
        return Icons.error;
      case 'failed':
        return Icons.warning;
      default:
        return Icons.help;
    }
  }

  String _getStatusText() {
    switch (_otpStatus) {
      case 'pending':
        return 'Code sent - waiting for verification';
      case 'verified':
        return 'Code verified successfully';
      case 'expired':
        return 'Code expired - please request a new one';
      case 'failed':
        return 'Verification failed - please try again';
      default:
        return 'Unknown status';
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Verify Code',
          style: AppTheme.headingSmall.copyWith(
            color: AppTheme.getTextPrimary(context),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: AppTheme.getTextPrimary(context),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Verification Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  size: 80,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Enter Verification Code',
                style: AppTheme.headingLarge.copyWith(
                  color: AppTheme.getTextPrimary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // Subtitle
              Text(
                'We sent a 6-digit code to\n$_identifier',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // OTP Status and Timer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.1),
                  borderRadius: AppTheme.mediumRadius,
                  border: Border.all(color: _getStatusColor().withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getStatusIcon(),
                      color: _getStatusColor(),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _getStatusText(),
                        style: TextStyle(
                          color: _getStatusColor(),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_timeLeft > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${_formatTime(_timeLeft)})',
                        style: TextStyle(
                          color: _getStatusColor(),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 32),

              // OTP Input Field
              PinCodeTextField(
                appContext: context,
                length: 6,
                controller: _otpController,
                keyboardType: TextInputType.number,
                animationType: AnimationType.fade,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: AppTheme.mediumRadius,
                  fieldHeight: 60,
                  fieldWidth: 50,
                  activeFillColor: AppTheme.getSurfaceColor(context),
                  inactiveFillColor: AppTheme.getBackgroundColor(context),
                  selectedFillColor: AppTheme.primaryColor.withOpacity(0.1),
                  activeColor: AppTheme.primaryColor,
                  inactiveColor: AppTheme.getBorderLight(context),
                  selectedColor: AppTheme.primaryColor,
                ),
                enableActiveFill: true,
                onCompleted: (value) {
                  _verifyOTP();
                },
                onChanged: (value) {
                  // Handle OTP input changes if needed
                },
              ),
              const SizedBox(height: 32),

              // Verify Button
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
                  onPressed: _isLoading ? null : _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
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
                          'Verify Code',
                          style: AppTheme.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Resend Code
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code? ",
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.getTextSecondary(context),
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _resendOTP,
                    child: Text(
                      'Resend',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
