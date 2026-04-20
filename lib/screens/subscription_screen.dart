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

// Available packages with prices
final List<Map<String, dynamic>> _packages = [
  {'name': 'Free Plan', 'price': 0.0},
  {'name': 'Basic Package', 'price': 25.0},
];

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isSubscribing = false;
  bool _isSubscribed = false;
  int _daysLeft = 0;
  String? _planName;
  double? _planPrice;
  String? _errorMessage;
  Timer? _countdownTimer;
  
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
    _startCountdownTimer();
  }

  Future<void> _loadUserSubscription() async {
    try {
      final response = await BotService.getUserData();

      if (response['success'] == true && response['data'] != null) {
        final userData = response['data'];
        final subscription = userData['subscription'];

        // Check subscription
        if (subscription == null) {
          setState(() {
            _isSubscribed = false;
            _planName = null;
            _planPrice = null;
            _daysLeft = 0;
            _errorMessage = null;
          });
          BotTradeDetailScreen.hasPackage = false;
          return;
        }

        // Extract subscription details
        final planName = subscription['plan']?.toString();
        final planPrice = double.tryParse(subscription['price']?.toString() ?? '');

        // Check expiry
        int remainingDays = 0;
        bool isActive = true;

        if (subscription['endDate'] != null) {
          final endDate = DateTime.tryParse(subscription['endDate'].toString());
          if (endDate != null) {
            final currentDate = DateTime.now();
            remainingDays = endDate.difference(currentDate).inDays;

            // Expired case
            if (remainingDays <= 0) {
              isActive = false;
              remainingDays = 0;
            }
          }
        }

        // Update state with final values
        setState(() {
          _isSubscribed = isActive;
          _planName = isActive ? planName : null;
          _planPrice = isActive ? planPrice : null;
          _daysLeft = remainingDays;
          _errorMessage = null;
        });

        BotTradeDetailScreen.hasPackage = isActive;
      } else {
        // API returned error
        final errorMsg = response['error']?.toString() ??
                        response['message']?.toString() ??
                        'Could not load subscription details';
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
                  _buildFeature('Advanced Edge'),
                  _buildFeature('Trade Pro'),
                  _buildFeature('70-30 Ratio'),
                  _buildFeature('Cap 100\$-2000\$'),
                  _buildFeature('1 Year'),
                  _buildFeature('Profit Master'),
                  
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
