import 'package:flutter/material.dart';
import 'bot_trade_detail_screen.dart';
import 'bot_history_screen.dart';
import 'bot_algorithm_screen.dart';
import '../services/bot_service.dart';
import '../services/user_service.dart';
import 'user_profile_screen.dart';
import 'update_profile_screen.dart';

class BotTradeScreen extends StatefulWidget {
  const BotTradeScreen({super.key});

  @override
  State<BotTradeScreen> createState() => _BotTradeScreenState();
}

class _BotTradeScreenState extends State<BotTradeScreen> {
  
  // User subscription data
  String? _subscriptionPlan;
  int _subscriptionDaysLeft = 0;
  bool _isLoadingSubscription = true;
  
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _fetchUserSubscription();
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

  // Validate profile before proceeding (KYC not required for bot trading)
  bool _validateUserRequirements() {
    if (!_isProfileComplete()) {
      _showProfileRequiredDialog();
      return false;
    }

    return true;
  }
  
  Future<void> _fetchUserSubscription() async {
    try {
      final response = await BotService.getUserData();
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        final subscription = data['subscription'];
        
        if (subscription != null && subscription['endDate'] != null) {
          final endDate = DateTime.tryParse(subscription['endDate'].toString());
          final now = DateTime.now();
          
          if (endDate != null) {
            final daysLeft = endDate.difference(now).inDays;
            
            setState(() {
              _subscriptionPlan = daysLeft > 0 ? subscription['plan']?.toString() : null;
              _subscriptionDaysLeft = daysLeft > 0 ? daysLeft : 0;
              _isLoadingSubscription = false;
            });
          } else {
            setState(() {
              _subscriptionPlan = null;
              _isLoadingSubscription = false;
            });
          }
        } else {
          setState(() {
            _subscriptionPlan = null;
            _isLoadingSubscription = false;
          });
        }
      } else {
        setState(() {
          _subscriptionPlan = null;
          _isLoadingSubscription = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching subscription: $e');
      setState(() {
        _subscriptionPlan = null;
        _isLoadingSubscription = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Bot Trade',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header Banner
              _buildHeaderBanner(),
              
              // Content
              _buildRecommendedContent(),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      height: 120,
      margin: const EdgeInsets.only(top: 8),
      child: Image.asset(
        'assets/images/adhome.png',
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF84BD00).withOpacity(0.1),
                  const Color(0xFF000000),
                ],
              ),
            ),
            child: const Center(
              child: Text(
                'TRADE FASTER. TRADE SMARTER.\nBuilt for speed, precision, and confidence.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }



  Widget _buildRecommendedContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildBotCard('Omega', '3x', true),
          const SizedBox(height: 16),
          _buildBotCard('Alpha', '2x', false),
          const SizedBox(height: 16),
          _buildBotCard('Ranger', '5X', false),
        ],
      ),
    );
  }

  Widget _buildBotCard(String name, String multiplier, bool isAvailable) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$name-$multiplier',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isAvailable)
                ElevatedButton(
                  onPressed: () {
                    // Check profile requirements first (KYC not required for bot trading)
                    if (!_validateUserRequirements()) {
                      return;
                    }

                    // Check if user has active subscription
                    if (_subscriptionPlan != null && _subscriptionDaysLeft > 0) {
                      // User is subscribed, navigate directly to Algos screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BotAlgorithmScreen()
                        )
                      ).then((_) {
                        setState(() {});
                        _fetchUserSubscription();
                      });
                    } else {
                      // Navigate to details screen for subscription
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BotTradeDetailScreen(name: name, multiplier: multiplier)
                        )
                      ).then((_) {
                        setState(() {});
                        _fetchUserSubscription();
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF84BD00),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Invest',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF84BD00),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Coming Soon',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Performance metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPerformanceMetric('3M:', '+12.5%'),
              _buildPerformanceMetric('6M:', '+28.3%'),
              _buildPerformanceMetric('1M:', '+8.7%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetric(String period, String value) {
    return Column(
      children: [
        Text(
          period,
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF84BD00),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
