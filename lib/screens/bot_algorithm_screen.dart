import 'package:flutter/material.dart';
import '../services/bot_service.dart';
import 'bot_trade_detail_screen.dart';

class BotAlgorithmScreen extends StatefulWidget {
  const BotAlgorithmScreen({super.key});

  @override
  State<BotAlgorithmScreen> createState() => _BotAlgorithmScreenState();
}

class _BotAlgorithmScreenState extends State<BotAlgorithmScreen> {
  Map<String, dynamic>? userData;
  bool isLoadingUserData = true;

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
          onPressed: () => Navigator.pop(context),
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
                              fontSize: 18,
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
                Text(
                  strategy['name'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                  Text(
                    strategy['description'],
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 13,
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
                Text(
                  '${strategy['followers']} Followers',
                  style: const TextStyle(
                    color: Color(0xFF4E4E4E),
                    fontSize: 14,
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
              if (showChartIcon) ...[
                const Icon(Icons.trending_up, color: Color(0xFF4E4E4E), size: 14),
                const SizedBox(width: 6),
              ],
              Expanded(
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
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBox(String feature) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          feature,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class StrategyPerformancePopup extends StatefulWidget {
  final Map<String, dynamic> strategy;

  const StrategyPerformancePopup({
    super.key,
    required this.strategy,
  });

  @override
  State<StrategyPerformancePopup> createState() => _StrategyPerformancePopupState();
}

class _StrategyPerformancePopupState extends State<StrategyPerformancePopup> {
  Map<String, dynamic>? performanceData;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchPerformanceData();
  }

  Future<void> _fetchPerformanceData() async {
    try {
      final response = await BotService.getStrategyPerformance(widget.strategy['name']);
      
      if (mounted) {
        setState(() {
          if (response['success']) {
            performanceData = response['data'];
          } else {
            error = response['error'] ?? 'Failed to load performance data';
          }
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Network error: $e';
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(),
          
          // Content
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: isLoading
                    ? _buildLoadingState()
                    : error != null
                        ? _buildErrorState()
                        : _buildPerformanceContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
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
                  widget.strategy['name'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Strategy Performance Details',
                  style: TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF84BD00)),
          const SizedBox(height: 16),
          Text(
            'Loading performance data...',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            error!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchPerformanceData,
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

  Widget _buildPerformanceContent() {
    if (performanceData == null) {
      return const Center(
        child: Text(
          'No performance data available',
          style: TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 16,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPerformanceStats(),
        const SizedBox(height: 26),
        _buildRecentTradesSection(),
        const SizedBox(height: 24),
        _buildRiskSection(),
      ],
    );
  }

  Widget _buildPerformanceStats() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Stats',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 8,
            childAspectRatio: 2.8,
            children: [
              _buildStatItem('Total P&L', performanceData!['rot'] ?? '0.0%', Colors.green),
              _buildStatItem('Win Rate', performanceData!['winRate'] ?? '0.0%', const Color(0xFF84BD00)),
              _buildStatItem('Total Trades', performanceData!['trades'] ?? '0', Colors.white),
              _buildStatItem('Volume', performanceData!['volume'] ?? '0.0', Colors.white),
              _buildStatItem('Drawdown', performanceData!['drawdown'] ?? '0.0%', Colors.red),
              _buildStatItem('Followers', performanceData!['followers'] ?? '0', Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildRecentTradesSection() {
    final trades = performanceData!['recentTrades'] as List<dynamic>? ?? [];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Trades',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (trades.isEmpty)
            const Center(
              child: Text(
                'No recent trades',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 14,
                ),
              ),
            )
          else
            Column(
              children: trades.take(5).map((trade) {
                return _buildTradeItem(trade);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTradeItem(Map<String, dynamic> trade) {
    final pnl = trade['pnl'] ?? 0.0;
    final isProfit = pnl >= 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                trade['pair'] ?? 'Unknown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${isProfit ? '+' : ''}${pnl.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: isProfit ? Colors.green : Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Entry: ${trade['entryPrice']?.toStringAsFixed(6) ?? '0.000000'}',
                style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 12,
                ),
              ),
              Text(
                'Exit: ${trade['exitPrice']?.toStringAsFixed(6) ?? '0.000000'}',
                style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                trade['time'] ?? '',
                style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 11,
                ),
              ),
              Text(
                'Size: ${trade['size'] ?? '0.00'}',
                style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Risk Metrics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: [
              _buildStatItem('Max Drawdown', performanceData!['drawdown'] ?? '0.0%', Colors.orange),
              _buildStatItem('Win Rate', performanceData!['winRate'] ?? '0.0%', const Color(0xFF84BD00)),
              _buildStatItem('Volume', performanceData!['volume'] ?? '0.0', Colors.white),
              _buildStatItem('Followers', performanceData!['followers'] ?? '0', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }
}
