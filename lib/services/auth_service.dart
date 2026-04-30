import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'user_service.dart';
import 'notification_service.dart';
import 'unified_wallet_service.dart';
import 'socket_service.dart';
import 'spot_socket_service.dart';
import 'temp_wallet_socket_service.dart';
import 'network_error_handler.dart';

class AuthService {
  static const String _baseUrl = 'https://api11.hathmetech.com/api';
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // HELPER: Get OS as Integer.
  // Based on your logs, '0' is invalid, so we use 1 for Android, 2 for iOS.
  static int getDeviceOSInt() {
    if (kIsWeb) return 3;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 1; // Android = 1
      case TargetPlatform.iOS:
        return 2; // iOS = 2
      default:
        return 4;
    }
  }

  static String getDeviceName() {
    if (kIsWeb) return 'Web Browser';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android Device';
      case TargetPlatform.iOS:
        return 'iOS Device';
      case TargetPlatform.windows:
        return 'Windows PC';
      case TargetPlatform.macOS:
        return 'Mac';
      case TargetPlatform.linux:
        return 'Linux PC';
      default:
        return 'Unknown Device';
    }
  }

  static Future<String> getDeviceUuid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? uuid = prefs.getString('deviceUuid');
      if (uuid == null) {
        if (!kIsWeb) {
          DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
          if (defaultTargetPlatform == TargetPlatform.android) {
            AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
            uuid = androidInfo.id;
          } else if (defaultTargetPlatform == TargetPlatform.iOS) {
            IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
            uuid = iosInfo.identifierForVendor;
          }
        }
        uuid ??=
            'device_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
        await prefs.setString('deviceUuid', uuid);
      }
      return uuid;
    } catch (e) {
      return 'fallback_uuid';
    }
  }

  static Map<String, String> _getHeaders() {
    return {'Content-Type': 'application/json', 'Accept': 'application/json'};
  }

  /// Maps raw KYC status strings (any case) to the canonical display value
  /// used throughout the app ('Completed', 'Pending', 'Rejected', 'Expired',
  /// 'Not Started').  Mirrors the logic in UserService._mapKycStatusFromAuthObject().
  static String _mapKycStatus(String rawStatus) {
    final s = rawStatus.toLowerCase().trim();
    if (s == 'completed' ||
        s == 'already_completed' ||
        s == 'verified' ||
        s == 'approved') {
      return 'Completed';
    }
    if (s == 'pending' || s == 'submitted' || s == 'processing')
      return 'Pending';
    if (s == 'rejected' || s == 'failed' || s == 'denied') return 'Rejected';
    if (s == 'expired') return 'Expired';
    return 'Not Started';
  }

  /// Extracts the KYC status from the auth response user object and saves it
  /// to SharedPreferences immediately so screens see the correct value without
  /// waiting for the separate KYC status API call.
  static Future<void> _saveKycStatusFromUserObject(
    Map<String, dynamic>? userObj,
    SharedPreferences prefs,
  ) async {
    if (userObj == null) return;

    String determinedStatus = 'Not Started';

    // Try nested kyc object with multiple fields: user.kyc
    final kycObj = userObj['kyc'];
    if (kycObj is Map) {
      determinedStatus = _parseKYCFromMultiFieldObject(
        Map<String, dynamic>.from(kycObj),
      );
    } else {
      // Fallback: top-level flat fields
      String? rawStatus =
          userObj['kycStatus']?.toString() ?? userObj['kyc_status']?.toString();

      if (rawStatus != null && rawStatus.isNotEmpty) {
        determinedStatus = _mapKycStatus(rawStatus);
      }
    }

    if (determinedStatus.isNotEmpty) {
      await prefs.setString('kyc_status', determinedStatus);
      debugPrint('KYC Status from auth user object: "$determinedStatus"');
    }
  }

  /// Parse KYC status from kyc object with multiple fields (same logic as UserService)
  static String _parseKYCFromMultiFieldObject(Map<String, dynamic> kycObj) {
    final kycCompleted = kycObj['kycCompleted'];
    final documentImageVerified = kycObj['documentImageVerified'];
    final selfieVerified = kycObj['selfieVerified'];
    final selfieStatus = kycObj['selfieStatus'] ?? kycObj['selfiestatus'];
    final kycStatus =
        kycObj['kycStatus']?.toString() ?? kycObj['status']?.toString();
    final rejection = kycObj['rejection'];

    debugPrint(
      '_parseKYCFromMultiFieldObject: kycCompleted=$kycCompleted, documentImageVerified=$documentImageVerified, selfieVerified=$selfieVerified, selfieStatus=$selfieStatus, rejection=$rejection',
    );

    String determinedStatus = 'Not Started';

    // Logic to determine KYC status based on multiple fields
    if (kycCompleted != null) {
      // Check if rejection object exists (indicates rejection with reason)
      if (rejection != null && rejection is Map<String, dynamic>) {
        determinedStatus = 'Rejected';
        final rejectionReason = rejection['reason']?.toString() ?? 'Unknown';
        debugPrint('✅ Auth KYC Status: REJECTED (rejection object present - Reason: $rejectionReason)');
      }
      // kycCompleted === 3 → Rejected
      else if (kycCompleted == 3) {
        determinedStatus = 'Rejected';
        debugPrint('✅ Auth KYC Status: REJECTED (kycCompleted=3)');
      } else if (documentImageVerified == true &&
          (selfieStatus == 0 || selfieStatus == 3)) {
        determinedStatus = 'Rejected';
        debugPrint('✅ Auth KYC Status: REJECTED (resume at selfie step)');
      }
      // kycCompleted === 2 → Completed
      else if (kycCompleted == 2) {
        determinedStatus = 'Completed';
        debugPrint('✅ Auth KYC Status: COMPLETED (kycCompleted=2)');
      }
      // kycCompleted === 1 → In progress, check other fields
      else if (kycCompleted == 1) {
        // selfieStatus === 3 → Selfie Rejected
        if (selfieStatus == 3) {
          determinedStatus = 'Rejected';
          debugPrint('✅ Auth KYC Status: REJECTED (selfieStatus=3)');
        }
        // kycCompleted === 1 && documentImageVerified === true && selfieStatus === 1 → Pending Admin Approval
        else if (documentImageVerified == true && selfieStatus == 1) {
          determinedStatus = 'Pending';
          debugPrint('✅ Auth KYC Status: PENDING ADMIN APPROVAL');
        }
        // kycCompleted === 1 && documentImageVerified === true → Document Verified
        else if (documentImageVerified == true) {
          determinedStatus = 'Pending';
          debugPrint('✅ Auth KYC Status: DOCUMENT VERIFIED');
        }
        // kycCompleted === 1 but document not verified yet → In Progress
        else {
          determinedStatus = 'Pending';
          debugPrint('✅ Auth KYC Status: PENDING');
        }
      }
    }
    // Fallback: Use kycStatus string if numeric fields are not available
    else if (kycStatus != null && kycStatus.isNotEmpty) {
      determinedStatus = _mapKycStatus(kycStatus);
      debugPrint(
        '✅ Auth KYC Status: Using kycStatus string "$kycStatus" → "$determinedStatus"',
      );
    }

    return determinedStatus;
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final deviceUuid = await getDeviceUuid();
      final osInt = getDeviceOSInt();

      final payload = {
        'email': email.trim(),
        'password': password,
        'os': osInt,
        'deviceOs': osInt,
        'deviceUuid': deviceUuid,
        'deviceName': getDeviceName(),
      };

      final response = await http
          .post(
            Uri.parse('$_baseUrl/user/v1/auth/login'),
            headers: _getHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('=== LOGIN API RESPONSE DATA ===');
        debugPrint('Full response: $data');
        debugPrint('Token field: ${data['token']}');
        debugPrint('User field: ${data['user']}');
        debugPrint('==============================');

        final prefs = await SharedPreferences.getInstance();

        // Check if response contains error message first
        if (data['message'] != null && data['success'] == false) {
          return {'success': false, 'message': data['message']};
        }

        // Ensure token exists and is not empty
        final token = data['authToken'] ?? data['token'] ?? '';
        if (token.isEmpty) {
          debugPrint('Token is empty or missing from response');
          return {
            'success': false,
            'message': 'Invalid credentials or token not received from server',
          };
        }

        // Clear any previous user data before saving new user data
        await UserService.instance.clearUserData();
        await UnifiedWalletService.clearState();
        SocketService.disconnect();
        SpotSocketService.reset();
        TempWalletSocketService.disconnect();

        // Save token and user data
        await prefs.setString(_tokenKey, token);
        await prefs.setString(_userKey, json.encode(data['user'] ?? {}));

        // Update last login time
        final now = DateTime.now();
        final formattedTime =
            '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} | ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        await prefs.setString('last_login', formattedTime);

        // Log login notification
        await NotificationService.addNotification(
          title: 'Login Successful',
          message: 'New login detected from ${getDeviceName()}',
          type: NotificationType.security,
        );

        // Store user ID as String
        if (data['user'] != null) {
          final userId =
              data['user']['_id'] ??
              data['user']['id'] ??
              data['user']['userId'];
          if (userId != null) {
            await prefs.setString('user_id', userId.toString());
          }
        }

        // Save KYC status directly from the auth response user object so the
        // correct status is available immediately — before any extra API call.
        await _saveKycStatusFromUserObject(
          data['user'] as Map<String, dynamic>?,
          prefs,
        );

        // Initialize and Refresh user profile immediately after login
        // This will fetch KYC status from /auth/me endpoint
        await UserService.instance.initUserData();

        // Extract and update wallet data from login response if available
        await _updateWalletFromLoginResponse(data);

        // Initialize wallet service and connect socket for balance fetching
        await _initializeWalletAndSocket();

        // Fetch IP address immediately after login
        await _fetchAndSaveIPAddress();

        debugPrint('Login successful, token and profile updated');
        return {'success': true, 'message': 'Login successful'};
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Login failed',
        };
      }
    } on SocketException catch (e) {
      debugPrint('SocketException during login: $e');
      return {
        'success': false,
        'message': 'No internet connection. Please check your network and try again.',
        'error_type': 'no_internet',
      };
    } on TimeoutException catch (e) {
      debugPrint('TimeoutException during login: $e');
      return {
        'success': false,
        'message': 'Connection timed out. Please check your internet and try again.',
        'error_type': 'timeout',
      };
    } on FormatException catch (e) {
      debugPrint('FormatException during login: $e');
      return {
        'success': false,
        'message': 'Invalid response from server. Please try again.',
        'error_type': 'format_error',
      };
    } catch (e) {
      debugPrint('Error during login: $e');
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Failed host lookup')) {
        return {
          'success': false,
          'message': 'No internet connection. Please check your network and try again.',
          'error_type': 'no_internet',
        };
      }
      return {
        'success': false,
        'message': 'Network error. Please try again.',
        'error_type': 'network_error',
      };
    }
  }

  // Fetch IP address from login activity API and save it
  static Future<void> _fetchAndSaveIPAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final userId = prefs.getString('user_id');

      if (token == null || userId == null) return;

      final response = await http
          .get(
            Uri.parse('$_baseUrl/user/v1/auth/loginactivity/$userId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true &&
            responseData['data'] is List &&
            responseData['data'].isNotEmpty) {
          final latestActivity = responseData['data'][0];
          String? ip =
              latestActivity['ipAddress']?.toString() ??
              latestActivity['ip']?.toString();
          if (ip != null && ip.isNotEmpty) {
            await prefs.setString('ip_address', ip);
            debugPrint('IP Address saved on login: $ip');
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching IP on login: $e');
    }
  }

  // Get saved KYC status (from /auth/me endpoint via UserService)
  static Future<String> getKYCStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('kyc_status') ?? 'Not Started';
    } catch (e) {
      return 'Not Started';
    }
  }

  static Future<Map<String, dynamic>> loginSendOtp(String email) async {
    try {
      final deviceUuid = await getDeviceUuid();
      final osInt = getDeviceOSInt();

      final payload = {
        'email': email.trim(),
        'os': osInt,
        'deviceOs': osInt,
        'deviceUuid': deviceUuid,
        'deviceName': getDeviceName(),
      };

      debugPrint('=== LOGIN SEND OTP PAYLOAD ===');
      debugPrint(jsonEncode(payload));

      final response = await http
          .post(
            Uri.parse('$_baseUrl/user/v1/auth/login/send-otp'),
            headers: _getHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint(
        'Login Send OTP Response: ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'OTP Sent'};
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to send OTP',
        };
      }
    } catch (e) {
      debugPrint('Login Send OTP Error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> signupSendOtp(
    String email, {
    String? referralCode,
  }) async {
    try {
      final deviceUuid = await getDeviceUuid();
      final osInt = getDeviceOSInt();

      final payload = {
        'email': email.trim(),
        'os': osInt,
        'deviceOs': osInt,
        'deviceUuid': deviceUuid,
        'deviceName': getDeviceName(),
        if (referralCode != null && referralCode.isNotEmpty)
          'referralCode': referralCode,
      };

      debugPrint('=== SIGNUP SEND OTP PAYLOAD ===');
      debugPrint(jsonEncode(payload));

      // Use signup-send-otp endpoint
      final response = await http
          .post(
            Uri.parse('$_baseUrl/user/v1/auth/signup-send-otp'),
            headers: _getHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint(
        'Signup Send OTP Response: ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'OTP Sent'};
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to send OTP',
        };
      }
    } catch (e) {
      debugPrint('Signup Send OTP Error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> signup(
    String email, {
    String? referralCode,
  }) async {
    try {
      final deviceUuid = await getDeviceUuid();
      final osInt = getDeviceOSInt();
      final prefs = await SharedPreferences.getInstance();
      final ipAddress = prefs.getString('ip_address') ?? '';

      debugPrint('=== SIGNUP DEBUG ===');
      debugPrint('Email: ${email.trim()}');
      debugPrint('Referral Code: $referralCode');
      debugPrint('Referral Code Is Empty: ${referralCode?.isEmpty ?? true}');

      final payload = {
        'email': email.trim(),
        'otp': '', // Will be filled during OTP verification
        if (referralCode != null && referralCode.isNotEmpty)
          'referralCode': referralCode,
        'ipAddress': ipAddress,
        'deviceName': getDeviceName(),
        'deviceUuid': deviceUuid,
        'deviceManufacturer':
            'Unknown', // Can be enhanced with device_info_plus
        'deviceVersion': '1.0', // Can be enhanced with device_info_plus
        'deviceOs': osInt,
      };

      debugPrint('SIGNUP PAYLOAD: $payload');
      debugPrint('ReferralCode in payload: ${payload['referralCode']}');

      final response = await http.post(
        Uri.parse('$_baseUrl/user/v1/auth/signup'),
        headers: _getHeaders(),
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': 'Signup successful, please verify OTP',
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Signup failed',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> resendOtp(String email) async {
    try {
      final deviceUuid = await getDeviceUuid();
      final osInt = getDeviceOSInt();

      final payload = {
        'email': email.trim(),
        'os': osInt,
        'deviceOs': osInt,
        'deviceUuid': deviceUuid,
        'deviceName': getDeviceName(),
      };

      debugPrint('=== RESEND OTP PAYLOAD ===');
      debugPrint(jsonEncode(payload));

      final response = await http
          .post(
            Uri.parse('$_baseUrl/user/v1/auth/login/send-otp'),
            headers: _getHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint(
        'Resend OTP Response: ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'OTP resent successfully'};
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to resend OTP',
        };
      }
    } catch (e) {
      debugPrint('Resend OTP Error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Generic OTP generation for various purposes
  static Future<Map<String, dynamic>> generateOtp({
    required String purpose,
    String? email,
  }) async {
    try {
      final deviceUuid = await getDeviceUuid();
      final osInt = getDeviceOSInt();

      final payload = {
        'purpose': purpose,
        if (email != null) 'email': email.trim(),
        'os': osInt,
        'deviceOs': osInt,
        'deviceUuid': deviceUuid,
        'deviceName': getDeviceName(),
      };

      debugPrint('Generating OTP for purpose: $purpose');

      final response = await http.post(
        Uri.parse('$_baseUrl/user/v1/otp/generate'),
        headers: _getHeaders(),
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'OTP generated successfully',
          'data': data,
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message':
              errorData['message'] ??
              errorData['error'] ??
              'Failed to generate OTP',
        };
      }
    } catch (e) {
      debugPrint('Error generating OTP: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> loginWithOtp(
    String email,
    String otp,
  ) async {
    try {
      final deviceUuid = await getDeviceUuid();
      final osInt = getDeviceOSInt();

      final payload = {
        'email': email.trim(),
        'otp': otp.trim(),
        'os': osInt,
        'deviceOs': osInt,
        'deviceUuid': deviceUuid,
        'deviceName': getDeviceName(),
      };

      debugPrint('=== VERIFY OTP PAYLOAD ===');
      debugPrint(jsonEncode(payload));

      final response = await http
          .post(
            Uri.parse('$_baseUrl/user/v1/auth/login'),
            headers: _getHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('=== API RESPONSE DATA ===');
        debugPrint('Full response: $data');
        debugPrint('Token field: ${data['token']}');
        debugPrint('User field: ${data['user']}');
        debugPrint('========================');

        final prefs = await SharedPreferences.getInstance();

        // Check if response contains error message first
        if (data['message'] != null && data['success'] == false) {
          return {'success': false, 'message': data['message']};
        }

        // Ensure token exists and is not empty
        final token = data['authToken'] ?? data['token'] ?? '';
        if (token.isEmpty) {
          debugPrint('Token is empty or missing from response');
          return {
            'success': false,
            'message': 'Invalid OTP or token not received from server',
          };
        }

        // Clear any previous user data before saving new user data
        await UserService.instance.clearUserData();
        await UnifiedWalletService.clearState();
        SocketService.disconnect();
        SpotSocketService.reset();
        TempWalletSocketService.disconnect();

        // Save token and user data
        await prefs.setString(_tokenKey, token);
        await prefs.setString(_userKey, json.encode(data['user'] ?? {}));

        // Update last login time
        final now = DateTime.now();
        final formattedTime =
            '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} | ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        await prefs.setString('last_login', formattedTime);

        // Log login notification
        await NotificationService.addNotification(
          title: 'Login Successful',
          message: 'New login detected from ${getDeviceName()}',
          type: NotificationType.security,
        );

        // Store user ID as String
        if (data['user'] != null) {
          final userId =
              data['user']['_id'] ??
              data['user']['id'] ??
              data['user']['userId'];
          if (userId != null) {
            await prefs.setString('user_id', userId.toString());
          }
        }

        // Save KYC status directly from the auth response user object.
        await _saveKycStatusFromUserObject(
          data['user'] as Map<String, dynamic>?,
          prefs,
        );

        // Initialize and Refresh user profile immediately after login
        // This will fetch KYC status from /auth/me endpoint
        await UserService.instance.initUserData();

        // Extract and update wallet data from login response if available
        await _updateWalletFromLoginResponse(data);

        // Initialize wallet service and connect socket for balance fetching
        await _initializeWalletAndSocket();

        // Fetch IP address immediately after login
        await _fetchAndSaveIPAddress();

        debugPrint('OTP Login successful, token and profile updated');
        return {'success': true, 'message': 'Login successful'};
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Verification failed',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> completeSignupWithOtp(
    String email,
    String otp, {
    String? referralCode,
  }) async {
    try {
      final deviceUuid = await getDeviceUuid();
      final osInt = getDeviceOSInt();
      final prefs = await SharedPreferences.getInstance();
      final ipAddress = prefs.getString('ip_address') ?? '';

      debugPrint('=== COMPLETE SIGNUP WITH OTP DEBUG ===');
      debugPrint('Email: ${email.trim()}');
      debugPrint('OTP: ${otp.trim()}');
      debugPrint('Referral Code: $referralCode');
      debugPrint('Referral Code Is Empty: ${referralCode?.isEmpty ?? true}');

      final payload = {
        'email': email.trim(),
        'otp': otp.trim(),
        if (referralCode != null && referralCode.isNotEmpty)
          'referralCode': referralCode,
        'ipAddress': ipAddress,
        'deviceName': getDeviceName(),
        'deviceUuid': deviceUuid,
        'deviceManufacturer':
            'Unknown', // Can be enhanced with device_info_plus
        'deviceVersion': '1.0', // Can be enhanced with device_info_plus
        'deviceOs': osInt,
      };

      debugPrint('COMPLETE SIGNUP PAYLOAD: $payload');
      debugPrint('ReferralCode in payload: ${payload['referralCode']}');

      // Use signup endpoint with OTP
      final response = await http
          .post(
            Uri.parse('$_baseUrl/user/v1/auth/signup'),
            headers: _getHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint(
        'Complete Signup Response: ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();

        final token = data['authToken'] ?? data['token'] ?? '';
        if (token.isEmpty) {
          debugPrint('Token is empty or missing from signup response');
          return {
            'success': false,
            'message': 'Token not received from server',
          };
        }

        // Clear any previous user data before saving new user data
        await UserService.instance.clearUserData();
        await UnifiedWalletService.clearState();
        SocketService.disconnect();
        SpotSocketService.reset();
        TempWalletSocketService.disconnect();

        await prefs.setString(_tokenKey, token);

        // Store user ID as String
        if (data['user'] != null) {
          final userId =
              data['user']['_id'] ??
              data['user']['id'] ??
              data['user']['userId'];
          if (userId != null) {
            await prefs.setString('user_id', userId.toString());
          }
        }

        // Save user data
        await prefs.setString(_userKey, json.encode(data['user'] ?? {}));

        // Save KYC status directly from the signup response user object.
        await _saveKycStatusFromUserObject(
          data['user'] as Map<String, dynamic>?,
          prefs,
        );

        // Initialize and Refresh user profile immediately after signup
        // This will fetch KYC status from /auth/me endpoint
        await UserService.instance.initUserData();

        // Extract and update wallet data from signup response if available
        await _updateWalletFromLoginResponse(data);

        // Initialize wallet service and connect socket for balance fetching
        await _initializeWalletAndSocket();

        // Fetch IP address immediately after signup
        await _fetchAndSaveIPAddress();

        // Log signup notification
        await NotificationService.addNotification(
          title: 'Welcome to CreddX!',
          message: 'Your account has been successfully created.',
          type: NotificationType.info,
        );

        debugPrint('Signup successful, token and profile updated');
        return {'success': true, 'message': 'Signup successful'};
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Signup failed',
        };
      }
    } catch (e) {
      debugPrint('Complete Signup Error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final userData = prefs.getString(_userKey);

      // More thorough check
      if (token == null || token.isEmpty) {
        debugPrint('No token found');
        return false;
      }

      if (userData == null || userData.isEmpty) {
        debugPrint('No user data found');
        return false;
      }

      // Validate user data is valid JSON
      try {
        final user = json.decode(userData);
        if (user is Map && user.isNotEmpty) {
          debugPrint('User is logged in: ${user['email'] ?? 'Unknown'}');
          return true;
        }
      } catch (e) {
        debugPrint('Invalid user data format: $e');
        // Clear invalid data
        await logout();
        return false;
      }

      return false;
    } catch (e) {
      debugPrint('Error checking login status: $e');
      return false;
    }
  }

  // Get user data
  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    if (userData != null && userData.isNotEmpty) {
      try {
        return json.decode(userData);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Logout user and call API
  static Future<Map<String, dynamic>> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);

      // Call logout API if token exists
      if (token != null && token.isNotEmpty) {
        try {
          await http
              .post(
                Uri.parse('$_baseUrl/user/v1/auth/logout'),
                headers: {..._getHeaders(), 'Authorization': 'Bearer $token'},
              )
              .timeout(const Duration(seconds: 10));
        } catch (e) {
          debugPrint('Logout API error (ignored): $e');
        }
      }

      // Clear local data
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      await prefs.remove('user_id');

      // Clear all cached user data from UserService
      await UserService.instance.clearUserData();

      // Clear all wallet and socket states
      await UnifiedWalletService.clearState();
      SocketService.disconnect();
      SpotSocketService.reset();
      TempWalletSocketService.disconnect();

      return {'success': true, 'message': 'Logout successful'};
    } catch (e) {
      return {'success': false, 'message': 'Error during logout: $e'};
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getUserEmail() async {
    final userData = await getUserData();
    if (userData != null) {
      return userData['email']?.toString();
    }
    return null;
  }

  // Initialize wallet service and connect socket for balance fetching after login
  static Future<void> _initializeWalletAndSocket() async {
    try {
      debugPrint(
        'AuthService: Initializing wallet service and socket connection...',
      );

      // Initialize the unified wallet service
      await UnifiedWalletService.initialize();

      // Connect to the main wallet socket
      await SocketService.connect();

      // Connect to spot socket for real-time balance updates
      await SpotSocketService.connect();

      // Request wallet summary immediately after connection
      SocketService.requestWalletSummary();

      debugPrint(
        'AuthService: Wallet service and socket initialized successfully',
      );
    } catch (e) {
      debugPrint(
        'AuthService: Error initializing wallet service and socket: $e',
      );
      // Don't fail login if wallet initialization fails
    }
  }

  // Fetch wallet data immediately after login
  static Future<void> _updateWalletFromLoginResponse(
    Map<String, dynamic> loginData,
  ) async {
    try {
      debugPrint('AuthService: Fetching wallet data after login...');

      // Call wallet API directly to get fresh balance data
      final result = await UnifiedWalletService.refreshWalletSummary();

      if (result['success'] == true) {
        debugPrint('AuthService: Wallet data fetched successfully after login');
        debugPrint('AuthService: Wallet data: ${result['data']}');
      } else {
        debugPrint(
          'AuthService: Failed to fetch wallet data after login: ${result['error']}',
        );
      }
    } catch (e) {
      debugPrint('AuthService: Error fetching wallet after login: $e');
      // Don't fail login if wallet fetch fails
    }
  }
}
