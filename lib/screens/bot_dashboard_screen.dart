import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/bot_service.dart';
import '../services/unified_wallet_service.dart';
import 'bot_trade_detail_screen.dart';
import 'package_program_screen.dart';
import 'bot_invest_screen.dart';
import 'bot_algorithm_screen.dart';
import 'bot_subscription_screen.dart';
import 'currency_market_screen.dart';
import 'bot_deposit_screen.dart';
import 'bot_withdraw_general_screen.dart';
import 'bot_inr_deposit_screen.dart';
import 'bot_inr_withdraw_screen.dart';
import 'bot_user_transfer_screen.dart';

class BotDashboardScreen extends StatefulWidget {
  const BotDashboardScreen({super.key});

  @override
  State<BotDashboardScreen> createState() => _BotDashboardScreenState();
}

class _BotDashboardScreenState extends State<BotDashboardScreen> {
  bool _isLoadingStrategies = true;
  double _availableBalance = 0.0;
  List<Map<String, dynamic>> _strategies = [];
  String? subscriptionPlan;
  String _selectedSort = 'Top';
  final Map<String, List<double>> _chartCache = {};
  StreamSubscription? _balanceSubscription;

  get investments => null;

  @override
  void initState() {
    super.initState();
    _fetchBotBalance();
    _fetchStrategiesFromAPI();
    _fetchUserData();
    _subscribeToBalance();
  }

  @override
  void dispose() {
    _balanceSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToBalance() {
    _balanceSubscription = UnifiedWalletService.walletBalanceStream.listen((balance) {
      if (mounted && balance != null) {
        setState(() {
          _availableBalance = balance.botBalance;
        });
      }
    });
    
    // Set initial balance
    if (UnifiedWalletService.walletBalance != null) {
      _availableBalance = UnifiedWalletService.walletBalance!.botBalance;
    }
  }

  Future<void> _fetchStrategiesFromAPI() async {
    setState(() => _isLoadingStrategies = true);

    try {
      final response = await BotService.getStrategyPerformanceAll();
      
      List<Map<String, dynamic>> fetchedStrategies = [];
      
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        
        if (data is List && data.isNotEmpty) {
          for (var strategy in data) {
            final strategyName = strategy['strategy']?.toString() ?? '';
            final isAvailable = strategy['isAvailable'] == true || 
                               strategy['available'] == true ||
                               strategy['status']?.toString().toLowerCase() == 'active';
            
            String multiplier = '1x';
            if (strategyName.contains('3X') || strategyName.contains('3x')) multiplier = '3x';
            else if (strategyName.contains('2X') || strategyName.contains('2x')) multiplier = '2x';
            else if (strategyName.contains('5X') || strategyName.contains('5x')) multiplier = '5x';
            else if (strategyName.contains('10X') || strategyName.contains('10x')) multiplier = '10x';
            
            String name = strategyName;
            if (strategyName.contains('-')) {
              name = strategyName.split('-')[0];
            }
            
            fetchedStrategies.add({
              'name': name,
              'multiplier': multiplier,
              'available': isAvailable,
              'roi3m': strategy['roi3m']?.toString() ?? strategy['returns3m']?.toString() ?? '+33%',
              'roi6m': strategy['roi6m']?.toString() ?? strategy['returns6m']?.toString() ?? '+60%',
              'roi1y': strategy['roi1y']?.toString() ?? strategy['returns1y']?.toString() ?? '+80%',
            });
          }
        }
      }
      
      if (fetchedStrategies.isEmpty || fetchedStrategies.length < 3) {
        fetchedStrategies = [
          {'name': 'Omega', 'multiplier': '3x', 'available': true, 'roi3m': '+33%', 'roi6m': '+60%', 'roi1y': '+80%'},
          {'name': 'Alpha', 'multiplier': '2x', 'available': false, 'roi3m': '+25%', 'roi6m': '+50%', 'roi1y': '+70%'},
          {'name': 'Ranger', 'multiplier': '5x', 'available': false, 'roi3m': '+40%', 'roi6m': '+70%', 'roi1y': '+90%'},
        ];
      }
      
      if (mounted) {
        setState(() {
          _strategies = fetchedStrategies;
          _isLoadingStrategies = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _strategies = [
            {'name': 'Omega', 'multiplier': '3x', 'available': true, 'roi3m': '+33%', 'roi6m': '+60%', 'roi1y': '+80%'},
            {'name': 'Alpha', 'multiplier': '2x', 'available': false, 'roi3m': '+25%', 'roi6m': '+50%', 'roi1y': '+70%'},
            {'name': 'Ranger', 'multiplier': '5x', 'available': false, 'roi3m': '+40%', 'roi6m': '+70%', 'roi1y': '+90%'},
          ];
          _isLoadingStrategies = false;
        });
      }
    }
  }

  Future<void> _fetchBotBalance() async {
    try {
      final response = await BotService.getBotBalance();
      
      if (mounted && response['success'] == true && response['data'] != null) {
        final data = response['data'];
        final availableBalance = double.tryParse(data['availableBalance']?.toString() ?? '0') ?? 0.0;
        
        setState(() {
          _availableBalance = availableBalance;
        });
      }
    } catch (e) {
      debugPrint('Error fetching bot balance: $e');
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final response = await BotService.getUserData();

      if (mounted && response['success'] == true && response['data'] != null) {
        final data = response['data'];
        final subscription = data['subscription'];
        
        if (subscription != null && subscription is Map) {
          final planValue = subscription['plan']?.toString();
          
          if (planValue != null && planValue.isNotEmpty && planValue.toLowerCase() != 'null') {
            final endDateStr = subscription['endDate']?.toString();
            
            if (endDateStr != null && endDateStr.isNotEmpty && endDateStr.toLowerCase() != 'null') {
              try {
                final endDate = DateTime.parse(endDateStr);
                final currentDate = DateTime.now();
                final remainingDays = endDate.difference(currentDate).inDays;

                if (remainingDays > 0) {
                  subscriptionPlan = planValue;
                } else {
                  subscriptionPlan = null;
                }
              } catch (e) {
                subscriptionPlan = planValue;
              }
            } else {
              subscriptionPlan = planValue;
            }
          } else {
            subscriptionPlan = null;
          }
        } else {
          subscriptionPlan = null;
        }
        
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
  }

  List<double> _generateChartFromPerformance(double roi, double winRate, int trades, String strategyName) {
    final cacheKey = '$strategyName-perf';
    if (_chartCache.containsKey(cacheKey)) {
      return _chartCache[cacheKey]!;
    }
    
    final random = math.Random(strategyName.hashCode);
    List<double> data = [];
    final totalPeriods = 30;
    
    // Different patterns for different strategies
    if (strategyName.toLowerCase().contains('omega')) {
      // Omega: Growth, peak, correction pattern
      for (int i = 0; i < totalPeriods; i++) {
        final progress = i / (totalPeriods - 1);
        double value;
        
        if (progress < 0.4) {
          // Growth phase: 90 to 130
          final phaseProgress = progress / 0.4;
          value = 90 + (40 * phaseProgress);
          value += (random.nextDouble() - 0.5) * 3;
        } else if (progress < 0.6) {
          // Peak phase: 120-130
          value = 125 + (random.nextDouble() - 0.5) * 8;
        } else {
          // Correction phase: 120 to 80
          final phaseProgress = (progress - 0.6) / 0.4;
          value = 120 - (40 * phaseProgress);
          value += (random.nextDouble() - 0.5) * 5;
        }
        
        value = value.clamp(70.0, 135.0);
        data.add(value);
      }
    } else if (strategyName.toLowerCase().contains('alpha')) {
      // Alpha: Steady upward trend with low volatility
      double currentValue = 85.0;
      for (int i = 0; i < totalPeriods; i++) {
        final progress = i / (totalPeriods - 1);
        
        // Steady growth from 85 to 115
        currentValue = 85 + (30 * progress);
        // Low volatility
        currentValue += (random.nextDouble() - 0.5) * 2;
        
        currentValue = currentValue.clamp(80.0, 120.0);
        data.add(currentValue);
      }
    } else if (strategyName.toLowerCase().contains('ranger')) {
      // Ranger: High volatility with aggressive swings
      double currentValue = 95.0;
      for (int i = 0; i < totalPeriods; i++) {
        final progress = i / (totalPeriods - 1);
        
        // Create wave pattern with high volatility
        final wave = math.sin(progress * math.pi * 2) * 15;
        currentValue = 100 + wave;
        
        // High volatility
        currentValue += (random.nextDouble() - 0.5) * 8;
        
        // Add upward trend
        currentValue += progress * 10;
        
        currentValue = currentValue.clamp(75.0, 130.0);
        data.add(currentValue);
      }
    } else {
      // Default pattern
      double currentValue = 90.0;
      for (int i = 0; i < totalPeriods; i++) {
        currentValue += (random.nextDouble() - 0.4) * 3;
        currentValue = currentValue.clamp(80.0, 120.0);
        data.add(currentValue);
      }
    }
    
    _chartCache[cacheKey] = data;
    return data;
  }

  List<double> _generateChartFromRoi(double roi, String strategyName) {
    final random = math.Random(strategyName.hashCode);
    List<double> data = [];
    double baseValue = 100.0;
    
    // Generate 30 data points with controlled range (70-130)
    for (int i = 0; i < 30; i++) {
      final progress = i / 29;
      
      // Small incremental growth based on ROI
      final growthFactor = (roi / 100) * progress; // Convert ROI to decimal growth
      final targetAtStep = 100.0 * (1 + growthFactor);
      
      // Add small volatility based on strategy type
      double volatility = 0.0;
      if (strategyName.toLowerCase().contains('omega')) {
        volatility = (random.nextDouble() - 0.5) * 4; // ±2
      } else if (strategyName.toLowerCase().contains('alpha')) {
        volatility = (random.nextDouble() - 0.5) * 3; // ±1.5
      } else if (strategyName.toLowerCase().contains('ranger')) {
        volatility = (random.nextDouble() - 0.5) * 5; // ±2.5
      } else {
        volatility = (random.nextDouble() - 0.5) * 3;
      }
      
      baseValue = targetAtStep + volatility;
      // Keep values in reasonable range (70-130)
      baseValue = baseValue.clamp(70.0, 130.0);
      data.add(baseValue);
    }
    
    return data;
  }

  List<double> _generateMockChartData(String strategyName) {
    if (_chartCache.containsKey(strategyName)) {
      return _chartCache[strategyName]!;
    }
    
    final random = math.Random(strategyName.hashCode);
    List<double> data = [];
    double baseValue = 100.0;
    
    // Generate 30 data points with realistic balance growth pattern
    for (int i = 0; i < 30; i++) {
      double growth = 0.0;
      
      // Different growth patterns for different strategies
      if (strategyName.toLowerCase().contains('omega')) {
        // Omega: Moderate volatility, upward trend
        growth = (random.nextDouble() - 0.3) * 3; // Slight upward bias
      } else if (strategyName.toLowerCase().contains('alpha')) {
        // Alpha: Lower volatility, steady growth
        growth = (random.nextDouble() - 0.25) * 2;
      } else if (strategyName.toLowerCase().contains('ranger')) {
        // Ranger: Higher volatility, aggressive growth
        growth = (random.nextDouble() - 0.35) * 4;
      } else {
        growth = (random.nextDouble() - 0.3) * 2.5;
      }
      
      baseValue += growth;
      // Keep in 70-130 range
      baseValue = baseValue.clamp(75.0, 125.0);
      data.add(baseValue);
    }
    
    _chartCache[strategyName] = data;
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CurrencyMarketScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF84BD00), width: 1),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.show_chart, color: Color(0xFF84BD00), size: 18),
                            SizedBox(width: 8),
                            Text('Market', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF84BD00), width: 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: Color(0xFF84BD00), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 2),
                          const Text('LIVE', style: TextStyle(color: Color(0xFF84BD00), fontSize: 8, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          Text('$_availableBalance USDT', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Action buttons: Deposit, Transfer, and Withdraw
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _showDepositOptions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF84BD00),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add_circle_outline, color: Colors.black, size: 14),
                            SizedBox(width: 4),
                            Text('Deposit', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const BotUserTransferScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1C1C1E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                            side: const BorderSide(color: Color(0xFF84BD00), width: 1),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.swap_horiz, color: Color(0xFF84BD00), size: 14),
                            SizedBox(width: 4),
                            Text('Transfer', style: TextStyle(color: Color(0xFF84BD00), fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _showWithdrawOptions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1C1C1E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                            side: const BorderSide(color: Color(0xFF84BD00), width: 1),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.remove_circle_outline, color: Color(0xFF84BD00), size: 14),
                            SizedBox(width: 4),
                            Text('Withdraw', style: TextStyle(color: Color(0xFF84BD00), fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/images/adhome.png', width: double.infinity, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 24),
              _buildTopStrategies(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopStrategies() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Top Strategies', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Sort by : ', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
                  Text(_selectedSort, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  const Text('Latest', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
                  const SizedBox(width: 16),
                  const Text('Showing all', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        if (_isLoadingStrategies)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF84BD00)))))
        else if (_strategies.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No strategies available', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14))))
        else
          SizedBox(
            height: 360,
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.85),
              physics: const BouncingScrollPhysics(),
              itemCount: _strategies.length,
              itemBuilder: (context, index) {
                final strategy = _strategies[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _buildStrategyCard(
                    strategy['name'] as String,
                    strategy['multiplier'] as String,
                    strategy['available'] as bool,
                    {
                      '3M': strategy['roi3m'] as String,
                      '6M': strategy['roi6m'] as String,
                      '1Y': strategy['roi1y'] as String,
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildStrategyCard(String name, String multiplier, bool isAvailable, Map<String, String> performance) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2C3E1F), Color(0xFF1A2415)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF84BD00).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$name - $multiplier', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () {
                  // Show direct performance popup for strategy
                  debugPrint('=== ARROW BUTTON CLICKED ===');
                  debugPrint('Strategy name: $name');
                  debugPrint('Strategy multiplier: $multiplier');
                  
                  // Find strategy data
                  final strategyFullName = '$name-$multiplier';
                  final Map<String, dynamic> strategyData = {
                    'name': strategyFullName,
                    'tag': multiplier == '3X' ? 'USDm' : 'Coin-m',
                    'annualizedROI': multiplier == '3X' ? '922.19%' : multiplier == '2X' ? '845.67%' : '734.28%',
                    'aum': multiplier == '3X' ? '805.99K' : multiplier == '2X' ? '623.45K' : '412.78K',
                    'followers': multiplier == '3X' ? '76 Followers' : multiplier == '2X' ? '89 Followers' : '54 Followers',
                    'winRate': multiplier == '3X' ? '69.23%' : multiplier == '2X' ? '72.75%' : '68.50%',
                    'volume': multiplier == '3X' ? '5.62M' : multiplier == '2X' ? '8.81M' : '11.23M',
                    'drawdown': multiplier == '3X' ? '33.6% Max / 21.8% Avg' : multiplier == '2X' ? '41.2% Max / 29.4% Avg' : '38.5% Max / 25.2% Avg',
                    'trades': multiplier == '3X' ? '26' : multiplier == '2X' ? '33' : '41',
                    'commission': multiplier == '3X' ? '20%' : multiplier == '2X' ? '25%' : '30%',
                    'risk': multiplier == '3X' ? '47.20%' : multiplier == '2X' ? '39.60%' : '52.80%',
                  };
                  
                  _showStrategyPerformancePopup(context, strategyData);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Color(0xFF84BD00), shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_outward, color: Colors.black, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 110,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: FutureBuilder<Map<String, dynamic>>(
              future: BotService.getBotBalanceHistory(
                strategy: '$name-${multiplier.toUpperCase()}',
                days: 90,
              ),
              builder: (context, snapshot) {
                // Check cache first for this strategy
                final cacheKey = '$name-$multiplier-balance';
                
                if (snapshot.connectionState == ConnectionState.waiting) {
                  // Show cached data if available while loading
                  if (_chartCache.containsKey(cacheKey)) {
                    return CustomPaint(
                      size: const Size(double.infinity, 90),
                      painter: _MiniChartPainter(data: _chartCache[cacheKey]!),
                    );
                  }
                  return const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF84BD00)),
                      ),
                    ),
                  );
                }
                
                List<double> chartData = [];
                
                if (snapshot.hasData && snapshot.data?['success'] == true) {
                  // Try to extract history from API response
                  final responseData = snapshot.data?['data'];
                  List? history;
                  
                  if (responseData is Map) {
                    history = responseData['history'] as List?;
                  } else if (responseData is List) {
                    history = responseData;
                  }
                  
                  if (history == null) {
                    history = snapshot.data?['history'] as List?;
                  }
                  
                  if (history != null && history.isNotEmpty) {
                    chartData = history.map((item) {
                      final balance = item['balance'] ?? item['value'] ?? item['amount'] ?? 0;
                      return double.tryParse(balance.toString()) ?? 0.0;
                    }).toList();
                    
                    // If we have valid data from API, cache and use it
                    if (chartData.isNotEmpty && chartData.any((v) => v > 0)) {
                      _chartCache[cacheKey] = chartData;
                      return CustomPaint(
                        size: const Size(double.infinity, 90),
                        painter: _MiniChartPainter(data: chartData),
                      );
                    }
                  }
                }
                
                // If no data from API, generate mock data
                if (chartData.isEmpty) {
                  final mockData = _generateMockChartData(name);
                  _chartCache[cacheKey] = mockData;
                  chartData = mockData;
                  return CustomPaint(
                    size: const Size(double.infinity, 90),
                    painter: _MiniChartPainter(data: chartData),
                  );
                }
                
                // Fallback: Check cache first before generating
                if (_chartCache.containsKey(cacheKey)) {
                  return CustomPaint(
                    size: const Size(double.infinity, 90),
                    painter: _MiniChartPainter(data: _chartCache[cacheKey]!),
                  );
                }
                
                // Generate from performance API
                return FutureBuilder<Map<String, dynamic>>(
                  future: BotService.getStrategyPerformance('$name-$multiplier'),
                  builder: (context, perfSnapshot) {
                    List<double> fallbackData = [];
                    
                    if (perfSnapshot.hasData && perfSnapshot.data?['success'] == true) {
                      final data = perfSnapshot.data?['data'];
                      if (data != null) {
                        final roiStr = data['rot']?.toString() ?? data['roi']?.toString() ?? '0%';
                        final roi = double.tryParse(roiStr.replaceAll('%', '').replaceAll('+', '').trim()) ?? 0.0;
                        
                        final winRateStr = data['winRate']?.toString() ?? '0%';
                        final winRate = double.tryParse(winRateStr.replaceAll('%', '').trim()) ?? 0.0;
                        
                        final tradesValue = data['trades'];
                        final trades = tradesValue is int ? tradesValue : (int.tryParse(tradesValue?.toString() ?? '0') ?? 0);
                        
                        fallbackData = _generateChartFromPerformance(roi, winRate, trades, name);
                      }
                    }
                    
                    if (fallbackData.isEmpty) {
                      fallbackData = _generateMockChartData(name);
                    }
                    
                    // Cache the fallback data
                    _chartCache[cacheKey] = fallbackData;
                    
                    return CustomPaint(
                      size: const Size(double.infinity, 90),
                      painter: _MiniChartPainter(data: fallbackData),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildReturnItem('3M:', performance['3M'] ?? '+33%')),
              const SizedBox(width: 6),
              Expanded(child: _buildReturnItem('6M:', performance['6M'] ?? '+60%')),
              const SizedBox(width: 6),
              Expanded(child: _buildReturnItem('1Y:', performance['1Y'] ?? '+80%')),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: isAvailable ? () {
                // Check subscription status
                if (subscriptionPlan == null || subscriptionPlan!.isEmpty) {
                  // New user - Navigate to subscription screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BotSubscriptionScreen(),
                    ),
                  ).then((_) {
                    // Refresh balance when returning from subscription screen
                    if (mounted) {
                      _fetchBotBalance();
                    }
                  });
                } else {
                  // Already subscribed - Navigate to investment screen
                  final strategyData = {
                    'name': name,
                    'multiplier': multiplier,
                    'available': isAvailable,
                    'roi3m': performance['3M'] ?? '+33%',
                    'roi6m': performance['6M'] ?? '+60%',
                    'roi1y': performance['1Y'] ?? '+80%',
                  };
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BotInvestScreen(
                        strategy: strategyData,
                        walletBalance: _availableBalance,
                      ),
                    ),
                  ).then((_) {
                    // Refresh balance when returning from invest screen
                    if (mounted) {
                      _fetchBotBalance();
                    }
                  });
                }
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isAvailable ? const Color(0xFF84BD00) : const Color(0xFF333333),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text(
                isAvailable ? 'Invest' : 'Coming Soon',
                style: TextStyle(
                  color: isAvailable ? Colors.black : const Color(0xFF8E8E93),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnItem(String period, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(period, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 9)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Color(0xFF84BD00), fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Build strategy performance popup
  void _showStrategyPerformancePopup(BuildContext context, Map<String, dynamic> strategy) {
    final strategyKey = strategy['name']?.toString() ?? '';
    final investedAmount = (investments ?? {})[strategyKey] ?? 0.0;
    
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
          child: StrategyPerformancePopup(
            strategy: strategy,
            investedAmount: investedAmount,
          ),
        );
      },
    );
  }

  void _showDepositOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildSelectionSheet(
        title: 'Deposit',
        options: [
          {
            'title': 'Crypto Deposit',
            'subtitle': 'Deposit USDT via Network',
            'icon': Icons.currency_bitcoin,
            'onTap': () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BotDepositScreen()),
              );
            },
          },
          {
            'title': 'INR Deposit',
            'subtitle': 'Deposit via Bank/UPI',
            'icon': Icons.account_balance,
            'onTap': () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BotInrDepositScreen()),
              );
            },
          },
        ],
      ),
    );
  }

  void _showWithdrawOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildSelectionSheet(
        title: 'Withdraw',
        options: [
          {
            'title': 'Crypto Withdraw',
            'subtitle': 'Withdraw USDT to Wallet',
            'icon': Icons.wallet,
            'onTap': () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BotWithdrawGeneralScreen()),
              );
            },
          },
          {
            'title': 'INR Withdraw',
            'subtitle': 'Withdraw to Bank Account',
            'icon': Icons.account_balance_wallet,
            'onTap': () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BotInrWithdrawScreen()),
              );
            },
          },
        ],
      ),
    );
  }

  Widget _buildSelectionSheet({required String title, required List<Map<String, dynamic>> options}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select $title Method',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...options.map((option) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              onTap: option['onTap'] as VoidCallback,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF84BD00).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF84BD00).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(option['icon'] as IconData, color: const Color(0xFF84BD00)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option['title'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            option['subtitle'] as String,
                            style: const TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Color(0xFF8E8E93), size: 16),
                  ],
                ),
              ),
            ),
          )).toList(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _MiniChartPainter extends CustomPainter {
  final List<double> data;
  
  _MiniChartPainter({this.data = const []});
  
  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height - 20;
    final chartWidth = size.width - 30;
    
    // Draw Y-axis labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    
    if (data.isNotEmpty) {
      final minValue = data.reduce((a, b) => a < b ? a : b);
      final maxValue = data.reduce((a, b) => a > b ? a : b);
      final range = maxValue - minValue;
      
      // Y-axis labels (4 labels) - properly spaced
      final yLabels = [
        maxValue.round().toString(),
        (minValue + range * 0.66).round().toString(),
        (minValue + range * 0.33).round().toString(),
        minValue.round().toString(),
      ];
      
      for (int i = 0; i < yLabels.length; i++) {
        textPainter.text = TextSpan(
          text: yLabels[i],
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(0, (chartHeight / (yLabels.length - 1)) * i - 4),
        );
      }
    } else {
      // Default labels when no data
      final yLabels = ['130', '110', '90', '70'];
      
      for (int i = 0; i < yLabels.length; i++) {
        textPainter.text = TextSpan(
          text: yLabels[i],
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(0, (chartHeight / (yLabels.length - 1)) * i - 4),
        );
      }
    }
    
    // Draw X-axis labels (dates)
    final now = DateTime.now();
    final xLabels = [
      '${now.subtract(const Duration(days: 90)).year}-W${((now.subtract(const Duration(days: 90)).month - 1) * 4 + 1)}',
      '${now.subtract(const Duration(days: 60)).year}-W${((now.subtract(const Duration(days: 60)).month - 1) * 4 + 1)}',
      '${now.subtract(const Duration(days: 30)).year}-W${((now.subtract(const Duration(days: 30)).month - 1) * 4 + 1)}',
      '${now.year}-W${((now.month - 1) * 4 + 1)}',
    ];
    
    final xSpacing = chartWidth / (xLabels.length - 1);
    for (int i = 0; i < xLabels.length; i++) {
      textPainter.text = TextSpan(
        text: xLabels[i],
        style: const TextStyle(
          color: Color(0xFF8E8E93),
          fontSize: 8,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(30 + (xSpacing * i) - textPainter.width / 2, size.height - 12),
      );
    }
    
    List<Offset> points;
    
    if (data.isNotEmpty) {
      final minValue = data.reduce((a, b) => a < b ? a : b);
      final maxValue = data.reduce((a, b) => a > b ? a : b);
      final range = maxValue - minValue;
      
      points = [];
      for (int i = 0; i < data.length; i++) {
        final x = 30 + (chartWidth * i / (data.length - 1));
        final normalizedValue = range > 0 ? (data[i] - minValue) / range : 0.5;
        final y = chartHeight * (1 - normalizedValue * 0.85);
        points.add(Offset(x, y));
      }
    } else {
      points = [
        Offset(30, chartHeight * 0.75),
        Offset(30 + chartWidth * 0.15, chartHeight * 0.7),
        Offset(30 + chartWidth * 0.3, chartHeight * 0.6),
        Offset(30 + chartWidth * 0.45, chartHeight * 0.55),
        Offset(30 + chartWidth * 0.6, chartHeight * 0.45),
        Offset(30 + chartWidth * 0.75, chartHeight * 0.4),
        Offset(30 + chartWidth, chartHeight * 0.25),
      ];
    }

    final paint = Paint()
      ..color = const Color(0xFF84BD00)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, controlPoint.dx, controlPoint.dy);
    }
    
    path.lineTo(points.last.dx, points.last.dy);
    canvas.drawPath(path, paint);

    final fillPath = Path.from(path);
    fillPath.lineTo(30 + chartWidth, chartHeight);
    fillPath.lineTo(30, chartHeight);
    fillPath.close();

    final gradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x4D84BD00), Color(0x0084BD00)],
    );

    final fillPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(30, 0, chartWidth, chartHeight))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
