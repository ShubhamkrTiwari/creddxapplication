import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'kyc_service.dart';
import 'auth_service.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';
  static const String _userIdKey = 'user_id';
  static const String _signUpTimeKey = 'sign_up_time';
  static const String _lastLoginKey = 'last_login';
  static const String _kycStatusKey = 'kyc_status';
  static const String _kycSubmittedAtKey = 'kyc_submitted_at';

  static const String _ipAddressKey = 'ip_address';

  String? _userName;
  String? _userEmail;
  String? _userId;
  String? _signUpTime;
  String? _lastLogin;
  String _kycStatus = 'Not Started'; 
  String? _kycSubmittedAt;

  String? _ipAddress;

  // Getters
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get userId => _userId;
  String? get signUpTime => _signUpTime;
  String? get lastLogin => _lastLogin;
  String get kycStatus => _kycStatus;
  String? get kycSubmittedAt => _kycSubmittedAt;
  String? get ipAddress => _ipAddress;

  // Helper to safely get string from prefs (handles cases where it might be int)
  String? _getSafeString(SharedPreferences prefs, String key) {
    try {
      return prefs.getString(key);
    } catch (e) {
      // If it's stored as int, convert to string
      final intValue = prefs.getInt(key);
      return intValue?.toString();
    }
  }

  // Initialize user data from SharedPreferences
  Future<void> initUserData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load from local storage first for immediate display
    _userName = _getSafeString(prefs, _userNameKey);
    _userEmail = _getSafeString(prefs, _userEmailKey);
    _userId = _getSafeString(prefs, _userIdKey);
    _signUpTime = _getSafeString(prefs, _signUpTimeKey);
    _lastLogin = _getSafeString(prefs, _lastLoginKey);
    _kycStatus = _getSafeString(prefs, _kycStatusKey) ?? 'Not Started';
    _kycSubmittedAt = _getSafeString(prefs, _kycSubmittedAtKey);
    _ipAddress = _getSafeString(prefs, _ipAddressKey);

    // If we have cached auth data, parse it too
    final userDataStr = _getSafeString(prefs, 'user_data');
    if (userDataStr != null && userDataStr.isNotEmpty) {
      try {
        final userData = json.decode(userDataStr);
        _parseAuthData(userData);
      } catch (e) {
        debugPrint('Error parsing cached user data: $e');
      }
    }
    
    // Background refresh
    _refreshDataFromAPI();
  }

  void _parseAuthData(Map<String, dynamic> userData) {
    _userName ??= userData['name']?.toString();
    _userEmail ??= userData['email']?.toString();
    String? authUserId = userData['_id']?.toString() ?? userData['id']?.toString() ?? userData['userId']?.toString();
    
    if (authUserId != null) {
      _userId = authUserId;
      if (_userId!.length > 8) {
        // Only trim if it looks like a MongoDB ID
        if (RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(_userId!)) {
           _userId = _userId!.substring(_userId!.length - 8);
        }
      }
    }

    if (_signUpTime == null) {
      String? createdAt = userData['createdAt']?.toString() ?? userData['signUpTime']?.toString();
      if (createdAt != null) {
        _signUpTime = _formatDate(createdAt);
      }
    }
  }

  String _formatDate(String dateStr) {
    try {
      DateTime parsedDate = DateTime.parse(dateStr);
      return '${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year} | ${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')}:${parsedDate.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _refreshDataFromAPI() async {
    // Don't await these to prevent blocking app launch
    fetchProfileDataFromAPI();
    fetchKYCStatusFromAPI();
  }

  // Fetch real profile data from API
  Future<void> fetchProfileDataFromAPI() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token != null) {
        final response = await http.get(
          Uri.parse('https://api11.hathmetech.com/api/user/v1/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          if (responseData['success'] == true && responseData['data'] != null) {
            final profileData = responseData['data'];
            
            _userName = profileData['name']?.toString() ?? _userName;
            _userEmail = profileData['email']?.toString() ?? _userEmail;
            
            String? profileUserId = profileData['_id']?.toString() ?? profileData['id']?.toString() ?? profileData['userId']?.toString();
            if (profileUserId != null) {
              _userId = profileUserId;
              if (_userId!.length > 8 && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(_userId!)) {
                _userId = _userId!.substring(_userId!.length - 8);
              }
            }
            
            if (profileData['createdAt'] != null) {
              _signUpTime = _formatDate(profileData['createdAt'].toString());
              await prefs.setString(_signUpTimeKey, _signUpTime!);
            }
            
            if (profileData['lastLogin'] != null || profileData['last_login'] != null) {
              String lastLoginStr = profileData['lastLogin']?.toString() ?? profileData['last_login']?.toString() ?? '';
              if (lastLoginStr.isNotEmpty) {
                _lastLogin = _formatDate(lastLoginStr);
                await prefs.setString(_lastLoginKey, _lastLogin!);
              }
            }
            
            if (_userName != null) await prefs.setString(_userNameKey, _userName!);
            if (_userEmail != null) await prefs.setString(_userEmailKey, _userEmail!);
            if (_userId != null) await prefs.setString(_userIdKey, _userId!);
          }
        }
        await fetchLoginActivity();
      }
    } catch (e) {
      debugPrint('Error fetching profile data: $e');
    }
  }

  // Fetch login activity from API
  Future<void> fetchLoginActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token != null && _userId != null) {
        final response = await http.get(
          Uri.parse('https://api11.hathmetech.com/api/user/v1/auth/loginactivity/$_userId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          if (responseData['success'] == true && responseData['data'] is List && responseData['data'].isNotEmpty) {
            final latestActivity = responseData['data'][0];
            String? loginTime = latestActivity['loginTime']?.toString() ?? latestActivity['login_time']?.toString();
            if (loginTime != null) {
              _lastLogin = _formatDate(loginTime);
              await prefs.setString(_lastLoginKey, _lastLogin!);
            }
            
            // Get IP address from login activity
            String? ip = latestActivity['ipAddress']?.toString() ?? latestActivity['ip']?.toString();
            if (ip != null && ip.isNotEmpty) {
              _ipAddress = ip;
              await prefs.setString(_ipAddressKey, _ipAddress!);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching login activity: $e');
    }
  }

  // Fetch KYC status from API
  Future<void> fetchKYCStatusFromAPI() async {
    try {
      // Use AuthService to get KYC status (same as login)
      final status = await AuthService.getKYCStatus();
      _kycStatus = _mapStatusToDisplay(status);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kycStatusKey, _kycStatus);
      
      debugPrint('KYC Status updated: $_kycStatus');
    } catch (e) {
      debugPrint('Failed to fetch KYC status from API: $e');
    }
  }

  // Map API status to display status
  String _mapStatusToDisplay(String apiStatus) {
    switch (apiStatus.toLowerCase()) {
      case 'approved':
      case 'verified':
        return 'Completed';
      case 'pending':
        return 'Pending';
      case 'rejected':
        return 'Rejected';
      case 'not_started':
      default:
        return 'Not Started';
    }
  }

  // Update user email
  Future<void> updateUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    _userEmail = email;
    await prefs.setString(_userEmailKey, email);
    
    final now = DateTime.now();
    _lastLogin = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} | ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    await prefs.setString(_lastLoginKey, _lastLogin!);
  }

  // Update KYC status
  Future<void> updateKYCStatus(String status) async {
    final prefs = await SharedPreferences.getInstance();
    _kycStatus = status;
    await prefs.setString(_kycStatusKey, status);
    
    if (status == 'Pending') {
      final now = DateTime.now();
      _kycSubmittedAt = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} | ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      await prefs.setString(_kycSubmittedAtKey, _kycSubmittedAt!);
    }
  }

  // Restore missing methods for Build fix
  Future<Map<String, dynamic>> submitKYC({
    required String documentType,
    required String documentId,
    required String idNumber,
    required dynamic frontImage,
    required dynamic backImage,
    required dynamic selfieImage,
  }) async {
    try {
      final result = await KYCService.submitKYC(
        documentType: documentType,
        documentId: documentId,
        idNumber: idNumber,
        frontImage: frontImage,
        backImage: backImage,
        selfieImage: selfieImage,
      );

      if (result['success'] == true) {
        await updateKYCStatus('Pending');
        return {
          'success': true,
          'message': 'KYC submitted successfully',
          'data': result['data']
        };
      } else {
        return {
          'success': false,
          'error': result['error'] ?? 'Failed to submit KYC'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<List<String>> getDocumentTypes() async {
    try {
      final result = await KYCService.getDocumentTypes();
      if (result['success'] == true) {
        final data = result['data'];
        if (data is List) return List<String>.from(data);
        if (data is Map && data['types'] is List) return List<String>.from(data['types']);
      }
    } catch (e) {
      debugPrint('Failed to get document types: $e');
    }
    return ['Passport', 'National ID', 'Driver License', 'Aadhaar Card', 'Voter ID'];
  }

  Future<Map<String, dynamic>> validateDocument({
    required String documentType,
    required String documentId,
  }) async {
    try {
      return await KYCService.validateDocument(
        documentType: documentType,
        documentId: documentId,
      );
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> verifySelfie({
    required dynamic selfieImage,
    String? documentType,
    String? documentId,
  }) async {
    try {
      final result = await KYCService.verifySelfie(
        selfieImage: selfieImage,
        documentType: documentType,
        documentId: documentId,
      );

      if (result['success'] == true) {
        await updateKYCStatus('Pending');
        return {
          'success': true,
          'message': 'Selfie verified successfully',
          'data': result['data']
        };
      } else {
        return {
          'success': false,
          'error': result['error'] ?? 'Failed to verify selfie'
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> verifySelfieFromDigiLocker({
    required dynamic selfieImage,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      final token = prefs.getString('auth_token') ?? '';

      if (userId.isEmpty || token.isEmpty) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      // Create multipart request for DigiLocker selfie verification
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api11.hathmetech.com/api/v1/kyc/digilocker/selfie-verify'),
      );

      // Add headers`
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      // Add form fields
      request.fields['user_id'] = userId;
      request.fields['source'] = 'digilocker';

      // Add selfie image
      if (selfieImage != null) {
        if (kIsWeb) {
          final bytes = await (selfieImage as XFile).readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            'selfie',
            bytes,
            filename: 'selfie.jpg',
          ));
        } else {
          final bytes = await selfieImage.readAsBytes();
          final fileName = selfieImage.path.split('/').last;
          request.files.add(http.MultipartFile.fromBytes(
            'selfie',
            bytes,
            filename: fileName,
          ));
        }
      }

      // Send request
      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      print('DigiLocker Selfie Verify Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          await updateKYCStatus('Pending');
          return {
            'success': true,
            'message': 'Selfie verified successfully',
            'data': responseData['data']
          };
        } else {
          return {
            'success': false,
            'error': responseData['error'] ?? 'Failed to verify selfie'
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('DigiLocker Selfie Verify Error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Initiate DigiLocker connection
  Future<Map<String, dynamic>> initiateDigiLockerConnection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      final token = prefs.getString('auth_token') ?? '';

      if (userId.isEmpty || token.isEmpty) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      final response = await http.post(
        Uri.parse('https://api11.hathmetech.com/api/v1/kyc/digilocker/initiate'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'user_id': userId,
        }),
      ).timeout(const Duration(seconds: 30));

      print('DigiLocker Initiate Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'],
            'message': responseData['message'] ?? 'DigiLocker initiated'
          };
        } else {
          return {
            'success': false,
            'error': responseData['error'] ?? 'Failed to initiate DigiLocker'
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('DigiLocker Initiate Error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Check DigiLocker status
  Future<Map<String, dynamic>> checkDigiLockerStatus(String requestId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      final token = prefs.getString('auth_token') ?? '';

      if (userId.isEmpty || token.isEmpty) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      final response = await http.get(
        Uri.parse('https://api11.hathmetech.com/api/v1/kyc/digilocker/status?request_id=$requestId&user_id=$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      print('DigiLocker Status Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'],
            'message': responseData['message'] ?? 'Status retrieved'
          };
        } else {
          return {
            'success': false,
            'error': responseData['error'] ?? 'Failed to get DigiLocker status'
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('DigiLocker Status Error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Check KYC status via POST (General endpoint)
  Future<Map<String, dynamic>> checkKYCStatusPost() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      final token = prefs.getString('auth_token') ?? '';

      if (userId.isEmpty || token.isEmpty) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      // Note: Using the server IP for consistent behavior in the app.
      // If testing locally, ensure the server is accessible.
      final response = await http.post(
        Uri.parse('https://api11.hathmetech.com/api/v1/kyc/status'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'user_id': userId,
        }),
      ).timeout(const Duration(seconds: 30));

      print('KYC Status POST Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return {
          'success': responseData['success'] ?? true,
          'data': responseData['data'],
          'message': responseData['message'] ?? 'Status retrieved'
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('KYC Status POST Error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateUserProfile({
    String? name,
    String? email,
    String? phone,
    String? avatar,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (_userId == null || token == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      final requestBody = <String, dynamic>{'user_id': _userId};
      if (name != null) requestBody['name'] = name;
      if (email != null) requestBody['email'] = email;
      if (phone != null) requestBody['phone'] = phone;
      if (avatar != null) requestBody['avatar'] = avatar;

      final response = await http.put(
        Uri.parse('https://api11.hathmetech.com/api/user/v1/auth/create-profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          if (name != null) {
            _userName = name;
            await prefs.setString(_userNameKey, name);
          }
          if (email != null) {
            _userEmail = email;
            await prefs.setString(_userEmailKey, email);
          }
          return {'success': true, 'message': 'Profile updated successfully', 'data': responseData['data']};
        }
        return {'success': false, 'error': responseData['error'] ?? 'Failed to update profile'};
      }
      return {'success': false, 'error': 'Server error: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Fetch referred friends from API
  Future<Map<String, dynamic>> getReferredFriends() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      debugPrint('Fetching referred friends from: https://api11.hathmetech.com/api/user/v1/auth/referred-friends');
      
      final response = await http.get(
        Uri.parse('https://api11.hathmetech.com/api/user/v1/auth/referred-friends'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('Referred Friends API Response Status: ${response.statusCode}');
      debugPrint('Referred Friends API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'] ?? responseData,
            'message': responseData['message'] ?? 'Referred friends fetched successfully',
          };
        } else {
          return {
            'success': false,
            'error': responseData['message'] ?? responseData['error'] ?? 'Failed to fetch referred friends',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching referred friends: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Send invitation email with verification code
  Future<Map<String, dynamic>> sendInvitationEmail({
    required String friendEmail,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      final requestBody = {
        'friendEmail': friendEmail,
        'type': 'invitation_with_verification',
      };

      debugPrint('Sending invitation email with verification: $requestBody');
      debugPrint('API URL: https://api11.hathmetech.com/api/user/v1/auth/send-invitation');
      
      final response = await http.post(
        Uri.parse('https://api11.hathmetech.com/api/user/v1/auth/send-invitation'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      debugPrint('Send Invitation API Response Status: ${response.statusCode}');
      debugPrint('Send Invitation API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'] ?? responseData,
            'message': responseData['message'] ?? 'Invitation sent successfully!',
            'requiresVerification': responseData['requiresVerification'] ?? true,
          };
        } else {
          return {
            'success': false,
            'error': responseData['message'] ?? responseData['error'] ?? 'Failed to send invitation',
          };
        }
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? errorData['error'] ?? 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error sending invitation email: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Send verification email for referral
  Future<Map<String, dynamic>> sendReferralVerificationEmail({
    required String email,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      final requestBody = {
        'email': email,
        'type': 'referral_verification',
      };

      debugPrint('Sending referral verification email: $requestBody');
      debugPrint('API URL: https://api11.hathmetech.com/api/user/v1/auth/send-verification-email');
      
      final response = await http.post(
        Uri.parse('https://api11.hathmetech.com/api/user/v1/auth/send-verification-email'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      debugPrint('Send Verification Email API Response Status: ${response.statusCode}');
      debugPrint('Send Verification Email API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'] ?? responseData,
            'message': responseData['message'] ?? 'Verification code sent successfully!',
          };
        } else {
          return {
            'success': false,
            'error': responseData['message'] ?? responseData['error'] ?? 'Failed to send verification code',
          };
        }
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? errorData['error'] ?? 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error sending referral verification email: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Verify and claim referral code
  Future<Map<String, dynamic>> verifyAndClaimReferral({
    required String verificationCode,
    required String referralCode,
    required String email,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      final requestBody = {
        'verificationCode': verificationCode,
        'referralCode': referralCode,
        'email': email,
      };

      debugPrint('Verifying and claiming referral: $requestBody');
      debugPrint('API URL: https://api11.hathmetech.com/api/user/v1/auth/verify-claim-referral');
      
      final response = await http.post(
        Uri.parse('https://api11.hathmetech.com/api/user/v1/auth/verify-claim-referral'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      debugPrint('Verify & Claim API Response Status: ${response.statusCode}');
      debugPrint('Verify & Claim API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'] ?? responseData,
            'message': responseData['message'] ?? 'Referral claimed successfully!',
          };
        } else {
          return {
            'success': false,
            'error': responseData['message'] ?? responseData['error'] ?? 'Failed to claim referral',
          };
        }
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? errorData['error'] ?? 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error verifying and claiming referral: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // Clear all user data
  Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userNameKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_signUpTimeKey);
    await prefs.remove(_lastLoginKey);
    await prefs.remove(_kycStatusKey);
    await prefs.remove(_kycSubmittedAtKey);
    await prefs.remove(_ipAddressKey);
    
    _userName = null;
    _userEmail = null;
    _userId = null;
    _signUpTime = null;
    _lastLogin = null;
    _kycStatus = 'Not Started';
    _kycSubmittedAt = null;
    _ipAddress = null;
  }

  bool hasEmail() => _userEmail != null && _userEmail!.isNotEmpty;
  bool isKYCPending() => _kycStatus == 'Pending';
  bool isKYCVerified() => _kycStatus == 'Completed';
  bool isKYCRejected() => _kycStatus == 'Rejected';
  bool isKYCNotStarted() => _kycStatus == 'Not Started';

  // Get auth token from SharedPreferences
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Fetch user assets from /user/v1/user endpoint
  static Future<Map<String, dynamic>> getUserAssets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        return {
          'success': false,
          'error': 'Authentication required',
        };
      }

      debugPrint('Fetching user assets from: https://api11.hathmetech.com/api/user/v1/user');
      final response = await http.get(
        Uri.parse('https://api11.hathmetech.com/api/user/v1/user'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('User Assets API Response Status: ${response.statusCode}');
      debugPrint('User Assets API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final userData = data['data'];
          // Extract assets from user data
          final assets = userData['assets'] ?? userData['wallet'] ?? userData['balances'] ?? {};
          return {
            'success': true,
            'data': assets,
            'userData': userData,
          };
        } else {
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to fetch user assets',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching user assets: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  Color getKYCStatusColor() {
    switch (_kycStatus) {
      case 'Completed': return const Color(0xFF84BD00);
      case 'Pending': return Colors.orange;
      case 'Rejected': return Colors.red;
      default: return Colors.grey;
    }
  }
}
