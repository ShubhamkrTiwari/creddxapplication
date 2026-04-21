import 'dart:async';
import 'package:flutter/material.dart';
import '../services/bot_service.dart';
import '../services/auth_service.dart';
import 'bot_trade_detail_screen.dart';
import 'login_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

// Available packages with prices and features
final List<Map<String, dynamic>> _packages = [
  {
    'name': 'Basic Package',
    'price': 25.0,
    'features': [
      {
        'title': 'Advanced Edge',
        'description': 'AI-powered insights based on real-time market signals to improve trading decisions.',
      },
      {
        'title': 'Trade Pro Tools',
        'description': 'Access essential tools for smooth and efficient trade execution.',
      },
      {
        'title': 'Annual Subscription',
        'description': 'Get full access to all trading strategies with a \$25 yearly subscription, valid for 12 months.',
      },
      {
        'title': 'Portfolio Range',
        'description': 'Optimized for portfolios ranging from \$100 to \$2,000.',
      },
      {
        'title': 'Platform Access',
        'description': 'Get complete access to all trading tools and features while your subscription is active.',
      },
      {
        'title': 'Profit Optimization',
        'description': 'Smart strategy adjustments designed to enhance performance and maximize returns.',
      },
    ],
  },
];

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isSubscribing = false;
  bool _isSubscribed = false;
  int _daysLeft = 0;
  String? _planName;
  double? _planPrice;
  String? _errorMessage;
  Timer? _countdownTimer;
  String _totalBalance = '0.00';
  bool _isLoadingBalance = false;
  
  // Selected plan for subscription - gets values from _packages
  Map<String, dynamic> get _selectedPackage => _packages.firstWhere(
    (p) => p['name'] == 'Basic Package',
    orElse: () => _packages[1], // Default to Basic Package
  );
  String get _selectedPlan => _selectedPackage['name'];
  double get _selectedPrice => _selectedPackage['price'];

  @override
  void initState() {
    super.initState();
    _loadUserSubscription();
    _loadBotBalance();
    _startCountdownTimer();
  }

  Future<void> _loadBotBalance() async {
    if (!mounted) return;
    setState(() => _isLoadingBalance = true);
    try {
      final result = await BotService.getBotBalance();
      if (result['success'] == true && result['data'] != null) {
        if (!mounted) return;
        setState(() {
          _totalBalance = result['data']['totalBalance'] ?? '0.00';
        });
      }
    } catch (e) {
      debugPrint('Error loading bot balance: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingBalance = false);
      }
    }
  }

  Future<void> _loadUserSubscription() async {
    try {
      // 1. Call API and get response
      final res = await BotService.getUserData();

      if (res['success'] == true && res['data'] != null) {
        final userData = res['data'];
        final subscription = userData['subscription'];

        // 2. Check subscription
        bool isSubscribed;
        String? planName;
        double? planPrice;
        int remainingDays = 0;

        if (subscription == null) {
          isSubscribed = false;
        } else {
          isSubscribed = true;
          
          // 3. If subscribed
          planName = subscription['plan']?.toString();
          planPrice = double.tryParse(subscription['price']?.toString() ?? '');

          // 4. Check expiry
          if (subscription['endDate'] != null) {
            final endDate = DateTime.tryParse(subscription['endDate'].toString());
            if (endDate != null) {
              final currentDate = DateTime.now();
              remainingDays = endDate.difference(currentDate).inDays;

              // 5. Expired case
              if (remainingDays <= 0) {
                isSubscribed = false;
                planName = null;
                planPrice = null;
                remainingDays = 0;
              }
            }
          }
        }

        // 6. Final values to use
        if (!mounted) return;
        setState(() {
          _isSubscribed = isSubscribed;
          _planName = planName;
          _planPrice = planPrice;
          _daysLeft = remainingDays;
          _errorMessage = null;
        });

        BotTradeDetailScreen.hasPackage = isSubscribed;
      } else {
        // 7. Error handling
        final errorMsg = res['error']?.toString() ??
                        res['message']?.toString() ??
                        'Could not load subscription details';
        if (!mounted) return;
        setState(() {
          _errorMessage = errorMsg;
          _isSubscribed = false;
          _planName = null;
          _planPrice = null;
          _daysLeft = 0;
        });
        BotTradeDetailScreen.hasPackage = false;
      }
    } catch (e) {
      debugPrint('Error loading user subscription: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load subscription details';
        _isSubscribed = false;
        _planName = null;
        _planPrice = null;
        _daysLeft = 0;
      });
      BotTradeDetailScreen.hasPackage = false;
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(hours: 24), (timer) {
      if (_isSubscribed && _daysLeft > 0) {
        setState(() {
          _daysLeft--;
        });
        
        // When subscription expires
        if (_daysLeft == 0) {
          setState(() {
            _isSubscribed = false;
          });
          BotTradeDetailScreen.hasPackage = false;
        }
      }
    });
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
        title: const Text(
          'Package Program',
          style: TextStyle(
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
          children: [
            // Bot Balance Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF84BD00).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bot Wallet Balance',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                      const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF84BD00), size: 20),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _isLoadingBalance 
                    ? const SizedBox(
                        height: 24, 
                        width: 24, 
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF84BD00)),
                        )
                      )
                    : Text(
                        '\$$_totalBalance',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                ],
              ),
            ),

            // Basic Package Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF84BD00),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Basic Package',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF84BD00),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'POPULAR',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Price
                  Text(
                    _planPrice != null ? '\$${_planPrice!.toStringAsFixed(0)}' : '\$25',
                    style: const TextStyle(
                      color: Color(0xFF84BD00),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSubscribed ? '$_daysLeft days remaining' : 'Annual Subscription',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Features
                  ..._selectedPackage['features'].map<Widget>((feature) {
                    return _buildDetailedFeature(
                      title: feature['title'] ?? '',
                      description: feature['description'] ?? '',
                    );
                  }).toList(),
                  
                  const SizedBox(height: 32),
                  
                  // Subscribe Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Builder(
                      builder: (context) {
                        final buttonState = _getButtonState();
                        return ElevatedButton(
                          onPressed: _isSubscribing || !buttonState['enabled']
                              ? null
                              : () => _handleSubscribe(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonState['color'],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubscribing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                  ),
                                )
                              : Text(
                                  buttonState['text'],
                                  style: TextStyle(
                                    color: buttonState['enabled'] ? Colors.black : Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          
          // Show subscription details if user is subscribed,
          if (_isSubscribed) ...[
            const SizedBox(height: 20),
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
                    'Subscription Details',
                    style: TextStyle(
                      color: Color(0xFF84BD00),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Plan', _planName ?? 'Annual Plan'),
                  _buildDetailRow('Status', _isSubscribed ? 'Active' : 'Inactive'),
                  _buildDetailRow('Days Remaining', '$_daysLeft days'),
                  _buildDetailRow('Price', _planPrice != null ? '\$${_planPrice!.toStringAsFixed(2)}' : '\$25.00'),
                  _buildDetailRow('Duration', '365 Days'),
                ],
              ),
            ),
          ],
      ],
    )));  // Scaffold
  }

  Widget _buildFeature(String feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF84BD00),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.check,
              color: Colors.black,
              size: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              feature,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedFeature({required String title, required String description}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF84BD00),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check,
              color: Colors.black,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
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
    );
  }

  // Handle subscribe button click
  Future<void> _handleSubscribe() async {
    // 1. Check if user is logged in
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      _showErrorDialog('Authentication Required', 'Please Login to invest in Bot Trade');
      // Redirect to login
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      });
      return;
    }

    // 2. Get current plan
    final current = _packages.firstWhere(
      (p) => p['name'] == _planName,
      orElse: () => <String, dynamic>{},
    );

    // 3. Define conditions
    final bool hasCurrentPlan = current.isNotEmpty;
    final bool isSame = hasCurrentPlan && current['name'] == _selectedPlan;
    final bool isDowngrade = hasCurrentPlan && _selectedPrice < (current['price'] as double);
    final bool isUpgrade = !hasCurrentPlan || _selectedPrice > (current['price'] as double);

    // 4. Handle conditions
    if (isSame) {
      // Same plan - do nothing (button should be disabled)
      return;
    }

    if (isDowngrade) {
      // Downgrade not allowed
      _showErrorDialog('Downgrade Not Allowed', 'Downgrade not allowed. Please wait for current plan to expire.');
      return;
    }

    // 5. Open confirmation modal for upgrade or new subscription
    _showConfirmationModal(
      plan: _selectedPlan,
      price: _selectedPrice,
      isUpgrade: isUpgrade,
      current: current.isNotEmpty ? current : null,
    );
  }

  // Show confirmation modal
  void _showConfirmationModal({
    required String plan,
    required double price,
    required bool isUpgrade,
    Map<String, dynamic>? current,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(
          isUpgrade ? 'Upgrade Subscription' : 'Confirm Subscription',
          style: const TextStyle(color: Color(0xFF84BD00)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plan: $plan',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Price: \$${price.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            if (current != null) ...[
              const SizedBox(height: 8),
              Text(
                'Current: ${current['name']}',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              isUpgrade
                  ? 'You will be upgraded to $plan. Your new subscription will start immediately.'
                  : 'Subscribe to $plan for \$${price.toStringAsFixed(2)}?',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleConfirmPlan(plan: plan, price: price);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF84BD00),
            ),
            child: const Text(
              'Confirm',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  // Handle confirm plan subscription
  Future<void> _handleConfirmPlan({required String plan, required double price}) async {
    // Prevent multiple clicks
    if (_isSubscribing) return;

    setState(() => _isSubscribing = true);

    try {
      debugPrint('=== CONFIRMING SUBSCRIPTION ===');
      debugPrint('Plan: $plan, Price: $price');

      // Call API
      final response = await BotService.subscribeToPlan(
        plan: plan,
        price: price,
      );

      if (response['success'] == true) {
        // Refresh bot wallet balance
        await _refetchBotWalletData();

        // Calculate remaining days based on plan
        final int remainingDays = price == 0 ? 30 : 365;

        // Update UI
        setState(() {
          _isSubscribed = true;
          _planName = plan;
          _planPrice = price;
          _daysLeft = remainingDays;
        });

        // Set global package state
        BotTradeDetailScreen.hasPackage = true;

        _showSuccessDialog(
          'Subscription Successful!',
          response['message'] ?? 'You are now subscribed to $plan',
        );
      } else {
        // Show error
        final errorMsg = response['error']?.toString() ??
                        response['message']?.toString() ??
                        'Subscription failed';
        _showErrorDialog('Subscription Failed', errorMsg);
      }
    } catch (e) {
      debugPrint('Subscription error: $e');
      _showErrorDialog('Error', e.toString().isNotEmpty ? e.toString() : 'Subscription failed');
    } finally {
      setState(() => _isSubscribing = false);
    }
  }

  // Refresh bot wallet data
  Future<void> _refetchBotWalletData() async {
    try {
      debugPrint('=== REFETCHING BOT WALLET DATA ===');
      final result = await BotService.getBotBalance();
      debugPrint('Bot wallet refresh result: $result');
    } catch (e) {
      debugPrint('Error refreshing bot wallet: $e');
    }
  }

  // Get button state based on subscription rules
  Map<String, dynamic> _getButtonState() {
    // No active subscription - enable button
    if (!_isSubscribed || _planName == null) {
      return {
        'enabled': true,
        'text': 'Get Basic Package',
        'color': const Color(0xFF84BD00),
      };
    }

    // Same plan - disable button
    if (_planName == _selectedPlan) {
      return {
        'enabled': false,
        'text': 'Current Plan',
        'color': Colors.grey,
      };
    }

    // Get current plan details
    final current = _packages.firstWhere(
      (p) => p['name'] == _planName,
      orElse: () => {'name': '', 'price': 0.0},
    );

    // Downgrade - disable button
    if (_selectedPrice < (current['price'] as double)) {
      return {
        'enabled': false,
        'text': 'Not Allowed',
        'color': Colors.grey,
      };
    }

    // Upgrade - enable button
    if (_selectedPrice > (current['price'] as double)) {
      return {
        'enabled': true,
        'text': 'Upgrade Plan',
        'color': const Color(0xFF84BD00),
      };
    }

    // Default
    return {
      'enabled': true,
      'text': 'Get Basic Package',
      'color': const Color(0xFF84BD00),
    };
  }

  // Legacy method - replaced by _handleSubscribe
  Future<void> _subscribeToBasicPackage() async {
    await _handleSubscribe();
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(
          title,
          style: const TextStyle(color: Color(0xFF84BD00)),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF84BD00)),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(
          title,
          style: const TextStyle(color: Color(0xFFFF3B30)),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFFFF3B30)),
            ),
          ),
        ],
      ),
    );
  }
}
