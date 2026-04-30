import 'package:flutter/material.dart';
import '../services/bot_service.dart';
import 'bot_trade_detail_screen.dart';

class BotDashboardScreen extends StatefulWidget {
  const BotDashboardScreen({super.key});

  @override
  State<BotDashboardScreen> createState() => _BotDashboardScreenState();
}

class _BotDashboardScreenState extends State<BotDashboardScreen> {
  String _selectedSort = 'Top';
  bool _isLoadingPerformance = true;
  bool _isLoadingTradeHistory = true;
  bool _isLoadingWeeklyBenchmark = true;
  String? _weeklyBenchmarkError;
  double? _weeklyBotRoi;
  double? _weeklyBtcRoi;
  double? _weeklyEthRoi;
  double? _weeklyVsBtc;
  double? _weeklyVsEth;
  List<Map<String, dynamic>> _weeklySnapshots = const [];

  // Performance data for each strategy
  Map<String, Map<String, String>> _performanceData = {
    'Omega': {'3M': '--', '6M': '--', '1Y': '--'},
    'Alpha': {'3M': '--', '6M': '--', '1Y': '--'},
    'Ranger': {'3M': '--', '6M': '--', '1Y': '--'},
  };

  // Trade history data
  List<Map<String, dynamic>> _tradeHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchAllStrategyPerformance();
    _fetchTradeHistory();
    _loadWeeklyBenchmark();
  }

  Future<void> _loadWeeklyBenchmark() async {
    setState(() {
      _isLoadingWeeklyBenchmark = true;
      _weeklyBenchmarkError = null;
    });

    try {
      final res = await BotService.getWeeklyBenchmark(
        strategy: 'Omega-3X',
      );
      if (!mounted) return;

      if (res['success'] == true && res['data'] is Map<String, dynamic>) {
        final data = res['data'] as Map<String, dynamic>;
        final rawSnapshots = data['snapshots'];
        final snapshots = (rawSnapshots is List)
            ? rawSnapshots
                .whereType<dynamic>()
                .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
                .where((e) => e.isNotEmpty)
                .toList()
            : <Map<String, dynamic>>[];
        setState(() {
          _weeklySnapshots = snapshots;
          _weeklyBotRoi = (data['botRoi'] as num?)?.toDouble();
          _weeklyBtcRoi = (data['btcRoi'] as num?)?.toDouble();
          _weeklyEthRoi = (data['ethRoi'] as num?)?.toDouble();
          _weeklyVsBtc = (data['vsBtc'] as num?)?.toDouble();
          _weeklyVsEth = (data['vsEth'] as num?)?.toDouble();
          _isLoadingWeeklyBenchmark = false;
        });
        return;
      }

      setState(() {
        _weeklyBenchmarkError = res['error']?.toString() ?? 'Failed to load weekly benchmark';
        _isLoadingWeeklyBenchmark = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _weeklyBenchmarkError = e.toString();
        _isLoadingWeeklyBenchmark = false;
      });
    }
  }

  String _fmtPct(double? v) {
    if (v == null) return '--';
    return '${v.toStringAsFixed(2)}%';
  }

  String _fmtBalance(dynamic v) {
    final n = (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '');
    if (n == null) return '--';
    return n.toStringAsFixed(2);
  }

  Future<void> _fetchTradeHistory() async {
    setState(() => _isLoadingTradeHistory = true);

    try {
      // Fetch trades from all strategies since API requires strategy and symbol
      final pairMappings = [
        {'strategy': 'Omega-3X', 'symbol': 'BTC-USDT'},
        {'strategy': 'Alpha-2X', 'symbol': 'ETH-USDT'},
        {'strategy': 'Ranger-5X', 'symbol': 'SOL-USDT'},
      ];
      
      List<Map<String, dynamic>> allTrades = [];
      
      for (final mapping in pairMappings) {
        final response = await BotService.getUserBotTrades(
          strategy: mapping['strategy'],
          symbol: mapping['symbol'],
          limit: 10,
        );
        
        if (response['success'] == true && response['data'] != null) {
          final data = response['data'];
          final trades = data['userTrades'] as List<dynamic>? ?? [];
          allTrades.addAll(trades.cast<Map<String, dynamic>>());
        }
      }
      
      // Sort by date (newest first) and take top 10
      allTrades.sort((a, b) {
        final dateA = DateTime.tryParse(a['time']?.toString() ?? '') ?? DateTime.now();
        final dateB = DateTime.tryParse(b['time']?.toString() ?? '') ?? DateTime.now();
        return dateB.compareTo(dateA);
      });
      
      if (allTrades.isNotEmpty && mounted) {
        setState(() {
          _tradeHistory = allTrades.take(10).toList();
          _isLoadingTradeHistory = false;
        });
      } else if (mounted) {
        // If no trades, use mock data
        final mockResponse = await BotService.getMockTradeHistory(
          limit: 10,
          sortBy: 'date',
          sortOrder: 'desc',
        );
        
        if (mockResponse['success'] == true) {
          final data = mockResponse['data'];
          final trades = data['trades'] as List<dynamic>? ?? [];
          setState(() {
            _tradeHistory = trades.cast<Map<String, dynamic>>();
            _isLoadingTradeHistory = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTradeHistory = false);
      }
    }
  }

  Future<void> _fetchAllStrategyPerformance() async {
    setState(() => _isLoadingPerformance = true);

    final strategies = ['Omega', 'Alpha', 'Ranger'];
    final newData = <String, Map<String, String>>{};

    for (final strategy in strategies) {
      try {
        final response = await BotService.getStrategyPerformance(strategy);
        if (response['success'] == true && response['data'] != null) {
          final data = response['data'];
          newData[strategy] = {
            '3M': data['returns3m']?.toString() ?? data['roi3m']?.toString() ?? '--',
            '6M': data['returns6m']?.toString() ?? data['roi6m']?.toString() ?? '--',
            '1Y': data['returns1y']?.toString() ?? data['roi1y']?.toString() ?? '--',
          };
        } else {
          newData[strategy] = {'3M': '--', '6M': '--', '1Y': '--'};
        }
      } catch (e) {
        newData[strategy] = {'3M': '--', '6M': '--', '1Y': '--'};
      }
    }

    if (mounted) {
      setState(() {
        _performanceData = newData;
        _isLoadingPerformance = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text(
          'Trading Bot Dashboard',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            _buildWelcomeSection(),
            const SizedBox(height: 24),
            
            // Currency Market Section
            _buildCurrencyMarket(),
            const SizedBox(height: 24),
            
            // Top Strategies Section
            _buildTopStrategies(),
            const SizedBox(height: 24),

            // Comparison with BTC/ETH Section
            _buildBtcEthComparisonSection(),
            const SizedBox(height: 24),
            
            // Trade History Section
            _buildTradeHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyMarket() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Currency Market',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Bitcoin
          _buildCurrencyItem(
            'BTC',
            'Bitcoin',
            '\$67,432.50',
            '+2.45%',
            const Color(0xFF84BD00),
            '₹5.67L Cr',
          ),
          const SizedBox(height: 8),
          
          // Ethereum
          _buildCurrencyItem(
            'ETH',
            'Ethereum',
            '\$3,456.78',
            '+1.23%',
            const Color(0xFF84BD00),
            '₹2.91L Cr',
          ),
          const SizedBox(height: 8),
          
          // Solana
          _buildCurrencyItem(
            'SOL',
            'Solana',
            '\$178.92',
            '-0.87%',
            const Color(0xFFFF3B30),
            '₹15.08K Cr',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyItem(
    String symbol,
    String name,
    String price,
    String change,
    Color changeColor,
    String marketCap,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                symbol,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: changeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  change,
                  style: TextStyle(
                    color: changeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            price,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'MCap $marketCap',
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to CreddX',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your Ultimate Crypto Trading AI Bot',
            style: TextStyle(
              color: Color(0xFF84BD00),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Automate your trading strategies with our advanced AI-powered bots. '
            'Choose from proven strategies or create your own custom trading algorithms.',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Active Bots', '12', Icons.autorenew),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Total Profit', '+24.5%', Icons.trending_up),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Win Rate', '78%', Icons.track_changes),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF84BD00), size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTopStrategies() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Top Strategies',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                _buildSortButton('Top'),
                const SizedBox(width: 8),
                _buildSortButton('Latest'),
                const SizedBox(width: 8),
                _buildSortButton('View all'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Strategy Cards Slider
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            itemBuilder: (context, index) {
              final strategies = [
                {'name': 'Omega', 'multiplier': '3x', 'available': true},
                {'name': 'Alpha', 'multiplier': '2x', 'available': false},
                {'name': 'Ranger', 'multiplier': '5x', 'available': false},
              ];
              final strategy = strategies[index];
              final name = strategy['name'] as String;
              final performance = _performanceData[name] ?? {'3M': '--', '6M': '--', '1Y': '--'};

              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 200,
                  child: _buildStrategyCard(
                    name,
                    strategy['multiplier'] as String,
                    strategy['available'] as bool,
                    performance,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSortButton(String label) {
    final isSelected = _selectedSort == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedSort = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF84BD00) : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStrategyCard(String name, String multiplier, bool isAvailable, Map<String, String> performance) {
    return Container(
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
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF84BD00).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${multiplier}x',
                  style: const TextStyle(
                    color: Color(0xFF84BD00),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Mini Chart
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(
                Icons.show_chart,
                color: Color(0xFF84BD00),
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Returns - Show loading indicator if fetching
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Returns',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 12,
                ),
              ),
              if (_isLoadingPerformance)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF84BD00),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildReturnItem('3M', performance['3M'] ?? '--'),
              _buildReturnItem('6M', performance['6M'] ?? '--'),
              _buildReturnItem('1Y', performance['1Y'] ?? '--'),
            ],
          ),
          const SizedBox(height: 16),
          
          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isAvailable
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BotTradeDetailScreen(
                            name: name,
                            multiplier: multiplier,
                          ),
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isAvailable ? const Color(0xFF84BD00) : const Color(0xFF333333),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                isAvailable ? 'Invest' : 'Coming Soon',
                style: TextStyle(
                  color: isAvailable ? Colors.black : const Color(0xFF8E8E93),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnItem(String period, String value) {
    return Column(
      children: [
        Text(
          period,
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF84BD00),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBtcEthComparisonSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comparison with BTC/ETH',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildBenchmarkComparison(),
        ],
      ),
    );
  }

  Widget _buildBenchmarkComparison() {
    return GestureDetector(
      onTap: _showBenchmarkComparisonDialog,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Benchmark Comparison',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF84BD00).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'This Week',
                    style: TextStyle(
                      color: Color(0xFF84BD00),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildComparisonSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonSummary() {
    final botRoi = _weeklyBotRoi;
    final btcRoi = _weeklyBtcRoi;
    final ethRoi = _weeklyEthRoi;

    final botVsBtc = _weeklyVsBtc ?? ((botRoi != null && btcRoi != null) ? (botRoi - btcRoi) : null);
    final botVsEth = _weeklyVsEth ?? ((botRoi != null && ethRoi != null) ? (botRoi - ethRoi) : null);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isLoadingWeeklyBenchmark)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF84BD00)),
                ),
                SizedBox(width: 10),
                Text(
                  'Loading benchmark...',
                  style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
                ),
              ],
            ),
          )
        else if (_weeklyBenchmarkError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _weeklyBenchmarkError!,
              style: TextStyle(
                color: (_weeklyBenchmarkError!.toLowerCase().contains('not enough data'))
                    ? const Color(0xFF8E8E93)
                    : const Color(0xFFFF9500),
                fontSize: 12,
              ),
            ),
          ),
        if (_weeklyBenchmarkError != null &&
            _weeklyBenchmarkError!.toLowerCase().contains('not enough data'))
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Benchmark will appear once you have more weekly activity.',
              style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
            ),
          ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Omega-3X Bot ROI',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 12,
              ),
            ),
            Text(
              _fmtPct(botRoi),
              style: const TextStyle(
                color: Color(0xFF84BD00),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'BTC ROI',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 12,
              ),
            ),
            Text(
              _fmtPct(btcRoi),
              style: const TextStyle(
                color: Color(0xFF84BD00),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ETH ROI',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 12,
              ),
            ),
            Text(
              _fmtPct(ethRoi),
              style: const TextStyle(
                color: Color(0xFF84BD00),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 1,
          color: const Color(0xFF2C2C2E),
        ),
        const SizedBox(height: 12),
        if (_weeklySnapshots.isNotEmpty) ...[
          const Text(
            'Weekly balance snapshots',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ..._weeklySnapshots.take(7).map((s) {
            final date = s['date']?.toString() ?? '--';
            final balance = _fmtBalance(s['balance']);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(date, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
                  Text(balance, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          Container(
            height: 1,
            color: const Color(0xFF2C2C2E),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Icon(
              (botVsBtc != null && botVsEth != null && botVsBtc >= 0 && botVsEth >= 0) ? Icons.check_circle : Icons.info,
              color: (botVsBtc != null && botVsEth != null && botVsBtc >= 0 && botVsEth >= 0) ? const Color(0xFF84BD00) : const Color(0xFFFF9500),
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                (botVsBtc == null || botVsEth == null)
                    ? 'Benchmark data unavailable'
                    : 'Bot ${botVsBtc >= 0 ? "outperformed" : "trailing"} BTC by ${botVsBtc.abs().toStringAsFixed(2)}%, '
                      '${botVsEth >= 0 ? "outperformed" : "trailing"} ETH by ${botVsEth.abs().toStringAsFixed(2)}%',
                style: TextStyle(
                  color: (botVsBtc != null && botVsEth != null && botVsBtc >= 0 && botVsEth >= 0) ? const Color(0xFF84BD00) : const Color(0xFFFF9500),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showBenchmarkComparisonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Benchmark Comparison (This Week)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _buildComparisonSummary(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(
                color: Color(0xFF84BD00),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeHistorySection() {
    return Container(
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
              const Text(
                'Trade History',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isLoadingTradeHistory)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF84BD00),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_tradeHistory.isEmpty && !_isLoadingTradeHistory)
            const Center(
              child: Text(
                'No trades yet',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 14,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _tradeHistory.length > 5 ? 5 : _tradeHistory.length,
              separatorBuilder: (context, index) => const Divider(
                color: Color(0xFF2C2C2E),
                height: 1,
              ),
              itemBuilder: (context, index) {
                final trade = _tradeHistory[index];
                return _buildTradeHistoryItem(trade);
              },
            ),
          if (_tradeHistory.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    // Navigate to full trade history
                  },
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: Color(0xFF84BD00),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTradeHistoryItem(Map<String, dynamic> trade) {
    final pair = trade['pair']?.toString() ?? 'Unknown';
    final botName = trade['botName']?.toString() ?? '-';
    final multiplier = trade['multiplier']?.toString() ?? '';
    final userPnl = double.tryParse(trade['userPnl']?.toString() ?? '0') ?? 0.0;
    final dateStr = trade['date']?.toString() ?? '';
    final status = trade['status']?.toString() ?? 'completed';

    DateTime? date;
    if (dateStr.isNotEmpty) {
      date = DateTime.tryParse(dateStr);
    }

    final isProfit = userPnl >= 0;
    final pnlColor = isProfit ? const Color(0xFF84BD00) : const Color(0xFFFF3B30);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                pair.split('-').first,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$botName ${multiplier.isNotEmpty ? "($multiplier)" : ""}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pair,
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 12,
                  ),
                ),
                if (date != null)
                  Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isProfit ? "+" : ""}${userPnl.toStringAsFixed(2)}',
                style: TextStyle(
                  color: pnlColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: status == 'completed'
                      ? const Color(0xFF84BD00).withValues(alpha: 0.2)
                      : const Color(0xFFFF9500).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: status == 'completed'
                        ? const Color(0xFF84BD00)
                        : const Color(0xFFFF9500),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
