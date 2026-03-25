import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'pay_bank_transfer_screen.dart';
import '../services/wallet_service.dart';
import '../services/auth_service.dart';

class BankDetailsScreen extends StatefulWidget {
  final String amount;
  
  const BankDetailsScreen({super.key, required this.amount});

  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  bool _isLoading = true;
  List<dynamic> _bankList = [];
  List<dynamic> _upiList = [];
  Map<String, dynamic>? _selectedBank;
  Map<String, dynamic>? _selectedUpi;

  @override
  void initState() {
    super.initState();
    _fetchBankDetails();
  }

  Future<void> _fetchBankDetails() async {
    try {
      final token = await AuthService.getToken();
      final headers = {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final bankResponse = await http.get(
        Uri.parse('${WalletService.baseUrl}/wallet/v1/wallet/deposit/bank-details'),
        headers: headers,
      );
      final upiResponse = await http.get(
        Uri.parse('${WalletService.baseUrl}/wallet/v1/wallet/deposit/upi-details'),
        headers: headers,
      );
      setState(() {
        if (bankResponse.statusCode == 200) {
          final bankResponseData = json.decode(bankResponse.body);
          final bankData = bankResponseData is Map ? (bankResponseData['data'] ?? bankResponseData) : bankResponseData;
          if (bankData is List) {
            _bankList = bankData;
            _selectedBank = bankData.firstWhere(
              (b) => b['accountNumber'] != null && b['accountNumber'].toString().isNotEmpty,
              orElse: () => bankData.isNotEmpty ? bankData.first : null,
            );
          }
        }
        if (upiResponse.statusCode == 200) {
          final upiResponseData = json.decode(upiResponse.body);
          final upiData = upiResponseData is Map ? (upiResponseData['data'] ?? upiResponseData) : upiResponseData;
          if (upiData is List) {
            _upiList = upiData;
            _selectedUpi = upiData.firstWhere(
              (u) => u['upiId'] != null && u['upiId'].toString().isNotEmpty,
              orElse: () => upiData.isNotEmpty ? upiData.first : null,
            );
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
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
          'Bank Details',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_bankList.isNotEmpty) ...[
                    _buildBankDropdown(),
                    const SizedBox(height: 20),
                  ],
                  if (_selectedBank != null)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bank Account Details',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildDetailRow('Bank Name', _selectedBank?['Name'] ?? 'N/A'),
                          const SizedBox(height: 16),
                          _buildDetailRow('Account Holder', _selectedBank?['accountHolderName'] ?? 'N/A'),
                          const SizedBox(height: 16),
                          _buildDetailRow('Account Number', _selectedBank?['accountNumber'] ?? 'N/A', showCopy: true),
                          const SizedBox(height: 16),
                          _buildDetailRow('IFSC Code', _selectedBank?['ifscCode'] ?? 'N/A', showCopy: true),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (_upiList.isNotEmpty) ...[
                    _buildUpiDropdown(),
                    const SizedBox(height: 20),
                  ],
                  if (_selectedUpi != null)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'UPI Details',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildDetailRow('UPI ID', _selectedUpi?['upiId'] ?? 'N/A', showCopy: true),
                        ],
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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PayBankTransferScreen(amount: widget.amount),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text(
                'Continue',
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

  Widget _buildBankDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value: _selectedBank,
          isExpanded: true,
          dropdownColor: const Color(0xFF1C1C1E),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedBank = value;
              });
            }
          },
          items: _bankList.map<DropdownMenuItem<Map<String, dynamic>>>((bank) {
            return DropdownMenuItem<Map<String, dynamic>>(
              value: bank,
              child: Text(bank['Name'] ?? 'Unknown Bank'),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildUpiDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value: _selectedUpi,
          isExpanded: true,
          dropdownColor: const Color(0xFF1C1C1E),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedUpi = value;
              });
            }
          },
          items: _upiList.map<DropdownMenuItem<Map<String, dynamic>>>((upi) {
            return DropdownMenuItem<Map<String, dynamic>>(
              value: upi,
              child: Text(upi['Name'] ?? 'Unknown UPI'),
            );
          }).toList(),
        ),
      ),
    );
  }
}
