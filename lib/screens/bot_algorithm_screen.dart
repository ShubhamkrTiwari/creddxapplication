import 'package:flutter/material.dart';
import '../services/bot_service.dart';
import 'bot_trade_detail_screen.dart';
import '../main_navigation.dart';
import 'bot_invest_screen.dart';
import 'bot_withdraw_screen.dart';
import 'package_program_screen.dart';

class BotAlgorithmScreen extends StatefulWidget {
  const BotAlgorithmScreen({super.key});

  @override
  State<BotAlgorithmScreen> createState() => _BotAlgorithmScreenState();
}

class _BotAlgorithmScreenState extends State<BotAlgorithmScreen> {
  // User data state
  double walletBalance = 0;
  double _totalBalance = 0.0;
  double _availableBalance = 0.0;
  double _investedBalance = 0.0;
  double _maxWithdrawOmega = 0.0;
  String? subscriptionPlan;
  Map<String, double> investments = {};
  bool btnDisable = true;
  String? errorMessage;
  
  // Get total invested from all strategies
  double get _totalInvested {
    return investments.values.fold(0.0, (sum, amount) => sum + amount);
  }
  
  // Loading states
  bool isLoadingUserData = true;
  bool isLoadingStrategies = true;
  Map<String, dynamic>? strategyPerformanceData;

  // Static alphaStrategies with full data
  final List<Map<String, dynamic>> _strategies = [
    {
      'name': 'Omega-3X',
      'badge': 'USDm',
      'badgeColor': 'bg-linear-to-r from-[#9DD329] to-[#7fb31f]',
      'pairType': 'Multiple Alt Pairs',
      'followers': '76 Followers',
      'annualizedROI': '922.19%',
      'aum': '805.99K',
      'marketType': 'Futures',
      'leverage': '3x Leverage',
      'status': 'Invest',
      'available': true,
      'volume': '5.62M',
      'drawdown': '33.6% Max / 21.8% Avg',
      'recovery': '137d Max / 73d Avg',
      'trades': '26',
      'winRate': '69.23%',
      'commission': '20%',
      'risk': '47.20%',
    },
    {
      'name': 'Alpha-2X',
      'badge': 'Coin-m',
      'badgeColor': 'bg-linear-to-r from-[#9DD329] to-[#7fb31f]',
      'pairType': 'Top Pairs',
      'followers': '928 Followers',
      'annualizedROI': '228.47%',
      'aum': '489.20K',
      'marketType': 'Spot',
      'leverage': '2x Leverage',
      'status': 'Coming Soon',
      'available': false,
      'volume': '3.27M',
      'drawdown': '27.4% Max / 18.1% Avg',
      'recovery': '98d Max / 56d Avg',
      'trades': '18',
      'winRate': '65.12%',
      'commission': '15%',
      'risk': '39.60%',
    },
    {
      'name': 'Ranger-5X',
      'badge': 'USDm',
      'badgeColor': 'bg-linear-to-r from-[#9DD329] to-[#7fb31f]',
      'pairType': 'SOLUSDT',
      'followers': '1576 Followers',
      'annualizedROI': '412.62%',
      'aum': '1.2M',
      'marketType': 'Scalper',
      'leverage': '5x Leverage',
      'status': 'Coming Soon',
      'available': false,
      'volume': '8.81M',
      'drawdown': '41.2% Max / 29.4% Avg',
      'recovery': '145d Max / 81d Avg',
      'trades': '33',
      'winRate': '72.75%',
      'commission': '25%',
      'risk': '52.80%',
    },
  ];

  // 7. Invest Button Conditions - Check if invest should be enabled
  bool _isInvestEnabled(Map<String, dynamic> strategy) {
    // If loading, disable
    if (btnDisable || isLoadingUserData) {
      debugPrint('INVEST DISABLED: btnDisable=$btnDisable, isLoadingUserData=$isLoadingUserData');
      return false;
    }

    // If subscriptionPlan == null, disable (user must subscribe first)
    if (subscriptionPlan == null) {
      debugPrint('INVEST DISABLED: subscriptionPlan is null');
      return false;
    }

    // If strategy.available == false (Coming Soon), disable
    if (strategy['available'] == false) {
      debugPrint('INVEST DISABLED: strategy not available');
      return false;
    }

    // User can invest if they have wallet balance OR already have investment in this strategy
    final strategyKey = strategy['name']?.toString() ?? '';
    final hasExistingInvestment = (investments[strategyKey] ?? 0) > 0;

    // Enable if wallet has balance OR user has existing investment (for invest more)
    if (walletBalance > 0 || hasExistingInvestment) {
      debugPrint('INVEST ENABLED: walletBalance=$walletBalance, hasExistingInvestment=$hasExistingInvestment');
      return true;
    }

    // Else, disable
    debugPrint('INVEST DISABLED: No balance or investment. walletBalance=$walletBalance, investments=$investments');
    return false;
  }

  Widget _buildBotBalanceSection() {
    if (isLoadingUserData) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF84BD00)),
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Loading balance...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
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
            children: [
              const Icon(Icons.account_balance_wallet, color: Color(0xFF84BD00), size: 16),
              const SizedBox(width: 6),
              const Text(
                'Bot Wallet Balance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (subscriptionPlan != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF84BD00).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Subscribed',
                    style: TextStyle(
                      color: const Color(0xFF84BD00),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Total Balance
          Text(
            'Total Balance',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_totalBalance.toStringAsFixed(2)} USDT',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          // Total Invested
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Invested',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
                Text(
                  '${_totalInvested.toStringAsFixed(2)} USDT',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // 1. On Page Load - Reset state
    setState(() {
      btnDisable = true;
      walletBalance = 0;
      subscriptionPlan = null;
      investments = {};
      errorMessage = null;
    });

    // 2. Call APIs
    await Future.wait([
      _fetchUserData(),
      _fetchStrategyPerformance(),
      _fetchBotBalance(),
    ]);
  }

  @override
  void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh user data and bot balance when returning from other screens
    _fetchUserData();
    _fetchBotBalance();
  }

  List<dynamic> _strategyStats = []; // Store API response array

  Future<void> _fetchStrategyPerformance() async {
    try {
      final response = await BotService.getStrategyPerformanceAll();

      if (mounted) {
        setState(() {
          if (response['success'] == true && response['data'] != null) {
            // API returns array of strategy stats
            _strategyStats = response['data'] is List ? response['data'] : [];
            // Merge API data with static strategies
            _mergeStrategyData();
          }
          isLoadingStrategies = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching strategy performance: $e');
      // If API fails, use static data (fallback)
      if (mounted) {
        setState(() {
          isLoadingStrategies = false;
        });
      }
    }
  }

  void _mergeStrategyData() {
    // If API returned strategies, rebuild the list from API data
    if (_strategyStats.isNotEmpty) {
      final List<Map<String, dynamic>> apiStrategies = [];

      for (var stat in _strategyStats) {
        final strategyName = stat['strategy']?.toString() ?? 'Unknown';
        final isAvailable = stat['isAvailable'] == true || stat['available'] == true;

        // Build features array from API data
        final List<String> features = [];
        if (stat['marketType'] != null) {
          features.add(stat['marketType'].toString());
        }
        if (stat['leverage'] != null) {
          features.add('${stat['leverage']}');
        }
        // Ensure at least 2 features for UI layout
        while (features.length < 2) {
          features.add('AI Powered');
        }

        apiStrategies.add({
          'name': strategyName,
          'tag': stat['badge']?.toString() ?? stat['type']?.toString() ?? 'USDm',
          'description': stat['pairType']?.toString() ?? stat['description']?.toString() ?? 'Multiple Pairs',
          'followers': stat['followers']?.toString() ?? '0',
          'annualizedROI': stat['roi'] != null ? '${stat['roi']}' : '0%',
          'aum': stat['aum']?.toString() ?? stat['volume']?.toString() ?? '0',
          'features': features,
          'isComingSoon': !isAvailable,
          'available': isAvailable,
          // Additional fields for popup/details
          'volume': stat['volume']?.toString() ?? '0',
          'winRate': stat['winRate']?.toString() ?? '0%',
          'drawdown': stat['drawdown']?.toString() ?? '0%',
          'trades': stat['trades']?.toString() ?? '0',
          'marketType': stat['marketType']?.toString() ?? 'Futures',
          'leverage': stat['leverage']?.toString() ?? '1x',
          'commission': stat['commission']?.toString() ?? '20%',
          'risk': stat['risk']?.toString() ?? 'Medium',
        });
      }

      // Replace static strategies with API data
      if (apiStrategies.isNotEmpty) {
        _strategies.clear();
        _strategies.addAll(apiStrategies);
      }
    }
  }

  Future<void> _fetchBotBalance() async {
    try {
      setState(() => isLoadingUserData = true);

      // Fetch from all endpoints for complete balance data
      final results = await Future.wait([
        BotService.getBotBalance(),
        BotService.getUserBalanceHistory(),
        BotService.getAdminBotUserData(),
        BotService.getUserData(),
      ]);

      final botBalanceResponse = results[0];
      final balanceHistoryResponse = results[1];
      final adminUserDataResponse = results[2];
      final userDataResponse = results[3];

      debugPrint('=== BOT BALANCE FETCH RESULTS ===');
      debugPrint('Bot Balance Response: $botBalanceResponse');
      debugPrint('Balance History Response: $balanceHistoryResponse');
      debugPrint('Admin User Data Response: $adminUserDataResponse');
      debugPrint('User Data Response (/users/user): $userDataResponse');

      if (mounted) {
        double totalBalance = 0.0;
        double availableBalance = 0.0;
        double investedBalance = 0.0;

        // 1. Try botwallet/balance endpoint
        if (botBalanceResponse['success'] == true && botBalanceResponse['data'] != null) {
          final data = botBalanceResponse['data'];
          // Handle different response formats
          if (data['balance'] != null && data['totalBalance'] == null) {
            // Simple format: {"success":true,"balance":27}
            final balance = double.tryParse(data['balance']?.toString() ?? '0') ?? 0.0;
            totalBalance = balance;
            availableBalance = balance;
            investedBalance = 0.0;
          } else {
            // Full format with separate fields
            totalBalance = double.tryParse(data['totalBalance']?.toString() ?? '0') ?? 0.0;
            availableBalance = double.tryParse(data['availableBalance']?.toString() ?? '0') ?? 0.0;
            investedBalance = double.tryParse(data['investedBalance']?.toString() ?? '0') ?? 0.0;
          }
          debugPrint('Parsed from Bot Balance: total=$totalBalance, available=$availableBalance, invested=$investedBalance');
        }

        // 2. Try user/balance-history endpoint for invested amount
        if (balanceHistoryResponse['success'] == true && balanceHistoryResponse['data'] != null) {
          final data = balanceHistoryResponse['data'];
          final historyInvested = double.tryParse(
            data['investedAmount']?.toString() ?? data['invested']?.toString() ?? '0'
          ) ?? 0.0;
          if (historyInvested > 0) {
            investedBalance = historyInvested;
            debugPrint('Using invested from balance-history: $investedBalance');
          }
          final historyBalance = double.tryParse(
            data['balance']?.toString() ?? data['availableBalance']?.toString() ?? '0'
          ) ?? 0.0;
          if (historyBalance > 0) {
            availableBalance = historyBalance;
            debugPrint('Using balance from balance-history: $availableBalance');
          }
        }

        // 3. Try admin/bot/user-data endpoint for any additional data
        if (adminUserDataResponse['success'] == true && adminUserDataResponse['data'] != null) {
          final data = adminUserDataResponse['data'];
          debugPrint('Admin user-data raw: $data');
          final adminInvested = double.tryParse(
            data['investedAmount']?.toString() ?? data['invested']?.toString() ??
            data['totalInvestment']?.toString() ?? '0'
          ) ?? 0.0;
          if (adminInvested > 0) {
            investedBalance = adminInvested;
            debugPrint('Using invested from admin user-data: $investedBalance');
          }
          final adminBalance = double.tryParse(
            data['balance']?.toString() ?? data['availableBalance']?.toString() ??
            data['walletBalance']?.toString() ?? '0'
          ) ?? 0.0;
          // Only use admin user data balance if availableBalance is still 0 (not set by bot balance API)
          if (adminBalance > 0 && availableBalance == 0) {
            availableBalance = adminBalance;
            debugPrint('Using balance from admin user-data: $availableBalance');
          }
          final adminTotal = double.tryParse(
            data['totalBalance']?.toString() ?? '0'
          ) ?? 0.0;
          if (adminTotal > 0) {
            totalBalance = adminTotal;
            debugPrint('Using total from admin user-data: $totalBalance');
          }
        }

        // 4. Try /bot/v1/api/users/user endpoint
        if (userDataResponse['success'] == true && userDataResponse['data'] != null) {
          final data = userDataResponse['data'];
          debugPrint('User data (/users/user) raw: $data');

          // Parse balance fields from user data
          final userInvested = double.tryParse(
            data['investedAmount']?.toString() ?? data['invested']?.toString() ??
            data['totalInvestment']?.toString() ?? data['investments']?.toString() ?? '0'
          ) ?? 0.0;
          if (userInvested > 0) {
            investedBalance = userInvested;
            debugPrint('Using invested from /users/user: $investedBalance');
          }

          final userBalance = double.tryParse(
            data['balance']?.toString() ?? data['availableBalance']?.toString() ??
            data['walletBalance']?.toString() ?? data['botBalance']?.toString() ??
            data['maxWithdrawOmega']?.toString() ?? '0'
          ) ?? 0.0;
          // Only use user data balance if availableBalance is still 0 (not set by bot balance API)
          if (userBalance > 0 && availableBalance == 0) {
            availableBalance = userBalance;
            debugPrint('Using balance from /users/user: $availableBalance');
          }

          final userTotal = double.tryParse(
            data['totalBalance']?.toString() ?? '0'
          ) ?? 0.0;
          if (userTotal > 0) {
            totalBalance = userTotal;
            debugPrint('Using total from /users/user: $totalBalance');
          }
        }

        // Calculate total if not provided
        if (totalBalance == 0 && (availableBalance > 0 || investedBalance > 0)) {
          totalBalance = availableBalance + investedBalance;
        }

        debugPrint('=== FINAL BALANCE VALUES ===');
        debugPrint('Total: $totalBalance, Available: $availableBalance, Invested: $investedBalance');

        setState(() {
          _totalBalance = totalBalance;
          _availableBalance = availableBalance;
          _investedBalance = investedBalance;
          walletBalance = availableBalance;
          isLoadingUserData = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching bot balance: $e');
      setState(() {
        walletBalance = 0;
        _totalBalance = 0.0;
        _availableBalance = 0.0;
        _investedBalance = 0.0;
        isLoadingUserData = false;
      });
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final response = await BotService.getUserData();

      if (mounted) {
        setState(() {
          if (response['success'] == true && response['data'] != null) {
            final data = response['data'];

            // 3. Set Wallet Balance (only if bot balance API didn't set it)
            // Bot balance API is more reliable, so only use user data as fallback
            final userDataBalance = (data['balance'] as num?)?.toDouble() ?? 0;
            if (walletBalance == 0 && userDataBalance > 0) {
              walletBalance = userDataBalance;
            }

            // 4. Check Subscription with endDate validation
            final subscription = data['subscription'];
            if (subscription != null && subscription['endDate'] != null) {
              final endDate = DateTime.tryParse(subscription['endDate'].toString());
              final currentDate = DateTime.now();

              if (endDate != null) {
                final remainingDays = endDate.difference(currentDate).inDays;

                if (remainingDays <= 0) {
                  // Expired subscription
                  subscriptionPlan = null;
                } else {
                  // Active subscription
                  subscriptionPlan = subscription['plan']?.toString();
                }
              } else {
                subscriptionPlan = subscription['plan']?.toString();
              }
            } else {
              subscriptionPlan = null;
            }

            // 5. Set Investments (Strategy-wise)
            // Try multiple possible field names from API
            final alphaInvested = (data['maxWithdrawAlpha'] as num?)?.toDouble() ?? 
                                 (data['maxWithdrawAplha'] as num?)?.toDouble() ?? 
                                 (data['alphaInvested'] as num?)?.toDouble() ?? 
                                 (data['investedAlpha'] as num?)?.toDouble() ?? 0;
            
            final omegaInvested = (data['maxWithdrawOmega'] as num?)?.toDouble() ?? 
                                  (data['maxWithdrawOmega'] as num?)?.toDouble() ?? 
                                  (data['omegaInvested'] as num?)?.toDouble() ?? 
                                  (data['investedOmega'] as num?)?.toDouble() ?? 
                                  (data['maxOmega'] as num?)?.toDouble() ?? 0;
            
            // Store maxWithdrawOmega separately for display
            _maxWithdrawOmega = omegaInvested;
            
            investments = {
              'Alpha-2X': alphaInvested,
              'Omega-3X': omegaInvested,
            };
            
            debugPrint('=== INVESTMENTS FETCHED ===');
            debugPrint('Alpha-2X: $alphaInvested');
            debugPrint('Omega-3X: $omegaInvested');
            debugPrint('All API fields: ${data.keys.toList()}');
            debugPrint('Raw API data: $data');

            errorMessage = null;
          } else {
            // 8. Error Handling
            errorMessage = 'Failed to fetch user info.';
            walletBalance = 0;
            subscriptionPlan = null;
            investments = {};
          }

          // 6. Button Control - After API success/fail
          btnDisable = false;
          isLoadingUserData = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      if (mounted) {
        setState(() {
          // 8. Error Handling
          errorMessage = 'Failed to fetch user info.';
          walletBalance = 0;
          subscriptionPlan = null;
          investments = {};
          btnDisable = false;
          isLoadingUserData = false;
        });
      }
    }
  }

  void _navigateToDetail(Map<String, dynamic> strategy) {
    final strategyName = strategy['name']?.toString() ?? 'Unknown-1X';
    List<String> parts = strategyName.split('-');
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

  void _showInvestDialog(Map<String, dynamic> strategy) {
    final TextEditingController amountController = TextEditingController();

    // Get available balance for max invest amount from walletBalance
    final availableBalance = walletBalance.toStringAsFixed(2);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: Text(
            'Invest in ${strategy['name']?.toString() ?? 'Unknown'}',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Amount (USDT)',
                  labelStyle: const TextStyle(color: Color(0xFF8E8E93)),
                  border: const OutlineInputBorder(),
                  hintText: 'Enter amount to invest',
                  hintStyle: const TextStyle(color: Color(0xFF4E4E4E)),
                  suffixText: 'Max: $availableBalance',
                  suffixStyle: const TextStyle(
                    color: Color(0xFF84BD00),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Available: $availableBalance USDT',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF84BD00),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      amountController.text = availableBalance;
                    },
                    child: const Text(
                      'Set Max',
                      style: TextStyle(
                        color: Color(0xFF84BD00),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Note: Investment will be processed in ${strategy['name']?.toString() ?? 'Unknown'} strategy.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid amount'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final maxAmount = double.tryParse(availableBalance) ?? 0.0;
                if (amount > maxAmount) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Maximum invest amount is $availableBalance USDT'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.of(context).pop();

                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF84BD00)),
                    ),
                  ),
                );

                try {
                  // Generate botId from strategy name
                  final strategyName = strategy['name']?.toString() ?? 'Unknown';
                  String botId = strategyName.replaceAll('-', '_').toLowerCase();

                  final result = await BotService.invest(
                    botId: botId,
                    amount: amount,
                    strategy: strategyName,
                  );

                  Navigator.of(context).pop(); // Remove loading indicator

                  if (result['success'] == true) {
                    // Immediately update local balance for instant feedback
                    setState(() {
                      walletBalance = walletBalance - amount;
                      _availableBalance = _availableBalance - amount;
                      _totalBalance = _totalBalance - amount;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Investment successful!'),
                        backgroundColor: const Color(0xFF84BD00),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                    // Refresh data - update bot balance after investment
                    _fetchUserData();
                    _fetchBotBalance();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['error'] ?? 'Investment failed'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  Navigator.of(context).pop(); // Remove loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
              ),
              child: const Text('Invest', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showWithdrawDialog(Map<String, dynamic> strategy) {
    final TextEditingController amountController = TextEditingController();
    
    // Get the invested amount for this strategy from investments state
    final strategyKey = strategy['name']?.toString() ?? '';
    final investedAmount = investments[strategyKey]?.toString() ?? '0';
    final maxWithdraw = investments[strategyKey] ?? 0.0;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Withdraw from ${strategy['name']?.toString() ?? 'Unknown'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (USDT)',
                  border: OutlineInputBorder(),
                  hintText: 'Enter amount to withdraw',
                  suffixText: 'Max: $investedAmount',
                  suffixStyle: TextStyle(
                    color: Color(0xFF84BD00),
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Maximum withdrawal: $investedAmount USDT',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF84BD00),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      amountController.text = investedAmount;
                    },
                    child: Text(
                      'Set Max',
                      style: TextStyle(
                        color: Color(0xFF84BD00),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Note: Withdrawal will be processed from your active investment in this strategy.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a valid amount'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                if (amount > maxWithdraw) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Maximum withdrawal amount is $investedAmount USDT'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.of(context).pop();
                
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                try {
                  // Generate botId from strategy name
                  final strategyName = strategy['name']?.toString() ?? 'Unknown';
                  String botId = strategyName.replaceAll('-', '_').toLowerCase();

                  final result = await BotService.withdraw(
                    botId: botId,
                    amount: amount,
                    strategy: strategyName,
                  );

                  Navigator.of(context).pop(); // Remove loading indicator

                  if (result['success'] == true) {
                    // Immediately update local balance for instant feedback
                    setState(() {
                      walletBalance = walletBalance + amount;
                      _availableBalance = _availableBalance + amount;
                      _totalBalance = _totalBalance + amount;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Withdrawal successful!'),
                        backgroundColor: Color(0xFF84BD00),
                        duration: Duration(seconds: 3),
                      ),
                    );
                    // Refresh data - update bot balance after withdrawal
                    _fetchUserData();
                    _fetchBotBalance();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['error'] ?? 'Withdrawal failed'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  Navigator.of(context).pop(); // Remove loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text('Withdraw', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF84BD00),
              ),
            ),
          ],
        );
      },
    );
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
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _fetchUserData(),
            _fetchStrategyPerformance(),
            _fetchBotBalance(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Bot Balance Section
              _buildBotBalanceSection(),
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
    ));
  }

  Widget _buildStrategyCard(Map<String, dynamic> strategy) {
    return Container(
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
          // Card content - tappable for performance popup
          GestureDetector(
            onTap: () => _showStrategyPerformancePopup(strategy),
            behavior: HitTestBehavior.translucent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    strategy['name']?.toString() ?? 'Unknown',
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
                    strategy['tag']?.toString() ?? 'N/A',
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
                      strategy['description']?.toString() ?? 'No description',
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
                    '${strategy['followers']?.toString() ?? '0'} Followers',
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
                    value: strategy['annualizedROI']?.toString() ?? '0%',
                    valueColor: const Color(0xFF84BD00),
                    showChartIcon: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDataBox(
                    label: 'AUM (USDT)',
                    value: strategy['aum']?.toString() ?? '0',
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
                  child: _buildFeatureBox(strategy['features']?[0]?.toString() ?? 'N/A'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFeatureBox(strategy['features']?[1]?.toString() ?? 'N/A'),
                ),
              ],
            ),
            const SizedBox(height: 24),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Show Invest/Withdraw buttons only for Omega-3X strategy
          if (strategy['name']?.toString() == 'Omega-3X')
            // Buttons outside GestureDetector so they don't trigger performance popup
            Row(
              children: [
                    // Show both buttons if subscribed, otherwise just Invest button
                    if (subscriptionPlan != null) ...[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            debugPrint('=== INVEST BUTTON CLICKED ===');
                            _openInvestScreen(strategy);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF84BD00),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Invest ↗',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            debugPrint('=== WITHDRAW BUTTON CLICKED ===');
                            _openWithdrawScreen(strategy);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF84BD00)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Withdraw ↗',
                            style: TextStyle(
                              color: Color(0xFF84BD00),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ] else
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _openInvestScreen(strategy),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF84BD00),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Invest / Withdraw ↗',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                )
            else if (strategy['isComingSoon'] == true || strategy['available'] == false)
              Container(
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
            else
              const SizedBox.shrink(),
          ],
        ),
      );
  }

  void _openInvestScreen(Map<String, dynamic> strategy) {
    debugPrint('=== INVEST BUTTON CLICKED ===');
    debugPrint('Strategy: ${strategy['name']}');
    debugPrint('Wallet Balance: $walletBalance');
    debugPrint('Subscription Plan: $subscriptionPlan');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BotInvestScreen(
          strategy: strategy,
          walletBalance: walletBalance,
        ),
      ),
    ).then((result) {
      debugPrint('=== INVEST SCREEN CLOSED ===');
      debugPrint('Result: $result');
      // Refresh data when returning from invest screen
      if (result == true) {
        _initializeData();
      }
    });
  }

  void _openWithdrawScreen(Map<String, dynamic> strategy) {
    final strategyKey = strategy['name']?.toString() ?? '';
    final investedAmount = investments[strategyKey] ?? 0.0;
    
    debugPrint('=== WITHDRAW SCREEN DEBUG ===');
    debugPrint('Strategy Key: $strategyKey');
    debugPrint('All Investments: $investments');
    debugPrint('Invested Amount: $investedAmount');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BotWithdrawScreen(
          strategy: strategy,
          investedAmount: investedAmount,
        ),
      ),
    ).then((result) {
      // Refresh data when returning from withdraw screen
      if (result == true) {
        _initializeData();
      }
    });
  }

  void _showStrategyPerformancePopup(Map<String, dynamic> strategy) {
    final strategyKey = strategy['name']?.toString() ?? '';
    final investedAmount = investments[strategyKey] ?? 0.0;
    
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

  Widget _buildActionButton(String label, VoidCallback? onTap) {
    final bool isDisabled = onTap == null;
    final bool isInvest = label.contains('Invest');

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isInvest
              ? (isDisabled ? const Color(0xFF444444) : const Color(0xFF84BD00))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: label.contains('Withdraw')
              ? Border.all(color: Colors.white.withOpacity(0.1))
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isInvest
                  ? (isDisabled ? Colors.white54 : Colors.black)
                  : Colors.white,
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
  final double investedAmount;

  const StrategyPerformancePopup({
    super.key,
    required this.strategy,
    required this.investedAmount,
  });

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
          _buildDetailRow('Strategy Name', strategy['name']?.toString() ?? 'Unknown'),
          _buildDetailRow('Type', strategy['tag']?.toString() ?? 'N/A'),
          _buildDetailRow('Annualized ROI', strategy['annualizedROI']?.toString() ?? '0%', valueColor: const Color(0xFF84BD00)),
          _buildDetailRow('AUM', strategy['aum']?.toString() ?? '0'),
          _buildDetailRow('Followers', strategy['followers']?.toString() ?? '0'),
          if (investedAmount > 0) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              'Your Investment',
              '${investedAmount.toStringAsFixed(2)} USDT',
              valueColor: Colors.orange,
            ),
          ],
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
