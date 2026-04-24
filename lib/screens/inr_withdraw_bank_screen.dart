import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/wallet_service.dart';
import '../services/auth_service.dart';
import 'bank_withdrawal_screen.dart';
import 'add_inr_bank_screen.dart';

class InrWithdrawBankScreen extends StatefulWidget {
  const InrWithdrawBankScreen({super.key});

  @override
  State<InrWithdrawBankScreen> createState() => _InrWithdrawBankScreenState();
}

class _InrWithdrawBankScreenState extends State<InrWithdrawBankScreen> {
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
      final result = await WalletService.getINRBankDetails();
      debugPrint('InrWithdrawBankScreen: Bank details result: $result');
      
      if (result['success'] == true && result['data'] != null) {
        final rawData = result['data'];
        List<Map<String, dynamic>> accounts = [];
        
        void parseItem(dynamic item) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            if (map.containsKey('accountNumber') || map.containsKey('bankName') || map.containsKey('Name')) {
              accounts.add(map);
            }
          }
        }

        if (rawData is List) {
          for (var item in rawData) parseItem(item);
        } else if (rawData is Map) {
          if (rawData['docs'] is List) {
            for (var item in rawData['docs']) parseItem(item);
          } else if (rawData['data'] is List) {
            for (var item in rawData['data']) parseItem(item);
          } else {
            parseItem(rawData);
          }
        }
        
        setState(() {
          _bankList = accounts.where((b) => b['accountNumber'] != null && b['accountNumber'].toString().isNotEmpty).toList();
          _selectedBank = _bankList.isNotEmpty ? _bankList.first : null;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching bank details: $e');
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
          'Select Bank Account',
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
                    const Text(
                      'Select Bank Account',
                      style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    _buildBankDropdown(),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AddInrBankScreen()),
                          ).then((value) {
                            if (value == true) {
                              _fetchBankDetails();
                            }
                          });
                        },
                        icon: const Icon(Icons.add, color: Color(0xFF84BD00), size: 18),
                        label: const Text(
                          'Add New Account',
                          style: TextStyle(color: Color(0xFF84BD00), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else ...[
                    const SizedBox(height: 40),
                    Center(
                      child: Column(
                        children: [
                          const Icon(Icons.account_balance_outlined, color: Colors.white24, size: 64),
                          const SizedBox(height: 16),
                          const Text(
                            'No Bank Account Found',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Please add a bank account to proceed with withdrawal',
                            style: TextStyle(color: Colors.white54, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AddInrBankScreen()),
                              ).then((value) {
                                if (value == true) {
                                  _fetchBankDetails();
                                }
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF84BD00),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Add Bank Account', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
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
                          _buildDetailRow('Bank Name', _selectedBank?['bankName'] ?? _selectedBank?['Name'] ?? 'N/A'),
                          const SizedBox(height: 16),
                          _buildDetailRow('Account Holder', _selectedBank?['accountHolderName'] ?? _selectedBank?['accountHolder'] ?? 'N/A'),
                          const SizedBox(height: 16),
                          _buildDetailRow('Account Number', _selectedBank?['accountNumber'] ?? 'N/A', showCopy: true),
                          const SizedBox(height: 16),
                          _buildDetailRow('IFSC Code', _selectedBank?['ifscCode'] ?? 'N/A', showCopy: true),
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
                    builder: (context) => BankWithdrawalScreen(
                      bankDetails: _selectedBank,
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
              setState(() => _selectedBank = value);
            }
          },
          items: _bankList.map<DropdownMenuItem<Map<String, dynamic>>>((bank) {
            return DropdownMenuItem<Map<String, dynamic>>(
              value: bank,
              child: Text(bank['bankName'] ?? bank['Name'] ?? 'Unknown Bank'),
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
