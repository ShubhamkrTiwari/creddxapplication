import 'package:flutter/material.dart';
import 'dart:async';
import '../services/auth_service.dart';

class KYCPendingScreen extends StatefulWidget {
  const KYCPendingScreen({super.key});

  @override
  State<KYCPendingScreen> createState() => _KYCPendingScreenState();
}

class _KYCPendingScreenState extends State<KYCPendingScreen> {
  String _kycStatus = 'pending';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkKYCStatus();
    
    // Auto-refresh KYC status every 30 seconds
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _checkKYCStatus();
      }
    });
  }

  Future<void> _checkKYCStatus() async {
    final status = await AuthService.getKYCStatus();
    if (mounted) {
      setState(() {
        _kycStatus = status;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshStatus() async {
    setState(() => _isLoading = true);
    await _checkKYCStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'KYC Verification',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Review (3/3)',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF84BD00).withOpacity(0.1),
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.pending_actions,
                color: Color(0xFF84BD00),
                size: 60,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'KYC Under Verification',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _getStatusMessage(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            if (_isLoading)
              const Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFF84BD00)),
                  SizedBox(height: 16),
                  Text(
                    'Checking status...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              )
            else
              _buildStatusCard(),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _refreshStatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text(
                'Refresh Status',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Go Back',
                style: TextStyle(color: Color(0xFF84BD00), fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (_kycStatus.toLowerCase()) {
      case 'approved':
      case 'verified':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'KYC Approved';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'KYC Rejected';
        break;
      case 'pending':
      default:
        statusColor = const Color(0xFF84BD00);
        statusIcon = Icons.hourglass_empty;
        statusText = 'KYC Pending';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            statusIcon,
            color: statusColor,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Current Status: ${_kycStatus.toUpperCase()}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusMessage() {
    switch (_kycStatus.toLowerCase()) {
      case 'approved':
      case 'verified':
        return 'Congratulations! Your KYC has been approved. You can now access all features of the app.';
      case 'rejected':
        return 'Your KYC application has been rejected. Please try again with correct documents.';
      case 'pending':
      default:
        return 'Your KYC application is under review. This usually takes 1-2 business hours. We will notify you once the verification is complete.';
    }
  }
}
