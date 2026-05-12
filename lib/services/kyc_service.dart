import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'notification_service.dart';

class KYCService {
  static const String _baseUrl = 'http://65.0.196.122:8085/api';
  
  // Get KYC status for current user
  static Future<Map<String, dynamic>> getKYCStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      
      if (userId.isEmpty) {
        return {
          'success': false,
          'error': 'User not logged in',
          'data': null
        };
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/user/v1/kyc/status'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${prefs.getString('auth_token') ?? ''}',
        },
        body: json.encode({
          'user_id': userId,
        }),
      ).timeout(const Duration(seconds: 30));

      print('KYC Status Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'],
            'error': null
          };
        } else {
          return {
            'success': false,
            'data': null,
            'error': responseData['error'] ?? 'Failed to get KYC status'
          };
        }
      } else {
        return {
          'success': false,
          'data': null,
          'error': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('KYC Status Error: $e');
      return {
        'success': false,
        'data': null,
        'error': 'Network error: $e'
      };
    }
  }

  // Submit KYC documents
  static Future<Map<String, dynamic>> submitKYC({
    required String documentType,
    required String documentId,
    required String idNumber,
    required dynamic frontImage,
    required dynamic backImage,
    required dynamic selfieImage,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      
      if (userId.isEmpty) {
        return {
          'success': false,
          'error': 'User not logged in',
          'data': null
        };
      }

      // Create multipart request with new API endpoint
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/user/v1/kyc/kyc-upload-and-verify'),
      );

      // Add headers
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer ${prefs.getString('auth_token') ?? ''}',
      });

      // Add form fields
      request.fields['docId'] = documentId;
      request.fields['idNumber'] = idNumber;

      // Add images
      if (frontImage != null) {
        if (kIsWeb) {
          // On web, frontImage is likely XFile or similar
          final bytes = await (frontImage as XFile).readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            'docFrontPic',
            bytes,
            filename: 'front.jpg',
          ));
        } else {
          // On mobile, frontImage is likely File
          final bytes = await frontImage.readAsBytes();
          final fileName = frontImage.path.split('/').last;
          request.files.add(http.MultipartFile.fromBytes(
            'docFrontPic',
            bytes,
            filename: fileName,
          ));
        }
      }

      if (backImage != null) {
        if (kIsWeb) {
          final bytes = await (backImage as XFile).readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            'docBackPic',
            bytes,
            filename: 'back.jpg',
          ));
        } else {
          final bytes = await backImage.readAsBytes();
          final fileName = backImage.path.split('/').last;
          request.files.add(http.MultipartFile.fromBytes(
            'docBackPic',
            bytes,
            filename: fileName,
          ));
        }
      }

      if (selfieImage != null) {
        if (kIsWeb) {
          final bytes = await (selfieImage as XFile).readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            'selfie_image',
            bytes,
            filename: 'selfie.jpg',
          ));
        } else {
          final bytes = await selfieImage.readAsBytes();
          final fileName = selfieImage.path.split('/').last;
          request.files.add(http.MultipartFile.fromBytes(
            'selfie_image',
            bytes,
            filename: fileName,
          ));
        }
      }

      // Send request
      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      print('KYC Submit Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          // Log KYC submission notification
          await NotificationService.addNotification(
            title: 'KYC Submitted',
            message: 'Your KYC documents have been successfully submitted and are under review.',
            type: NotificationType.security,
          );

          return {
            'success': true,
            'data': responseData['data'],
            'error': null
          };
        } else {
          return {
            'success': false,
            'data': null,
            'error': responseData['error'] ?? 'Failed to submit KYC'
          };
        }
      } else {
        return {
          'success': false,
          'data': null,
          'error': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('KYC Submit Error: $e');
      return {
        'success': false,
        'data': null,
        'error': 'Network error: $e'
      };
    }
  }

  // Get supported document types
  static Future<Map<String, dynamic>> getDocumentTypes() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/kyc/document-types'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      print('Document Types Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'],
            'error': null
          };
        } else {
          return {
            'success': false,
            'data': null,
            'error': responseData['error'] ?? 'Failed to get document types'
          };
        }
      } else {
        return {
          'success': false,
          'data': null,
          'error': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('Document Types Error: $e');
      return {
        'success': false,
        'data': null,
        'error': 'Network error: $e'
      };
    }
  }

  // Validate document format
  static Future<Map<String, dynamic>> validateDocument({
    required String documentType,
    required String documentId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';

      final response = await http.post(
        Uri.parse('$_baseUrl/user/v1/kyc/kyc-validate'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${prefs.getString('auth_token') ?? ''}',
        },
        body: json.encode({
          'user_id': userId,
          'document_type': documentType,
          'document_id': documentId,
        }),
      ).timeout(const Duration(seconds: 30));

      print('Document Validation Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'],
            'error': null
          };
        } else {
          return {
            'success': false,
            'data': null,
            'error': responseData['error'] ?? 'Document validation failed'
          };
        }
      } else {
        return {
          'success': false,
          'data': null,
          'error': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('Document Validation Error: $e');
      return {
        'success': false,
        'data': null,
        'error': 'Network error: $e'
      };
    }
  }

  // Verify selfie
  static Future<Map<String, dynamic>> verifySelfie({
    required dynamic selfieImage,
    String? documentType,
    String? documentId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      
      if (userId.isEmpty) {
        return {
          'success': false,
          'error': 'User not logged in',
          'data': null
        };
      }

      // Create multipart request for selfie verification
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/user/v1/kyc/kyc-selfie-verify'),
      );

      // Add headers
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer ${prefs.getString('auth_token') ?? ''}',
      });

      // Add form fields
      request.fields['user_id'] = userId;
      if (documentType != null) {
        request.fields['document_type'] = documentType;
      }
      if (documentId != null) {
        request.fields['document_id'] = documentId;
      }

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

      print('Selfie Verify Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'],
            'error': null
          };
        } else {
          return {
            'success': false,
            'data': null,
            'error': responseData['error'] ?? 'Failed to verify selfie'
          };
        }
      } else {
        return {
          'success': false,
          'data': null,
          'error': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('Selfie Verify Error: $e');
      return {
        'success': false,
        'data': null,
        'error': 'Network error: $e'
      };
    }
  }

  // Get KYC requirements
  static Future<Map<String, dynamic>> getKYCRequirements() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/kyc/requirements'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      print('KYC Requirements Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'],
            'error': null
          };
        } else {
          return {
            'success': false,
            'data': null,
            'error': responseData['error'] ?? 'Failed to get KYC requirements'
          };
        }
      } else {
        return {
          'success': false,
          'data': null,
          'error': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('KYC Requirements Error: $e');
      return {
        'success': false,
        'data': null,
        'error': 'Network error: $e'
      };
    }
  }

  // Get KYC document
  static Future<Map<String, dynamic>> getKYCDocument() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      
      if (userId.isEmpty) {
        return {
          'success': false,
          'error': 'User not logged in',
          'data': null
        };
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/user/v1/kyc/kyc-document?user_id=$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${prefs.getString('auth_token') ?? ''}',
        },
      ).timeout(const Duration(seconds: 30));

      print('KYC Document Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return {
            'success': true,
            'data': responseData['data'],
            'error': null
          };
        } else {
          return {
            'success': false,
            'data': null,
            'error': responseData['error'] ?? 'Failed to get KYC document'
          };
        }
      } else {
        return {
          'success': false,
          'data': null,
          'error': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('KYC Document Error: $e');
      return {
        'success': false,
        'data': null,
        'error': 'Network error: $e'
      };
    }
  }
}
