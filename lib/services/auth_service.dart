import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_otp_service.dart';

class AuthService {
  // Send OTP to phone number using Supabase
  static Future<Map<String, dynamic>> sendOTPToPhone(String phoneNumber) async {
    try {
      final result = await SupabaseOTPService.sendOTPToPhone(phoneNumber);
      return result;
    } catch (e) {
      throw Exception('Failed to send OTP to phone: $e');
    }
  }

  // Send OTP to email using Supabase
  static Future<Map<String, dynamic>> sendOTPToEmail(String email) async {
    try {
      final result = await SupabaseOTPService.sendOTPToEmail(email);
      return result;
    } catch (e) {
      throw Exception('Failed to send OTP to email: $e');
    }
  }

  // Verify OTP for phone using Supabase
  static Future<Map<String, dynamic>> verifyPhoneOTP(String phoneNumber, String otp) async {
    try {
      final result = await SupabaseOTPService.verifyOTP(phoneNumber, otp);
      return result;
    } catch (e) {
      throw Exception('Failed to verify phone OTP: $e');
    }
  }

  // Verify OTP for email using Supabase
  static Future<Map<String, dynamic>> verifyEmailOTP(String email, String otp) async {
    try {
      final result = await SupabaseOTPService.verifyOTP(email, otp);
      return result;
    } catch (e) {
      throw Exception('Failed to verify email OTP: $e');
    }
  }

  // Get real-time OTP status stream
  static Stream<Map<String, dynamic>> getOTPStatusStream(String identifier) {
    return SupabaseOTPService.getOTPStatusStream(identifier);
  }

  // Get real-time SMS delivery status stream
  static Stream<String> getSMSDeliveryStatusStream(String identifier) {
    return SupabaseOTPService.getSMSDeliveryStatusStream(identifier);
  }

  // Clean up expired OTPs
  static Future<void> cleanupExpiredOTPs() async {
    await SupabaseOTPService.cleanupExpiredOTPs();
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await SupabaseOTPService.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  // Get current user
  static User? getCurrentUser() {
    return SupabaseOTPService.getCurrentUser();
  }

  // Check if user is authenticated
  static bool isAuthenticated() {
    return SupabaseOTPService.isAuthenticated();
  }

  // Authenticate with password
  static Future<Map<String, dynamic>> authenticateWithPassword(String identifier, String password, String type) async {
    try {
      final result = await SupabaseOTPService.authenticateWithPassword(identifier, password, type);
      return result;
    } catch (e) {
      throw Exception('Failed to authenticate with password: $e');
    }
  }

  // Send Supabase native email verification
  static Future<Map<String, dynamic>> sendSupabaseEmailVerification(String email) async {
    try {
      final result = await SupabaseOTPService.sendSupabaseEmailVerification(email);
      return result;
    } catch (e) {
      throw Exception('Failed to send Supabase email verification: $e');
    }
  }

  // Verify Supabase email OTP
  static Future<Map<String, dynamic>> verifySupabaseEmailOTP(String email, String otp) async {
    try {
      final result = await SupabaseOTPService.verifySupabaseEmailOTP(email, otp);
      return result;
    } catch (e) {
      throw Exception('Failed to verify Supabase email OTP: $e');
    }
  }
}
