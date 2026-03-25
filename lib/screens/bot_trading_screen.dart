import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class BotTradingScreen extends StatefulWidget {
  const BotTradingScreen({super.key});

  @override
  State<BotTradingScreen> createState() => _BotTradingScreenState();
}

class _BotTradingScreenState extends State<BotTradingScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  final List<Map<String, dynamic>> _activeBots = [];
  final List<Map<String, dynamic>> _botHistory = [];
  final List<Map<String, dynamic>> _botStrategies = [];
  double _totalProfit = 0.0;
  double _todayProfit = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchBotData();
  }

  Future<void> _fetchBotData() async {
    setState(() => _isLoading = true);
    
    // Mock data for active bots
    _activeBots.addAll([
      {
        'id': '1',
        'name': 'BTC Scalper',
        'pair': 'BTC/USDT',
        'status': 'active',
        'profit': '+125.50',
        'profitPercent': '+12.5%',
        'runningTime': '2h 35m',
        'strategy': 'Scalping',
      },
      {
        'id': '2', 
        'name': 'ETH Swing',
        'pair': 'ETH/USDT',
        'status': 'active',
        'profit': '+45.20',
        'profitPercent': '+8.2%',
        'runningTime': '1h 15m',
        'strategy': 'Swing Trading',
      },
      {
        'id': '3',
        'name': 'BNB Grid',
        'pair': 'BNB/USDT', 
        'status': 'paused',
        'profit': '-12.30',
        'profitPercent': '-3.1%',
        'runningTime': '45m',
        'strategy': 'Grid Trading',
      },
    ]);

    // Mock data for bot history
    _botHistory.addAll([
      {
        'botName': 'BTC Scalper',
        'pair': 'BTC/USDT',
        'action': 'BUY',
        'amount': '0.025',
        'price': '43250.00',
        'time': '2024-03-20 10:30:00',
        'profit': '+15.20',
        'status': 'completed',
      },
      {
        'botName': 'ETH Swing',
        'pair': 'ETH/USDT',
        'action': 'SELL',
        'amount': '0.5',
        'price': '2180.00',
        'time': '2024-03-20 09:45:00',
        'profit': '+8.50',
        'status': 'completed',
      },
      {
        'botName': 'BNB Grid',
        'pair': 'BNB/USDT',
        'action': 'BUY',
        'amount': '2.5',
        'price': '315.00',
        'time': '2024-03-20 08:20:00',
        'profit': '-5.20',
        'status': 'completed',
      },
    ]);

    // Mock data for bot strategies
    _botStrategies.addAll([
      {
        'name': 'Scalping Bot',
        'description': 'High-frequency trading with small profit margins',
        'minInvestment': '100 USDT',
        'expectedReturn': '5-15% daily',
        'risk': 'Medium',
        'popularity': 4.5,
      },
      {
        'name': 'Grid Trading',
        'description': 'Automated buy/sell at predefined price levels',
        'minInvestment': '500 USDT',
        'expectedReturn': '8-20% monthly',
        'risk': 'Low',
        'popularity': 4.8,
      },
      {
        'name': 'Swing Trading',
        'description': 'Medium-term trend following strategy',
        'minInvestment': '200 USDT',
        'expectedReturn': '10-25% monthly',
        'risk': 'Medium',
        'popularity': 4.2,
      },
    ]);

    _totalProfit = 158.40;
    _todayProfit = 25.60;

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Bot Trading',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF84BD00)),
            onPressed: _showCreateBotDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF84BD00),
          labelColor: const Color(0xFF84BD00),
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Active Bots'),
            Tab(text: 'History'),
            Tab(text: 'Strategies'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildActiveBots(),
                _buildBotHistory(),
                _buildBotStrategies(),
              ],
            ),
    );
  }

  Widget _buildActiveBots() {
    return Column(
      children: [
        // Profit Summary
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Profit',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${_totalProfit.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF84BD00),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white24,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's Profit",
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${_todayProfit.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: _todayProfit >= 0 ? const Color(0xFF84BD00) : Colors.red,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Active Bots List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _activeBots.length,
            itemBuilder: (context, index) {
              final bot = _activeBots[index];
              return _buildBotCard(bot);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBotCard(Map<String, dynamic> bot) {
    final isActive = bot['status'] == 'active';
    final isProfit = (bot['profit'] as String).startsWith('+');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xFF84BD00).withOpacity(0.3) : Colors.white24,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Bot Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          bot['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFF84BD00) : Colors.grey,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            bot['status'].toString().toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bot['pair'],
                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bot['strategy'],
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Profit Info
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    bot['profit'],
                    style: TextStyle(
                      color: isProfit ? const Color(0xFF84BD00) : Colors.red,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bot['profitPercent'],
                    style: TextStyle(
                      color: isProfit ? const Color(0xFF84BD00) : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bot['runningTime'],
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _toggleBotStatus(bot),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isActive ? Colors.orange : const Color(0xFF84BD00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(isActive ? 'Pause' : 'Start'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showBotSettings(bot),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF84BD00)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Settings'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBotHistory() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _botHistory.length,
      itemBuilder: (context, index) {
        final trade = _botHistory[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Trade Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trade['botName'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trade['pair'],
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Action & Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: trade['action'] == 'BUY' ? const Color(0xFF84BD00) : Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          trade['action'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${trade['price']}',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trade['amount'],
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    trade['time'],
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                  const Spacer(),
                  Text(
                    trade['profit'],
                    style: TextStyle(
                      color: (trade['profit'] as String).startsWith('+') 
                          ? const Color(0xFF84BD00) 
                          : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBotStrategies() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _botStrategies.length,
      itemBuilder: (context, index) {
        final strategy = _botStrategies[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strategy['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strategy['description'],
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Rating
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            strategy['popularity'].toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getRiskColor(strategy['risk']),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          strategy['risk'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Strategy Details
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Min Investment: ${strategy['minInvestment']}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Expected Return: ${strategy['expectedReturn']}',
                          style: const TextStyle(color: Color(0xFF84BD00), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _deployStrategy(strategy),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF84BD00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Deploy'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getRiskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'low':
        return const Color(0xFF84BD00);
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showCreateBotDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E20),
        title: const Text(
          'Create New Bot',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Bot creation feature coming soon!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF84BD00)),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleBotStatus(Map<String, dynamic> bot) {
    setState(() {
      bot['status'] = bot['status'] == 'active' ? 'paused' : 'active';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Bot ${bot['name']} ${bot['status'] == 'active' ? 'started' : 'paused'}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF84BD00),
      ),
    );
  }

  void _showBotSettings(Map<String, dynamic> bot) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E20),
        title: Text(
          '${bot['name']} Settings',
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Bot settings feature coming soon!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF84BD00)),
            ),
          ),
        ],
      ),
    );
  }

  void _deployStrategy(Map<String, dynamic> strategy) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Deploying ${strategy['name']} bot...',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF84BD00),
      ),
    );
  }
}
