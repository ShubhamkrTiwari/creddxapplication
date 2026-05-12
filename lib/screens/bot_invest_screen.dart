import 'package:flutter/material.dart';
import '../services/bot_service.dart';
import '../services/socket_service.dart';
import '../services/user_service.dart';
import '../services/unified_wallet_service.dart';
import 'user_profile_screen.dart';
import 'update_profile_screen.dart';
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

class _BotInvestScreenState extends State<BotInvestScreen> {
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
  }

  
  @override
  void dispose() {
    _balanceSubscription?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  void _subscribeToBotBalance() {
    _balanceSubscription = UnifiedWalletService.walletBalanceStream.listen((balance) {
      if (mounted && balance != null) {
        // Use availableBalance from UnifiedWalletService
        // Note: UnifiedWalletService botBalance is the total bot balance
        // We might need to fetch availableBalance specifically or use the one from mainBalance if available
        setState(() {
          _liveBotBalance = balance.botBalance;
        });
        debugPrint('Invest Screen: Bot balance updated from UnifiedWalletService: ${_liveBotBalance}');
      }
    });
    
    // Initial balance from service
    if (UnifiedWalletService.walletBalance != null) {
      _liveBotBalance = UnifiedWalletService.walletBalance!.botBalance;
    }
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

  // Check if profile is complete
  bool _isProfileComplete() {
    return _userService.hasEmail() && 
           _userService.userPhone != null && 
           _userService.userPhone!.isNotEmpty;
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

  // Validate profile before proceeding (KYC not required for bot subscription)
  bool _validateUserRequirements() {
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

    // Check profile requirements first (KYC not required for bot subscription)
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

        // Refresh global balance
        UnifiedWalletService.refreshBotBalance();

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
                        '$_liveBotBalance USDT',
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
                              'Invested: $_currentInvestment USDT',
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
                onPressed: (_isLoading || _isCheckingSubscription || !_isProfileComplete() || !_isSubscribed) ? null : _handleInvest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_isProfileComplete() && _isSubscribed) ? const Color(0xFF84BD00) : Colors.grey,
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
                    : !_isProfileComplete()
                    ? const Text(
                        'Complete Profile - Button Disabled',
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
