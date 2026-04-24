import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../services/wallet_service.dart';
import '../services/auth_service.dart';
import '../main_navigation.dart';

class PaymentProofScreen extends StatefulWidget {
  final String amount;
  final String paymentMethod;
  final String? account;
  final String? senderAccountName;
  
  const PaymentProofScreen({
    super.key, 
    required this.amount, 
    required this.paymentMethod,
    this.account,
    this.senderAccountName,
  });

  @override
  State<PaymentProofScreen> createState() => _PaymentProofScreenState();
}

class _PaymentProofScreenState extends State<PaymentProofScreen> {
  final TextEditingController _transactionIdController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isLoading = false;
  Map<String, dynamic>? _bankDetails;

  @override
  void initState() {
    super.initState();
    _fetchBankDetails();
  }

  Future<void> _fetchBankDetails() async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('${WalletService.baseUrl}/wallet/v1/wallet/deposit/bank-details'),
        headers: {
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final bankResponseData = json.decode(response.body);
        setState(() {
          // Extract data array from response
          final bankData = bankResponseData is Map ? (bankResponseData['data'] ?? bankResponseData) : bankResponseData;
          // Handle list response - take first item
          if (bankData is List && bankData.isNotEmpty) {
            _bankDetails = bankData.first;
          } else if (bankData is Map) {
            _bankDetails = Map<String, dynamic>.from(bankData);
          }
        });
      }
    } catch (e) {
      // Ignore error
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1080,
    );
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<void> _submitDeposit() async {
    if (_transactionIdController.text.isEmpty) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await AuthService.getToken();
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${WalletService.baseUrl}/wallet/v1/wallet/deposit/inr-request'),
      );
      
      // Add auth header
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      request.fields['amount'] = widget.amount;
      request.fields['txid'] = _transactionIdController.text;
      
      // Use _id for the account field, fallback to widget.account or a default ID
      final accountId = _bankDetails?['_id'] ?? widget.account ?? '698f14193c74d9cba2ab4eb1';
      final accountName = _bankDetails?['accountHolderName'] ?? _bankDetails?['accountHolder'] ?? widget.senderAccountName ?? 'shikha';
      
      request.fields['account'] = accountId;
      request.fields['senderAccountName'] = accountName;
      
      if (_selectedImage != null) {
        if (kIsWeb) {
          final bytes = await _selectedImage!.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            'screenshot',
            bytes,
            filename: _selectedImage!.name,
          ));
        } else {
          request.files.add(await http.MultipartFile.fromPath(
            'screenshot',
            _selectedImage!.path,
          ));
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        // Show success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deposit request submitted successfully'),
            backgroundColor: Color(0xFF84BD00),
          ),
        );
        // Navigate back to home screen immediately
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainNavigation()),
            (route) => false,
          );
        }
      } else {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${response.body}')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _transactionIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Payment Proof',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            // Order Details Card
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailRow('Amount', '${widget.amount}.00 INR'),
                  const Divider(color: Color(0xFF2C2C2E), height: 24),
                  _buildDetailRow('Payment Method', widget.paymentMethod),
                  if (_bankDetails != null) ...[
                    const Divider(color: Color(0xFF2C2C2E), height: 24),
                    _buildDetailRow('Account Number', _bankDetails!['accountNumber'] ?? 'N/A'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Upload Screenshot
            const Text(
              'Add Payment Screenshot',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF3C3C3E),
                    style: BorderStyle.solid,
                  ),
                ),
                child: _selectedImage == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/uploadicon.png',
                            width: 48,
                            height: 48,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'UPLOAD HERE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '(JPG/JPEG/PNG/BMP, less than 1MB)',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb
                            ? Image.network(
                                _selectedImage!.path,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _buildImageError(),
                              )
                            : Image.file(
                                File(_selectedImage!.path),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _buildImageError(),
                              ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            // Transaction ID
            const Text(
              'Transaction ID',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _transactionIdController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Enter Transaction ID',
                  hintStyle: TextStyle(color: Color(0xFF8E8E93)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitDeposit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
                disabledBackgroundColor: Colors.white10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Confirm',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool showCopy = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
        ),
        Row(
          children: [
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            if (showCopy) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  // Copy to clipboard
                },
                child: const Icon(
                  Icons.copy,
                  color: Color(0xFF8E8E93),
                  size: 16,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildImageError() {
    return Container(
      color: const Color(0xFF2C2C2E),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            color: Color(0xFF8E8E93),
            size: 48,
          ),
          SizedBox(height: 8),
          Text(
            'Image Error',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
