import 'package:flutter/material.dart';
import '../services/bot_service.dart';
import 'bot_trade_detail_screen.dart';
import '../main_navigation.dart';

class BotAlgorithmScreen extends StatefulWidget {
  const BotAlgorithmScreen({super.key});

  @override
  State<BotAlgorithmScreen> createState() => _BotAlgorithmScreenState();
}

class _BotAlgorithmScreenState extends State<BotAlgorithmScreen> {
  Map<String, dynamic>? userData;
  bool isLoadingUserData = true;
  bool isLoadingStrategies = true;
  Map<String, dynamic>? strategyPerformanceData;

  final List<Map<String, dynamic>> _strategies = [
    {
      'name': 'Omega-3X',
      'tag': 'USDm',
      'description': 'Multiple Alt Pairs',
      'followers': '12',
      'annualizedROI': '922.19%',
      'aum': '805.99K',
      'features': ['Futures', '3x Leverage'],
      'isComingSoon': false,
    },
    {
      'name': 'Alpha-2X',
      'tag': 'Coin-m',
      'description': 'Top Pairs',
      'followers': '928',
      'annualizedROI': '228.47%',
      'aum': '489.20K',
      'features': ['Spot', '2x Leverage'],
      'isComingSoon': true,
    },
    {
      'name': 'Ranger-5X',
      'tag': 'USDm',
      'description': 'SOLUSDT',
      'followers': '1576',
      'annualizedROI': '412.62%',
      'aum': '1.2M',
      'features': ['Scalper', '5x Leverage'],
      'isComingSoon': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchStrategyPerformance();
  }

  Future<void> _fetchStrategyPerformance() async {
    try {
      final response = await BotService.getStrategyPerformance('all');
      
      if (mounted) {
        setState(() {
          if (response['success'] && response['data'] != null) {
            strategyPerformanceData = response['data'];
            // Update strategies with real data from API
            _updateStrategiesWithRealData();
          }
          isLoadingStrategies = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingStrategies = false;
        });
      }
    }
  }

  void _updateStrategiesWithRealData() {
    if (strategyPerformanceData == null) return;
    
    // Update each strategy with real data from API
    for (var i = 0; i < _strategies.length; i++) {
      final strategyName = _strategies[i]['name']?.toString().split('-')[0]; // Get 'Omega' from 'Omega-3X'
      
      // Look for matching strategy data in API response
      if (strategyPerformanceData!.containsKey(strategyName)) {
        final apiData = strategyPerformanceData![strategyName];
        _strategies[i]['annualizedROI'] = apiData['annualizedROI'] ?? _strategies[i]['annualizedROI'];
        _strategies[i]['aum'] = apiData['aum'] ?? _strategies[i]['aum'];
        _strategies[i]['followers'] = apiData['followers']?.toString() ?? _strategies[i]['followers'];
      }
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final response = await BotService.getUserData();
      
      if (mounted) {
        setState(() {
          if (response['success']) {
            userData = response['data'];
          }
          isLoadingUserData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingUserData = false;
        });
      }
    }
  }

  void _navigateToDetail(Map<String, dynamic> strategy) {
    List<String> parts = strategy['name'].split('-');
    String name = parts[0];
    String multiplier = parts.length > 1 ? parts[1] : '1X';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BotTradeDetailScreen(
          name: name,
          multiplier: multiplier,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MainNavigation()),
              (route) => false,
            );
          },
        ),
        title: const Text(
          'Algos',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            // User Info Section
            if (!isLoadingUserData && userData != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F0F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back, ${userData!['name'] ?? 'User'}!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Subscription: ${userData!['subscription'] ?? 'Free'}',
                            style: const TextStyle(
                              color: Color(0xFF84BD00),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF84BD00),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Active Bots: ${userData!['activeBots'] ?? 0}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (!isLoadingUserData && userData != null)
              const SizedBox(height: 20),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Invest In ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: 'Alpha Strategies',
                        style: TextStyle(
                          color: Color(0xFF84BD00),
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Invest in our top-performing Alpha strategies and only pay a portion of your profits.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 40),
            if (isLoadingStrategies)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF84BD00)),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _strategies.map((strategy) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.85,
                        child: _buildStrategyCard(strategy),
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategyCard(Map<String, dynamic> strategy) {
    return GestureDetector(
      onTap: () => _showStrategyPerformancePopup(strategy),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    strategy['name'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF84BD00),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    strategy['tag'],
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF84BD00),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      strategy['description'],
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.people_outline,
                  color: Color(0xFF4E4E4E),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${strategy['followers']} Followers',
                    style: const TextStyle(
                      color: Color(0xFF4E4E4E),
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _buildDataBox(
                    label: 'ANNUALIZED ROI',
                    value: strategy['annualizedROI'],
                    valueColor: const Color(0xFF84BD00),
                    showChartIcon: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDataBox(
                    label: 'AUM (USDT)',
                    value: strategy['aum'],
                    valueColor: Colors.white,
                    showChartIcon: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildFeatureBox(strategy['features'][0]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFeatureBox(strategy['features'][1]),
                ),
              ],
            ),
            const SizedBox(height: 24),
            strategy['isComingSoon']
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161618),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: const Center(
                      child: Text(
                        'Coming Soon',
                        style: TextStyle(
                          color: Color(0xFF444444),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _buildActionButton('Invest more ↗', () => _navigateToDetail(strategy)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton('Withdraw ↗', () => _navigateToDetail(strategy)),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  void _showStrategyPerformancePopup(Map<String, dynamic> strategy) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: StrategyPerformancePopup(strategy: strategy),
        );
      },
    );
  }

  Widget _buildDataBox({
    required String label,
    required String value,
    required Color valueColor,
    required bool showChartIcon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF4E4E4E),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showChartIcon) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.show_chart,
                  color: Color(0xFF84BD00),
                  size: 12,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBox(String feature) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          feature,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: label.contains('Invest') ? const Color(0xFF84BD00) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: label.contains('Withdraw')
              ? Border.all(color: Colors.white.withOpacity(0.1))
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: label.contains('Invest') ? Colors.black : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class StrategyPerformancePopup extends StatelessWidget {
  final Map<String, dynamic> strategy;

  const StrategyPerformancePopup({super.key, required this.strategy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Performance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDetailRow('Strategy Name', strategy['name']),
          _buildDetailRow('Type', strategy['tag']),
          _buildDetailRow('Annualized ROI', strategy['annualizedROI'], valueColor: const Color(0xFF84BD00)),
          _buildDetailRow('AUM', strategy['aum']),
          _buildDetailRow('Followers', strategy['followers']),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Close',
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
    );
  }

  Widget _buildDetailRow(String label, String value, {Color valueColor = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
