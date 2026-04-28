import 'dart:async';
import 'package:flutter/material.dart';
import '../services/bot_service.dart';
import 'bot_trade_detail_screen.dart';

class SubscriptionScreenNew extends StatefulWidget {
  const SubscriptionScreenNew({super.key});

  @override
  State<SubscriptionScreenNew> createState() => _SubscriptionScreenNewState();
}

class _SubscriptionScreenNewState extends State<SubscriptionScreenNew> {
  bool _isSubscribing = false;
  bool _isSubscribed = false;
  int _daysLeft = 3;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadUserSubscription();
    _startCountdownTimer();
  }

  Future<void> _loadUserSubscription() async {
    try {
      final response = await BotService.getUserSubscription();
      if (response['success'] == true && response['subscription'] != null) {
        final subscription = response['subscription'];
        final startDate = DateTime.tryParse(subscription['startDate'] ?? '');
        final duration = subscription['duration'] ?? 30;
        
        if (startDate != null) {
          final endDate = startDate.add(Duration(days: duration));
          final now = DateTime.now();
          final daysLeft = endDate.difference(now).inDays + 1;
          
          if (daysLeft > 0) {
            setState(() {
              _isSubscribed = true;
              _daysLeft = daysLeft;
            });
            BotTradeDetailScreen.hasPackage = true;
          } else {
            setState(() {
              _isSubscribed = false;
              _daysLeft = 0;
            });
            BotTradeDetailScreen.hasPackage = false;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user subscription: $e');
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
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
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
                  const Text(
                    '\$25',
                    style: TextStyle(
                      color: Color(0xFF84BD00),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSubscribed ? '$_daysLeft days remaining' : 'Annual Subscription',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
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
                    child: ElevatedButton(
                      onPressed: _isSubscribing 
                          ? null 
                          : () => _subscribeToBasicPackage(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSubscribed 
                            ? Colors.grey 
                            : const Color(0xFF84BD00),
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
                              _isSubscribed 
                                  ? 'Already Subscribed'
                                  : 'Get Basic Package',
                              style: TextStyle(
                                color: _isSubscribed ? Colors.white : Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            // Show subscription details if user is subscribed
            if (_isSubscribed) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF84BD00).withValues(alpha: 0.3),
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
                    _buildDetailRow('Plan', 'Basic Package'),
                    _buildDetailRow('Status', 'Active'),
                    _buildDetailRow('Days Remaining', '$_daysLeft days'),
                    _buildDetailRow('Price', '\$25'),
                    _buildDetailRow('Duration', '365 Days'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
                color: Colors.white.withValues(alpha: 0.9),
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
              color: Colors.white.withValues(alpha: 0.7),
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

  Future<void> _subscribeToBasicPackage() async {
    setState(() => _isSubscribing = true);
    
    try {
      debugPrint('=== SUBSCRIBING TO BASIC PACKAGE ===');
      
      final response = await BotService.subscribeToPlan(
        plan: 'Basic Package',
        price: 25.0, // Set price to 25 USD as required by API
      );
      
      if (response['success'] == true) {
        setState(() {
          _isSubscribed = true;
          _daysLeft = 365; // 365 days for annual plan
        });
        BotTradeDetailScreen.hasPackage = true;
        
        _showSuccessDialog('Subscription successful!', response['message'] ?? 'You are now subscribed to Basic Package');
      } else {
        _showErrorDialog('Subscription failed', response['error'] ?? 'Something went wrong');
      }
    } catch (e) {
      debugPrint('Subscription error: $e');
      _showErrorDialog('Error', 'Network error. Please try again.');
    } finally {
      setState(() => _isSubscribing = false);
    }
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
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
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
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
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
