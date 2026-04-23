import 'package:flutter/material.dart';
import '../services/bot_service.dart';

class BotHistoryScreen extends StatefulWidget {
  final bool showHeader;
  
  const BotHistoryScreen({
    super.key, 
    this.showHeader = false,
  });

  @override
  State<BotHistoryScreen> createState() => _BotHistoryScreenState();
}

class _BotHistoryScreenState extends State<BotHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedHistoryPair = 'BTC-USDT';
  String _selectedSortBy = 'date';
  String _selectedSortOrder = 'desc';
  bool _isLoading = false;
  List<BotTrade> _trades = [];
  List<Transaction> _transactions = [];
  List<String> _availablePairs = [];
  String? _errorMessage;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTradeHistory();
    _loadTransactions();
    _loadAvailablePairs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailablePairs() async {
    final pairs = await BotService.getAvailablePairs();
    if (mounted) {
      setState(() {
        _availablePairs = pairs;
        if (!_availablePairs.contains(_selectedHistoryPair)) {
          _selectedHistoryPair = pairs.isNotEmpty ? pairs.first : 'BTC-USDT';
        }
      });
    }
  }

  Future<void> _loadTradeHistory() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Extract strategy and symbol from selected pair
      String? strategy;
      String? symbol;
      
      // Define all pair mappings - using Omega-3X for all as requested
      final pairMappings = {
        'BTC-USDT': {'strategy': 'Omega-3X', 'symbol': 'BTC-USDT'},
        'ETH-USDT': {'strategy': 'Omega-3X', 'symbol': 'ETH-USDT'},
        'SOL-USDT': {'strategy': 'Omega-3X', 'symbol': 'SOL-USDT'},
      };
      
      // Map pairs to their strategies and symbols
      final mapping = pairMappings[_selectedHistoryPair];
      if (mapping != null) {
        strategy = mapping['strategy'];
        symbol = mapping['symbol'];
      } else {
        strategy = 'Omega-3X';
        symbol = 'BTC-USDT';
      }

      List<BotTrade> allTrades = [];
      bool hasError = false;
      String? errorMessage;

      // Fetch trades for selected pair only
      final result = await BotService.getUserBotTrades(
        strategy: strategy,
        symbol: symbol,
        startDate: _startDate?.toIso8601String(),
        endDate: _endDate?.toIso8601String(),
      );
      
      if (result['success'] == true) {
        final data = result['data'];
        final List<dynamic> tradesList = data is List
            ? data
            : (data['userTrades'] ?? data['trades'] ?? []);
        // Get strategy from parent data object
        final parentStrategy = data['strategy']?.toString();
        allTrades = tradesList.map((trade) => BotTrade.fromJson(trade, strategy: parentStrategy)).toList();
      } else if (result['error']?.toString().toLowerCase().contains('no investment') != true &&
                 result['error']?.toString().toLowerCase().contains('no trades') != true) {
        hasError = true;
        errorMessage = result['error'];
      }
      
      // Update state with results
      if (mounted) {
        if (hasError && allTrades.isEmpty) {
          setState(() {
            _errorMessage = errorMessage ?? 'Failed to load trade history';
            _isLoading = false;
            _trades = [];
          });
        } else {
          setState(() {
            _trades = allTrades;
            _isLoading = false;
            _errorMessage = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading trade history: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTransactions() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final result = await BotService.getUserTransactions();

      if (mounted) {
        if (result['success'] == true) {
          final List<dynamic> transactionsList = result['transactions'] ?? [];
          setState(() {
            _transactions = transactionsList.map((transaction) => Transaction.fromJson(transaction)).toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = result['error'] ?? 'Failed to load transactions';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading transactions: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool displayHeader = widget.showHeader;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: displayHeader ? AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Trade Logs',
          style: TextStyle(
            color: Colors.white, 
            fontSize: 20, 
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ) : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF84BD00),
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.black,
              unselectedLabelColor: Colors.white.withOpacity(0.7),
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
              tabs: const [
                Tab(text: 'Trades'),
                Tab(text: 'Transactions'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTradesContent(),
                _buildTransactionsContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryMetric(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeCard(BotTrade trade) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trade.pair,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (trade.botName.isNotEmpty)
                        Text(
                          trade.botName,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  if (trade.status.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (trade.status.toUpperCase() == 'LONG' || trade.status.toUpperCase() == 'BUY') 
                            ? Colors.green.withOpacity(0.1) 
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        trade.status.toUpperCase(),
                        style: TextStyle(
                          color: (trade.status.toUpperCase() == 'LONG' || trade.status.toUpperCase() == 'BUY') 
                              ? Colors.green 
                              : Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              Text(
                trade.formattedTime,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildHistoryMetric('Entry Price:', trade.formattedOpenPrice),
          _buildHistoryMetric('Exit Price:', trade.formattedClosePrice),
          if (trade.userSimulatedMargin != null && trade.userSimulatedMargin! > 0)
            _buildHistoryMetric('Margin:', '${trade.userSimulatedMargin!.toStringAsFixed(2)} USDT'),
          _buildHistoryMetric(
            'PnL:', 
            '${trade.isProfit ? '+' : ''}${trade.userPnl.toStringAsFixed(2)} USDT',
            valueColor: trade.isProfit ? Colors.green : Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 50,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An error occurred',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadTradeHistory,
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

  Widget _buildEmptyWidget() {
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
              Icons.history,
              color: Color(0xFF8E8E93),
              size: 50,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Investments Found',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Start investing in strategies to see your trade history',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Navigate to algorithm screen
              Navigator.of(context).pushNamed('/bot_algorithm');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF84BD00),
              foregroundColor: Colors.black,
            ),
            child: const Text('Start Investing'),
          ),
        ],
      ),
    );
  }

  void _showDateFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Filter by Date',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(true),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Start Date',
                            style: TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _startDate != null 
                                ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                : 'Select',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(false),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'End Date',
                            style: TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _endDate != null 
                                ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                : 'Select',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                      _loadTradeHistory();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: const Color(0xFF84BD00),
                      side: const BorderSide(color: Color(0xFF84BD00)),
                    ),
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _loadTradeHistory();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF84BD00),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate 
          ? _startDate ?? DateTime.now().subtract(const Duration(days: 30))
          : _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF84BD00),
              surface: Color(0xFF1C1C1E),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1C1C1E),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sort By',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildSortOption('Date', 'date'),
            _buildSortOption('PnL', 'pnl'),
            _buildSortOption('Pair', 'pair'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String title, String value) {
    final isSelected = _selectedSortBy == value;
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        setState(() {
          _selectedSortBy = value;
          if (isSelected) {
            _selectedSortOrder = _selectedSortOrder == 'desc' ? 'asc' : 'desc';
          }
        });
        _loadTradeHistory();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF84BD00).withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF84BD00) : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFF84BD00) : Colors.white,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isSelected)
              Icon(
                _selectedSortOrder == 'desc' ? Icons.arrow_downward : Icons.arrow_upward,
                color: const Color(0xFF84BD00),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _viewTradeDetails(BotTrade trade) {
    // Navigate to trade detail screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing details for ${trade.pair} trade'),
        backgroundColor: const Color(0xFF84BD00),
      ),
    );
    
    // TODO: Navigate to detailed trade screen
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => BotTradeDetailScreen(trade: trade),
    //   ),
    // );
  }

  Widget _buildTradesContent() {
    return Column(
      children: [
        // Pair selector for trades
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _availablePairs?.length ?? 0,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      if (_availablePairs == null || _availablePairs.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final pair = _availablePairs[index];
                      final isSelected = _selectedHistoryPair == pair;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedHistoryPair = pair;
                          });
                          _loadTradeHistory();
                        },
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF2C2C2E) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            pair,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF8E8E93),
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Trades list
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
            : _errorMessage != null
              ? _buildErrorWidget()
              : _trades.isEmpty
                ? _buildEmptyWidget()
                : ListView.builder(
                    itemCount: _trades.length,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final trade = _trades[index];
                      return _buildTradeCard(trade);
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildTransactionsContent() {
    return Expanded(
      child: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
        : _errorMessage != null
          ? _buildErrorWidget()
          : _transactions.isEmpty
            ? _buildEmptyTransactionsWidget()
            : ListView.builder(
                itemCount: _transactions.length,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final transaction = _transactions[index];
                  return _buildTransactionCard(transaction);
                },
              ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: transaction.isCredit ? const Color(0xFF00C851) : const Color(0xFFFF3B30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      transaction.isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.type,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        transaction.formattedDate,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                transaction.formattedAmount,
                style: TextStyle(
                  color: transaction.isCredit ? const Color(0xFF00C851) : const Color(0xFFFF3B30),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (transaction.description != null) ...[
            const SizedBox(height: 12),
            _buildHistoryMetric('Description:', transaction.description!),
          ],
          if (transaction.balance != null) ...[
            const SizedBox(height: 8),
            _buildHistoryMetric('Balance:', '\$${transaction.balance!.toStringAsFixed(2)}'),
          ],
          if (transaction.reference != null) ...[
            const SizedBox(height: 8),
            _buildHistoryMetric('Reference:', transaction.reference!),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyTransactionsWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.receipt_long,
              color: Color(0xFF84BD00),
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Transactions Yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your transaction history will appear here',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

}
