import 'dart:async';

import 'package:android_intent_plus/android_intent.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/user_service.dart';

class DigiLockerWebViewScreen extends StatefulWidget {
  const DigiLockerWebViewScreen({
    super.key,
    required this.kycUrl,
    this.requestId,
  });

  final String kycUrl;
  final String? requestId;

  @override
  State<DigiLockerWebViewScreen> createState() =>
      _DigiLockerWebViewScreenState();
}

class _DigiLockerWebViewScreenState extends State<DigiLockerWebViewScreen> {
  final UserService _userService = UserService();
  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _linkSubscription;
  late final WebViewController _controller;

  bool _isLoading = true;
  bool _isProcessing = false;
  bool _completionHandled = false;

  @override
  void initState() {
    super.initState();
    _controller = _buildController();
    _listenForCallbackLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  WebViewController _buildController() {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onNavigationRequest: (request) async {
            final url = request.url;

            // Intercept callback URL - this triggers completion
            if (_isCallbackUrl(url)) {
              unawaited(_handleCompletion());
              return NavigationDecision.prevent;
            }

            // Handle external intent URLs (DigiLocker app, Play Store)
            if (_isExternalIntentUrl(url)) {
              await _openIntentUrl(url);
              return NavigationDecision.prevent;
            }

            // Block external website redirects after submission
            // Only allow Digilocker domains and the initial KYC URL
            if (_isExternalWebsiteRedirect(url)) {
              print('Blocked external redirect to: $url');
              // If processing is done, this might be a success redirect - handle completion
              if (_completionHandled || _isProcessing) {
                return NavigationDecision.prevent;
              }
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.kycUrl));
  }

  void _listenForCallbackLinks() {
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (_isCallbackUrl(uri.toString())) {
        unawaited(_handleCompletion());
      }
    });

    _appLinks.getInitialLink().then((uri) {
      if (uri != null && _isCallbackUrl(uri.toString())) {
        unawaited(_handleCompletion());
      }
    });
  }

  bool _isCallbackUrl(String url) {
    return url.startsWith('creddx://kyc/callback');
  }

  bool _isExternalIntentUrl(String url) {
    return url.startsWith('intent://') ||
        url.startsWith('digilocker://') ||
        url.startsWith('market://');
  }

  bool _isExternalWebsiteRedirect(String url) {
    // Allow Digilocker domains and the initial KYC URL
    final allowedDomains = [
      'digilocker.mannit.in',
      'digilocker.gov.in',
      'www.digilocker.gov.in',
      'accounts.digilocker.gov.in',
    ];

    // Check if URL is HTTP/HTTPS
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return false;
    }

    // Check if URL contains any allowed domain
    for (final domain in allowedDomains) {
      if (url.contains(domain)) {
        return false;
      }
    }

    // This is an external website redirect - block it
    return true;
  }

  Future<void> _openIntentUrl(String url) async {
    if (url.startsWith('intent://')) {
      await _openAndroidIntent(url);
      return;
    }

    await _openExternalUrl(url);
  }

  Future<void> _openAndroidIntent(String intentUrl) async {
    final schemeMatch = RegExp(r'scheme=([^;]+)').firstMatch(intentUrl);
    final packageMatch = RegExp(r'package=([^;]+)').firstMatch(intentUrl);
    final path = intentUrl
        .replaceFirst('intent://', '')
        .split('#Intent;')
        .first;
    final scheme = schemeMatch?.group(1) ?? 'https';
    final packageName = packageMatch?.group(1);

    final nativeUrl = '$scheme://$path';
    final openedNative = await _openExternalUrl(nativeUrl);
    if (openedNative) {
      return;
    }

    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        packageName != null) {
      try {
        await AndroidIntent(
          action: 'action_view',
          data: 'market://details?id=$packageName',
        ).launch();
        return;
      } catch (_) {
        await _openExternalUrl(
          'https://play.google.com/store/apps/details?id=$packageName',
        );
      }
    }
  }

  Future<bool> _openExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleCompletion() async {
    if (_completionHandled || _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _completionHandled = true;
    });

    await Future<void>.delayed(const Duration(seconds: 2));

    try {
      final result = await _checkCompletionStatus();
      final outcome = _extractOutcome(result);

      if (outcome['status'] == 'pending') {
        await Future<void>.delayed(const Duration(seconds: 4));
        final retryResult = await _checkCompletionStatus();
        final retryOutcome = _extractOutcome(retryResult);
        if (!mounted) return;
        Navigator.pop(context, retryOutcome);
        return;
      }

      if (!mounted) return;
      Navigator.pop(context, outcome);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context, {
        'status': 'failed',
        'code': 'ERROR',
        'message': 'Status check failed: $e',
      });
    }
  }

  Future<Map<String, dynamic>> _checkCompletionStatus() async {
    final requestId = widget.requestId;
    if (requestId != null && requestId.isNotEmpty) {
      return _userService.checkDigiLockerStatus(requestId);
    }

    return _userService.checkKYCStatusPost();
  }

  Map<String, dynamic> _extractOutcome(Map<String, dynamic> response) {
    final data = response['data'];
    final dataMap = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final rawStatus =
        [
              response['status'],
              response['rawStatus'],
              dataMap['status'],
              dataMap['kyc_status'],
              dataMap['kycStatus'],
            ]
            .map((value) => value?.toString().trim())
            .firstWhere(
              (value) => value != null && value.isNotEmpty,
              orElse: () => '',
            ) ??
        '';

    final normalizedStatus = rawStatus.toLowerCase();
    final code =
        [
              response['code'],
              dataMap['code'],
              dataMap['error_code'],
              dataMap['errorCode'],
            ]
            .map((value) => value?.toString().trim())
            .firstWhere(
              (value) => value != null && value.isNotEmpty,
              orElse: () => '',
            ) ??
        '';

    final message =
        [
              response['message'],
              response['error'],
              dataMap['message'],
              dataMap['error'],
            ]
            .map((value) => value?.toString().trim())
            .firstWhere(
              (value) => value != null && value.isNotEmpty,
              orElse: () => 'KYC status unavailable',
            ) ??
        'KYC status unavailable';

    if ({
      'completed',
      'already_completed',
      'verified',
      'approved',
    }.contains(normalizedStatus)) {
      return {'status': 'completed', 'data': dataMap, 'message': message};
    }

    if ({
      'pending',
      'processing',
      'submitted',
      'in_progress',
    }.contains(normalizedStatus)) {
      return {'status': 'pending', 'data': dataMap, 'message': message};
    }

    if (normalizedStatus == 'expired') {
      return {
        'status': 'expired',
        'code': code.isEmpty ? 'EXPIRED' : code,
        'message': message,
      };
    }

    if (normalizedStatus == 'not_started' ||
        normalizedStatus == 'not-started') {
      // Treat not_started as failed so user can retry
      return {
        'status': 'failed',
        'code': 'NOT_STARTED',
        'message': 'KYC not started. Please complete document submission in DigiLocker.',
        'data': dataMap,
      };
    }

    return {
      'status': 'failed',
      'code': code,
      'message': message,
      'data': dataMap,
    };
  }

  void _closeAsCancelled() {
    Navigator.pop(context, {
      'status': 'cancelled',
      'message': 'DigiLocker flow cancelled by user.',
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isProcessing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isProcessing) {
          _closeAsCancelled();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Complete KYC'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isProcessing ? null : _closeAsCancelled,
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading && !_isProcessing)
              Container(
                color: Colors.white,
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF84BD00)),
                    SizedBox(height: 16),
                    Text(
                      'Loading DigiLocker...',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            if (_isProcessing)
              Container(
                color: Colors.white.withValues(alpha: 0.96),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF84BD00)),
                    SizedBox(height: 20),
                    Text(
                      'Verifying your documents',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please wait, do not close this screen.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
