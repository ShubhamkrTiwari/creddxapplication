import 'package:flutter/material.dart';

import '../services/user_service.dart';
import 'digilocker_webview_screen.dart';
import 'kyc_selfie_screen.dart';

class KYCDigiLockerScreen extends StatefulWidget {
  const KYCDigiLockerScreen({super.key});

  @override
  State<KYCDigiLockerScreen> createState() => _KYCDigiLockerScreenState();
}

class _KYCDigiLockerScreenState extends State<KYCDigiLockerScreen>
    with WidgetsBindingObserver {
  final UserService _userService = UserService();

  bool _isDigiLockerConnected = false;
  bool _isLoading = false;
  bool _isCheckingStatus = false;
  bool _sessionStarted = false;
  Map<String, dynamic>? _fetchedDocuments;
  String? _requestId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _sessionStarted &&
        !_isDigiLockerConnected &&
        !_isLoading &&
        !_isCheckingStatus) {
      _checkDigiLockerStatus(silent: true);
    }
  }

  Future<void> _connectDigiLocker() async {
    setState(() => _isLoading = true);

    try {
      final initiateResult = await _userService.initiateDigiLockerConnection();
      if (!mounted) return;

      if (initiateResult['success'] != true) {
        setState(() => _isLoading = false);
        _showError(initiateResult['error'] ?? 'Failed to initiate DigiLocker.');
        return;
      }

      final data = initiateResult['data'];
      final kycUrl = _extractKycUrl(data);
      _requestId = _extractRequestId(data);

      if (kycUrl == null || kycUrl.isEmpty) {
        setState(() => _isLoading = false);
        _showError('DigiLocker URL not received from server.');
        return;
      }

      setState(() {
        _isLoading = false;
        _sessionStarted = true;
      });

      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              DigiLockerWebViewScreen(kycUrl: kycUrl, requestId: _requestId),
        ),
      );

      if (!mounted) return;

      // If user closed WebView without completing (result is null),
      // reset session to allow retry
      if (result == null) {
        setState(() {
          _sessionStarted = false;
          _isDigiLockerConnected = false;
        });
        _showError(
          'DigiLocker was closed without completing. Please click "Start KYC with DigiLocker" again to retry.',
        );
        return;
      }

      await _handleWebFlowResult(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Error connecting to DigiLocker: $e');
    }
  }

  String? _extractKycUrl(dynamic data) {
    if (data is String) {
      if (data.startsWith('http://') || data.startsWith('https://')) {
        return data;
      }
      return null;
    }

    if (data is! Map) {
      return null;
    }

    final map = Map<String, dynamic>.from(data);
    final url = _findFirstStringValue(map, const [
      'url',
      'redirect_url',
      'redirectUrl',
      'digilocker_url',
      'digilockerUrl',
      'auth_url',
      'authUrl',
      'link',
      'deeplink',
      'deepLink',
    ]);
    final token = _findFirstStringValue(map, const [
      'token',
      'access_token',
      'accessToken',
      'auth_token',
      'authToken',
    ]);

    if (url != null && url.isNotEmpty) {
      return url;
    }
    if (token != null && token.isNotEmpty) {
      return 'https://digilocker.mannit.in/?token=$token';
    }
    return null;
  }

  String? _extractRequestId(dynamic data) {
    if (data is! Map) {
      return null;
    }

    final map = Map<String, dynamic>.from(data);
    return map['request_id']?.toString() ??
        map['requestId']?.toString() ??
        map['req_id']?.toString() ??
        map['reference_id']?.toString() ??
        map['referenceId']?.toString() ??
        map['session_id']?.toString() ??
        map['sessionId']?.toString() ??
        map['client_id']?.toString() ??
        map['clientId']?.toString() ??
        map['id']?.toString();
  }

  String? _findFirstStringValue(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }

    for (final value in map.values) {
      if (value is Map) {
        final nested = _findFirstStringValue(
          Map<String, dynamic>.from(value),
          keys,
        );
        if (nested != null && nested.isNotEmpty) {
          return nested;
        }
      } else if (value is String &&
          (value.startsWith('http://') || value.startsWith('https://'))) {
        return value;
      }
    }

    return null;
  }

  Future<void> _handleWebFlowResult(Map<String, dynamic> result) async {
    final status = (result['status'] ?? '').toString().toLowerCase();

    if (status == 'completed') {
      final data = result['data'];
      final dataMap = data is Map<String, dynamic> ? data : <String, dynamic>{};

      // Validate that Aadhaar document is present - reject if only 12th doc or others submitted
      final documents = _parseDocuments(dataMap['documents'] ?? dataMap['docs']);
      if (!documents.containsKey('aadhaar')) {
        setState(() {
          _sessionStarted = false;
          _isDigiLockerConnected = false;
        });
        _showError(
          'Aadhaar is mandatory for KYC. Please retry and select Aadhaar in DigiLocker. Other documents like 12th certificate are not accepted.',
        );
        return;
      }

      setState(() {
        _isDigiLockerConnected = true;
        _fetchedDocuments = documents;
      });

      await _userService.fetchProfileDataFromAPI();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('DigiLocker verification completed.'),
          backgroundColor: Color(0xFF84BD00),
        ),
      );
      _proceedToSelfie();
      return;
    }

    if (status == 'pending') {
      // If pending without documents, user likely closed without submitting
      // Reset session to allow retry
      setState(() {
        _sessionStarted = false;
        _isDigiLockerConnected = false;
      });
      _showError(
        'KYC not completed. Please click "Start KYC with DigiLocker" again and complete the document submission.',
      );
      return;
    }

    if (status == 'expired') {
      setState(() {
        _sessionStarted = false;
        _isDigiLockerConnected = false;
      });
      _showError('DigiLocker session expired. Start a fresh KYC session.');
      return;
    }

    if (status == 'cancelled') {
      setState(() {
        _sessionStarted = false;
        _isDigiLockerConnected = false;
      });
      return;
    }

    // For any failed status, reset session to allow retry
    setState(() {
      _sessionStarted = false;
      _isDigiLockerConnected = false;
    });
    _showError(
      _buildFailureMessage(
        result['code']?.toString(),
        result['message']?.toString(),
      ),
    );
  }

  String _buildFailureMessage(String? code, String? message) {
    switch ((code ?? '').toUpperCase()) {
      case 'AADHAAR_CONSENT_NOT_GIVEN':
        return 'Aadhaar was not selected in DigiLocker. Select Aadhaar on the consent screen and retry.';
      case 'USER_DENIED_ACCESS':
        return 'DigiLocker access was denied. Allow access on the authorization screen and try again.';
      case 'EXPIRED':
        return 'DigiLocker session expired. Start a fresh KYC session.';
      default:
        return message?.isNotEmpty == true
            ? message!
            : 'DigiLocker verification failed.';
    }
  }

  Future<void> _checkDigiLockerStatus({bool silent = false}) async {
    if (!_sessionStarted || _isCheckingStatus) {
      return;
    }

    setState(() {
      _isLoading = true;
      _isCheckingStatus = true;
    });

    try {
      final result = await _lookupDigiLockerStatus();
      if (!mounted) return;

      await _handleWebFlowResult(_normalizeStatusResult(result));
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCheckingStatus = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isCheckingStatus = false;
      });
      if (!silent) {
        _showError('Error checking DigiLocker status: $e');
      }
    }
  }

  Future<Map<String, dynamic>> _lookupDigiLockerStatus() async {
    final requestId = _requestId;
    if (requestId != null && requestId.isNotEmpty) {
      return _userService.checkDigiLockerStatus(requestId);
    }
    return _userService.checkKYCStatusPost();
  }

  Map<String, dynamic> _normalizeStatusResult(Map<String, dynamic> response) {
    final data = response['data'];
    final dataMap = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final rawStatus =
        [
              response['status'],
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

    if ({
      'completed',
      'already_completed',
      'verified',
      'approved',
    }.contains(normalizedStatus)) {
      return {'status': 'completed', 'data': dataMap};
    }

    if ({
      'pending',
      'processing',
      'submitted',
      'in_progress',
    }.contains(normalizedStatus)) {
      return {
        'status': 'pending',
        'message': response['message'] ?? dataMap['message'],
      };
    }

    if (normalizedStatus == 'expired') {
      return {'status': 'expired'};
    }

    return {
      'status': 'failed',
      'code': code,
      'message': response['error'] ?? response['message'] ?? dataMap['message'],
    };
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Map<String, dynamic> _parseDocuments(dynamic documents) {
    if (documents == null) return {};

    final Map<String, dynamic> result = {};
    if (documents is! List) {
      return result;
    }

    for (final doc in documents) {
      if (doc is! Map) {
        continue;
      }

      final docType = (doc['type'] ?? doc['doc_type'] ?? '')
          .toString()
          .toLowerCase();
      final docNumber = (doc['number'] ?? doc['doc_number'] ?? '').toString();

      if (docType == 'aadhaar') {
        result['aadhaar'] = {
          'name': 'Aadhaar Card',
          'number': _maskNumber(docNumber),
        };
      } else if (docType == 'pan') {
        result['pan'] = {'name': 'PAN Card', 'number': _maskNumber(docNumber)};
      }
    }

    return result;
  }

  String _maskNumber(String number) {
    if (number.length <= 4) {
      return number;
    }
    return 'XXXX-XXXX-${number.substring(number.length - 4)}';
  }

  void _proceedToSelfie() {
    if (!_isDigiLockerConnected) {
      _showError('Please complete DigiLocker first.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KYCSelfieScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Know Your Customers (KYC)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'DigiLocker Verification (1/2)',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDigiLockerSection(),
            const SizedBox(height: 24),
            if (_sessionStarted && !_isDigiLockerConnected)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _checkDigiLockerStatus(),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.refresh, color: Colors.black),
                  label: Text(
                    _isLoading ? 'Checking...' : 'Check DigiLocker Status',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF84BD00),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            if (_sessionStarted && !_isDigiLockerConnected)
              const SizedBox(height: 24),
            if (_fetchedDocuments != null && _fetchedDocuments!.isNotEmpty) ...[
              _buildFetchedDocumentsSection(),
              const SizedBox(height: 24),
            ],
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildDigiLockerSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDigiLockerConnected
              ? const Color(0xFF84BD00)
              : Colors.white24,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF84BD00).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              _isDigiLockerConnected ? Icons.verified : Icons.account_balance,
              color: const Color(0xFF84BD00),
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _isDigiLockerConnected
                ? 'DigiLocker Connected'
                : 'Connect DigiLocker',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isDigiLockerConnected
                ? 'Your Aadhaar details were verified successfully. You can continue to selfie verification.'
                : 'A secure DigiLocker session will open inside the app. Login, approve Aadhaar access, and return here automatically.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _connectDigiLocker,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Icon(
                      _isDigiLockerConnected ? Icons.check_circle : Icons.link,
                      color: Colors.black,
                    ),
              label: Text(
                _isLoading
                    ? 'Starting...'
                    : _isDigiLockerConnected
                    ? 'Reconnect DigiLocker'
                    : 'Start KYC with DigiLocker',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFetchedDocumentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fetched Documents',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ..._fetchedDocuments!.entries.map((entry) {
          final document = entry.value as Map<String, dynamic>;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF84BD00).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.description,
                    color: Color(0xFF84BD00),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document['name']?.toString() ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Number: ${document['number'] ?? ''}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.verified, color: Color(0xFF84BD00)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C1C1E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Back'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isDigiLockerConnected ? _proceedToSelfie : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF84BD00),
              foregroundColor: Colors.black,
              disabledBackgroundColor: const Color(
                0xFF84BD00,
              ).withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Next',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
