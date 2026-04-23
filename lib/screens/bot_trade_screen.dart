import 'package:flutter/material.dart';
import 'bot_trade_detail_screen.dart';
import 'bot_history_screen.dart';
import 'bot_algorithm_screen.dart';
import '../services/bot_service.dart';

class BotTradeScreen extends StatefulWidget {
  const BotTradeScreen({super.key});

  @override
  State<BotTradeScreen> createState() => _BotTradeScreenState();
}

class _BotTradeScreenState extends State<BotTradeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // User subscription data
  String? _subscriptionPlan;
  int _subscriptionDaysLeft = 0;
  bool _isLoadingSubscription = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchUserSubscription();
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
    _tabController.dispose();
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
        child: Column(
          children: [
            // Header Banner
            _buildHeaderBanner(),
            
            // Tabs
            _buildTabs(),
            
            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRecommendedContent(),
                  const BotHistoryScreen(showHeader: false), // Using the synchronized history screen
                ],
              ),
            ),
          ],
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

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF84BD00),
        indicatorWeight: 2,
        labelColor: const Color(0xFF84BD00),
        unselectedLabelColor: const Color(0xFF8E8E93),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'Recommended'),
          Tab(text: 'History'),
        ],
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
