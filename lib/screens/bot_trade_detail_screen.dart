import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/bot_service.dart';
import '../services/unified_wallet_service.dart';
import 'package_program_screen.dart';
import 'bot_invest_screen.dart';
import 'bot_withdraw_screen.dart';
import 'bot_subscription_screen.dart';

class BotTradeDetailScreen extends StatefulWidget {
  static bool hasPackage = false;
  final String name;
  final String multiplier;
  final bool isAvailable;

  const BotTradeDetailScreen({
    super.key,
    required this.name,
    required this.multiplier,
    this.isAvailable = true,
  });

  @override
  State<BotTradeDetailScreen> createState() => _BotTradeDetailScreenState();
}

class _BotTradeDetailScreenState extends State<BotTradeDetailScreen> {
  final TextEditingController _investController = TextEditingController();
  final TextEditingController _withdrawController = TextEditingController();

  bool _isLoading = true;
  bool _hasPackage = false;
  bool _isInvested = false;
  double _investedAmount = 0.0;
  Map<String, dynamic>? _performanceData;
  
  // New State Variables based on User Data flow
  double _walletBalance = 0.0;
  String? _subscriptionPlan;
  Map<String, double> _investments = {};
  bool _btnDisable = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUserData(); // Main flow for balance, subscription and investments
    _fetchPerformanceData();
    _fetchUserBalanceHistory();
  }

  Future<void> _fetchUserData() async {
    if (!mounted) return;
    
    debugPrint('=== FETCHING USER DATA FLOW ===');
    // 1. On Page Load - Reset state
    setState(() {
      _btnDisable = true;
      _isLoading = true;
    });

    try {
      // 2. Call API
      final res = await BotService.getUserData();
      debugPrint('User Data Response: $res');

      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        
        // 3. Set Wallet Balance
        final balance = double.tryParse(data['balance']?.toString() ?? '0') ?? 0.0;
        
        // 4. Check Subscription
        String? plan;
        final subscription = data['subscription'];
        
        debugPrint('Subscription Data: $subscription');
        
        if (subscription != null && subscription is Map) {
          // Check if subscription has plan field
          final planValue = subscription['plan']?.toString();
          
          if (planValue != null && planValue.isNotEmpty && planValue.toLowerCase() != 'null') {
            // Check end date if available
            final endDateStr = subscription['endDate']?.toString();
            
            if (endDateStr != null && endDateStr.isNotEmpty && endDateStr.toLowerCase() != 'null') {
              try {
                final endDate = DateTime.parse(endDateStr);
                final currentDate = DateTime.now();
                final remainingDays = endDate.difference(currentDate).inDays;

                debugPrint('Subscription End Date: $endDate, Remaining Days: $remainingDays');

                if (remainingDays > 0) {
                  plan = planValue;
                  debugPrint('Valid subscription found: $plan');
                } else {
                  debugPrint('Subscription expired');
                }
              } catch (e) {
                debugPrint('Error parsing end date: $e');
                // If date parsing fails but plan exists, consider it valid
                plan = planValue;
                debugPrint('Using plan without date validation: $plan');
              }
            } else {
              // No end date but plan exists - consider it valid
              plan = planValue;
              debugPrint('Using plan without end date: $plan');
            }
          } else {
            debugPrint('No valid plan found in subscription');
          }
        } else {
          debugPrint('No subscription data found');
        }

        // 5. Set Investments (Strategy-wise) - Use correct keys matching widget.name format
        final strategyKey = '${widget.name}-${widget.multiplier}X';
        final inv = {
          "Alpha-2X": double.tryParse(data['maxWithdrawAplha']?.toString() ?? '0') ?? 0.0,
          "Omega-3X": double.tryParse(data['maxWithdrawOmega']?.toString() ?? '0') ?? 0.0,
        };

        if (!mounted) return;
        setState(() {
          _walletBalance = balance;
          _subscriptionPlan = plan;
          _investments = inv;
          _hasPackage = plan != null;

          // Current strategy investment - show max withdrawable amount (what user can withdraw)
          _investedAmount = inv[strategyKey] ?? 0.0;
          _isInvested = _investedAmount > 0;
          
          _errorMessage = null;
          _isLoading = false;
          _btnDisable = false;
        });
        debugPrint('Final State: Balance=$_walletBalance, Plan=$_subscriptionPlan, Invested=$_investedAmount');
      } else {
        // 8. Error Handling
        if (!mounted) return;
        setState(() {
          _errorMessage = "Failed to fetch user info.";
          _isLoading = false;
          _btnDisable = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = "Failed to fetch user info.";
        _isLoading = false;
        _btnDisable = false;
      });
    }
  }

  // Helper to check Invest Button Conditions
  bool _canInvest() {
    // 7. Invest Button Conditions
    if (_isLoading) return false; // Disable only during loading
    if (!widget.isAvailable) return false;
    // Allow button if no subscription (to navigate to subscribe) OR if has valid subscription
    return true;
  }

  Future<void> _fetchPerformanceData() async {
    setState(() => _isLoading = true);
    try {
      final response = await BotService.getStrategyPerformance(widget.name);
      if (mounted) {
        setState(() {
          if (response['success']) {
            _performanceData = response['data'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchUserBalanceHistory() async {
    try {
      final response = await BotService.getBotBalance();
      if (mounted && response['success'] == true) {
        final data = response['data'] ?? {};

        // Parse all balance fields for Invest/Withdraw screen
        final totalBalance = double.tryParse(data['totalBalance']?.toString() ?? '0') ?? 0.0;
        final availableBalance = double.tryParse(data['availableBalance']?.toString() ?? '0') ?? 0.0;
        final investedBalance = double.tryParse(data['investedBalance']?.toString() ?? '0') ?? 0.0;

        // Use exact strategy name mapping to check investment
        String mappedStrategyKey = 'Omega';
        if (widget.name.toLowerCase().contains('omega')) {
          mappedStrategyKey = 'Omega';
        } else if (widget.name.toLowerCase().contains('alpha')) {
          mappedStrategyKey = 'Alpha';
        } else if (widget.name.toLowerCase().contains('ranger')) {
          mappedStrategyKey = 'Ranger';
        } else if (widget.name.toLowerCase().contains('delta')) {
          mappedStrategyKey = 'Delta';
        }

        // Note: _investedAmount is already set correctly from _fetchUserData using maxWithdrawOmega/maxWithdrawAlpha
        // We only update wallet balance here, not the invested amount
        setState(() {
          _walletBalance = availableBalance;
        });
      }
    } catch (e) {
      debugPrint('Error fetching bot balance: $e');
    }
  }

  @override
  void dispose() {
    _investController.dispose();
    _withdrawController.dispose();
    super.dispose();
  }

  void _showAmountDialog({
    required String title, 
    required String hint, 
    required TextEditingController controller, 
    required bool isConfirmingInvestment
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: Colors.white38),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: InputBorder.none,
                    suffixIcon: TextButton(
                      onPressed: () {
                        setState(() {
                          controller.text = hint.replaceAll('Max: \$', '').replaceAll('Total: \$', '');
                        });
                      },
                      child: const Text(
                        'Max value',
                        style: TextStyle(color: Color(0xFF4A90E2), fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (isConfirmingInvestment) {
                            // Get the investment amount from the controller
                            final amountText = controller.text.trim();
                            final amount = double.tryParse(amountText) ?? 0.0;
                            
                            if (amount > 0) {
                              _makeInvestment(amount);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a valid amount'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          } else {
                            // Logic for withdrawal confirmation
                            final amountText = controller.text.trim();
                            final amount = double.tryParse(amountText) ?? 0.0;
                            
                            if (amount > 0) {
                              _makeWithdrawal(amount);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a valid amount'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF84BD00),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleInvestClick() {
    debugPrint('=== INVEST BUTTON CLICKED (Trade Detail) ===');
    debugPrint('Subscription Plan: $_subscriptionPlan');
    
    if (_subscriptionPlan != null) {
      // User is subscribed - Open invest screen
      debugPrint('User is subscribed - Opening invest screen');
      _openInvestScreen();
    } else {
      // User is not subscribed - Show subscribe dialog
      debugPrint('User not subscribed - Showing subscribe dialog');
      _showSubscribeDialog();
    }
  }

  void _showSubscribeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text(
            'Subscribe to Invest',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'You need an active subscription to invest in bot strategies. Subscribe now to access premium trading features.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BotSubscriptionScreen(),
                  ),
                ).then((_) => _fetchUserData());
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF84BD00)),
              child: const Text('Subscribe', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  void _openInvestScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BotInvestScreen(
          strategy: {
            'name': widget.name,
            'multiplier': widget.multiplier,
            'annualizedROI': _performanceData?['annualizedROI'] ?? '0%',
          },
          walletBalance: _walletBalance,
        ),
      ),
    ).then((result) {
      // Refresh data when returning from invest screen
      if (result == true) {
        _fetchUserData();
      }
    });
  }

  void _openWithdrawScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BotWithdrawScreen(
          strategy: {
            'name': widget.name,
            'multiplier': widget.multiplier,
            'annualizedROI': _performanceData?['annualizedROI'] ?? '0%',
          },
          investedAmount: _investedAmount,
        ),
      ),
    ).then((result) {
      // Refresh data when returning from withdraw screen
      if (result == true) {
        _fetchUserData();
      }
    });
  }

  Future<void> _makeWithdrawal(double amount) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await BotService.withdraw(
        botId: widget.name,
        amount: amount,
        strategy: widget.name,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          setState(() {
            _isInvested = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Withdrawal successful!'),
              backgroundColor: const Color(0xFF84BD00),
              duration: const Duration(seconds: 3),
            ),
          );
          // Refresh balance via UnifiedWalletService
          UnifiedWalletService.refreshBotBalance();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Withdrawal failed'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _makeInvestment(double amount) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await BotService.invest(
        botId: widget.name,
        amount: amount,
        strategy: widget.name,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          setState(() {
            _isInvested = true;
            _investedAmount = amount;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Investment successful!'),
              backgroundColor: const Color(0xFF84BD00),
              duration: const Duration(seconds: 3),
            ),
          );
          // Refresh balance via UnifiedWalletService
          UnifiedWalletService.refreshBotBalance();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Investment failed'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.name}- ${widget.multiplier}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
          : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Algo Overview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _buildOverviewItem('Pair:', _performanceData?['pair'] ?? 'Multiple Alt Pairs'),
                _buildOverviewItem('AUM:', _performanceData?['aum'] ?? '805.99K'),
                _buildOverviewItem('Volume:', _performanceData?['volume'] ?? 'InfinityM'),
                _buildOverviewItem('Drawdown:', _performanceData?['drawdown'] ?? '172.94%'),
                _buildOverviewItem('Recovery:', _performanceData?['recovery'] ?? '137d Max / 73d Avg'),
                _buildOverviewItem('Trades:', _performanceData?['trades']?.toString() ?? '40'),
                _buildOverviewItem('Win Rate:', _performanceData?['winRate'] ?? '95.00%'),
                _buildOverviewItem('Profit Comm:', _performanceData?['profitComm'] ?? '20%'),
                _buildOverviewItem('Max Risk:', _performanceData?['maxRisk'] ?? '47.20%'),
                
                const SizedBox(height: 40),
                
                const Text(
                  'Performance History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildPerformanceRow('Today', _performanceData?['todayRoi'] ?? '+1.24%', Colors.green),
                _buildPerformanceRow('Last 7 Days', _performanceData?['last7DaysRoi'] ?? '+8.45%', Colors.green),
                _buildPerformanceRow('Last 30 Days', _performanceData?['last30DaysRoi'] ?? '+24.12%', Colors.green),
                _buildPerformanceRow('All Time', _performanceData?['rot'] ?? '+922.19%', Colors.green),
                
                const SizedBox(height: 40),

                const Text(
                  'Strategy Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _performanceData?['strategyDescription'] ?? 'This strategy uses multiple indicator confirmations to trade high-volatility altcoin pairs with ${widget.multiplier} leverage. It focuses on momentum breakouts and trend reversals with strict risk management.',
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 40),
                
                if (_isInvested) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Invested:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$_investedAmount USDT',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                Padding(
                  padding: const EdgeInsets.only(bottom: 30.0),
                  child: _isInvested
                    ? Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _canInvest() ? _openInvestScreen : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF84BD00),
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _subscriptionPlan == null ? 'Subscribe First' : 'Invest',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: (_isLoading || _investedAmount <= 0) ? null : _openWithdrawScreen,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF84BD00),
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Withdraw',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _canInvest() ? _handleInvestClick : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF84BD00),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _subscriptionPlan == null ? 'Subscribe to Invest' : 'Invest',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildOverviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 15,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 15,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
