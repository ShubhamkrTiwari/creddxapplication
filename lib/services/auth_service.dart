import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'user_service.dart';
import 'notification_service.dart';

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
      case TargetPlatform.android: return 'Android Device';
      case TargetPlatform.iOS: return 'iOS Device';
      case TargetPlatform.windows: return 'Windows PC';
      case TargetPlatform.macOS: return 'Mac';
      case TargetPlatform.linux: return 'Linux PC';
      default: return 'Unknown Device';
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
        uuid ??= 'device_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
        await prefs.setString('deviceUuid', uuid);
      }
      return uuid;
    } catch (e) {
      return 'fallback_uuid';
    }
  }

  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
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

      final response = await http.post(
        Uri.parse('$_baseUrl/user/v1/auth/login'),
        headers: _getHeaders(),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

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
          return {'success': false, 'message': 'Invalid credentials or token not received from server'};
        }
        
        // Save token and user data
        await prefs.setString(_tokenKey, token);
        await prefs.setString(_userKey, json.encode(data['user'] ?? {}));
        
        // Update last login time
        final now = DateTime.now();
        final formattedTime = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} | ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        await prefs.setString('last_login', formattedTime);
        
        // Log login notification
        await NotificationService.addNotification(
          title: 'Login Successful',
          message: 'New login detected from ${getDeviceName()}',
          type: NotificationType.security,
        );

        // Store user ID as String
        if (data['user'] != null) {
          final userId = data['user']['_id'] ?? data['user']['id'] ?? data['user']['userId'];
          if (userId != null) {
            await prefs.setString('user_id', userId.toString());
          }
        }
        
        // Fetch IP address immediately after login
        await _fetchAndSaveIPAddress();
        
        // Log login notification
        await NotificationService.addNotification(
          title: 'Login Successful',
          message: 'New login detected from ${getDeviceName()}',
          type: NotificationType.security,
        );
        
        // Check KYC status after login
        await _checkAndSaveKYCStatus();
        
        debugPrint('Login successful, token saved');
        return {'success': true, 'message': 'Login successful'};
      } else {
        final errorData = json.decode(response.body);
        return {'success': false, 'message': errorData['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Fetch IP address from login activity API and save it
  static Future<void> _fetchAndSaveIPAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final userId = prefs.getString('user_id');

      if (token == null || userId == null) return;

      final response = await http.get(
        Uri.parse('$_baseUrl/user/v1/auth/loginactivity/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] is List && responseData['data'].isNotEmpty) {
          final latestActivity = responseData['data'][0];
          String? ip = latestActivity['ipAddress']?.toString() ?? latestActivity['ip']?.toString();
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

  // Check KYC status and save it locally
  static Future<void> _checkAndSaveKYCStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final userId = prefs.getString('user_id');

      if (token == null || userId == null) return;

      final response = await http.post(
        Uri.parse('$_baseUrl/v1/kyc/status'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'user_id': userId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final kycData = responseData['data'];
          final kycStatus = kycData['status']?.toString() ?? 'not_started';
          await prefs.setString('kyc_status', kycStatus);
          debugPrint('KYC Status saved: $kycStatus');
        }
      }
    } catch (e) {
      debugPrint('Error checking KYC status: $e');
    }
  }

  // Get saved KYC status
  static Future<String> getKYCStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('kyc_status') ?? 'not_started';
    } catch (e) {
      return 'not_started';
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

      final response = await http.post(
        Uri.parse('$_baseUrl/user/v1/auth/login/send-otp'),
        headers: _getHeaders(),
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'OTP Sent'};
      } else {
        final errorData = json.decode(response.body);
        return {'success': false, 'message': errorData['message'] ?? 'Failed to send OTP'};
      }
    } catch (e) { return {'success': false, 'message': 'Network error'}; }
  }

  static Future<Map<String, dynamic>> signupSendOtp(String email) async {
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

      final response = await http.post(
        Uri.parse('$_baseUrl/user/v1/auth/signup-send-otp'),
        headers: _getHeaders(),
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'OTP Sent'};
      } else {
        final errorData = json.decode(response.body);
        return {'success': false, 'message': errorData['message'] ?? 'Failed to send OTP'};
      }
    } catch (e) { return {'success': false, 'message': 'Network error'}; }
  }

  static Future<Map<String, dynamic>> signup(String email, {String? referralCode}) async {
    try {
      final deviceUuid = await getDeviceUuid();
      final osInt = getDeviceOSInt();
      
      final payload = {
        'email': email.trim(),
        if (referralCode != null) 'referral_code': referralCode,
        'os': osInt,
        'deviceOs': osInt,
        'deviceUuid': deviceUuid,
        'deviceName': getDeviceName(),
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/user/v1/auth/signup'),
        headers: _getHeaders(),
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'Signup successful, please verify OTP'};
      } else {
        final errorData = json.decode(response.body);
        return {'success': false, 'message': errorData['message'] ?? 'Signup failed'};
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

      final response = await http.post(
        Uri.parse('$_baseUrl/user/v1/auth/login/send-otp'),
        headers: _getHeaders(),
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'OTP resent successfully'};
      } else {
        final errorData = json.decode(response.body);
        return {'success': false, 'message': errorData['message'] ?? 'Failed to resend OTP'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  // Generic OTP generation for various purposes
  static Future<Map<String, dynamic>> generateOtp({required String purpose, String? email}) async {
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
          'message': errorData['message'] ?? errorData['error'] ?? 'Failed to generate OTP',
        };
      }
    } catch (e) {
      debugPrint('Error generating OTP: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> loginWithOtp(String email, String otp) async {
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
      
      final response = await http.post(
        Uri.parse('$_baseUrl/user/v1/auth/login'),
        headers: _getHeaders(),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

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
          return {'success': false, 'message': 'Invalid OTP or token not received from server'};
        }
        
        // Save token and user data
        await prefs.setString(_tokenKey, token);
        await prefs.setString(_userKey, json.encode(data['user'] ?? {}));
        
        // Update last login time
        final now = DateTime.now();
        final formattedTime = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} | ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        await prefs.setString('last_login', formattedTime);
        
        // Log login notification
        await NotificationService.addNotification(
          title: 'Login Successful',
          message: 'New login detected from ${getDeviceName()}',
          type: NotificationType.security,
        );

        // Store user ID as String
        if (data['user'] != null) {
          final userId = data['user']['_id'] ?? data['user']['id'] ?? data['user']['userId'];
          if (userId != null) {
            await prefs.setString('user_id', userId.toString());
          }
        }
        
        // Fetch IP address immediately after login
        await _fetchAndSaveIPAddress();
        
        debugPrint('OTP Login successful, token saved');
        return {'success': true, 'message': 'Login successful'};
      } else {
        final errorData = json.decode(response.body);
        return {'success': false, 'message': errorData['message'] ?? 'Verification failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> completeSignupWithOtp(String email, String otp, {String? referralCode}) async {
    try {
      final deviceUuid = await getDeviceUuid();
      final osInt = getDeviceOSInt();
      
      final payload = {
        'email': email.trim(),
        'otp': otp.trim(),
        if (referralCode != null) 'referralCode': referralCode,
        'os': osInt,
        'deviceOs': osInt,
        'deviceUuid': deviceUuid,
        'deviceName': getDeviceName(),
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/user/v1/auth/complete-signup'),
        headers: _getHeaders(),
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, data['authToken'] ?? data['token'] ?? '');
        
        // Store user ID as String
        if (data['user'] != null) {
          final userId = data['user']['_id'] ?? data['user']['id'] ?? data['user']['userId'];
          if (userId != null) {
            await prefs.setString('user_id', userId.toString());
          }
        }
        
        // Log signup notification
        await NotificationService.addNotification(
          title: 'Welcome to CreddX!',
          message: 'Your account has been successfully created.',
          type: NotificationType.info,
        );

        return {'success': true, 'message': 'Signup successful'};
      } else {
        final errorData = json.decode(response.body);
        return {'success': false, 'message': errorData['message'] ?? 'Signup failed'};
      }
    } catch (e) { return {'success': false, 'message': 'Network error'}; }
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
          await http.post(
            Uri.parse('$_baseUrl/user/v1/auth/logout'),
            headers: {
              ..._getHeaders(),
              'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 10));
        } catch (e) {
          debugPrint('Logout API error (ignored): $e');
        }
      }

      // Clear local data
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      await prefs.remove('user_id');

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
}
