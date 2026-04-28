import 'package:flutter/material.dart';
import '../services/bot_service.dart';
import '../services/socket_service.dart';
import '../services/user_service.dart';
import '../utils/kyc_unlock_mixin.dart';
import 'kyc_digilocker_instruction_screen.dart';
import 'user_profile_screen.dart';
import 'dart:async';

class BotInvestScreen extends StatefulWidget {
  final Map<String, dynamic> strategy;
  final double walletBalance;

  const BotInvestScreen({
    super.key,
    required this.strategy,
    required this.walletBalance,
  });

  @override
  State<BotInvestScreen> createState() => _BotInvestScreenState();
}

class _BotInvestScreenState extends State<BotInvestScreen> with KYCUnlockMixin {
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  double _currentInvestment = 0.0;
  bool _isLoadingInvestment = false;
  double _liveBotBalance = 0.0;
  StreamSubscription? _balanceSubscription;
  bool _isSubscribed = false;
  bool _isCheckingSubscription = false;
  
  final UserService _userService = UserService.instance;

  @override
  void initState() {
    super.initState();
    _liveBotBalance = widget.walletBalance;
    _fetchCurrentInvestment();
    _subscribeToBotBalance();
    _checkSubscriptionStatus();
    // Refresh KYC status to ensure we have the latest status
    refreshKYCStatus();
    // Also manually check KYC status from API to ensure it's updated
    _checkAndUpdateKYCStatus();
  }

  
  @override
  void dispose() {
    _balanceSubscription?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  void _subscribeToBotBalance() {
    _balanceSubscription = SocketService.balanceStream.listen((data) {
      if (mounted && (data['type'] == 'wallet_summary_update' || data['type'] == 'wallet_summary')) {
        final balanceData = data['data'];
        if (balanceData != null && balanceData is Map) {
          // Use availableBalance instead of botBalance to show only investable amount
          final availableBalance = balanceData['availableBalance'] ?? balanceData['available'];
          if (availableBalance != null) {
            double newBalance = 0.0;
            if (availableBalance is num) {
              newBalance = availableBalance.toDouble();
            } else if (availableBalance is Map) {
              newBalance = double.tryParse(availableBalance['USDT']?.toString() ?? '0') ?? 0.0;
            } else {
              newBalance = double.tryParse(availableBalance.toString()) ?? 0.0;
            }
            setState(() {
              _liveBotBalance = newBalance;
            });
            debugPrint('Invest Screen: Available balance updated: $newBalance');
          }
        }
      }
    });
  }

  Future<void> _fetchCurrentInvestment() async {
    setState(() => _isLoadingInvestment = true);
    try {
      final strategyName = widget.strategy['name']?.toString() ?? '';
      final symbol = widget.strategy['symbol']?.toString() ?? 'BTC-USDT';
      
      final result = await BotService.getUserBotPositions(
        strategy: strategyName,
        symbol: symbol,
      );
      
      if (mounted && result['success'] == true) {
        final data = result['data'];
        final userInvestment = data?['userInvestment'] ?? 0.0;
        setState(() {
          _currentInvestment = userInvestment is double ? userInvestment : double.tryParse(userInvestment.toString()) ?? 0.0;
        });
        debugPrint('Current investment for $strategyName: $_currentInvestment USDT');
      }
    } catch (e) {
      debugPrint('Error fetching current investment: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingInvestment = false);
      }
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    setState(() => _isCheckingSubscription = true);
    try {
      final result = await BotService.getSubscriptionDetails();
      if (mounted && result['success'] == true) {
        setState(() {
          _isSubscribed = result['isSubscribed'] ?? false;
        });
        debugPrint('User subscription status: $_isSubscribed');
      }
    } catch (e) {
      debugPrint('Error checking subscription status: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingSubscription = false);
      }
    }
  }

  // Check and update KYC status from /auth/me endpoint
  Future<void> _checkAndUpdateKYCStatus() async {
    try {
      // Fetch fresh KYC status from /auth/me endpoint
      await _userService.fetchProfileDataFromAPI();
      
      final kycStatus = _userService.kycStatus;
      print('BotInvestScreen - KYC Status from /auth/me: "$kycStatus"');
      
      // Status is already updated in UserService by fetchProfileDataFromAPI()
      // No need to manually update it here
    } catch (e) {
      print('BotInvestScreen - Error checking KYC status: $e');
    }
  }

  // Get KYC warning content based on status
  Map<String, dynamic> _getKYCWarningContent() {
    final kycStatus = _userService.kycStatus.toLowerCase();
    
    switch (kycStatus) {
      case 'rejected':
        return {
          'title': 'KYC Verification Rejected',
          'message': 'Your KYC verification was rejected. Please contact support or re-submit your documents.',
          'buttonText': 'Re-submit KYC',
          'icon': Icons.error_outline,
          'iconColor': Colors.red,
          'gradientColors': [Colors.red.withOpacity(0.15), Colors.red.withOpacity(0.1)],
          'borderColor': Colors.red.withOpacity(0.3),
          'iconBgColor': Colors.red.withOpacity(0.2),
          'buttonColor': Colors.red,
        };
      case 'deleted':
        return {
          'title': 'KYC Verification Deleted',
          'message': 'Your KYC verification has been deleted. Please complete the verification process again.',
          'buttonText': 'Start KYC Again',
          'icon': Icons.delete_outline,
          'iconColor': Colors.red,
          'gradientColors': [Colors.red.withOpacity(0.15), Colors.red.withOpacity(0.1)],
          'borderColor': Colors.red.withOpacity(0.3),
          'iconBgColor': Colors.red.withOpacity(0.2),
          'buttonColor': Colors.red,
        };
      default:
        return {
          'title': 'KYC Verification Required',
          'message': 'Complete your KYC verification to start investing in algorithmic trading bots',
          'buttonText': 'Complete KYC Now',
          'icon': Icons.verified_user_outlined,
          'iconColor': Colors.orange,
          'gradientColors': [Colors.orange.withOpacity(0.15), Colors.red.withOpacity(0.1)],
          'borderColor': Colors.orange.withOpacity(0.3),
          'iconBgColor': Colors.orange.withOpacity(0.2),
          'buttonColor': Colors.orange,
        };
    }
  }

  // Check if KYC is completed
  bool _isKYCCompleted() {
    return isKYCCompleted(); // Use the mixin method
  }

  // Check if profile is complete
  bool _isProfileComplete() {
    return _userService.hasEmail() && 
           _userService.userPhone != null && 
           _userService.userPhone!.isNotEmpty;
  }

  // Show KYC verification required dialog
  void _showKYCRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'KYC Verification Required',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'You need to complete KYC verification to invest in trading bots. Please complete your KYC process first.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(context, MaterialPageRoute(builder: (context) => const KYCDigiLockerInstructionScreen()));
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF84BD00)),
              child: const Text('Complete KYC', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
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
            'Profile Completion Required',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Please complete your profile information (email and phone number) to invest in trading bots.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(context, MaterialPageRoute(builder: (context) => const UserProfileScreen()));
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF84BD00)),
              child: const Text('Complete Profile', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  // Validate KYC and profile before proceeding
  bool _validateUserRequirements() {
    if (!_isKYCCompleted()) {
      _showKYCRequiredDialog();
      return false;
    }
    
    if (!_isProfileComplete()) {
      _showProfileRequiredDialog();
      return false;
    }
    
    return true;
  }

  Future<void> _handleInvest() async {
    final amount = double.tryParse(_amountController.text);
    debugPrint('=== INVEST HANDLE ===');
    debugPrint('Amount entered: $amount');
    
    if (amount == null || amount <= 0) {
      _showSnackBar('Please enter a valid amount', isError: true);
      return;
    }

    // Check KYC and profile requirements first
    if (!_validateUserRequirements()) {
      return;
    }

    // Check subscription status before allowing investment
    if (!_isSubscribed) {
      _showSubscriptionRequiredDialog();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final strategyName = widget.strategy['name']?.toString() ?? 'Unknown';
      String botId = strategyName.replaceAll('-', '_').toLowerCase();
      
      debugPrint('Calling BotService.invest with botId: $botId, amount: $amount, strategy: $strategyName');

      final result = await BotService.invest(
        botId: botId,
        amount: amount,
        strategy: strategyName,
      );
      
      debugPrint('Invest API Result: $result');

      if (result['success'] == true) {
        // Immediately update local balance for instant feedback
        setState(() {
          _liveBotBalance = _liveBotBalance - amount;
        });

        _showSnackBar(result['message'] ?? 'Investment successful!');
        Navigator.pop(context, true);
      } else {
        _showSnackBar(result['error'] ?? 'Investment failed', isError: true);
      }
    } catch (e) {
      debugPrint('Invest Exception: $e');
      _showSnackBar('Investment failed: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF84BD00),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSubscriptionRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Subscription Required',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'You need to subscribe to a bot plan to invest in algorithms. Please subscribe to access premium trading features.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/bot-subscription');
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF84BD00)),
              child: const Text('Subscribe Now', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Debug check for KYC warning card visibility
    final shouldShowKYCWarning = !_isKYCCompleted();
    final kycStatus = _userService.kycStatus.toLowerCase();
    debugPrint('=== BUILD DEBUG ===');
    debugPrint('KYC Status: "$kycStatus"');
    debugPrint('Should Show KYC Warning: $shouldShowKYCWarning');
    debugPrint('==================');
    
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Invest in ${widget.strategy['name']?.toString() ?? 'Unknown'}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF84BD00).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bot Wallet Balance',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_liveBotBalance.toStringAsFixed(2)} USDT',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (_currentInvestment > 0 || _isLoadingInvestment) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF84BD00).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF84BD00).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.account_balance_wallet,
                            color: Color(0xFF84BD00),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          if (_isLoadingInvestment)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF84BD00)),
                              ),
                            )
                          else
                            Text(
                              'Invested: ${_currentInvestment.toStringAsFixed(2)} USDT',
                              style: const TextStyle(
                                color: Color(0xFF84BD00),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Amount Input
            const Text(
              'Enter Amount',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1C1C1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                hintText: 'Enter amount to invest',
                hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
                suffixText: 'USDT',
                suffixStyle: const TextStyle(color: Color(0xFF84BD00)),
              ),
            ),
            const SizedBox(height: 12),

            const SizedBox(height: 24),

            // KYC Requirement Warning - Only show when KYC is not completed
            if (shouldShowKYCWarning)
                Builder(
                  builder: (context) {
                    final warningContent = _getKYCWarningContent();
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: warningContent['gradientColors'],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: warningContent['borderColor'],
                          width: 1,
                        ),
                      ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: warningContent['iconBgColor'],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          warningContent['icon'],
                          color: warningContent['iconColor'],
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              warningContent['title'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              warningContent['message'],
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const KYCDigiLockerInstructionScreen()));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: warningContent['buttonColor'],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        warningContent['buttonText'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
                    );
                  },
                ),
            
            const SizedBox(height: 24),

            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Strategy', widget.strategy['name']?.toString() ?? 'Unknown'),
                  const SizedBox(height: 8),
                  _buildInfoRow('Annualized ROI', widget.strategy['annualizedROI']?.toString() ?? '0%'),
                  const SizedBox(height: 8),
                  _buildInfoRow('Minimum Invest', 'No minimum'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Subscription Status Warning
            if (!_isSubscribed && !_isCheckingSubscription)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      color: Colors.orange,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Subscription Required',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Subscribe to a bot plan to start investing in algorithms.',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            
            if (_isCheckingSubscription)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF84BD00)),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Checking subscription status...',
                      style: TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),

            // Invest Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_isLoading || _isCheckingSubscription || !_isKYCCompleted() || !_isSubscribed) ? null : _handleInvest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_isKYCCompleted() && _isSubscribed) ? const Color(0xFF84BD00) : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : _isCheckingSubscription
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : !_isKYCCompleted()
                    ? const Text(
                        'KYC Required - Button Disabled',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : !_isSubscribed
                    ? const Text(
                        'Subscription Required - Button Disabled',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : const Text(
                        'Invest Now',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
