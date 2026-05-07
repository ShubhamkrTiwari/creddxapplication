import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Map<String, dynamic>? _selectedBank;

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
      debugPrint('BankDetailsScreen: Fetching bank details...');
      final bankResponse = await http.get(
        Uri.parse('${WalletService.baseUrl}/wallet/v1/wallet/deposit/bank-details'),
        headers: headers,
      );
      debugPrint('BankDetailsScreen: Bank API Status: ${bankResponse.statusCode}');
      debugPrint('BankDetailsScreen: Bank API Body: ${bankResponse.body}');
      
      setState(() {
        if (bankResponse.statusCode == 200) {
          final bankResponseData = json.decode(bankResponse.body);
          final bankData = bankResponseData is Map ? (bankResponseData['data'] ?? bankResponseData) : bankResponseData;
          debugPrint('BankDetailsScreen: Parsed bankData: $bankData (type: ${bankData.runtimeType})');
          if (bankData is List) {
            _bankList = bankData;
            _selectedBank = bankData.firstWhere(
              (b) => b['accountNumber'] != null && b['accountNumber'].toString().isNotEmpty,
              orElse: () => bankData.isNotEmpty ? bankData.first : null,
            );
            debugPrint('BankDetailsScreen: Bank list count: ${_bankList.length}');
          } else {
            debugPrint('BankDetailsScreen: bankData is not a List');
          }
        } else {
          debugPrint('BankDetailsScreen: Bank API failed with status ${bankResponse.statusCode}');
        }
        _isLoading = false;
        debugPrint('BankDetailsScreen: Final - banks: ${_bankList.length}');
      });
    } catch (e) {
      debugPrint('BankDetailsScreen: Error fetching details: $e');
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
                          _buildDetailRow('Bank Name', _selectedBank?['Name'] ?? 'N/A', showCopy: true),
                          const SizedBox(height: 16),
                          _buildDetailRow('Account Holder', _selectedBank?['accountHolderName'] ?? 'N/A', showCopy: true),
                          const SizedBox(height: 16),
                          _buildDetailRow('Account Number', _selectedBank?['accountNumber'] ?? 'N/A', showCopy: true),
                          const SizedBox(height: 16),
                          _buildDetailRow('IFSC Code', _selectedBank?['ifscCode'] ?? 'N/A', showCopy: true),
                        ],
                      ),
                    ),
                  // Empty state when no bank details available
                  if (_bankList.isEmpty)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 100),
                          const Icon(
                            Icons.account_balance_outlined,
                            color: Color(0xFF8E8E93),
                            size: 64,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'No Payment Details Available',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Bank details are not available at the moment. Please try again later.',
                            style: TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          ElevatedButton.icon(
                            onPressed: _fetchBankDetails,
                            icon: const Icon(Icons.refresh, color: Colors.black),
                            label: const Text(
                              'Retry',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF84BD00),
                              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
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
              onPressed: _selectedBank == null ? null : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PayBankTransferScreen(
                      amount: widget.amount,
                      accountId: _selectedBank?['_id']?.toString(),
                      accountHolderName: _selectedBank?['accountHolderName']?.toString(),
                      accountNumber: _selectedBank?['accountNumber']?.toString(),
                      bankName: _selectedBank?['Name']?.toString(),
                      ifscCode: _selectedBank?['ifscCode']?.toString(),
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

  Widget _buildDetailRow(String label, String value, {bool showCopy = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
          ),
        ),
        Expanded(
          flex: 3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
              if (showCopy && value != 'N/A') ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: value));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$label copied!'),
                          backgroundColor: const Color(0xFF84BD00),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: const Icon(
                    Icons.copy,
                    color: Color(0xFF84BD00),
                    size: 16,
                  ),
                ),
              ],
            ],
          ),
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
}
