import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseOTPService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  
  // Generate a 6-digit OTP
  static String _generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Send email OTP using Supabase Edge Function
  static Future<void> _sendEmailOTP(String email, String otp) async {
    try {
      await _supabase.functions.invoke(
        'send-email',
        body: {
          'email': email,
          'subject': 'Your FixmyCity OTP Code',
          'message': 'Your OTP code is: $otp. This code will expire in 5 minutes. Please enter this code in the app to verify your email address.',
          'otp': otp,
        },
      );
    } catch (e) {
      print('Failed to send email OTP: $e');
      // Don't throw error - let the OTP be stored even if email fails
    }
  }


  // Send email OTP using Supabase native auth with updated template
  static Future<Map<String, dynamic>> sendOTPToEmail(String email, {String? displayName}) async {
    try {
      // Use signInWithOtp with specific configuration to force OTP tokens
      await _supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
        data: {
          'type': 'email_otp', // Explicitly specify OTP type
          'display_name': displayName, // Store display name for new users
        },
      );
      
      return {
        'success': true,
        'message': 'OTP code sent to your email',
        'verification_type': 'supabase_native_otp',
      };
    } catch (e) {
      print('Error sending Supabase native OTP: $e');
      
      // Fallback to custom OTP if Supabase native fails
      try {
        return await _sendCustomOTPToEmail(email);
      } catch (fallbackError) {
        print('Custom OTP fallback also failed: $fallbackError');
        throw Exception('Failed to send email OTP: $e');
      }
    }
  }

  // Send custom OTP to email
  static Future<Map<String, dynamic>> _sendCustomOTPToEmail(String email) async {
    final otp = _generateOTP();
    final expiry = DateTime.now().add(const Duration(minutes: 5));
    
    // Store OTP in Supabase database
    final response = await _supabase
        .from('otp_verifications')
        .insert({
          'identifier': email,
          'otp_code': otp,
          'type': 'email',
          'expires_at': expiry.toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'status': 'pending',
        })
        .select()
        .single();

    // Send real email with OTP using Supabase Edge Function
    await _sendEmailOTP(email, otp);
    
    return {
      'success': true,
      'otp_id': response['id'],
      'message': 'Verification code sent to email successfully',
      'expires_at': expiry,
      'verification_type': 'custom_otp',
    };
  }


  // Verify OTP using Supabase native auth to match native OTP sending
  static Future<Map<String, dynamic>> verifyOTP(String identifier, String otp) async {
    try {
      // Use Supabase native OTP verification to match the native OTP sending
      final response = await _supabase.auth.verifyOTP(
        email: identifier,
        token: otp,
        type: OtpType.email,
      );

      if (response.user != null) {
        // Update user metadata with display name if provided during signup
        if (response.user!.userMetadata?['display_name'] != null) {
          try {
            await _supabase.auth.updateUser(
              UserAttributes(
                data: {
                  'display_name': response.user!.userMetadata!['display_name'],
                }
              )
            );
          } catch (e) {
            print('Failed to update user display name: $e');
          }
        }
        
        return {
          'success': true,
          'message': 'Email verified successfully',
          'user': response.user,
          'session': response.session,
        };
      } else {
        throw Exception('Invalid OTP or verification failed');
      }
    } catch (e) {
      print('Error verifying OTP: $e');
      throw Exception('Failed to verify OTP: $e');
    }
  }

  // Create user session manually without triggering Supabase email confirmation
  static Future<Map<String, dynamic>> _createUserSessionManually(String identifier) async {
    try {
      final isEmail = identifier.contains('@');
      
      // Store user data in a custom users table instead of using Supabase Auth
      final userData = {
        'id': 'user_${DateTime.now().millisecondsSinceEpoch}',
        'email': isEmail ? identifier : null,
        'phone': isEmail ? null : identifier,
        'created_at': DateTime.now().toIso8601String(),
        'email_verified': isEmail,
        'phone_verified': !isEmail,
        'is_active': true,
      };
      
      // Store in custom users table (you may need to create this table)
      try {
        await _supabase
            .from('users')
            .upsert(userData, onConflict: isEmail ? 'email' : 'phone');
      } catch (e) {
        print('Failed to store user data: $e');
      }
      
      return userData;
      
    } catch (e) {
      // Return basic user object if storage fails
      final isEmail = identifier.contains('@');
      return {
        'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
        'email': isEmail ? identifier : null,
        'phone': isEmail ? null : identifier,
        'created_at': DateTime.now().toIso8601String(),
        'email_verified': isEmail,
        'phone_verified': !isEmail,
        'is_active': true,
      };
    }
  }

  // Create or get user in Supabase Auth with proper email verification
  static Future<Map<String, dynamic>> _createOrGetUser(String identifier) async {
    try {
      final isEmail = identifier.contains('@');
      
      if (isEmail) {
        // For email, try to get existing user first
        try {
          final currentUser = _supabase.auth.currentUser;
          if (currentUser != null && currentUser.email == identifier) {
            return {
              'id': currentUser.id,
              'email': currentUser.email,
              'phone': currentUser.phone,
              'created_at': currentUser.createdAt,
              'email_confirmed': currentUser.emailConfirmedAt != null,
            };
          }
        } catch (e) {
          print('Current user check failed: $e');
        }
        
        // Create new user without email redirect to avoid verification links
        final response = await _supabase.auth.signUp(
          email: identifier,
          password: _generateOTP() + DateTime.now().millisecondsSinceEpoch.toString(),
        );
        
        if (response.user != null) {
          return {
            'id': response.user!.id,
            'email': response.user!.email,
            'phone': response.user!.phone,
            'created_at': response.user!.createdAt,
            'email_confirmed': response.user!.emailConfirmedAt != null,
          };
        }
      }
      
      // If user creation failed, return a basic user object
      return {
        'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
        'email': isEmail ? identifier : null,
        'phone': isEmail ? null : identifier,
        'created_at': DateTime.now().toIso8601String(),
        'email_confirmed': false,
        'phone_confirmed': false,
      };
      
    } catch (e) {
      // If user creation fails, return a basic user object
      final isEmail = identifier.contains('@');
      return {
        'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
        'email': isEmail ? identifier : null,
        'phone': isEmail ? null : identifier,
        'created_at': DateTime.now().toIso8601String(),
        'email_confirmed': false,
        'phone_confirmed': false,
      };
    }
  }

  // Get real-time OTP status updates
  static Stream<Map<String, dynamic>> getOTPStatusStream(String identifier) {
    return _supabase
        .from('otp_verifications')
        .stream(primaryKey: ['id'])
        .eq('identifier', identifier)
        .order('created_at', ascending: false)
        .limit(1)
        .map((data) {
          if (data.isNotEmpty) {
            final otpData = data.first;
            return {
              'status': otpData['status'],
              'expires_at': otpData['expires_at'],
              'created_at': otpData['created_at'],
              'verified_at': otpData['verified_at'],
              // SMS status is tracked in the service, not database
            };
          }
          return {'status': 'none'};
        });
  }


  // Get current user
  static User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  // Check if user is authenticated
  static bool isAuthenticated() {
    return _supabase.auth.currentUser != null;
  }

  // Clean up expired OTPs (call this periodically)
  static Future<void> cleanupExpiredOTPs() async {
    try {
      await _supabase
          .from('otp_verifications')
          .update({'status': 'expired'})
          .lt('expires_at', DateTime.now().toIso8601String())
          .eq('status', 'pending');
    } catch (e) {
      print('Error cleaning up expired OTPs: $e');
    }
  }

  // Send Supabase native email OTP (6-digit code, not verification link)
  static Future<Map<String, dynamic>> sendSupabaseEmailVerification(String email) async {
    try {
      // Remove emailRedirectTo to get OTP instead of verification link
      await _supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );
      
      return {
        'success': true,
        'message': 'OTP sent to email via Supabase',
        'expires_at': DateTime.now().add(const Duration(minutes: 60)), // Supabase OTP expires in 1 hour
        'verification_type': 'supabase_otp',
      };
    } catch (e) {
      throw Exception('Failed to send Supabase email OTP: $e');
    }
  }

  // Verify Supabase email OTP
  static Future<Map<String, dynamic>> verifySupabaseEmailOTP(String email, String otp) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.email,
      );
      
      if (response.user != null) {
        return {
          'success': true,
          'user': {
            'id': response.user!.id,
            'email': response.user!.email,
            'phone': response.user!.phone,
            'created_at': response.user!.createdAt,
            'email_confirmed': response.user!.emailConfirmedAt != null,
          },
          'message': 'Email verified successfully with Supabase',
        };
      } else {
        throw Exception('Invalid OTP or verification failed');
      }
    } catch (e) {
      throw Exception('Supabase email verification failed: $e');
    }
  }

  // Authenticate with password
  static Future<Map<String, dynamic>> authenticateWithPassword(String identifier, String password, String type) async {
    try {
      // Check if user exists in Supabase Auth
      if (type == 'email') {
        final response = await _supabase.auth.signInWithPassword(
          email: identifier,
          password: password,
        );
        
        if (response.user != null) {
          return {
            'success': true,
            'user': {
              'id': response.user!.id,
              'email': response.user!.email,
              'phone': response.user!.phone,
              'created_at': response.user!.createdAt,
              'email_confirmed': response.user!.emailConfirmedAt != null,
            },
            'message': 'Login successful with password',
          };
        } else {
          return {
            'success': false,
            'message': 'Invalid email or password',
          };
        }
      }
      
      return {
        'success': false,
        'message': 'Invalid authentication type',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Authentication failed: ${e.toString()}',
      };
    }
  }
}
