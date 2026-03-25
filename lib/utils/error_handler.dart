import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class ErrorHandler {
  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF84BD00),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static void logError(String error, String context) {
    if (kDebugMode) {
      debugPrint('[$context] Error: $error');
    }
  }

  static String getErrorMessage(dynamic error) {
    if (error is String) return error;
    if (error is Map) {
      return error['message'] ?? error['error'] ?? 'An error occurred';
    }
    return 'An unexpected error occurred';
  }

  static Future<T?> handleAsyncOperation<T>(
    Future<T> Function() operation,
    BuildContext context, {
    String? loadingMessage,
    String? successMessage,
    String? errorMessage,
  }) async {
    try {
      if (loadingMessage != null && context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            content: Row(
              children: [
                const CircularProgressIndicator(color: Color(0xFF84BD00)),
                const SizedBox(width: 16),
                Text(loadingMessage, style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        );
      }

      final result = await operation();

      // Dismiss loading dialog
      if (loadingMessage != null && context.mounted) {
        Navigator.pop(context);
      }

      if (successMessage != null && context.mounted) {
        showSnackBar(context, successMessage);
      }

      return result;
    } catch (error) {
      // Dismiss loading dialog if it's showing
      if (loadingMessage != null && context.mounted) {
        Navigator.pop(context);
      }

      final message = errorMessage ?? getErrorMessage(error);
      if (context.mounted) {
        showSnackBar(context, message, isError: true);
      }
      
      logError(error.toString(), 'AsyncOperation');
      return null;
    }
  }
}

class LoadingOverlay {
  static OverlayEntry? _overlayEntry;

  static void show(BuildContext context, {String message = 'Loading...'}) {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFF84BD00)),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class ValidationHelper {
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  static bool isValidPhone(String phone) {
    return RegExp(r'^[0-9]{10}$').hasMatch(phone);
  }

  static bool isValidAmount(String amount) {
    if (amount.isEmpty) return false;
    final value = double.tryParse(amount);
    return value != null && value > 0;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    if (!isValidEmail(value)) return 'Please enter a valid email';
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Phone number is required';
    if (!isValidPhone(value)) return 'Please enter a valid 10-digit phone number';
    return null;
  }

  static String? validateAmount(String? value, {String fieldName = 'Amount'}) {
    if (value == null || value.isEmpty) return '$fieldName is required';
    if (!isValidAmount(value)) return 'Please enter a valid amount';
    return null;
  }

  static String? validateRequired(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }
}
