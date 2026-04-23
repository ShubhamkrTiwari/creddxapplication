import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _hasOpenPosition = true; // Set to true to show open position
  bool _showMoreOptions = false;
  String _selectedTimeframe = '15 Min';
  
  // User subscription data
  String? _subscriptionPlan;
  int _subscriptionDaysLeft = 0;
  bool _isLoadingSubscription = true;

  // Bot balance data
  Map<String, dynamic>? _botBalance;
  double _totalBalance = 0.0;
  double _availableBalance = 0.0;
  double _investedBalance = 0.0;
  bool _isLoadingBalance = true;

  // Bot positions data
  List<dynamic> _userPositions = [];
  bool _isLoadingPositions = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchUserSubscription();
    _fetchBotBalance();
    _fetchUserPositions();
  }

  Future<void> _fetchBotBalance() async {
    try {
      setState(() => _isLoadingBalance = true);
      final response = await BotService.getBotBalance();
      if (mounted && response['success'] == true) {
        final data = response['data'] ?? {};
        setState(() {
          _botBalance = data;
          _totalBalance = double.tryParse(data['totalBalance']?.toString() ?? '0') ?? 0.0;
          _availableBalance = double.tryParse(data['availableBalance']?.toString() ?? '0') ?? 0.0;
          _investedBalance = double.tryParse(data['investedBalance']?.toString() ?? '0') ?? 0.0;
          _isLoadingBalance = false;
        });
      } else {
        setState(() => _isLoadingBalance = false);
      }
    } catch (e) {
      debugPrint('Error fetching bot balance: $e');
      setState(() => _isLoadingBalance = false);
    }
  }

  Future<void> _fetchUserPositions() async {
    try {
      setState(() => _isLoadingPositions = true);
      // Fetch positions for Omega strategy as default
      final response = await BotService.getUserBotPositions(
        strategy: 'Omega-3X',
        symbol: 'BTC-USDT',
      );
      if (mounted && response['success'] == true) {
        final data = response['data'] ?? {};
        final positions = data['adjustedPositions'] ?? [];
        setState(() {
          _userPositions = positions;
          _hasOpenPosition = positions.isNotEmpty;
          _isLoadingPositions = false;
        });
      } else {
        setState(() {
          _userPositions = [];
          _hasOpenPosition = false;
          _isLoadingPositions = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user positions: $e');
      setState(() {
        _userPositions = [];
        _hasOpenPosition = false;
        _isLoadingPositions = false;
      });
    }
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

  Widget _buildRunningContent() {
    if (_hasOpenPosition) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subscription Package Card
            if (_subscriptionPlan != null && _subscriptionDaysLeft > 0) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF84BD00), Color(0xFF5A8A00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Active Package',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$_subscriptionDaysLeft days left',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _subscriptionPlan ?? 'Annual Plan',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Price: \$25.00',
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            // Trading Chart Section
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // Header with Price Info
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'BTC/USDT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Icon(
                              Icons.star_border,
                              color: Color(0xFF84BD00),
                              size: 18,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text(
                              '4890.12',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF84BD00).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '+12.1%',
                                style: TextStyle(
                                  color: Color(0xFF84BD00),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          '27190.02CNY',
                          style: TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildPriceInfo('H', '4933.09'),
                            const SizedBox(width: 12),
                            _buildPriceInfo('L', '4721.90'),
                            const SizedBox(width: 12),
                            _buildPriceInfo('24H', '40311'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Timeframe Selector
                  Container(
                    height: _showMoreOptions ? 100 : 28,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _showMoreOptions 
                        ? _buildMoreTimeframeOptions()
                        : Row(
                            children: [
                              _buildTimeframeButton('Line', 'Line'),
                              const SizedBox(width: 4),
                              _buildTimeframeButton('15 Min', '15 Min'),
                              const SizedBox(width: 4),
                              _buildTimeframeButton('1 Hour', '1 Hour'),
                              const SizedBox(width: 4),
                              _buildTimeframeButton('4 Hour', '4 Hour'),
                              const SizedBox(width: 4),
                              _buildTimeframeButton('1 Day', '1 Day'),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showMoreOptions = true;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Text(
                                    'More',
                                    style: TextStyle(
                                      color: Color(0xFF8E8E93),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  
                  // Chart Area
                  Container(
                    height: 160,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        // Candlestick Chart
                        CustomPaint(
                          painter: CandlestickChartPainter(),
                          child: Container(),
                        ),
                        // Price Lines
                        Positioned(
                          top: 30,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 1,
                            color: const Color(0xFF84BD00).withOpacity(0.3),
                          ),
                        ),
                        Positioned(
                          top: 30,
                          left: 10,
                          child: const Text(
                            '4813.90',
                            style: TextStyle(
                              color: Color(0xFF84BD00),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 30,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 1,
                            color: const Color(0xFF84BD00).withOpacity(0.3),
                          ),
                        ),
                        Positioned(
                          bottom: 30,
                          left: 10,
                          child: const Text(
                            '3801.03',
                            style: TextStyle(
                              color: Color(0xFF84BD00),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Open Position Section
            Container(
              width: double.infinity,
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
                  const Text(
                    'Open Position',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your Investment: ${_investedBalance.toStringAsFixed(2)} USDT',
                    style: const TextStyle(
                      color: Color(0xFF84BD00),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _userPositions.isNotEmpty
                          ? '${_userPositions[0]['symbol'] ?? 'BTC-USDT'} - ${_userPositions[0]['positionSide'] ?? 'LONG'}'
                          : 'No active position',
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Position Metrics List
                  _isLoadingPositions
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
                      : _userPositions.isEmpty
                          ? const Center(
                              child: Text(
                                'No active positions',
                                style: TextStyle(
                                  color: Color(0xFF8E8E93),
                                  fontSize: 14,
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _buildMetricCard('Avg Entry', _formatPositionValue(_userPositions[0]['avgPrice']))),
                                    const SizedBox(width: 10),
                                    Expanded(child: _buildMetricCard('Mark Price', _formatPositionValue(_userPositions[0]['markPrice']))),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: _buildMetricCard('Leverage', '${_userPositions[0]['leverage'] ?? '0'}x')),
                                    const SizedBox(width: 10),
                                    Expanded(child: _buildMetricCard('User Margin', _formatPositionValue(_userPositions[0]['userMargin']))),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: _buildMetricCard('Liq. Price', _formatPositionValue(_userPositions[0]['liqPrice']))),
                                    const SizedBox(width: 10),
                                    Expanded(child: _buildMetricCard('TP Price', '--')),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: _buildMetricCard('SL Price', '--')),
                                    const SizedBox(width: 10),
                                    Expanded(child: _buildMetricCard('PnL', _formatPositionValue(_userPositions[0]['userUnrealizedProfit']))),
                                  ],
                                ),
                              ],
                            ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.search_off,
                color: Color(0xFF8E8E93),
                size: 50,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Position Found',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'You don\'t have any active positions',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildMoreTimeframeOptions() {
    final timeframes = [
      '5 Sec', '10 Sec', '30 Sec', '1 Min', '5 Min', '15 Min', '30 Min',
      '1 Hour', '4 Hour', '1 Day', '1 Week', '2 Weeks', '3 Weeks', '1 Month', 
      '2 Months', '3 Months', '6 Months', '9 Months', '1 Year', '2 Years', '3 Years', '5 Years', 'All Time'
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Select Timeframe',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _showMoreOptions = false;
                });
              },
              child: const Icon(
                Icons.close,
                color: Color(0xFF8E8E93),
                size: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: timeframes.length,
            itemBuilder: (context, index) {
              final timeframe = timeframes[index];
              final isSelected = _selectedTimeframe == timeframe;
              
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTimeframe = timeframe;
                      _showMoreOptions = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF84BD00) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF84BD00) : Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      timeframe,
                      style: TextStyle(
                        color: isSelected ? Colors.black : const Color(0xFF8E8E93),
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
          
          // Chart
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: CustomPaint(
              painter: CandlestickChartPainter(),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildChartLabel('Week 1'),
                    _buildChartLabel('Week 2'),
                    _buildChartLabel('Week 3'),
                    _buildChartLabel('Week 4'),
                    _buildChartLabel('Week 5'),
                  ],
                ),
              ),
            ),
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

  Widget _buildChartLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF8E8E93),
        fontSize: 10,
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

  String _formatPositionValue(dynamic value) {
    if (value == null) return '--';
    final doubleValue = double.tryParse(value.toString());
    if (doubleValue == null) return '--';
    if (doubleValue == 0) return '0.00';
    return doubleValue.toStringAsFixed(2);
  }

  Widget _buildPriceInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
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

  Widget _buildTimeframeButton(String text, String timeframe) {
    final isSelected = _selectedTimeframe == timeframe;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeframe = timeframe;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF84BD00) : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isSelected ? const Color(0xFF84BD00) : Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.black : const Color(0xFF8E8E93),
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class CandlestickChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    
    // Draw candlesticks
    final candleWidth = size.width / 20;
    final candleSpacing = candleWidth * 0.3;
    
    for (int i = 0; i < 15; i++) {
      final x = candleSpacing + i * (candleWidth + candleSpacing);
      final isGreen = i % 3 != 0; // Alternate colors for demo
      
      // Wick
      final wickPaint = Paint()
        ..color = isGreen ? const Color(0xFF84BD00) : Colors.red
        ..strokeWidth = 1;
      
      final wickTop = size.height * 0.2 + (i % 5) * 10;
      final wickBottom = size.height * 0.8 - (i % 4) * 15;
      
      canvas.drawLine(
        Offset(x + candleWidth / 2, wickTop),
        Offset(x + candleWidth / 2, wickBottom),
        wickPaint,
      );
      
      // Body
      final bodyPaint = Paint()
        ..color = isGreen ? const Color(0xFF84BD00) : Colors.red
        ..style = PaintingStyle.fill;
      
      final bodyTop = size.height * 0.4 + (i % 3) * 20;
      final bodyHeight = size.height * 0.3 - (i % 2) * 10;
      
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, bodyTop, candleWidth, bodyHeight),
        const Radius.circular(2),
      );
      
      canvas.drawRRect(rect, bodyPaint);
    }
    
    // Draw moving average lines
    _drawMovingAverage(canvas, size, const Color(0xFFFFD700), 0.3); // Yellow
    _drawMovingAverage(canvas, size, const Color(0xFF00BFFF), 0.5); // Blue
    _drawMovingAverage(canvas, size, const Color(0xFF9370DB), 0.7); // Purple
  }
  
  void _drawMovingAverage(Canvas canvas, Size size, Color color, double position) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    final points = <Offset>[];
    
    for (int i = 0; i < 15; i++) {
      final x = size.width * (i + 1) / 16;
      final y = size.height * (0.3 + position * 0.4) + 
                (i % 4 - 2) * 10 * (1 - position);
      points.add(Offset(x, y));
    }
    
    if (points.isNotEmpty) {
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
