import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/wallet_service.dart';
import '../services/user_service.dart';
import 'otp_verification_screen.dart';
import 'pay_upi_screen.dart';
import 'bank_details_screen.dart';
import 'upi_details_screen.dart';
import 'user_profile_screen.dart';
import 'update_profile_screen.dart';
import 'package:intl/intl.dart';

class InrDepositScreen extends StatefulWidget {
  const InrDepositScreen({super.key});

  @override
  State<InrDepositScreen> createState() => _InrDepositScreenState();
}

class _InrDepositScreenState extends State<InrDepositScreen> {
  final TextEditingController _amountController = TextEditingController();
  String _selectedMethod = 'Bank Transfer';
  bool _showHistory = false;
  bool _isLoadingHistory = false;
  List<dynamic> _depositHistory = [];
  String? _historyError;
  
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() {
      setState(() {});
    });
    // Check profile completeness when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProfileAndShowDialog();
    });
  }

  // Check if profile is complete
  bool _isProfileComplete() {
    return _userService.hasEmail() &&
           _userService.userPhone != null &&
           _userService.userPhone!.isNotEmpty;
  }

  // Check profile and show dialog if incomplete
  void _checkProfileAndShowDialog() {
    if (!_isProfileComplete()) {
      _showProfileRequiredDialog();
    }
  }

  // Show profile completion required dialog
  void _showProfileRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Profile Incomplete',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Please complete your profile (email and phone number) before depositing INR.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to previous screen
              },
              child: const Text('Go Back', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(context, MaterialPageRoute(builder: (context) => const UpdateProfileScreen()));
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF84BD00)),
              child: const Text('Complete Profile', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadDepositHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      debugPrint('INR Deposit Screen: Fetching INR deposit history...');
      final result = await WalletService.getINRDepositHistory(limit: 50);
      debugPrint('INR Deposit Screen: API result: $result');
      
      if (result['success'] == true) {
        final data = result['data'];
        debugPrint('INR Deposit Screen: Data type: ${data.runtimeType}');
        
        if (data != null && data is Map) {
          // API returns { message: "...", result: [...] }
          final transactions = data['result'] ?? data['transactions'];
          if (transactions is List) {
            // Sort by createdAt in descending order (newest first)
            transactions.sort((a, b) {
              final dateA = a['createdAt']?.toString() ?? '';
              final dateB = b['createdAt']?.toString() ?? '';
              return dateB.compareTo(dateA);
            });
            setState(() {
              _depositHistory = transactions;
            });
            debugPrint('INR Deposit Screen: Loaded ${transactions.length} transactions');
          } else {
            setState(() {
              _depositHistory = [];
            });
            debugPrint('INR Deposit Screen: No transactions found in data');
          }
        } else if (data is List) {
          // Sort by createdAt in descending order (newest first)
          data.sort((a, b) {
            final dateA = a['createdAt']?.toString() ?? '';
            final dateB = b['createdAt']?.toString() ?? '';
            return dateB.compareTo(dateA);
          });
          setState(() {
            _depositHistory = data;
          });
          debugPrint('INR Deposit Screen: Loaded ${data.length} transactions (direct list)');
        } else {
          setState(() {
            _depositHistory = [];
          });
          debugPrint('INR Deposit Screen: Empty or invalid data structure');
        }
      } else {
        setState(() {
          _historyError = result['error'] ?? 'Failed to load history';
        });
        debugPrint('INR Deposit Screen: API error: ${result['error']}');
      }
    } catch (e, stackTrace) {
      setState(() {
        _historyError = 'Error: $e';
      });
      debugPrint('INR Deposit Screen: Exception loading history: $e');
      debugPrint('Stack trace: $stackTrace');
    } finally {
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  void _toggleHistory() {
    setState(() {
      _showHistory = !_showHistory;
    });
    if (_showHistory && _depositHistory.isEmpty) {
      _loadDepositHistory();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  bool _isButtonEnabled() {
    return _amountController.text.isNotEmpty && 
           _amountController.text != '0' && 
           _selectedMethod.isNotEmpty;
  }

  bool _isLoading = false;

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _handleContinue() async {
    if (!_isButtonEnabled()) return;

    setState(() => _isLoading = true);

    try {
      // Directly navigate to Bank or UPI details screen based on selection
      if (_selectedMethod == 'UPI Payment') {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UpiDetailsScreen(amount: _amountController.text),
          ),
        );
      } else if (_selectedMethod == 'Bank Transfer') {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BankDetailsScreen(
              amount: _amountController.text,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
          'INR Deposit',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: _toggleHistory,
            icon: Icon(
              _showHistory ? Icons.add_circle_outline : Icons.history,
              color: const Color(0xFF84BD00),
              size: 20,
            ),
            label: Text(
              _showHistory ? 'Deposit' : 'History',
              style: const TextStyle(
                color: Color(0xFF84BD00),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _showHistory ? _buildHistoryView() : _buildDepositForm(),
      bottomNavigationBar: _showHistory
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_isButtonEnabled() && !_isLoading) ? _handleContinue : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isButtonEnabled() ? const Color(0xFF84BD00) : Colors.white10,
                      disabledBackgroundColor: Colors.white10,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                          )
                        : Text(
                            'Continue',
                            style: TextStyle(
                              color: _isButtonEnabled() ? Colors.black : Colors.white24,
                              fontWeight: FontWeight.bold,
                              fontSize: 16
                            ),
                          ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildDepositForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter Amount',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2C2C2E)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      hintStyle: TextStyle(color: Color(0xFF8E8E93), fontSize: 16),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const Text(
                  'INR',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'Payment Mode',
            style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
          ),
          const SizedBox(height: 12),
          _buildPaymentMethod('Bank Transfer'),
        ],
      ),
    );
  }

  Widget _buildHistoryView() {
    if (_isLoadingHistory) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF84BD00),
        ),
      );
    }

    if (_historyError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _historyError!,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDepositHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
                foregroundColor: Colors.black,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_depositHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, color: Colors.white38, size: 64),
            const SizedBox(height: 16),
            const Text(
              'No Deposit History',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your INR deposit history will appear here',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _toggleHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Make a Deposit'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDepositHistory,
      color: const Color(0xFF84BD00),
      backgroundColor: const Color(0xFF1C1C1E),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _depositHistory.length,
        itemBuilder: (context, index) {
          final deposit = _depositHistory[index];
          return _buildDepositHistoryItem(deposit);
        },
      ),
    );
  }

  Widget _buildDepositHistoryItem(Map<String, dynamic> deposit) {
    // Handle actual API response field names
    final amount = deposit['amount']?.toString() ?? '0';
    final status = deposit['status']?.toString() ?? 'pending';
    final createdAt = deposit['createdAt']?.toString() ?? '';
    final reference = deposit['txid']?.toString() ?? deposit['_id']?.toString() ?? '';
    final coin = deposit['category']?.toString().toUpperCase() ?? 'INR';
    final senderAccount = deposit['senderAccountName']?.toString() ?? deposit['sender_account_name']?.toString() ?? '';
    final bankName = deposit['bankName']?.toString() ?? deposit['bank_name']?.toString() ?? '';

    // Handle status codes (API returns numeric status)
    String statusText;
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case '1':
        statusText = 'Pending';
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case '2':
        statusText = 'Processing';
        statusColor = Colors.blue;
        statusIcon = Icons.pending;
        break;
      case '3':
        statusText = 'Completed';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case '4':
        statusText = 'Rejected';
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case '5':
        statusText = 'Success';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      default:
        statusText = 'Unknown';
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    String formattedDate = 'Unknown date';
    if (createdAt != null) {
      try {
        DateTime date;
        final createdAtStr = createdAt.toString();
        
        // Try parsing as ISO string first
        date = DateTime.tryParse(createdAtStr) ?? DateTime.now();
        
        // If parsing failed, try parsing as Unix timestamp
        if (date == DateTime.now() && createdAtStr.isNotEmpty) {
          try {
            final timestamp = int.tryParse(createdAtStr);
            if (timestamp != null) {
              date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
            }
          } catch (e) {
            // If all parsing fails, use current time
            date = DateTime.now();
          }
        }
        
        // Format to local time with proper 12-hour format
        formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date.toLocal());
        
        // Debug logging to check the conversion
        debugPrint('Original createdAt: $createdAtStr');
        debugPrint('Parsed date: $date');
        debugPrint('Formatted date: $formattedDate');
        
      } catch (e) {
        debugPrint('Error parsing date: $e');
        formattedDate = createdAt.toString();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Deposit',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Amount',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      coin.toString().toUpperCase() == 'INR' 
                          ? '₹${double.tryParse(amount.toString())?.toStringAsFixed(2) ?? amount}'
                          : '${double.tryParse(amount.toString())?.toStringAsFixed(4) ?? amount} ${coin.toString().toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'From',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      senderAccount.isNotEmpty ? senderAccount : 'Bank Transfer',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Show bank name if available
          if (bankName.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_balance, color: Colors.white54, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Bank: $bankName',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          const Divider(color: Color(0xFF2C2C2E), height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  formattedDate,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (reference.toString().isNotEmpty)
                Flexible(
                  child: Text(
                    'Ref: $reference',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod(String title) {
    bool isSelected = _selectedMethod == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF84BD00) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF8E8E93),
                fontSize: 16,
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF84BD00) : Colors.white54,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF84BD00),
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
