import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'kyc_selfie_screen.dart';
import '../services/user_service.dart';

class KYCDigiLockerScreen extends StatefulWidget {
  const KYCDigiLockerScreen({super.key});

  @override
  State<KYCDigiLockerScreen> createState() => _KYCDigiLockerScreenState();
}

class _KYCDigiLockerScreenState extends State<KYCDigiLockerScreen> with WidgetsBindingObserver {
  bool _isDigiLockerConnected = false;
  bool _isLoading = false;
  Map<String, dynamic>? _fetchedDocuments;
  Map<String, dynamic>? _kycUserData;
  final UserService _userService = UserService();

  String? _clientId;
  String? _requestId;
  String? _lastOpenedUrl;
  bool _hasOpenedUrl = false;
  bool _statusCheckedAndVerified = false;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  bool _isCheckingStatus = false;

  // Start auto refresh when status is pending
  void _startAutoRefresh() {
    _stopAutoRefresh(); // Clear any existing timer
    
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_statusCheckedAndVerified && _requestId != null) {
        print('Auto refreshing KYC status via API...');
        await _checkKYCStatusViaAPI();
      } else {
        _stopAutoRefresh(); // Stop when verified or no request ID
      }
    });
  }

  // Stop auto refresh timer
  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  // Check KYC status via /auth/me endpoint for auto refresh
  Future<void> _checkKYCStatusViaAPI() async {
    if (_isCheckingStatus) return;
    
    try {
      // Check KYC status from /auth/me endpoint
      await _userService.fetchProfileDataFromAPI();
      
      final status = _userService.kycStatus.toLowerCase();
      
      print('Auto-refresh KYC Status from /auth/me: $status');
      
      // Check if KYC is completed
      bool isCompleted = status == 'completed';
      
      if (isCompleted) {
        if (mounted) {
          setState(() {
            _isDigiLockerConnected = true;
            _statusCheckedAndVerified = true;
            _hasOpenedUrl = false;
            _lastOpenedUrl = null;
          });

          // Stop auto refresh since status is now verified
          _stopAutoRefresh();

          // Show success message and redirect immediately to selfie screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document shared successfully! Redirecting to selfie upload...'),
              backgroundColor: Color(0xFF84BD00),
            ),
          );

          // Immediate redirect to selfie screen
          if (mounted) {
            _proceedToSelfie();
          }
        }
      }
    } catch (e) {
      print('Auto-refresh error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Automatically check status when user returns to the app from the browser
    if (state == AppLifecycleState.resumed && (_isLoading || _hasOpenedUrl)) {
      // Add a small delay to ensure the app is fully resumed
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkDigiLockerStatus();
          // Start auto refresh if DigiLocker was opened but status not verified
          if (_hasOpenedUrl && !_statusCheckedAndVerified) {
            _startAutoRefresh();
          }
        }
      });
    }
  }

  Future<void> _connectDigiLocker() async {
    setState(() => _isLoading = true);

    try {
      // Step 1: Initiate DigiLocker connection via API
      final initiateResult = await _userService.initiateDigiLockerConnection();

      print('DigiLocker Initiate Result: $initiateResult');

      if (initiateResult['success'] == true) {
        final data = initiateResult['data'];
        print('DigiLocker API Data: $data');
        
        // Check for various possible field names
        final String? digiLockerUrl = data?['url'] ?? data?['redirect_url'] ?? data?['redirectUrl'] ?? data?['digilocker_url'] ?? data?['digilockerUrl'];
        final String? token = data?['token'] ?? data?['access_token'] ?? data?['accessToken'];
        _requestId = data?['request_id']?.toString() ?? data?['requestId']?.toString() ?? data?['id']?.toString();

        print('DigiLocker URL: $digiLockerUrl');
        print('DigiLocker Token: $token');
        print('DigiLocker RequestId: $_requestId');

        if (digiLockerUrl != null && digiLockerUrl.isNotEmpty) {
          // Modify URL to use app callback scheme instead of website redirect
          String modifiedUrl = digiLockerUrl;
          if (digiLockerUrl.contains('redirect_url=')) {
            modifiedUrl = digiLockerUrl.replaceAll(RegExp(r'redirect_url=[^&]*'), 'redirect_url=creddx://kyc/callback');
          }
          await _openDigiLockerUrl(modifiedUrl);
          return;
        } else if (token != null && token.isNotEmpty) {
          // Construct URL using the fresh token from API with app callback
          final String constructedUrl = 'https://digilocker.mannit.in/?token=$token&redirect_url=creddx://kyc/callback';
          print('Constructed DigiLocker URL: $constructedUrl');
          await _openDigiLockerUrl(constructedUrl);
          return;
        } else {
          // No URL or token found
          setState(() => _isLoading = false);
          _showError('DigiLocker URL not received from server. Please try again.');
          return;
        }
      } else {
        // API returned error
        setState(() => _isLoading = false);
        _showError(initiateResult['error'] ?? 'Failed to initiate DigiLocker. Please try again.');
        return;
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('DigiLocker Connection Error: $e');
      _showError('Error connecting to DigiLocker: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _openDigiLockerUrl(String url) async {
    final uri = Uri.parse(url);
    
    try {
      // platformDefault allows the OS to choose the best way to open the URL
      // this often fixes "Access Denied" issues caused by browser restrictions
      final bool launched = await launchUrl(
        uri, 
        mode: LaunchMode.platformDefault,
      );

      if (launched && mounted) {
        // Store the URL for potential reopening
        setState(() {
          _lastOpenedUrl = url;
          _hasOpenedUrl = true;
        });
        // Keep _isLoading true so didChangeAppLifecycleState can trigger status check
        _showReturnDialog();
        // Start auto refresh to continuously check API status
        _startAutoRefresh();
      } else {
        setState(() => _isLoading = false);
        throw 'Could not launch $url';
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening DigiLocker: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showReturnDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Complete DigiLocker Verification',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Please complete the DigiLocker verification in your browser. Once done, tap "Check Status" below.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (Navigator.of(dialogContext).canPop()) {
                Navigator.of(dialogContext).pop();
              }
              setState(() => _isLoading = false);
            },
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              if (Navigator.of(dialogContext).canPop()) {
                Navigator.of(dialogContext).pop();
              }
              // Reopen the same URL
              if (_lastOpenedUrl != null) {
                _openDigiLockerUrl(_lastOpenedUrl!);
              }
            },
            child: const Text(
              'Reopen URL',
              style: TextStyle(color: Color(0xFF84BD00)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (Navigator.of(dialogContext).canPop()) {
                Navigator.of(dialogContext).pop();
              }
              _checkDigiLockerStatus();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF84BD00),
              foregroundColor: Colors.black,
            ),
            child: const Text('Check Status'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkDigiLockerStatus() async {
    if (_isCheckingStatus) return;
    
    setState(() {
      _isLoading = true;
      _isCheckingStatus = true;
    });

    try {
      // Step 1: Check KYC status from /auth/me endpoint
      await _userService.fetchProfileDataFromAPI();
      
      bool isSuccess = false;
      
      final status = _userService.kycStatus.toLowerCase();
      print('KYC Status from /auth/me: $status');
      
      if (status == 'completed') {
        isSuccess = true;
      }

      // Step 2: Fallback to specific DigiLocker request status if needed
      if (!isSuccess && _requestId != null) {
        final digiStatus = await _userService.checkDigiLockerStatus(_requestId!);
        if (digiStatus['success'] && digiStatus['data']?['status'] == 'completed') {
          isSuccess = true;
          _clientId = digiStatus['data']?['client_id'];
          _fetchedDocuments = _parseDocuments(digiStatus['data']?['documents']);
        }
      }

      if (isSuccess) {
        if (mounted) {
          // Dismiss the dialog if it's showing (since we've succeeded in background)
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          
          setState(() {
            _isDigiLockerConnected = true;
            _isLoading = false;
            _isCheckingStatus = false;
            _statusCheckedAndVerified = true;
            _hasOpenedUrl = false;
            _lastOpenedUrl = null;
          });

          // Stop auto refresh since status is now verified
          _stopAutoRefresh();

          // Show success message and redirect immediately to selfie screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document shared successfully! Redirecting to selfie upload...'),
              backgroundColor: Color(0xFF84BD00),
            ),
          );

          // Immediate redirect to selfie screen
          if (mounted) {
            _proceedToSelfie();
          }
        }
      } else {
        // If status check failed, start auto refresh if DigiLocker was opened
        if (_hasOpenedUrl && !_statusCheckedAndVerified) {
          _startAutoRefresh();
        }
        
        setState(() {
          _isLoading = false;
          _isCheckingStatus = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification not completed yet. Please finish the process in your browser.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isCheckingStatus = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _parseDocuments(dynamic documents) {
    if (documents == null) return {};

    final Map<String, dynamic> result = {};
    
    if (documents is List) {
      for (var doc in documents) {
        if (doc['type'] == 'aadhaar' || doc['doc_type'] == 'aadhaar') {
          result['aadhaar'] = {
            'name': 'Aadhaar Card',
            'number': _maskNumber(doc['number'] ?? doc['doc_number'] ?? ''),
            'verified': true,
          };
        } else if (doc['type'] == 'pan' || doc['doc_type'] == 'pan') {
          result['pan'] = {
            'name': 'PAN Card',
            'number': _maskNumber(doc['number'] ?? doc['doc_number'] ?? ''),
            'verified': true,
          };
        }
      }
    }

    return result;
  }

  String _maskNumber(String number) {
    if (number.length <= 4) return number;
    return 'XXXX-XXXX-${number.substring(number.length - 4)}';
  }

  void _resetDigiLockerConnection() {
    setState(() {
      _requestId = null;
      _clientId = null;
      _lastOpenedUrl = null;
      _hasOpenedUrl = false;
      _isLoading = false;
      _isCheckingStatus = false;
    });
  }

  void _proceedToSelfie() {
    // Navigate directly to selfie verification
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const KYCSelfieScreen(),
      ),
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
          children: [
            const Text(
              'Know Your Customers (KYC)',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Text(
              'DigiLocker Verification (1/3)',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - 120,
          ),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDigiLockerSection(),
                const SizedBox(height: 32),
                if (_requestId != null && (!_isDigiLockerConnected || (_isDigiLockerConnected && !_statusCheckedAndVerified))) ...[
                  if (_hasOpenedUrl && _lastOpenedUrl != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : () => _openDigiLockerUrl(_lastOpenedUrl!),
                        icon: const Icon(Icons.open_in_browser, color: Colors.black),
                        label: const Text(
                          'Reopen DigiLocker URL',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _checkDigiLockerStatus,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.refresh, color: Colors.black),
                      label: Text(
                        _isLoading 
                            ? 'Checking...' 
                            : _isDigiLockerConnected 
                                ? 'Confirm Status & Enable Next'
                                : 'Check DigiLocker Status',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF84BD00),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
                if (_isDigiLockerConnected) ...[
                  _buildFetchedDocumentsSection(),
                  const SizedBox(height: 32),
                ],
                _buildNavigationButtons(),
                const SizedBox(height: 20),
              ],
            ),
          ),
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
          color: _isDigiLockerConnected ? const Color(0xFF84BD00) : Colors.white24,
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
            _isDigiLockerConnected ? 'DigiLocker Connected' : 'Connect DigiLocker',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isDigiLockerConnected
                ? _statusCheckedAndVerified
                    ? 'Your documents have been successfully fetched from DigiLocker.'
                    : 'DigiLocker verification completed! Please click "Check Status" to confirm and proceed.'
                : _hasOpenedUrl
                    ? 'DigiLocker URL opened. Please complete verification or reopen the URL if needed.'
                    : 'Verify your identity using DigiLocker. We will fetch your Aadhaar and PAN details securely.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          if (!_isDigiLockerConnected)
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
                    : const Icon(Icons.link, color: Colors.black),
                label: Text(
                  _isLoading ? 'Connecting...' : 'Connect DigiLocker',
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
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            )
          else
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF84BD00).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF84BD00), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Connected',
                        style: TextStyle(
                          color: Color(0xFF84BD00),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _proceedToSelfie,
                    icon: const Icon(Icons.camera_alt, color: Colors.black),
                    label: const Text(
                      'Upload Selfie Now',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF84BD00),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFetchedDocumentsSection() {
    // Show KYC user data if available from the new /user/v1/kyc/status endpoint (Image 1)
    if (_kycUserData != null && _kycUserData!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verified Identity Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildKycInfoCard(
            icon: Icons.person,
            title: 'Full Name',
            value: _kycUserData!['name'] ?? 'N/A',
          ),
          const SizedBox(height: 12),
          _buildKycInfoCard(
            icon: Icons.cake,
            title: 'Date of Birth',
            value: _kycUserData!['dob'] ?? 'N/A',
          ),
          const SizedBox(height: 12),
          _buildKycInfoCard(
            icon: Icons.wc,
            title: 'Gender',
            value: _kycUserData!['gender'] ?? 'N/A',
          ),
          const SizedBox(height: 12),
          _buildKycInfoCard(
            icon: Icons.home,
            title: 'Address',
            value: _kycUserData!['address'] ?? 'N/A',
          ),
          const SizedBox(height: 12),
          _buildKycInfoCard(
            icon: Icons.credit_card,
            title: 'Aadhaar Number',
            value: _kycUserData!['aadhaarNumber'] ?? 'N/A',
            isVerified: true,
          ),
          const SizedBox(height: 32),
        ],
      );
    }

    if (_fetchedDocuments == null) return const SizedBox.shrink();

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
                        entry.value['name'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Number: ${entry.value['number'] ?? ''}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF84BD00).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, color: Color(0xFF84BD00), size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Verified',
                        style: TextStyle(
                          color: Color(0xFF84BD00),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildKycInfoCard({
    required IconData icon,
    required String title,
    required String value,
    bool isVerified = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF84BD00), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (isVerified)
            const Icon(Icons.verified, color: Color(0xFF84BD00), size: 20),
        ],
      ),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Back',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _proceedToSelfie,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF84BD00),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              disabledBackgroundColor: const Color(0xFF84BD00).withValues(alpha: 0.3),
            ),
            child: const Text(
              'Selfie',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
