import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'kyc_service.dart';
import 'auth_service.dart';
import 'network_error_handler.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  static UserService get instance => _instance;

  // KYC completion notification stream
  static final StreamController<void> _kycCompletionController =
      StreamController<void>.broadcast();
  static Stream<void> get kycCompletionStream =>
      _kycCompletionController.stream;

  // Referral data cache
  static Map<String, dynamic>? _cachedReferralData;

  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';
  static const String _userIdKey = 'user_id';
  static const String _signUpTimeKey = 'sign_up_time';
  static const String _lastLoginKey = 'last_login';
  static const String _kycStatusKey = 'kyc_status';
  static const String _kycSubmittedAtKey = 'kyc_submitted_at';
  static const String _kycRejectionReasonKey = 'kyc_rejection_reason';

  static const String _ipAddressKey = 'ip_address';

  static const String _userPhoneKey = 'user_phone';
  static const String _userCountryKey = 'user_country';
  static const String _userStateKey = 'user_state';
  static const String _userCityKey = 'user_city';
  static const String _userCountryCodeKey = 'user_country_code';
  static const String _referralCodeKey = 'referral_code';

  String? _userName;
  String? _userEmail;
  String? _userId;
  String? _signUpTime;
  String? _lastLogin;
  String _kycStatus = 'Not Started';
  String? _kycSubmittedAt;
  String? _kycRejectionReason;

  String? _ipAddress;
  String? _userPhone;
  String? _userCountry;
  String? _userState;
  String? _userCity;
  String? _userCountryCode;
  String? _referralCode;
  bool? _documentImageVerified;
  int? _selfieStatusValue;
  bool _isFetchingLocationNames = false;

  // Getters
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get userId => _userId;
  String? get signUpTime => _signUpTime;
  String? get lastLogin => _lastLogin;
  String get kycStatus {
    print('🔧 USER SERVICE: KYC status getter called, returning "$_kycStatus"');
    return _kycStatus;
  }

  String? get kycSubmittedAt => _kycSubmittedAt;
  String? get kycRejectionReason => _kycRejectionReason;
  String? get ipAddress => _ipAddress;
  String? get userPhone => _userPhone;
  String? get userCountry => (_userCountry != null && _isObjectId(_userCountry!)) ? null : _userCountry;
  String? get userState => (_userState != null && _isObjectId(_userState!)) ? null : _userState;
  String? get userCity => (_userCity != null && _isObjectId(_userCity!)) ? null : _userCity;
  String? get userCountryCode => _userCountryCode;
  String? get referralCode => _referralCode;
  bool get isFetchingLocationNames => _isFetchingLocationNames;
  bool get documentImageVerified => _documentImageVerified ?? false;
  bool get shouldResumeKYCAtSelfieStep {
    // IMPORTANT: If KYC is rejected, user must restart from DigiLocker (not selfie)
    if (_kycStatus == 'Rejected') {
      return false;
    }
    
    final documentVerified = _documentImageVerified == true;
    final selfieStatus = _selfieStatusValue;
    final needsSelfieRetry = selfieStatus == 0 || selfieStatus == 3;
    return documentVerified && needsSelfieRetry;
  }

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

  // Helper to check if a value looks like a MongoDB ObjectID (24 hex characters)
  bool _isObjectId(String value) {
    return RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(value);
  }

  // Initialize user data from SharedPreferences
  Future<void> initUserData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load from local storage first for immediate display
    _userName = _getSafeString(prefs, _userNameKey);
    _userEmail = _getSafeString(prefs, _userEmailKey);
    _userId = _getSafeString(prefs, _userIdKey);
    _signUpTime = _getSafeString(prefs, _signUpTimeKey);

    // Debug: Log UID loaded from SharedPreferences
    debugPrint('🔍 INIT USER DATA DEBUG:');
    debugPrint('UID loaded from SharedPreferences: $_userId');
    debugPrint('UID length from SharedPreferences: ${_userId?.length}');
    _lastLogin = _getSafeString(prefs, _lastLoginKey);
    _kycStatus = _getSafeString(prefs, _kycStatusKey) ?? 'Not Started';
    _kycSubmittedAt = _getSafeString(prefs, _kycSubmittedAtKey);
    _kycRejectionReason = _getSafeString(prefs, _kycRejectionReasonKey);
    _ipAddress = _getSafeString(prefs, _ipAddressKey);
    _userPhone = _getSafeString(prefs, _userPhoneKey);
    _userCountry = _getSafeString(prefs, _userCountryKey);
    _userState = _getSafeString(prefs, _userStateKey);
    _userCity = _getSafeString(prefs, _userCityKey);
    _userCountryCode = _getSafeString(prefs, _userCountryCodeKey);
    _referralCode = _getSafeString(prefs, _referralCodeKey);

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

    // Check if referral code is already stored in SharedPreferences
    final storedReferralCode = _getSafeString(prefs, _referralCodeKey);
    if (storedReferralCode != null && storedReferralCode.isNotEmpty) {
      _referralCode = storedReferralCode;
      debugPrint(
        '✅ Referral code loaded from SharedPreferences: $_referralCode',
      );
    } else {
      debugPrint('⚠️ No referral code found in SharedPreferences');
    }

    // Fetch referral code
    fetchReferralCode();
  }

  // Force refresh user data from API and clear cached UID
  Future<void> forceRefreshUserData() async {
    debugPrint('🔄 FORCE REFRESH USER DATA - Clearing cached UID...');
    final prefs = await SharedPreferences.getInstance();

    // Clear cached user ID to force refresh from API
    await prefs.remove(_userIdKey);
    _userId = null;

    debugPrint('🔄 Cleared cached UID, fetching fresh data from API...');
    await fetchProfileDataFromAPI();

    debugPrint('🔄 Force refresh completed. New UID: $_userId');
  }

  void _parseAuthData(Map<String, dynamic> userData) {
    // Always update name and email if present in auth data
    if (userData['name'] != null) _userName = userData['name'].toString();
    if (userData['email'] != null) _userEmail = userData['email'].toString();

    // Always update phone if present (handle multiple field names)
    final phone =
        userData['phone'] ??
        userData['mobile'] ??
        userData['phoneNumber'] ??
        userData['mobileNumber'];
    if (phone != null) _userPhone = phone.toString();

    // Debug: Log all possible UID fields from auth data
    debugPrint('🔍 AUTH DATA UID EXTRACTION DEBUG:');
    debugPrint('userData[_id]: ${userData['_id']}');
    debugPrint('userData[id]: ${userData['id']}');
    debugPrint('userData[userId]: ${userData['userId']}');
    debugPrint('All userData keys: ${userData.keys.toList()}');

    String? authUserId =
        userData['userId']?.toString() ??
        userData['_id']?.toString() ??
        userData['id']?.toString();
    debugPrint('🔍 Extracted authUserId: $authUserId');

    if (authUserId != null) {
      _userId = authUserId;
      debugPrint('✅ UID set from auth data: $_userId');
    } else {
      debugPrint('❌ No UID found in auth data');
    }

    // Extract referral code
    final refCode =
        userData['userReferralCode']?.toString() ??
        userData['referralCode']?.toString() ??
        userData['referral_code']?.toString();
    if (refCode != null && refCode.isNotEmpty) {
      _referralCode = refCode;
      debugPrint('✅ Referral Code set from auth data: $_referralCode');
    }

    if (_signUpTime == null) {
      String? createdAt =
          userData['createdAt']?.toString() ??
          userData['signUpTime']?.toString();
      if (createdAt != null) {
        _signUpTime = _formatDate(createdAt);
      }
    }

    // Extract KYC status - try multiple possible locations
    debugPrint('=== _parseAuthData: Checking KYC fields ===');
    debugPrint('All keys in userData: ${userData.keys.toList()}');

    final kycObj = userData['kyc'];
    if (kycObj is Map) {
      debugPrint('✅ Found nested kyc object: $kycObj');
      _parseKYCFromObject(Map<String, dynamic>.from(kycObj));
    } else {
      // Fallback: Check for flat KYC status fields
      String? rawKycStatus =
          userData['kycStatus']?.toString() ??
          userData['kyc_status']?.toString() ??
          userData['kyc_completed']?.toString();

      if (rawKycStatus != null && rawKycStatus.isNotEmpty) {
        debugPrint('✅ Found flat KYC status field: "$rawKycStatus"');
        _kycStatus = _mapKycStatusFromAuthObject(rawKycStatus);
      } else {
        debugPrint(
          '⚠️ No KYC data found in current auth/profile object. Relying on specialized status check.',
        );
      }
    }

    debugPrint('Final KYC Status: "$_kycStatus"');
    debugPrint('=====================================');
  }

  /// Parse KYC status from kyc object with multiple fields:
  /// - kycCompleted: 1 = in progress, 2 = completed, 3 = rejected
  /// - documentImageVerified: true/false
  /// - selfieVerified: true/false
  /// - selfiestatus: 0 = not checked, 1 = pending, 3 = rejected
  void _parseKYCFromObject(Map<String, dynamic> kycObj) {
    debugPrint('🔴🔴🔴 _parseKYCFromObject CALLED WITH: $kycObj');
    
    // Extract fields from kyc object
    final kycCompleted = kycObj['kycCompleted'];
    final documentImageVerified = kycObj['documentImageVerified'];
    final selfieVerified = kycObj['selfieVerified'];
    final selfieStatus = kycObj['selfieStatus'] ?? kycObj['selfiestatus'];
    final kycStatus =
        kycObj['kycStatus']?.toString() ?? kycObj['status']?.toString();
    final rejection = kycObj['rejection'];

    debugPrint('🔴🔴🔴 EXTRACTED VALUES:');
    debugPrint('  kycCompleted: $kycCompleted (type: ${kycCompleted.runtimeType})');
    debugPrint('  documentImageVerified: $documentImageVerified (type: ${documentImageVerified.runtimeType})');
    debugPrint('  selfieVerified: $selfieVerified (type: ${selfieVerified.runtimeType})');
    debugPrint('  selfieStatus: $selfieStatus (type: ${selfieStatus.runtimeType})');
    debugPrint('  kycStatus string: $kycStatus');
    debugPrint('  rejection: $rejection');

    _documentImageVerified = documentImageVerified == true;
    _selfieStatusValue = selfieStatus is int
        ? selfieStatus
        : int.tryParse(selfieStatus?.toString() ?? '');

    debugPrint('  _documentImageVerified set to: $_documentImageVerified');
    debugPrint('  _selfieStatusValue set to: $_selfieStatusValue');

    String determinedStatus = 'Not Started';

    // Logic to determine KYC status based on multiple fields
    if (kycCompleted != null) {
      debugPrint('🔵 kycCompleted is NOT null, checking conditions...');
      
      // kycCompleted === 2 → Completed (highest priority)
      if (kycCompleted == 2) {
        determinedStatus = 'Completed';
        debugPrint('✅✅✅ KYC Status: COMPLETED (kycCompleted=2)');
      }
      // kycCompleted === 1 → In progress, check other fields
      else if (kycCompleted == 1) {
        debugPrint('🟡 kycCompleted=1, checking sub-conditions...');
        
        // PRIORITY 1: Check for name mismatch rejection FIRST (highest priority - should always show)
        if (rejection != null && rejection is Map<String, dynamic>) {
          final rejectionType = rejection['type'];
          final rejectionReason = rejection['reason']?.toString().toLowerCase() ?? '';
          
          // Special case: Name mismatch rejection should be shown even if documents are verified
          if (rejectionType != null && rejectionReason.contains('name')) {
            determinedStatus = 'Rejected';
            _kycRejectionReason = rejection['reason']?.toString();
            debugPrint('❌❌❌ KYC Status: REJECTED (name mismatch rejection - HIGHEST PRIORITY)');
          }
          // PRIORITY 2: Document verified + selfie uploaded (pending admin review)
          else if (documentImageVerified == true && selfieStatus == 1) {
            determinedStatus = 'Pending';
            debugPrint(
              '🟠🟠🟠 KYC Status: PENDING ADMIN APPROVAL (document verified + selfie uploaded, selfieStatus=1) - FRESH SUBMISSION',
            );
          }
          // Document verified but selfie not uploaded yet - should allow selfie upload
          else if (documentImageVerified == true && (selfieStatus == null || selfieStatus == 0)) {
            determinedStatus = 'Pending';
            debugPrint('🟠🟠🟠 KYC Status: PENDING (document verified, awaiting selfie, selfieStatus=$selfieStatus) - SKIPPING REJECTION');
          }
          // Other rejections only if documents not verified
          else if (documentImageVerified != true) {
            determinedStatus = 'Rejected';
            _kycRejectionReason = rejection['reason']?.toString() ?? 'Unknown';
            debugPrint('❌❌❌ KYC Status: REJECTED (rejection.type=$rejectionType, reason=$_kycRejectionReason, documents not verified)');
          }
        }
        // PRIORITY 2: Document verified + selfie uploaded (pending admin review)
        else if (documentImageVerified == true && selfieStatus == 1) {
          determinedStatus = 'Pending';
          debugPrint(
            '🟠🟠🟠 KYC Status: PENDING ADMIN APPROVAL (document verified + selfie uploaded, selfieStatus=1) - FRESH SUBMISSION',
          );
        }
        // Document verified but selfie not uploaded yet - should allow selfie upload
        else if (documentImageVerified == true && (selfieStatus == null || selfieStatus == 0)) {
          determinedStatus = 'Pending';
          debugPrint('🟠🟠🟠 KYC Status: PENDING (document verified, awaiting selfie, selfieStatus=$selfieStatus)');
        }
        // PRIORITY 3: selfieStatus === 3 → Selfie was rejected
        else if (selfieStatus == 3) {
          determinedStatus = 'Rejected';
          debugPrint('❌❌❌ KYC Status: REJECTED (selfieStatus=3)');
        }
        // Document not verified yet
        else {
          determinedStatus = 'Pending';
          debugPrint(
            '🟠🟠🟠 KYC Status: PENDING (document verification in progress)',
          );
        }
      }
      // kycCompleted === 3 → Rejected
      else if (kycCompleted == 3) {
        determinedStatus = 'Rejected';
        _kycRejectionReason = rejection?['reason']?.toString();
        debugPrint('❌❌❌ KYC Status: REJECTED (kycCompleted=3)');
      }
      // Check if rejection object exists (special case for name mismatch)
      else if (rejection != null && rejection is Map<String, dynamic>) {
        final rejectionType = rejection['type'];
        final rejectionReason = rejection['reason']?.toString().toLowerCase() ?? '';
        
        // Special case: Name mismatch rejection should be shown even if documents are verified
        if (rejectionType != null && rejectionReason.contains('name mismatch')) {
          determinedStatus = 'Rejected';
          _kycRejectionReason = rejection['reason']?.toString();
          debugPrint('❌❌❌ KYC Status: REJECTED (name mismatch rejection - special case, showing rejection)');
        }
        // Other rejections only if documents not verified
        else if (documentImageVerified != true) {
          determinedStatus = 'Rejected';
          _kycRejectionReason = rejection['reason']?.toString() ?? 'Unknown';
          debugPrint('❌❌❌ KYC Status: REJECTED (rejection object present - Reason: $_kycRejectionReason, documents not verified)');
        }
        // If documents are verified and no name mismatch, treat as pending for selfie upload
        else if (documentImageVerified == true) {
          determinedStatus = 'Pending';
          debugPrint('🟠🟠🟠 KYC Status: PENDING (document verified, allowing selfie upload - ignoring rejection)');
        }
      }
      // If documents are verified but we reached here, treat as pending for selfie upload
      else if (documentImageVerified == true) {
        determinedStatus = 'Pending';
        debugPrint('🟠🟠🟠 KYC Status: PENDING (document verified, allowing selfie upload - ignoring rejection)');
      }
      else {
        debugPrint('⚠️ kycCompleted has unexpected value: $kycCompleted');
      }
    }
    // Fallback: Use kycStatus string if numeric fields are not available
    else if (kycStatus != null && kycStatus.isNotEmpty) {
      debugPrint('🔵 kycCompleted is null, using kycStatus string: "$kycStatus"');
      determinedStatus = _mapKycStatusFromAuthObject(kycStatus);
      debugPrint(
        '✅ KYC Status: Using kycStatus string "$kycStatus" → "$determinedStatus"',
      );
    }
    else {
      debugPrint('⚠️⚠️⚠️ No kycCompleted or kycStatus found, defaulting to Not Started');
    }

    // Update the KYC status
    _kycStatus = determinedStatus;
    debugPrint('🔴🔴🔴 _parseKYCFromObject: FINAL KYC Status = "$_kycStatus"');
    debugPrint('================================================================================');
  }

  /// Maps a raw KYC status string coming from the auth/profile user object to
  /// the canonical display value used throughout the app.
  /// Mirrors the logic in AuthService._mapKycStatus().
  String _mapKycStatusFromAuthObject(String rawStatus) {
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

  String _formatDate(String dateStr) {
    try {
      DateTime parsedDate = DateTime.parse(dateStr);
      return '${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year} | ${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')}:${parsedDate.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _refreshDataFromAPI() async {
    // Fetch profile data from /auth/me endpoint (includes kycStatus object)
    await fetchProfileDataFromAPI();
  }

  // Fetch real profile data from API
  Future<void> fetchProfileDataFromAPI() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      debugPrint('🔵 fetchProfileDataFromAPI: Starting...');
      debugPrint('🔵 Token exists: ${token != null}');

      if (token != null) {
        final response = await http
            .get(
              Uri.parse('https://api11.hathmetech.com/api/user/v1/auth/me'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: 10));

        debugPrint('🔵 /auth/me Response Status: ${response.statusCode}');
        debugPrint('🔵 /auth/me Response Body: ${response.body}');

        // Handle rate limit error (429)
        if (response.statusCode == 429) {
          debugPrint('⚠️ Rate limit reached (429) - keeping existing KYC status');
          // Try to parse error message from response
          try {
            final errorData = json.decode(response.body);
            final errorMsg = errorData['message'] ?? errorData['error'] ?? 'Rate limit exceeded';
            debugPrint('⚠️ Rate limit message: $errorMsg');
            // Don't update KYC status when rate limited - keep existing status
            return;
          } catch (e) {
            debugPrint('⚠️ Could not parse rate limit error: $e');
            return;
          }
        }

        // Handle other error status codes
        if (response.statusCode != 200) {
          debugPrint('⚠️ Non-200 status code: ${response.statusCode} - keeping existing KYC status');
          return;
        }

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          debugPrint('🔵 Response success: ${responseData['success']}');

          if (responseData['success'] == true) {
            // Extract user data from response
            final profileData = responseData['user'] ?? responseData['data'];

            if (profileData != null) {
              debugPrint('🔵 User data found: ${profileData.keys.toList()}');

              // Save the full user data object for initUserData() consistency
              await prefs.setString('user_data', json.encode(profileData));
            }

            // Always update name and email with latest API data
            if (profileData['name'] != null) {
              _userName = profileData['name'].toString();
              await prefs.setString(_userNameKey, _userName!);
            }
            if (profileData['email'] != null) {
              _userEmail = profileData['email'].toString();
              await prefs.setString(_userEmailKey, _userEmail!);
            }

            // Debug: Log all possible UID fields from API response
            debugPrint('🔍 UID EXTRACTION DEBUG:');
            debugPrint('profileData[_id]: ${profileData['_id']}');
            debugPrint('profileData[id]: ${profileData['id']}');
            debugPrint('profileData[userId]: ${profileData['userId']}');
            debugPrint('All profileData keys: ${profileData.keys.toList()}');

            String? profileUserId =
                profileData['userId']?.toString() ??
                profileData['_id']?.toString() ??
                profileData['id']?.toString();
            debugPrint('🔍 Extracted profileUserId: $profileUserId');

            if (profileUserId != null) {
              _userId = profileUserId;
              await prefs.setString(_userIdKey, _userId!);
              debugPrint('✅ UID saved: $_userId');
            } else {
              debugPrint('❌ No UID found in profile data');
            }

            if (profileData['createdAt'] != null) {
              _signUpTime = _formatDate(profileData['createdAt'].toString());
              await prefs.setString(_signUpTimeKey, _signUpTime!);
            }

            if (profileData['lastLogin'] != null ||
                profileData['last_login'] != null) {
              String lastLoginStr =
                  profileData['lastLogin']?.toString() ??
                  profileData['last_login']?.toString() ??
                  '';
              if (lastLoginStr.isNotEmpty) {
                _lastLogin = _formatDate(lastLoginStr);
                await prefs.setString(_lastLoginKey, _lastLogin!);
              }
            }

            // Parse new profile fields
            final phone =
                profileData['phone'] ??
                profileData['mobile'] ??
                profileData['phoneNumber'] ??
                profileData['mobileNumber'];
            if (phone != null) {
              _userPhone = phone.toString();
              await prefs.setString(_userPhoneKey, _userPhone!);
            }

            // Fix country code synchronization - try multiple field names and ensure consistency
            String? countryCodeValue =
                profileData['country_code']?.toString() ??
                profileData['countryCode']?.toString() ??
                profileData['countryCode']?.toString() ??
                profileData['dial_code']?.toString() ??
                profileData['dialCode']?.toString();

            if (countryCodeValue != null && countryCodeValue.isNotEmpty) {
              // Ensure country code starts with +
              if (!countryCodeValue.startsWith('+')) {
                countryCodeValue = '+$countryCodeValue';
              }
              _userCountryCode = countryCodeValue;
              await prefs.setString(_userCountryCodeKey, _userCountryCode!);
              debugPrint('✅ Country Code saved: $_userCountryCode');
            }

            // Debug: Log all location-related fields from API response
            debugPrint('📍 LOCATION FIELDS FROM API:');
            debugPrint('Country: ${profileData['country']}');
            debugPrint('State: ${profileData['state']}');
            debugPrint('City: ${profileData['city']}');
            debugPrint('Country ID: ${profileData['countryId']}');
            debugPrint('Country Name: ${profileData['countryName']}');
            debugPrint('State Name: ${profileData['stateName']}');
            debugPrint('City Name: ${profileData['cityName']}');
            debugPrint('Location object: ${profileData['location']}');
            debugPrint('Address object: ${profileData['address']}');
            debugPrint('All profile data keys: ${profileData.keys.toList()}');

            // Save countryId for location name fetching and sync country names
            final countryIdValue =
                profileData['countryId'] ?? profileData['country_id'];
            if (countryIdValue != null) {
              await prefs.setString('countryId', countryIdValue.toString());
              debugPrint('✅ Country ID saved: $countryIdValue');

              // Immediately fetch country name if we have the ID but no name
              if ((_userCountry == null || _userCountry!.isEmpty) &&
                  countryIdValue.toString().isNotEmpty) {
                await _fetchCountryNameById(countryIdValue.toString());
              }
            }

            // Try multiple possible field names for country with better synchronization
            final countryValue =
                profileData['country'] ??
                profileData['countryName'] ??
                profileData['country_name'] ??
                profileData['country_name'] ??
                profileData['location']?['country'] ??
                profileData['address']?['country'] ??
                profileData['country_name'] ?? // Additional fallback
                profileData['countryName']; // Additional fallback

            if (countryValue != null && countryValue.toString().isNotEmpty) {
              _userCountry = countryValue.toString();
              await prefs.setString(_userCountryKey, _userCountry!);
              debugPrint('✅ Country saved: $_userCountry');
            }

            // Try multiple possible field names for state
            final stateValue =
                profileData['state'] ??
                profileData['stateName'] ??
                profileData['state_name'] ??
                profileData['region'] ??
                profileData['location']?['state'] ??
                profileData['address']?['state'];
            if (stateValue != null) {
              _userState = stateValue.toString();
              await prefs.setString(_userStateKey, _userState!);
              debugPrint('✅ State saved: $_userState');
            }

            // Try multiple possible field names for city
            final cityValue =
                profileData['city'] ??
                profileData['cityName'] ??
                profileData['city_name'] ??
                profileData['location']?['city'] ??
                profileData['address']?['city'];
            if (cityValue != null) {
              _userCity = cityValue.toString();
              await prefs.setString(_userCityKey, _userCity!);
              debugPrint('✅ City saved: $_userCity');
            }

            // Extract and save referral code
            final apiRefCode =
                profileData['userReferralCode']?.toString() ??
                profileData['referralCode']?.toString() ??
                profileData['referral_code']?.toString();
            if (apiRefCode != null && apiRefCode.isNotEmpty) {
              _referralCode = apiRefCode;
              await prefs.setString(_referralCodeKey, _referralCode!);
              debugPrint('✅ Referral Code saved from /auth/me: $_referralCode');
            }

            if (_userName != null)
              await prefs.setString(_userNameKey, _userName!);
            if (_userEmail != null)
              await prefs.setString(_userEmailKey, _userEmail!);
            if (_userId != null) await prefs.setString(_userIdKey, _userId!);

            // ALWAYS fetch KYC status from top-level kycStatus object in /auth/me response
            // This is the source of truth for KYC status
            debugPrint('🔍🔍🔍 FULL /auth/me RESPONSE DATA: $responseData');
            debugPrint('🔍🔍🔍 PROFILE DATA: $profileData');
            debugPrint('🔍🔍🔍 PROFILE DATA KEYS: ${profileData.keys.toList()}');
            
            final kycStatusObj = responseData['kycStatus'];
            debugPrint('🔍🔍🔍 TOP-LEVEL kycStatus object: $kycStatusObj');
            
            // Check for kyc field in user object
            final userKycObj = profileData['kyc'];
            debugPrint('🔍🔍🔍 USER OBJECT kyc field: $userKycObj');
            
            // Check for status field in user object (might be KYC status)
            final userStatus = profileData['status'];
            debugPrint('🔍🔍🔍 USER OBJECT status field: $userStatus (type: ${userStatus.runtimeType})');
            
            if (kycStatusObj is Map) {
              debugPrint('🟢 Found top-level kycStatus object: $kycStatusObj');
              _parseKYCFromObject(Map<String, dynamic>.from(kycStatusObj));
              
              // CRITICAL FIX: Ensure top-level status overrides if it's "Completed"
              final responseStatus = (responseData['status'] ?? '').toString().toLowerCase();
              if (responseStatus == 'already_completed' || responseStatus == 'completed' || responseStatus == 'verified' || responseStatus == 'approved') {
                debugPrint('✅ FORCE OVERRIDE: Setting status to Completed based on top-level API status: $responseStatus');
                _kycStatus = 'Completed';
              }
            } else if (userKycObj is Map) {
              debugPrint('🟡 Found kyc object in user data: $userKycObj');
              _parseKYCFromObject(Map<String, dynamic>.from(userKycObj));
            } else {
              // Fallback: Parse KYC status from user object fields
              debugPrint('🟡 No kycStatus or kyc object found, parsing from user fields...');
              _parseAuthData(profileData);
              
              // CRITICAL: Fetch KYC status from dedicated endpoint since /auth/me doesn't include it
              debugPrint('🔵🔵🔵 Fetching KYC status from /kyc/status endpoint...');
              final kycStatusResult = await checkKYCStatusPost();
              debugPrint('🔵🔵🔵 KYC Status API Result: $kycStatusResult');
              
              if (kycStatusResult['success'] == true) {
                final kycData = kycStatusResult['data'];
                if (kycData is Map) {
                  debugPrint('🟢🟢🟢 Parsing KYC status from /kyc/status endpoint');
                  _parseKYCFromObject(Map<String, dynamic>.from(kycData));
                } else {
                  // Use the validated status from checkKYCStatusPost
                  final validatedStatus = kycStatusResult['status']?.toString() ?? 'Not Started';
                  debugPrint('🟡🟡🟡 Using validated status from API: $validatedStatus');
                  _kycStatus = validatedStatus;
                }
              } else {
                debugPrint('⚠️⚠️⚠️ Failed to fetch KYC status: ${kycStatusResult['error']}');
              }
            }

            // Save KYC status to SharedPreferences
            await prefs.setString(_kycStatusKey, _kycStatus);
            if (_kycRejectionReason != null) {
              await prefs.setString(_kycRejectionReasonKey, _kycRejectionReason!);
            }
            debugPrint('✅ Final KYC Status: "$_kycStatus", Rejection Reason: "$_kycRejectionReason"');

            // Fetch location names from IDs
            await _fetchLocationNames();
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
        final response = await http
            .get(
              Uri.parse(
                'https://api11.hathmetech.com/api/user/v1/auth/loginactivity/$_userId',
              ),
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
            String? loginTime =
                latestActivity['loginTime']?.toString() ??
                latestActivity['login_time']?.toString();
            if (loginTime != null) {
              _lastLogin = _formatDate(loginTime);
              await prefs.setString(_lastLoginKey, _lastLogin!);
            }

            // Get IP address from login activity
            String? ip =
                latestActivity['ipAddress']?.toString() ??
                latestActivity['ip']?.toString();
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

  // Fetch referral code from API
  Future<void> fetchReferralCode({Function()? onReferralCodeLoaded}) async {
    try {
      debugPrint('🔵 Fetching referral code...');
      debugPrint('🔍 Current _referralCode: $_referralCode');
      debugPrint(
        '🔍 _cachedReferralData exists: ${_cachedReferralData != null}',
      );

      // First try to get from cached referral data
      if (_cachedReferralData != null) {
        debugPrint(
          '🔍 Cached data keys: ${_cachedReferralData!.keys.toList()}',
        );
        final cachedCode =
            _cachedReferralData!['referralCode']?.toString() ??
            _cachedReferralData!['userReferralCode']?.toString() ??
            _cachedReferralData!['referral_code']?.toString() ??
            _cachedReferralData!['code']?.toString();
        debugPrint('🔍 Cached code extracted: $cachedCode');
        if (cachedCode != null && cachedCode.isNotEmpty) {
          _referralCode = cachedCode;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_referralCodeKey, _referralCode!);
          debugPrint('✅ Referral code from cache: $_referralCode');
          onReferralCodeLoaded?.call();
          return;
        } else {
          debugPrint('⚠️ Cached code is null or empty');
        }
      } else {
        debugPrint('⚠️ No cached referral data available');
      }

      // If not in cache, fetch from API
      final result = await getReferralData();
      if (result['success'] == true && result['data'] != null) {
        final referralData = result['data'];
        debugPrint('🔍 API referral data: $referralData');

        // Try multiple possible field names for referral code
        final apiReferralCode =
            referralData['referralCode']?.toString() ??
            referralData['userReferralCode']?.toString() ??
            referralData['referral_code']?.toString() ??
            referralData['code']?.toString();

        if (apiReferralCode != null && apiReferralCode.isNotEmpty) {
          _referralCode = apiReferralCode;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_referralCodeKey, _referralCode!);
          debugPrint('✅ Referral code fetched from API: $_referralCode');
          onReferralCodeLoaded?.call();
          return;
        }
      }

      // If API doesn't return a referral code, generate a fallback
      if (_referralCode == null || _referralCode!.isEmpty) {
        _referralCode = _generateFallbackReferralCode();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_referralCodeKey, _referralCode!);
        debugPrint('✅ Generated fallback referral code: $_referralCode');
        onReferralCodeLoaded?.call();
      }
    } catch (e) {
      debugPrint('Error fetching referral code: $e');
      // Generate fallback code on error
      if (_referralCode == null || _referralCode!.isEmpty) {
        _referralCode = _generateFallbackReferralCode();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_referralCodeKey, _referralCode!);
        debugPrint(
          '✅ Generated fallback referral code on error: $_referralCode',
        );
        onReferralCodeLoaded?.call();
      }
    }
  }

  // Generate fallback referral code based on username or user ID
  String _generateFallbackReferralCode() {
    if (_userName != null && _userName!.isNotEmpty) {
      // Use username, convert to uppercase and remove spaces
      return _userName!.toUpperCase().replaceAll(' ', '');
    } else if (_userId != null && _userId!.isNotEmpty) {
      // Use last 8 characters of user ID
      return _userId!.substring(_userId!.length - 8).toUpperCase();
    } else if (_userEmail != null && _userEmail!.isNotEmpty) {
      // Use part of email before @
      final emailPart = _userEmail!.split('@')[0];
      return emailPart.toUpperCase();
    } else {
      // Generate random code
      return 'USER${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    }
  }

  // Debug method to test referral code loading
  Future<void> debugReferralCode() async {
    debugPrint('=== DEBUGGING REFERRAL CODE ===');
    debugPrint('Current _referralCode: $_referralCode');

    final prefs = await SharedPreferences.getInstance();
    final storedCode = _getSafeString(prefs, _referralCodeKey);
    debugPrint('Stored in SharedPreferences: $storedCode');

    debugPrint('_cachedReferralData exists: ${_cachedReferralData != null}');
    if (_cachedReferralData != null) {
      debugPrint('Cached data keys: ${_cachedReferralData!.keys.toList()}');
      debugPrint(
        'Cached referralCode: ${_cachedReferralData!['referralCode']}',
      );
      debugPrint(
        'Cached userReferralCode: ${_cachedReferralData!['userReferralCode']}',
      );
    }

    // Try to fetch from API directly
    debugPrint('Fetching from API...');
    final result = await getReferralData();
    debugPrint('API result: $result');

    if (result['success'] == true && result['data'] != null) {
      final data = result['data'];
      debugPrint('API data keys: ${data.keys.toList()}');
      debugPrint('API userReferralCode: ${data['userReferralCode']}');
      debugPrint('API referralCode: ${data['referralCode']}');
    }

    debugPrint('=== END DEBUG ===');
  }

  // Auto-sync country code based on country name
  Future<void> _syncCountryCodeWithCountryName() async {
    if (_userCountry == null || _userCountry!.isEmpty) return;

    // Enhanced country code mapping with multiple name variations
    final countryMapping = {
      // Major countries with multiple name variations
      'India': '+91',
      'United States': '+1',
      'USA': '+1',
      'United States of America': '+1',
      'UK': '+44',
      'United Kingdom': '+44',
      'Australia': '+61',
      'China': '+86',
      'Japan': '+81',
      'Germany': '+49',
      'France': '+33',
      'UAE': '+971',
      'United Arab Emirates': '+971',
      'Singapore': '+65',
      'South Korea': '+82',
      'Korea': '+82',
      'Russia': '+7',
      'Italy': '+39',
      'Spain': '+34',
      'Brazil': '+55',

      // Additional countries
      'Canada': '+1',
      'Mexico': '+52',
      'Argentina': '+54',
      'Chile': '+56',
      'Peru': '+51',
      'Colombia': '+57',
      'Venezuela': '+58',

      // European countries
      'Netherlands': '+31',
      'Holland': '+31',
      'Belgium': '+32',
      'Switzerland': '+41',
      'Austria': '+43',
      'Sweden': '+46',
      'Norway': '+47',
      'Denmark': '+45',
      'Finland': '+358',
      'Poland': '+48',
      'Portugal': '+351',
      'Greece': '+30',
      'Ireland': '+353',
      'Iceland': '+354',

      // Asian countries
      'Pakistan': '+92',
      'Bangladesh': '+880',
      'Sri Lanka': '+94',
      'Nepal': '+977',
      'Malaysia': '+60',
      'Thailand': '+66',
      'Vietnam': '+84',
      'Philippines': '+63',
      'Indonesia': '+62',
      'Hong Kong': '+852',
      'Taiwan': '+886',

      // Middle East
      'Saudi Arabia': '+966',
      'Qatar': '+974',
      'Kuwait': '+965',
      'Bahrain': '+973',
      'Oman': '+968',
      'Israel': '+972',
      'Turkey': '+90',

      // African countries
      'South Africa': '+27',
      'Egypt': '+20',
      'Nigeria': '+234',
      'Kenya': '+254',
      'Morocco': '+212',
      'Tunisia': '+216',
      'Algeria': '+213',

      // Oceanic countries
      'New Zealand': '+64',

      // Misc
      'Iran': '+98',
      'Iraq': '+964',
      'Afghanistan': '+93',
    };

    // Try exact match first
    String? countryCode = countryMapping[_userCountry];

    // If no exact match, try case-insensitive search
    if (countryCode == null) {
      for (String key in countryMapping.keys) {
        if (key.toLowerCase() == _userCountry!.toLowerCase()) {
          countryCode = countryMapping[key];
          break;
        }
      }
    }

    // If still no match, try partial matching
    if (countryCode == null) {
      final lowerCountryName = _userCountry!.toLowerCase();
      if (lowerCountryName.contains('united states') ||
          lowerCountryName.contains('usa')) {
        countryCode = '+1';
      } else if (lowerCountryName.contains('united kingdom') ||
          lowerCountryName.contains('uk')) {
        countryCode = '+44';
      } else if (lowerCountryName.contains('united arab')) {
        countryCode = '+971';
      }
    }

    if (countryCode != null && countryCode != _userCountryCode) {
      _userCountryCode = countryCode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userCountryCodeKey, _userCountryCode!);
      debugPrint(
        'Auto-synced country code: $countryCode for country: $_userCountry',
      );
    } else if (countryCode == null) {
      debugPrint('No country code found for: $_userCountry');
    }
  }

  // Enhanced error handling method to extract specific error messages
  String _extractSpecificError(Map<String, dynamic> errorData, int statusCode) {
    // Try multiple possible error field names
    final String? message = errorData['message']?.toString();
    final String? error = errorData['error']?.toString();
    final String? detail = errorData['detail']?.toString();
    final String? validationError = errorData['validation_error']?.toString();

    // Handle validation errors with field-specific messages
    if (errorData['errors'] is Map) {
      final errors = errorData['errors'] as Map;
      final errorMessages = <String>[];
      errors.forEach((field, messages) {
        if (messages is List) {
          errorMessages.add('$field: ${messages.join(', ')}');
        } else if (messages is String) {
          errorMessages.add('$field: $messages');
        }
      });
      if (errorMessages.isNotEmpty) {
        return errorMessages.join('; ');
      }
    }

    // Return the most specific error message available
    if (message != null && message.isNotEmpty) return message;
    if (validationError != null && validationError.isNotEmpty)
      return validationError;
    if (error != null && error.isNotEmpty) return error;
    if (detail != null && detail.isNotEmpty) return detail;

    // Fallback to status code specific messages
    switch (statusCode) {
      case 400:
        return 'Invalid request data. Please check your inputs and try again.';
      case 401:
        return 'Authentication expired. Please login again.';
      case 403:
        return 'Access denied. You do not have permission to perform this action.';
      case 404:
        return 'Service not found. Please contact support.';
      case 429:
        return 'KYC limit exceeded. Please try again later or contact support.';
      case 500:
        return 'Server error. Please try again later or contact support.';
      default:
        return 'Request failed with status code $statusCode';
    }
  }

  String _mapStatusToDisplay(String apiStatus) {
    final status = apiStatus.toLowerCase().trim();

    // Only mark as completed if explicitly completed
    if (status == 'completed' || status == 'already_completed') {
      return 'Completed';
    }

    // Handle rejected status
    if (status == 'rejected' || status == 'failed' || status == 'denied') {
      return 'Rejected';
    }

    // Handle pending status (including approved/verified which still need admin review)
    if (status == 'pending' ||
        status == 'submitted' ||
        status == 'processing' ||
        status == 'approved' ||
        status == 'verified') {
      return 'Pending';
    }

    // Handle not started
    if (status == 'not_started' || status == 'not-started') {
      return 'Not Started';
    }

    // Default to not started for any unclear status
    return 'Not Started';
  }

  // Update user email
  Future<void> updateUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    _userEmail = email;
    await prefs.setString(_userEmailKey, email);

    final now = DateTime.now();
    _lastLogin =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} | ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    await prefs.setString(_lastLoginKey, _lastLogin!);
  }

  // Update KYC status
  Future<void> updateKYCStatus(String status, {String? rejectionReason}) async {
    final prefs = await SharedPreferences.getInstance();
    _kycStatus = status;
    await prefs.setString(_kycStatusKey, status);

    if (rejectionReason != null) {
      _kycRejectionReason = rejectionReason;
      await prefs.setString(_kycRejectionReasonKey, rejectionReason);
    }

    if (status == 'Pending') {
      final now = DateTime.now();
      _kycSubmittedAt =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} | ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      await prefs.setString(_kycSubmittedAtKey, _kycSubmittedAt!);
    }
  }

  // Force broadcast KYC completion event (for cases where status is already completed)
  void forceKYCCompletionBroadcast() {
    _kycCompletionController.add(null);
    debugPrint('KYC Completion force broadcasted - All features unlocked!');
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
          'data': result['data'],
        };
      } else {
        return {
          'success': false,
          'error': result['error'] ?? 'Failed to submit KYC',
        };
      }
    } on SocketException catch (e) {
      debugPrint('SocketException in submitKYC: $e');
      return {
        'success': false,
        'error': 'No internet connection. Please check your network and try again.',
        'error_type': 'no_internet',
      };
    } on TimeoutException catch (e) {
      debugPrint('TimeoutException in submitKYC: $e');
      return {
        'success': false,
        'error': 'Connection timed out. Please try again.',
        'error_type': 'timeout',
      };
    } catch (e) {
      debugPrint('Error in submitKYC: $e');
      return {
        'success': false,
        'error': NetworkErrorHandler.getErrorMessage(e),
        'error_type': 'unknown',
      };
    }
  }

  Future<List<String>> getDocumentTypes() async {
    try {
      final result = await KYCService.getDocumentTypes();
      if (result['success'] == true) {
        final data = result['data'];
        if (data is List) return List<String>.from(data);
        if (data is Map && data['types'] is List)
          return List<String>.from(data['types']);
      }
    } catch (e) {
      debugPrint('Failed to get document types: $e');
    }
    return [
      'Passport',
      'National ID',
      'Driver License',
      'Aadhaar Card',
      'Voter ID',
    ];
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
    } on SocketException catch (e) {
      debugPrint('SocketException in validateDocument: $e');
      return {
        'success': false,
        'error': 'No internet connection. Please check your network and try again.',
        'error_type': 'no_internet',
      };
    } on TimeoutException catch (e) {
      debugPrint('TimeoutException in validateDocument: $e');
      return {
        'success': false,
        'error': 'Connection timed out. Please try again.',
        'error_type': 'timeout',
      };
    } catch (e) {
      debugPrint('Error in validateDocument: $e');
      return {
        'success': false,
        'error': NetworkErrorHandler.getErrorMessage(e),
        'error_type': 'unknown',
      };
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
          'data': result['data'],
        };
      } else {
        return {
          'success': false,
          'error': result['error'] ?? 'Failed to verify selfie',
        };
      }
    } on SocketException catch (e) {
      debugPrint('SocketException in verifySelfie: $e');
      return {
        'success': false,
        'error': 'No internet connection. Please check your network and try again.',
        'error_type': 'no_internet',
      };
    } on TimeoutException catch (e) {
      debugPrint('TimeoutException in verifySelfie: $e');
      return {
        'success': false,
        'error': 'Connection timed out. Please try again.',
        'error_type': 'timeout',
      };
    } catch (e) {
      debugPrint('Error in verifySelfie: $e');
      return {
        'success': false,
        'error': NetworkErrorHandler.getErrorMessage(e),
        'error_type': 'unknown',
      };
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
        Uri.parse(
          'https://api11.hathmetech.com/api/user/v1/kyc/kyc-selfie-verify',
        ),
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
          request.files.add(
            http.MultipartFile.fromBytes(
              'selfie',
              bytes,
              filename: 'selfie.jpg',
            ),
          );
        } else {
          final bytes = await selfieImage.readAsBytes();
          final fileName = selfieImage.path.split('/').last;
          request.files.add(
            http.MultipartFile.fromBytes('selfie', bytes, filename: fileName),
          );
        }
      }

      // Send request
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamedResponse);

      print('DigiLocker Selfie Verify Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        // Check for success field or success message
        final bool hasSuccess = responseData['success'] == true;
        final String message =
            responseData['message']?.toString().toLowerCase() ?? '';
        final bool hasSuccessMessage =
            message.contains('successful') || message.contains('uploaded');

        if (hasSuccess || hasSuccessMessage) {
          await updateKYCStatus('Pending');
          return {
            'success': true,
            'message':
                responseData['message'] ?? 'Selfie verified successfully',
            'data': responseData['data'],
          };
        } else {
          return {
            'success': false,
            'error':
                responseData['error'] ??
                responseData['message'] ??
                'Failed to verify selfie',
            'error_type': 'api_error',
          };
        }
      } else if (response.statusCode == 400) {
        // Parse 400 error for specific messages
        try {
          final responseData = json.decode(response.body);
          final errorMsg = responseData['error'] ?? responseData['message'] ?? 'Invalid request';
          return {
            'success': false,
            'error': errorMsg,
            'error_type': 'validation_error',
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Invalid request. Please check your selfie and try again.',
            'error_type': 'validation_error',
          };
        }
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'error': 'KYC service endpoint not found. Please contact support.',
          'error_type': 'not_found',
        };
      } else if (response.statusCode == 429) {
        return {
          'success': false,
          'error': 'Too many requests. Please try again after some time.',
          'error_type': 'rate_limit',
        };
      } else if (response.statusCode == 500) {
        return {
          'success': false,
          'error': 'Server error. Please try again later.',
          'error_type': 'server_error',
        };
      } else {
        // Try to parse error message from response
        try {
          final responseData = json.decode(response.body);
          final errorMsg = responseData['error'] ?? responseData['message'] ?? 'Server error: ${response.statusCode}';
          return {
            'success': false,
            'error': errorMsg,
            'error_type': 'server_error',
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Server error: ${response.statusCode}',
            'error_type': 'server_error',
          };
        }
      }
    } on SocketException catch (e) {
      print('SocketException in verifySelfieFromDigiLocker: $e');
      return {
        'success': false,
        'error': 'No internet connection. Please check your network and try again.',
        'error_type': 'no_internet',
      };
    } on TimeoutException catch (e) {
      print('TimeoutException in verifySelfieFromDigiLocker: $e');
      return {
        'success': false,
        'error': 'Connection timed out. Please try again.',
        'error_type': 'timeout',
      };
    } catch (e) {
      print('DigiLocker Selfie Verify Error: $e');
      return {
        'success': false,
        'error': NetworkErrorHandler.getErrorMessage(e),
        'error_type': 'unknown',
      };
    }
  }

  // Initiate DigiLocker connection
  Future<Map<String, dynamic>> initiateDigiLockerConnection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      if (token.isEmpty) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      // Backend reference for DigiLocker initiate expects auth-driven session setup,
      // with redirect handling configured server-side. Some deployments still accept
      // a redirect_url, so retry with progressively broader payloads if validation fails.
      final payloads = <Map<String, dynamic>>[
        {},
        {'redirect_url': 'creddx://kyc/callback'},
      ];

      final userId = prefs.getString('user_id') ?? '';
      if (userId.isNotEmpty) {
        payloads.add({
          'user_id': userId,
          'redirect_url': 'creddx://kyc/callback',
        });
      }

      Map<String, dynamic>? lastError;

      for (final payload in payloads) {
        final requestBody = json.encode(payload);
        print('DigiLocker Initiate Request Body: $requestBody');
        print(
          'DigiLocker Initiate URL: https://api11.hathmetech.com/api/user/v1/kyc/digilocker/initiate',
        );

        final response = await http
            .post(
              Uri.parse(
                'https://api11.hathmetech.com/api/user/v1/kyc/digilocker/initiate',
              ),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: requestBody,
            )
            .timeout(const Duration(seconds: 30));

        print('DigiLocker Initiate Status Code: ${response.statusCode}');
        print('DigiLocker Initiate Response: ${response.body}');

        final parsedResult = _parseDigiLockerInitiateResponse(response);
        if (parsedResult['success'] == true) {
          return parsedResult;
        }

        lastError = parsedResult;

        final errorText = (parsedResult['error'] ?? '')
            .toString()
            .toLowerCase();
        final isValidationFailure =
            response.statusCode == 400 &&
            (errorText.contains('validation') ||
                errorText.contains('redirect_url') ||
                errorText.contains('user_id'));

        if (!isValidationFailure) {
          return parsedResult;
        }
      }

      return lastError ??
          {'success': false, 'error': 'Failed to initiate DigiLocker'};
    } on SocketException catch (e) {
      print('SocketException in initiateDigiLockerConnection: $e');
      return {
        'success': false,
        'error': 'No internet connection. Please check your network and try again.',
        'error_type': 'no_internet',
      };
    } on TimeoutException catch (e) {
      print('TimeoutException in initiateDigiLockerConnection: $e');
      return {
        'success': false,
        'error': 'Connection timed out. Please try again.',
        'error_type': 'timeout',
      };
    } catch (e) {
      print('DigiLocker Initiate Error: $e');
      return {
        'success': false,
        'error': NetworkErrorHandler.getErrorMessage(e),
        'error_type': 'unknown',
      };
    }
  }

  Map<String, dynamic> _parseDigiLockerInitiateResponse(
    http.Response response,
  ) {
    if (response.statusCode == 200 ||
        response.statusCode == 201 ||
        response.statusCode == 400) {
      final responseData = json.decode(response.body);

      if (response.statusCode == 400 || responseData['success'] == false) {
        print('DigiLocker Validation Error Details:');
        print('  - Success: ${responseData['success']}');
        print('  - Message: ${responseData['message']}');
        print('  - Error: ${responseData['error']}');
        print('  - Data: ${responseData['data']}');
        if (responseData['errors'] != null) {
          print('  - Validation Errors: ${responseData['errors']}');
        }
      }

      if (responseData['success'] == true) {
        return {
          'success': true,
          'data': _normalizeDigiLockerInitiateData(responseData),
          'message': responseData['message'] ?? 'DigiLocker initiated',
          'error': null,
        };
      }

      if (response.statusCode == 400) {
        String errorMsg = responseData['message'] ?? 'Input validation failed';
        if (responseData['errors'] != null) {
          final errors = responseData['errors'];
          if (errors is Map) {
            final errorDetails = errors.entries
                .map((e) => '${e.key}: ${e.value}')
                .join(', ');
            errorMsg = '$errorMsg ($errorDetails)';
          }
        }
        
        // Handle specific session-related errors
        if (errorMsg.toLowerCase().contains('session already active') || 
            errorMsg.toLowerCase().contains('already active')) {
          return {
            'success': false, 
            'error': 'DigiLocker session already active. Please complete the existing session or wait for it to expire.',
            'message': responseData['message'] ?? errorMsg,
            'code': 'SESSION_ALREADY_ACTIVE'
          };
        }
        
        return {
          'success': false, 
          'error': errorMsg,
          'message': responseData['message'] ?? errorMsg
        };
      }

      final errorMsg =
          responseData['error'] ??
          responseData['message'] ??
          'Failed to initiate DigiLocker';
      return {'success': false, 'error': errorMsg};
    }

    String errorDetail = 'Server error: ${response.statusCode}';
    if (response.statusCode == 404) {
      errorDetail = 'KYC service endpoint not found. Please contact support.';
    } else if (response.statusCode == 500) {
      errorDetail = 'Internal server error. Please try again later.';
    } else if (response.statusCode == 429) {
      errorDetail =
          'KYC limit exceeded. Please try again later or contact support.';
    }

    return {'success': false, 'error': errorDetail};
  }

  Map<String, dynamic> _normalizeDigiLockerInitiateData(
    Map<String, dynamic> responseData,
  ) {
    final normalized = <String, dynamic>{};

    void mergeMap(dynamic value) {
      if (value is Map) {
        normalized.addAll(Map<String, dynamic>.from(value));
      }
    }

    mergeMap(responseData['data']);
    mergeMap(responseData['result']);
    mergeMap(responseData['payload']);
    mergeMap(responseData['response']);
    mergeMap(responseData);

    final rawData = responseData['data'];
    if (rawData is String && rawData.isNotEmpty) {
      if (rawData.startsWith('http://') || rawData.startsWith('https://')) {
        normalized.putIfAbsent('url', () => rawData);
      } else {
        normalized.putIfAbsent('token', () => rawData);
      }
    }

    final rawMessage = responseData['message'];
    if (rawMessage is String &&
        (rawMessage.startsWith('http://') ||
            rawMessage.startsWith('https://'))) {
      normalized.putIfAbsent('url', () => rawMessage);
    }

    return normalized;
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

      debugPrint('🔵 checkDigiLockerStatus: Checking status for requestId: $requestId');

      // Use the standard KYC status endpoint instead of DigiLocker-specific one
      // since the DigiLocker status endpoint doesn't exist
      final response = await http
          .post(
            Uri.parse(
              'https://api11.hathmetech.com/api/user/v1/kyc/status',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'user_id': userId,
              'request_id': requestId, // Include request_id for tracking
            }),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('🔵 checkDigiLockerStatus Response Status: ${response.statusCode}');
      debugPrint('🔵 checkDigiLockerStatus Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 400) {
        final responseData = json.decode(response.body);
        
        // Even if success=false, check if we have data with documents
        // This handles cases where backend returns error but documents are present
        if (responseData['data'] != null) {
          debugPrint('🔵 checkDigiLockerStatus: Data present in response');
          return {
            'success': true, // Override success to true if we have data
            'data': responseData['data'],
            'message': responseData['message'] ?? 'Status retrieved',
          };
        }
        
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'],
            'message': responseData['message'] ?? 'Status retrieved',
          };
        } else {
          // Return error but don't fail completely - let WebView handle it
          return {
            'success': false,
            'error': responseData['error'] ?? responseData['message'] ?? 'Failed to get DigiLocker status',
            'data': responseData['data'], // Include data even on error
          };
        }
      } else if (response.statusCode == 404) {
        // Endpoint not found - fallback to profile check
        debugPrint('⚠️ DigiLocker status endpoint not found, using profile data');
        return {
          'success': false,
          'error': 'Endpoint not available',
          'fallback_to_profile': true,
        };
      } else if (response.statusCode == 429) {
        return {
          'success': false,
          'error': 'Rate limit exceeded. Please try again later.',
          'error_type': 'rate_limit',
        };
      } else {
        String errorDetail = 'Server error: ${response.statusCode}';
        if (response.statusCode == 500) {
          errorDetail = 'Internal server error. Please try again later.';
        }
        return {'success': false, 'error': errorDetail};
      }
    } on SocketException catch (e) {
      debugPrint('SocketException in checkDigiLockerStatus: $e');
      return {
        'success': false,
        'error': 'No internet connection. Please check your network and try again.',
        'error_type': 'no_internet',
      };
    } on TimeoutException catch (e) {
      debugPrint('TimeoutException in checkDigiLockerStatus: $e');
      return {
        'success': false,
        'error': 'Connection timed out. Please try again.',
        'error_type': 'timeout',
      };
    } catch (e) {
      debugPrint('DigiLocker Status Error: $e');
      return {
        'success': false,
        'error': NetworkErrorHandler.getErrorMessage(e),
        'error_type': 'unknown',
      };
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
      final response = await http
          .post(
            Uri.parse('https://api11.hathmetech.com/api/user/v1/kyc/status'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({'user_id': userId}),
          )
          .timeout(const Duration(seconds: 30));

      print('KYC Status POST Response: ${response.body}');

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 400) {
        final responseData = json.decode(response.body);

        // Extract and validate status as per Image 1
        // We check both the top-level status and the nested data status
        String? apiStatus = responseData['status']?.toString();
        final data = responseData['data'];
        String? dataStatus;

        if (data != null && data is Map<String, dynamic>) {
          dataStatus = data['status']?.toString();
        }

        String validatedStatus = 'Not Started';

        // 'already_completed' at the top level unambiguously means KYC is done —
        // do NOT override it with the nested data.status which may carry a raw
        // internal value that would fall through to 'Not Started'.
        String statusToMap = (apiStatus ?? '').toLowerCase().trim();
        if (statusToMap == 'already_completed') {
          validatedStatus = 'Completed';
        } else {
          // When top-level status is absent, try the nested data.status
          if (statusToMap == '' && dataStatus != null) {
            statusToMap = dataStatus.toLowerCase().trim();
          }

          if (statusToMap == 'completed' ||
              statusToMap == 'verified' ||
              statusToMap == 'approved') {
            validatedStatus = 'Completed';
          } else if (statusToMap == 'pending' ||
              statusToMap == 'submitted' ||
              statusToMap == 'processing') {
            validatedStatus = 'Pending';
          } else if (statusToMap == 'expired') {
            validatedStatus = 'Expired';
          } else if (statusToMap == 'not_started' ||
              statusToMap == 'not-started') {
            validatedStatus = 'Not Started';
          } else if (statusToMap == 'rejected' ||
              statusToMap == 'failed' ||
              statusToMap == 'denied') {
            validatedStatus = 'Rejected';
          } else {
            validatedStatus = 'Not Started';
          }
        }

        print(
          '🔍 checkKYCStatusPost: Raw API Status="$apiStatus", Data Status="$dataStatus" -> Validated Status="$validatedStatus"',
        );

        return {
          'success': responseData['success'] ?? (response.statusCode != 400),
          'data': responseData['data'], // Image 1 shows data is an object
          'status': validatedStatus,
          'rawStatus': apiStatus, // Keep the actual raw top-level status
          'message': responseData['message'] ?? 'Status retrieved',
          'error': response.statusCode == 400 ? responseData['message'] : null,
        };
      } else {
        String errorDetail = 'Server error: ${response.statusCode}';
        if (response.statusCode == 404) {
          errorDetail = 'KYC status service not found. Please contact support.';
        } else if (response.statusCode == 500) {
          errorDetail = 'Internal server error. Please try again later.';
        }

        return {'success': false, 'error': errorDetail};
      }
    } catch (e) {
      print('KYC Status POST Error: $e');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Check KYC status via /user/v1/kyc/check-kyc endpoint
  Future<Map<String, dynamic>> checkKYCV2() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      final token = prefs.getString('auth_token') ?? '';

      if (userId.isEmpty || token.isEmpty) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse('https://api11.hathmetech.com/api/user/v1/kyc/check-kyc'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      print('Check KYC V2 Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);

        return {
          'success': responseData['success'] ?? true,
          'status': (responseData['success'] == true) ? 'Completed' : 'Pending',
          'message': responseData['message'] ?? 'Status retrieved',
        };
      } else {
        String errorDetail = 'Server error: ${response.statusCode}';
        if (response.statusCode == 404) {
          errorDetail = 'KYC status service not found.';
        } else if (response.statusCode == 500) {
          errorDetail = 'Internal server error. Please try again later.';
        }

        return {
          'success': false,
          'error': errorDetail,
          'statusCode': response.statusCode,
        };
      }
    } on SocketException catch (e) {
      print('SocketException in checkKYCStatusPost: $e');
      return {
        'success': false,
        'error': 'No internet connection. Please check your network and try again.',
        'error_type': 'no_internet',
      };
    } on TimeoutException catch (e) {
      print('TimeoutException in checkKYCStatusPost: $e');
      return {
        'success': false,
        'error': 'Connection timed out. Please try again.',
        'error_type': 'timeout',
      };
    } catch (e) {
      print('Check KYC V2 Error: $e');
      return {
        'success': false,
        'error': NetworkErrorHandler.getErrorMessage(e),
        'error_type': 'unknown',
      };
    }
  }

  Future<Map<String, dynamic>> updateUserProfile({
    String? name,
    String? email,
    String? mobile,
    String? countryCode,
    String? countryId,
    String? state,
    String? city,
    String? avatar,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (_userId == null || token == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      // Build request body - only include non-empty values to avoid server errors
      final requestBody = <String, dynamic>{'user_id': _userId};
      if (name != null && name.isNotEmpty) requestBody['name'] = name;
      if (email != null && email.isNotEmpty) requestBody['email'] = email;

      // Convert mobile to number if possible to match server expectation
      if (mobile != null && mobile.isNotEmpty) {
        final numericMobile = int.tryParse(
          mobile.replaceAll(RegExp(r'[^0-9]'), ''),
        );
        if (numericMobile != null) {
          requestBody['mobile'] = numericMobile;
        } else {
          // Don't send invalid mobile data
          debugPrint('Invalid mobile format, excluding from request: $mobile');
        }
      }

      if (countryCode != null && countryCode.isNotEmpty)
        requestBody['countryCode'] = countryCode;
      if (countryId != null && countryId.isNotEmpty)
        requestBody['countryId'] = countryId;
      if (state != null && state.isNotEmpty) requestBody['state'] = state;
      if (city != null && city.isNotEmpty) requestBody['city'] = city;
      if (avatar != null && avatar.isNotEmpty) requestBody['avatar'] = avatar;

      debugPrint('Update Profile Request: $requestBody');

      final response = await http
          .post(
            Uri.parse(
              'https://api11.hathmetech.com/api/user/v1/auth/create-profile',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('Update Profile Response Status: ${response.statusCode}');
      debugPrint('Update Profile Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          // Robustly update internal state using the fresh data returned by the server
          final serverUserData = responseData['user'] ?? responseData['data'];
          if (serverUserData != null &&
              serverUserData is Map<String, dynamic>) {
            // Save the full user data object for initUserData() consistency
            await prefs.setString('user_data', json.encode(serverUserData));

            _parseAuthData(serverUserData);

            // Auto-sync country code if country changed
            await _syncCountryCodeWithCountryName();

            // Update SharedPreferences for persistence
            if (_userName != null)
              await prefs.setString(_userNameKey, _userName!);
            if (_userEmail != null)
              await prefs.setString(_userEmailKey, _userEmail!);
            if (_userPhone != null)
              await prefs.setString(_userPhoneKey, _userPhone!);
            if (_userCountryCode != null)
              await prefs.setString(_userCountryCodeKey, _userCountryCode!);
            if (_userCountry != null)
              await prefs.setString(_userCountryKey, _userCountry!);
            if (_userState != null)
              await prefs.setString(_userStateKey, _userState!);
            if (_userCity != null)
              await prefs.setString(_userCityKey, _userCity!);
          }

          // Await a full profile refresh to ensure absolute synchronization before UI updates
          await fetchProfileDataFromAPI();

          return {
            'success': true,
            'message':
                responseData['message'] ?? 'Profile updated successfully',
            'data': responseData['data'],
          };
        }
        return {
          'success': false,
          'error':
              responseData['error'] ??
              responseData['message'] ??
              'Failed to update profile',
        };
      } else if (response.statusCode == 400) {
        // Handle 400 error - parse specific error message from server
        try {
          final errorData = json.decode(response.body);
          final errorMessage = _extractSpecificError(errorData, 400);
          debugPrint('400 Error Details: ${response.body}');
          return {'success': false, 'error': errorMessage};
        } catch (e) {
          debugPrint('Failed to parse 400 error: $e');
          return {
            'success': false,
            'error':
                'Invalid request data. Please check your inputs and try again.',
          };
        }
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Authentication expired. Please login again.',
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'error':
              'Access denied. You do not have permission to perform this action.',
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'error': 'Service not found. Please contact support.',
        };
      } else if (response.statusCode == 429) {
        return {
          'success': false,
          'error':
              'KYC limit exceeded. Please try again later or contact support.',
        };
      } else if (response.statusCode == 500) {
        // Handle 500 error - try to parse error message if available
        try {
          final errorData = json.decode(response.body);
          final errorMessage = _extractSpecificError(errorData, 500);
          return {'success': false, 'error': errorMessage};
        } catch (e) {
          return {
            'success': false,
            'error': 'Server error. Please try again later or contact support.',
          };
        }
      }
      String errorDetail = 'Server error: ${response.statusCode}';
      try {
        final errorData = json.decode(response.body);
        errorDetail = _extractSpecificError(errorData, response.statusCode);
      } catch (e) {
        // Keep the default error message if parsing fails
      }
      return {'success': false, 'error': errorDetail};
    } on SocketException catch (e) {
      debugPrint('SocketException in updateUserProfile: $e');
      return {
        'success': false,
        'error': 'No internet connection. Please check your network and try again.',
        'error_type': 'no_internet',
      };
    } on TimeoutException catch (e) {
      debugPrint('TimeoutException in updateUserProfile: $e');
      return {
        'success': false,
        'error': 'Connection timed out. Please try again.',
        'error_type': 'timeout',
      };
    } catch (e) {
      debugPrint('Update Profile Error: $e');
      return {
        'success': false,
        'error': NetworkErrorHandler.getErrorMessage(e),
        'error_type': 'unknown',
      };
    }
  }

  // Fetch countries list from API
  Future<Map<String, dynamic>> getCountries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse(
              'https://api11.hathmetech.com/api/user/v1/config/countries',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      debugPrint(
        'Countries API Response: ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          // Check for different response formats
          final data = responseData['data'] ?? responseData['countries'] ?? [];
          return {
            'success': true,
            'data': data,
            'message':
                responseData['message'] ?? 'Countries fetched successfully',
          };
        }
        return {
          'success': false,
          'error': responseData['message'] ?? 'Failed to fetch countries',
        };
      }
      String errorDetail = 'Server error: ${response.statusCode}';
      try {
        final errorData = json.decode(response.body);
        errorDetail = _extractSpecificError(errorData, response.statusCode);
      } catch (e) {
        // Keep the default error message if parsing fails
      }
      return {'success': false, 'error': errorDetail};
    } on SocketException catch (e) {
      debugPrint('SocketException in getCountries: $e');
      return {
        'success': false,
        'error': 'No internet connection. Please check your network and try again.',
        'error_type': 'no_internet',
      };
    } on TimeoutException catch (e) {
      debugPrint('TimeoutException in getCountries: $e');
      return {
        'success': false,
        'error': 'Connection timed out. Please try again.',
        'error_type': 'timeout',
      };
    } catch (e) {
      debugPrint('Error fetching countries: $e');
      return {
        'success': false,
        'error': NetworkErrorHandler.getErrorMessage(e),
        'error_type': 'unknown',
      };
    }
  }

  // Fetch states list for a country from API
  Future<Map<String, dynamic>> getStates(String countryId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      final url =
          'https://api11.hathmetech.com/api/user/v1/config/states?countryId=$countryId';
      debugPrint('Fetching states from: $url');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      debugPrint(
        'States API Response: ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        debugPrint('States responseData: $responseData');
        if (responseData['success'] == true) {
          // Check for different response formats
          final data = responseData['data'] ?? responseData['states'] ?? [];
          debugPrint('States extracted data: $data');
          return {
            'success': true,
            'data': data,
            'message': responseData['message'] ?? 'States fetched successfully',
          };
        }
        return {
          'success': false,
          'error': responseData['message'] ?? 'Failed to fetch states',
        };
      }
      String errorDetail = 'Server error: ${response.statusCode}';
      try {
        final errorData = json.decode(response.body);
        errorDetail = _extractSpecificError(errorData, response.statusCode);
      } catch (e) {
        // Keep the default error message if parsing fails
      }
      return {'success': false, 'error': errorDetail};
    } on SocketException catch (e) {
      debugPrint('SocketException in getStates: $e');
      return {
        'success': false,
        'error': 'No internet connection. Please check your network and try again.',
        'error_type': 'no_internet',
      };
    } on TimeoutException catch (e) {
      debugPrint('TimeoutException in getStates: $e');
      return {
        'success': false,
        'error': 'Connection timed out. Please try again.',
        'error_type': 'timeout',
      };
    } catch (e) {
      debugPrint('Error fetching states: $e');
      return {
        'success': false,
        'error': NetworkErrorHandler.getErrorMessage(e),
        'error_type': 'unknown',
      };
    }
  }

  // Fetch cities list for a state from API
  Future<Map<String, dynamic>> getCities(
    String countryId,
    String stateId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      final response = await http
          .get(
            Uri.parse(
              'https://api11.hathmetech.com/api/user/v1/config/cities?stateId=$stateId',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'] ?? [],
            'message': responseData['message'] ?? 'Cities fetched successfully',
          };
        }
        return {
          'success': false,
          'error': responseData['message'] ?? 'Failed to fetch cities',
        };
      }
      String errorDetail = 'Server error: ${response.statusCode}';
      try {
        final errorData = json.decode(response.body);
        errorDetail = _extractSpecificError(errorData, response.statusCode);
      } catch (e) {
        // Keep the default error message if parsing fails
      }
      return {'success': false, 'error': errorDetail};
    } on SocketException catch (e) {
      debugPrint('SocketException in getCities: $e');
      return {
        'success': false,
        'error': 'No internet connection. Please check your network and try again.',
        'error_type': 'no_internet',
      };
    } on TimeoutException catch (e) {
      debugPrint('TimeoutException in getCities: $e');
      return {
        'success': false,
        'error': 'Connection timed out. Please try again.',
        'error_type': 'timeout',
      };
    } catch (e) {
      debugPrint('Error fetching cities: $e');
      return {
        'success': false,
        'error': NetworkErrorHandler.getErrorMessage(e),
        'error_type': 'unknown',
      };
    }
  }

  // Fetch country name by ID for immediate synchronization
  Future<void> _fetchCountryNameById(String countryId) async {
    try {
      debugPrint('📍 Fetching country name for ID: $countryId');

      final countriesResult = await getCountries();
      if (countriesResult['success'] == true &&
          countriesResult['data'] is List) {
        final countries = countriesResult['data'] as List;
        for (var country in countries) {
          if (country['_id']?.toString() == countryId ||
              country['id']?.toString() == countryId) {
            _userCountry = country['name']?.toString() ?? countryId;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_userCountryKey, _userCountry!);
            debugPrint('✅ Country name found by ID: $_userCountry');
            return;
          }
        }
      }

      // Fallback: use countryId if no country name found
      _userCountry = countryId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userCountryKey, _userCountry!);
      debugPrint('✅ Country set to ID (fallback): $_userCountry');
    } catch (e) {
      debugPrint('Error fetching country name by ID: $e');
    }
  }

  // Fetch location names from IDs and store them
  Future<void> _fetchLocationNames() async {
    _isFetchingLocationNames = true;
    try {
      debugPrint('📍 Fetching location names from IDs...');

      final prefs = await SharedPreferences.getInstance();

      // Get current location IDs
      final countryId =
          _getSafeString(prefs, 'country_id') ??
          _getSafeString(prefs, 'countryId');
      final stateId = _userState;
      final cityId = _userCity;

      debugPrint(
        '📍 Current IDs - Country: $countryId, State: $stateId, City: $cityId',
      );
      debugPrint('📍 User service state: $_userState, city: $_userCity');

      if (countryId != null && countryId.isNotEmpty) {
        // Fetch country name from countries API
        final countriesResult = await getCountries();
        if (countriesResult['success'] == true &&
            countriesResult['data'] is List) {
          final countries = countriesResult['data'] as List;
          for (var country in countries) {
            if (country['_id']?.toString() == countryId ||
                country['id']?.toString() == countryId) {
              _userCountry = country['name']?.toString() ?? countryId;
              await prefs.setString(_userCountryKey, _userCountry!);
              debugPrint('✅ Country name found: $_userCountry');
              break;
            }
          }
        }

        // Fallback: use countryId if no country name found
        if (_userCountry == null || _userCountry!.isEmpty) {
          _userCountry = countryId;
          await prefs.setString(_userCountryKey, _userCountry!);
          debugPrint('✅ Country set to ID (fallback): $_userCountry');
        }
      }

      if (stateId != null && stateId.isNotEmpty && countryId != null) {
        // Fetch states to find state name
        final statesResult = await getStates(countryId);
        if (statesResult['success'] == true && statesResult['data'] is List) {
          final states = statesResult['data'] as List;
          for (var state in states) {
            if (state['_id']?.toString() == stateId ||
                state['id']?.toString() == stateId) {
              _userState = state['name']?.toString() ?? stateId;
              await (await SharedPreferences.getInstance()).setString(
                _userStateKey,
                _userState!,
              );
              debugPrint('✅ State name found: $_userState');
              break;
            }
          }
        }
      }

      if (cityId != null && cityId.isNotEmpty && countryId != null) {
        // Fetch cities to find city name
        final citiesResult = await getCities(countryId, stateId ?? '');
        if (citiesResult['success'] == true && citiesResult['data'] is List) {
          final cities = citiesResult['data'] as List;
          for (var city in cities) {
            if (city['_id']?.toString() == cityId ||
                city['id']?.toString() == cityId) {
              _userCity = city['name']?.toString() ?? cityId;
              await (await SharedPreferences.getInstance()).setString(
                _userCityKey,
                _userCity!,
              );
              debugPrint('✅ City name found: $_userCity');
              break;
            }
          }
        }
      }

      debugPrint(
        '📍 Final location names - Country: $_userCountry, State: $_userState, City: $_userCity',
      );
    } catch (e) {
      debugPrint('Error fetching location names: $e');
    } finally {
      _isFetchingLocationNames = false;
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

      debugPrint(
        'Fetching referred friends from: https://api11.hathmetech.com/api/user/v1/auth/referred-friends',
      );

      final response = await http
          .get(
            Uri.parse(
              'https://api11.hathmetech.com/api/user/v1/auth/referred-friends',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      debugPrint(
        'Referred Friends API Response Status: ${response.statusCode}',
      );
      debugPrint('Referred Friends API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'] ?? responseData,
            'message':
                responseData['message'] ??
                'Referred friends fetched successfully',
          };
        } else {
          return {
            'success': false,
            'error':
                responseData['message'] ??
                responseData['error'] ??
                'Failed to fetch referred friends',
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
      return {'success': false, 'error': 'Network error: $e'};
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
      debugPrint(
        'API URL: https://api11.hathmetech.com/api/user/v1/auth/send-invitation',
      );

      final response = await http
          .post(
            Uri.parse(
              'https://api11.hathmetech.com/api/user/v1/auth/send-invitation',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('Send Invitation API Response Status: ${response.statusCode}');
      debugPrint('Send Invitation API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'] ?? responseData,
            'message':
                responseData['message'] ?? 'Invitation sent successfully!',
            'requiresVerification':
                responseData['requiresVerification'] ?? true,
          };
        } else {
          return {
            'success': false,
            'error':
                responseData['message'] ??
                responseData['error'] ??
                'Failed to send invitation',
          };
        }
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error':
              errorData['message'] ??
              errorData['error'] ??
              'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error sending invitation email: $e');
      return {'success': false, 'error': 'Network error: $e'};
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

      final requestBody = {'email': email, 'type': 'referral_verification'};

      debugPrint('Sending referral verification email: $requestBody');
      debugPrint(
        'API URL: https://api11.hathmetech.com/api/user/v1/auth/send-verification-email',
      );

      final response = await http
          .post(
            Uri.parse(
              'https://api11.hathmetech.com/api/user/v1/auth/send-verification-email',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint(
        'Send Verification Email API Response Status: ${response.statusCode}',
      );
      debugPrint('Send Verification Email API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'] ?? responseData,
            'message':
                responseData['message'] ??
                'Verification code sent successfully!',
          };
        } else {
          return {
            'success': false,
            'error':
                responseData['message'] ??
                responseData['error'] ??
                'Failed to send verification code',
          };
        }
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error':
              errorData['message'] ??
              errorData['error'] ??
              'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error sending referral verification email: $e');
      return {'success': false, 'error': 'Network error: $e'};
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
      debugPrint(
        'API URL: https://api11.hathmetech.com/api/user/v1/auth/verify-claim-referral',
      );

      final response = await http
          .post(
            Uri.parse(
              'https://api11.hathmetech.com/api/user/v1/auth/verify-claim-referral',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('Verify & Claim API Response Status: ${response.statusCode}');
      debugPrint('Verify & Claim API Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'] ?? responseData,
            'message':
                responseData['message'] ?? 'Referral claimed successfully!',
          };
        } else {
          return {
            'success': false,
            'error':
                responseData['message'] ??
                responseData['error'] ??
                'Failed to claim referral',
          };
        }
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error':
              errorData['message'] ??
              errorData['error'] ??
              'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error verifying and claiming referral: $e');
      return {'success': false, 'error': 'Network error: $e'};
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
    await prefs.remove(_kycRejectionReasonKey);
    await prefs.remove(_ipAddressKey);
    await prefs.remove(_userPhoneKey);
    await prefs.remove(_userCountryKey);
    await prefs.remove(_userStateKey);
    await prefs.remove(_userCityKey);
    await prefs.remove(_userCountryCodeKey);

    _userName = null;
    _userEmail = null;
    _userId = null;
    _signUpTime = null;
    _lastLogin = null;
    _kycStatus = 'Not Started';
    _kycSubmittedAt = null;
    _kycRejectionReason = null;
    _ipAddress = null;
    _userPhone = null;
    _userCountry = null;
    _userState = null;
    _userCity = null;
    _userCountryCode = null;
    _documentImageVerified = null;
    _selfieStatusValue = null;
  }

  bool hasEmail() => _userEmail != null && _userEmail!.isNotEmpty;
  bool isKYCPending() => _kycStatus == 'Pending';
  bool isKYCVerified() => _kycStatus == 'Completed';
  bool isKYCRejected() => _kycStatus == 'Rejected';
  bool isKYCNotStarted() => _kycStatus == 'Not Started';
  
  /// Returns true when KYC status is Pending but document not verified
  /// This happens when user opened Digilocker but didn't submit documents
  bool canRestartKYC() => _kycStatus == 'Pending' && _documentImageVerified != true;

  /// Returns true when document is verified but selfie needs to be uploaded
  /// This happens when user completed DigiLocker but hasn't uploaded selfie yet
  /// IMPORTANT: Returns false if KYC is rejected (user must restart from DigiLocker)
  bool needsSelfieUpload() {
    final result = _kycStatus != 'Rejected' && 
        _documentImageVerified == true && 
        (_selfieStatusValue == null || _selfieStatusValue == 0);
    debugPrint('🔧 needsSelfieUpload: status=$_kycStatus, docVerified=$_documentImageVerified, selfieStatus=$_selfieStatusValue → result=$result');
    return result;
  }

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
        return {'success': false, 'error': 'Authentication required'};
      }

      debugPrint(
        'Fetching user assets from: https://api11.hathmetech.com/api/user/v1/user',
      );
      final response = await http
          .get(
            Uri.parse('https://api11.hathmetech.com/api/user/v1/user'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('User Assets API Response Status: ${response.statusCode}');
      debugPrint('User Assets API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final userData = data['data'];
          // Extract assets from user data
          final assets =
              userData['assets'] ??
              userData['wallet'] ??
              userData['balances'] ??
              {};
          return {'success': true, 'data': assets, 'userData': userData};
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
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  Color getKYCStatusColor() {
    // Check if rejection is due to name mismatch
    final bool isNameMismatchRejection = _kycStatus == 'Rejected' && 
        _kycRejectionReason != null && 
        _kycRejectionReason!.toLowerCase().contains('name mismatch');
    
    if (isNameMismatchRejection) {
      return Colors.orange;
    }
    
    switch (_kycStatus) {
      case 'Completed':
        return const Color(0xFF84BD00);
      case 'Pending':
        return Colors.orange;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Centralized KYC status validation function
  static String validateKYCStatus(Map<String, dynamic> apiResponse) {
    String? apiStatus;
    String validatedStatus = 'not_started';

    // Try to get status from different possible locations
    apiStatus = apiResponse['status']?.toString();
    if (apiStatus == null && apiResponse['data'] != null) {
      apiStatus = apiResponse['data']['status']?.toString();
    }

    if (apiStatus != null) {
      final status = apiStatus.toLowerCase().trim();
      final message = apiResponse['message']?.toString().toLowerCase() ?? '';

      // Apply strict validation
      if (status == 'completed' || status == 'already_completed') {
        validatedStatus = 'completed';
      } else if (status == 'rejected' ||
          status == 'failed' ||
          status == 'denied') {
        validatedStatus = 'rejected';
      } else if (status == 'pending' ||
          status == 'submitted' ||
          status == 'processing' ||
          status == 'approved' ||
          status == 'verified') {
        validatedStatus = 'pending';
      } else if (status == 'not_started' || status == 'not-started') {
        validatedStatus = 'not_started';
      } else {
        // Fallback to message check with strict validation
        if (message.contains('KYC completed successfully') &&
            !message.contains('pending') &&
            !message.contains('processing')) {
          validatedStatus = 'completed';
        } else if (message.contains('rejected') || message.contains('failed')) {
          validatedStatus = 'rejected';
        } else if (message.contains('pending') ||
            message.contains('submitted') ||
            message.contains('processing')) {
          validatedStatus = 'pending';
        }
      }

      print(
        '🔍 validateKYCStatus: Raw API Status="$apiStatus" -> Validated Status="$validatedStatus"',
      );
    }

    return validatedStatus;
  }

  // Referral API methods
  static Future<Map<String, dynamic>> getReferralData() async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Authentication required'};
      }

      final response = await http.get(
        Uri.parse(
          'https://api11.hathmetech.com/api/referral/v1/referral/stats',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Process the new API response format
          final processedData = _processReferralData(data);
          _cachedReferralData = processedData;
          return {'success': true, 'data': processedData};
        } else {
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to fetch referral data',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } on SocketException catch (e) {
      debugPrint('SocketException in getReferralData: $e');
      return {
        'success': false,
        'error': 'No internet connection. Please check your network and try again.',
        'error_type': 'no_internet',
      };
    } on TimeoutException catch (e) {
      debugPrint('TimeoutException in getReferralData: $e');
      return {
        'success': false,
        'error': 'Connection timed out. Please try again.',
        'error_type': 'timeout',
      };
    } catch (e) {
      debugPrint('Error fetching referral data: $e');
      return {
        'success': false,
        'error': NetworkErrorHandler.getErrorMessage(e),
        'error_type': 'unknown',
      };
    }
  }

  static Future<Map<String, dynamic>> getReferralEarnings({
    int? page,
    int? limit,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Authentication required'};
      }

      final queryParams = <String, String>{
        if (page != null) 'page': page.toString(),
        if (limit != null) 'limit': limit.toString(),
      };

      final uri = Uri.parse(
        'https://api11.hathmetech.com/api/referral/v1/referral/earnings',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to fetch referral earnings',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } on SocketException catch (e) {
      debugPrint('SocketException in getReferralEarnings: $e');
      return {
        'success': false,
        'error': 'No internet connection. Please check your network and try again.',
        'error_type': 'no_internet',
      };
    } on TimeoutException catch (e) {
      debugPrint('TimeoutException in getReferralEarnings: $e');
      return {
        'success': false,
        'error': 'Connection timed out. Please try again.',
        'error_type': 'timeout',
      };
    } catch (e) {
      debugPrint('Error fetching referral earnings: $e');
      return {
        'success': false,
        'error': NetworkErrorHandler.getErrorMessage(e),
        'error_type': 'unknown',
      };
    }
  }

  // Static date formatting method for referral data
  static String _formatDateForReferral(String dateStr) {
    try {
      DateTime parsedDate = DateTime.parse(dateStr);
      return '${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year}';
    } catch (e) {
      return dateStr;
    }
  }

  // Process the new API response format to match the expected UI structure
  static Map<String, dynamic> _processReferralData(
    Map<String, dynamic> apiData,
  ) {
    final tradingIncome = apiData['tradingIncome'] ?? {};
    final subscriptionIncome = apiData['subscriptionIncome'] ?? {};

    // Extract referral code from API response
    final referralCodeFromApi =
        apiData['referralCode']?.toString() ??
        apiData['referral_code']?.toString() ??
        apiData['code']?.toString() ??
        apiData['userReferralCode']?.toString();

    final tradingTotal = (tradingIncome['total'] as num?)?.toDouble() ?? 0.0;
    final subscriptionTotal =
        (subscriptionIncome['total'] as num?)?.toDouble() ?? 0.0;
    final totalIncome = tradingTotal + subscriptionTotal;

    // Combine transactions from both sources for recent earnings
    final List<Map<String, dynamic>> recentEarnings = [];

    // Add trading income transactions
    if (tradingIncome['transactions'] is List) {
      for (var transaction in tradingIncome['transactions']) {
        recentEarnings.add({
          'amount': (transaction['amount'] as num?)?.toDouble() ?? 0.0,
          'date': _formatDateForReferral(transaction['createdAt'] ?? ''),
          'referredUser': 'Trading Income',
          'type': 'trading',
        });
      }
    }

    // Add subscription income transactions
    if (subscriptionIncome['transactions'] is List) {
      for (var transaction in subscriptionIncome['transactions']) {
        recentEarnings.add({
          'amount': (transaction['amount'] as num?)?.toDouble() ?? 0.0,
          'date': _formatDateForReferral(transaction['createdAt'] ?? ''),
          'referredUser': transaction['name']?.toString() ?? 'Unknown User',
          'type': 'subscription',
          'level': transaction['level'],
          'email': transaction['email'],
        });
      }
    }

    // Sort by date (most recent first)
    recentEarnings.sort((a, b) {
      final dateA = DateTime.tryParse(a['date'].toString()) ?? DateTime.now();
      final dateB = DateTime.tryParse(b['date'].toString()) ?? DateTime.now();
      return dateB.compareTo(dateA);
    });

    // Use the actual referral code from API, or fallback to username if not available
    final finalReferralCode = referralCodeFromApi?.isNotEmpty == true
        ? referralCodeFromApi
        : (_instance._userName?.toUpperCase() ?? 'USER123');

    return {
      'totalReferrals':
          (subscriptionIncome['transactions'] as List?)?.length ?? 0,
      'activeReferrals':
          (subscriptionIncome['transactions'] as List?)?.length ?? 0,
      'totalIncome': totalIncome,
      'tradingIncome': tradingTotal,
      'subscriptionIncome': subscriptionTotal,
      'pendingIncome': 0.0, // API doesn't specify pending vs confirmed
      'referralCode': finalReferralCode,
      'referralLink': 'https://creddx.com/ref/$finalReferralCode',
      'recentEarnings': recentEarnings,
      'tier': 'Bronze',
      'nextTier': 'Silver',
      'progressToNextTier': 0.0,
      'tradingTransactions': tradingIncome['transactions'] ?? [],
      'subscriptionTransactions': subscriptionIncome['transactions'] ?? [],
    };
  }

  static Map<String, dynamic>? get cachedReferralData => _cachedReferralData;

  // Get level-wise income summary for affiliate program
  static Future<Map<String, dynamic>> getLevelWiseSummary() async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Authentication required'};
      }

      final response = await http.get(
        Uri.parse(
          'https://api11.hathmetech.com/api/bot/v1/api/user/income/level-wise-summary',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to fetch level summary',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching level-wise summary: $e');
      return {
        'success': false,
        'error': NetworkErrorHandler.getErrorMessage(e),
      };
    }
  }

  // Get detailed level income summary for specific level
  static Future<Map<String, dynamic>> getLevelIncomeSummary(int level) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'Authentication required'};
      }

      final response = await http.get(
        Uri.parse(
          'https://api11.hathmetech.com/api/bot/v1/api/user/income/level-summary/$level',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to fetch level summary',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error fetching level income summary: $e');
      return {
        'success': false,
        'error': NetworkErrorHandler.getErrorMessage(e),
      };
    }
  }
}
