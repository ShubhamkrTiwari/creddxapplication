import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/wallet_service.dart';
import '../services/auth_service.dart';
import 'upi_withdrawal_screen.dart';

class InrWithdrawUpiScreen extends StatefulWidget {
  const InrWithdrawUpiScreen({super.key});

  @override
  State<InrWithdrawUpiScreen> createState() => _InrWithdrawUpiScreenState();
}

class _InrWithdrawUpiScreenState extends State<InrWithdrawUpiScreen> {
  bool _isLoading = true;
  List<dynamic> _upiList = [];
  Map<String, dynamic>? _selectedUpi;

  @override
  void initState() {
    super.initState();
    _fetchUpiDetails();
  }

  Future<void> _fetchUpiDetails() async {
    try {
      final token = await AuthService.getToken();
      final headers = {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final response = await http.get(
        Uri.parse('${WalletService.baseUrl}/wallet/v1/wallet/deposit/upi-details'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final data = responseData is Map ? (responseData['data'] ?? responseData) : responseData;
        if (data is List) {
          setState(() {
            _upiList = data.where((u) => u['upiId'] != null && u['upiId'].toString().isNotEmpty).toList();
            _selectedUpi = _upiList.isNotEmpty ? _upiList.first : null;
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
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
          'Select UPI ID',
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
                  if (_upiList.isNotEmpty) ...[
                    const Text(
                      'Select UPI ID',
                      style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
                    ),
                    const SizedBox(height: 12),
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
                          const SizedBox(height: 16),
                          _buildDetailRow('Merchant Name', _selectedUpi?['accountHolderName'] ?? 'N/A'),
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
              onPressed: _selectedUpi == null ? null : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UpWithdrawalScreen(
                      upiDetails: _selectedUpi,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
                disabledBackgroundColor: Colors.white10,
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
              setState(() => _selectedUpi = value);
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
}
