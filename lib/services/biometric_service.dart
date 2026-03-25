import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class BiometricService {
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricDeviceKey = 'biometric_device_id';
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // Check if biometric authentication is available
  static Future<bool> isBiometricAvailable() async {
    try {
      final LocalAuthentication localAuth = LocalAuthentication();
      final bool canCheckBiometrics = await localAuth.canCheckBiometrics;
      if (!canCheckBiometrics) return false;
      
      final List<BiometricType> availableBiometrics = await localAuth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      print('Error checking biometric availability: $e');
      return false;
    }
  }

  // Get device ID
  static Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await DeviceInfoPlugin().iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown_ios';
      }
      return 'unknown_device';
    } catch (e) {
      return 'device_error';
    }
  }

  // Enable biometric authentication for current device
  static Future<bool> enableBiometricAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await getDeviceId();
      
      // Store biometric enabled flag and device ID
      await prefs.setBool(_biometricEnabledKey, true);
      await prefs.setString(_biometricDeviceKey, deviceId);
      
      return true;
    } catch (e) {
      print('Error enabling biometric auth: $e');
      return false;
    }
  }

  // Disable biometric authentication
  static Future<bool> disableBiometricAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_biometricEnabledKey);
      await prefs.remove(_biometricDeviceKey);
      return true;
    } catch (e) {
      print('Error disabling biometric auth: $e');
      return false;
    }
  }

  // Check if biometric auth is enabled for current device
  static Future<bool> isBiometricAuthEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await getDeviceId();
      final storedDeviceId = prefs.getString(_biometricDeviceKey);
      final isEnabled = prefs.getBool(_biometricEnabledKey) ?? false;
      
      // Only enable if same device and biometric was enabled
      return isEnabled && storedDeviceId == deviceId;
    } catch (e) {
      print('Error checking biometric auth status: $e');
      return false;
    }
  }

  // Authenticate with biometrics
  static Future<Map<String, dynamic>> authenticateWithBiometrics() async {
    try {
      final LocalAuthentication localAuth = LocalAuthentication();
      
      final bool didAuthenticate = await localAuth.authenticate(
        localizedReason: 'Use fingerprint or face to login',
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
          biometricOnly: true,
        ),
      );



      if (didAuthenticate) {
        // Get stored user data and token
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(_tokenKey);
        final userData = prefs.getString(_userKey);
        
        if (token != null && userData != null) {
          return {
            'success': true,
            'message': 'Biometric authentication successful',
            'token': token,
            'user': json.decode(userData!),
          };
        } else {
          return {
            'success': false,
            'message': 'No stored credentials found. Please login with password first.',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Biometric authentication failed',
        };
      }
    } catch (e) {
      print('Error during biometric authentication: $e');
      return {
        'success': false,
        'message': 'Biometric authentication error: ${e.toString()}',
      };
    }
  }

  // Store credentials for biometric authentication
  static Future<bool> storeCredentialsForBiometric(String token, Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userKey, json.encode(userData));
      return true;
    } catch (e) {
      print('Error storing credentials: $e');
      return false;
    }
  }

  // Get available biometric types
  static Future<String> getBiometricType() async {
    try {
      final LocalAuthentication localAuth = LocalAuthentication();
      final List<BiometricType> availableBiometrics = await localAuth.getAvailableBiometrics();
      
      if (availableBiometrics.contains(BiometricType.fingerprint)) {
        return 'Fingerprint';
      } else if (availableBiometrics.contains(BiometricType.face)) {
        return 'Face ID';
      } else if (availableBiometrics.contains(BiometricType.iris)) {
        return 'Iris Scanner';
      } else {
        return 'Biometric';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}
