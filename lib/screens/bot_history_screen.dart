import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/bot_service.dart';
import 'bot_main_screen.dart';

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
  bool _isTabControllerInitialized = false;
  String _selectedHistoryPair = 'BTC-USDT';
  String _selectedSortBy = 'date';
  String _selectedSortOrder = 'desc';
  String _selectedPnlFilter = 'all';
  bool _isLoading = false;
  List<BotTrade> _trades = [];
  List<Transaction> _transactions = [];
  List<String> _availablePairs = [];
  String? _errorMessage;
  double _userInvestment = 0.0;
  DateTime? _startDate;
  DateTime? _endDate;
  
  // Referral Earnings data
  Map<String, dynamic> _tradingIncome = {};
  Map<String, dynamic> _subscriptionIncome = {};
  bool _isLoadingIncome = false;
  String? _incomeError;
  
  // Benchmark ROI data
  double _btcRoi = 3.70;
  double _ethRoi = 0.61;
  bool _showComparison = false;

  @override
  void initState() {
    super.initState();
    _initializeTabController();
    _loadTradeHistory();
    _loadTransactions();
    _loadAvailablePairs();
    _loadIncomeData();
  }

  void _initializeTabController() {
    // Initialize the controller if it hasn't been initialized yet
    if (!_isTabControllerInitialized) {
      _tabController = TabController(length: 3, vsync: this);
      _tabController.addListener(_onTabChanged);
      _isTabControllerInitialized = true;
      return;
    }
    
    // Dispose existing controller if it has no listeners
    if (!_tabController.hasListeners) {
      _tabController.dispose();
      _tabController = TabController(length: 3, vsync: this);
    }
    
    // Ensure the controller has the correct length
    if (_tabController.length != 3) {
      _tabController.dispose();
      _tabController = TabController(length: 3, vsync: this);
    }
    
    // Reset index to 0 if it's out of bounds
    if (_tabController.index >= 3 || _tabController.index < 0) {
      _tabController.index = 0;
    }
    
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    
    // Ensure index is within bounds
    if (_tabController.index < 0 || _tabController.index >= 3) {
      return;
    }
    
    // Refresh data when switching tabs
    if (_tabController.index == 0) {
      // Trades tab - refresh trade history
      _loadTradeHistory();
    } else if (_tabController.index == 1) {
      // Transactions tab - refresh transactions
      _loadTransactions();
    } else if (_tabController.index == 2) {
      // Referral Earnings tab - refresh income data
      _loadIncomeData();
    }
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
      // Format dates for API - try YYYY-MM-DD format which is more commonly supported
      final startDateStr = _startDate != null 
          ? '${_startDate!.year.toString().padLeft(4, '0')}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}'
          : null;
      final endDateStr = _endDate != null 
          ? '${_endDate!.year.toString().padLeft(4, '0')}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'
          : null;
      
      debugPrint('Date filter: Start=$startDateStr, End=$endDateStr');
      
      final result = await BotService.getUserBotTrades(
        strategy: strategy,
        symbol: symbol,
        startDate: startDateStr,
        endDate: endDateStr,
      );
      
      if (result['success'] == true) {
        final data = result['data'];
        if (data == null) {
          hasError = true;
          errorMessage = 'No data received from server';
        } else {
          try {
            final List<dynamic> tradesList = data is List
                ? data
                : (data['userTrades'] ?? data['trades'] ?? []);
            // Get strategy from parent data object
            final parentStrategy = data['strategy']?.toString();
            
            // Safely parse trades with error handling
            for (var tradeData in tradesList) {
              try {
                final trade = BotTrade.fromJson(tradeData, strategy: parentStrategy);
                allTrades.add(trade);
              } catch (e) {
                debugPrint('Error parsing trade: $e');
                debugPrint('Trade data: $tradeData');
                // Skip invalid trade but continue processing others
                continue;
              }
            }
          } catch (e) {
            debugPrint('Error processing trades data: $e');
            hasError = true;
            errorMessage = 'Failed to process trade data';
          }
        }
      } else if (result['error']?.toString().toLowerCase().contains('no investment') != true &&
                 result['error']?.toString().toLowerCase().contains('no trades') != true) {
        hasError = true;
        errorMessage = result['error'];
      }
      
      // Apply date filter (client-side filtering as fallback)
      if (_startDate != null || _endDate != null) {
        debugPrint('Applying client-side date filter. Total trades before filter: ${allTrades.length}');
        allTrades = allTrades.where((trade) {
          final tradeDate = trade.date;
          
          // Normalize dates to start of day for comparison
          final tradeDateOnly = DateTime(tradeDate.year, tradeDate.month, tradeDate.day);
          final startDateOnly = _startDate != null ? DateTime(_startDate!.year, _startDate!.month, _startDate!.day) : null;
          final endDateOnly = _endDate != null ? DateTime(_endDate!.year, _endDate!.month, _endDate!.day) : null;
          
          bool passesFilter = true;
          if (startDateOnly != null && tradeDateOnly.isBefore(startDateOnly)) {
            passesFilter = false;
          }
          if (endDateOnly != null && tradeDateOnly.isAfter(endDateOnly)) {
            passesFilter = false;
          }
          
          if (!passesFilter) {
            debugPrint('Filtered out trade: ${trade.pair} on ${tradeDateOnly} (Filter: $startDateOnly to $endDateOnly)');
          }
          
          return passesFilter;
        }).toList();
        debugPrint('Total trades after client-side filter: ${allTrades.length}');
      }

      // Apply PnL filter
      if (_selectedPnlFilter != 'all') {
        allTrades = allTrades.where((trade) {
          if (_selectedPnlFilter == 'profit') {
            return trade.userPnl > 0;
          } else if (_selectedPnlFilter == 'loss') {
            return trade.userPnl < 0;
          }
          return true;
        }).toList();
      }

      // Apply sorting
      allTrades.sort((a, b) {
        int comparison = 0;
        switch (_selectedSortBy) {
          case 'date':
            comparison = a.date.compareTo(b.date);
            break;
          case 'pnl':
            comparison = a.userPnl.compareTo(b.userPnl);
            break;
          case 'pair':
            comparison = a.pair.compareTo(b.pair);
            break;
        }
        return _selectedSortOrder == 'desc' ? -comparison : comparison;
      });

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
            
            // Extract investment if available
            if (result['data'] is Map && result['data']['userInvestment'] != null) {
              _userInvestment = double.tryParse(result['data']['userInvestment'].toString()) ?? 0.0;
            }
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
          List<Transaction> parsedTransactions = [];
          
          // Safely parse transactions with error handling
          for (var transactionData in transactionsList) {
            try {
              final transaction = Transaction.fromJson(transactionData);
              parsedTransactions.add(transaction);
            } catch (e) {
              debugPrint('Error parsing transaction: $e');
              debugPrint('Transaction data: $transactionData');
              // Skip invalid transaction but continue processing others
              continue;
            }
          }
          
          setState(() {
            _transactions = parsedTransactions;
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

  Future<void> _loadIncomeData() async {
    if (mounted) {
      setState(() {
        _isLoadingIncome = true;
        _incomeError = null;
      });
    }

    try {
      final result = await BotService.getUserIncome();

      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _tradingIncome = result['tradingIncome'] ?? {};
            _subscriptionIncome = result['subscriptionIncome'] ?? {};
            _isLoadingIncome = false;
          });
        } else {
          setState(() {
            _incomeError = result['error'] ?? 'Failed to load income data';
            _isLoadingIncome = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _incomeError = 'Error loading income data: $e';
          _isLoadingIncome = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool displayHeader = widget.showHeader;
    
    // Ensure TabController is valid
    if (!_isTabControllerInitialized || !_tabController.hasListeners || _tabController.length != 3) {
      // Reinitialize if needed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeTabController();
        setState(() {});
      });
      // Return a loading indicator while reinitializing
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF84BD00)),
        ),
      );
    }
    
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
          const SizedBox(height: 8),
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
                Tab(text: 'Referral Earnings'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTradesContent(),
                _buildTransactionsContent(),
                _buildReferralEarningsContent(),
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
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeCard(BotTrade trade) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
                trade.formattedRawTime,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildHistoryMetric('Entry Price:', trade.formattedOpenPrice),
          _buildHistoryMetric('Exit Price:', trade.formattedClosePrice),
          _buildHistoryMetric(
            'Your PnL:',
            '${trade.isProfit ? '+' : ''}${trade.userPnl.toStringAsFixed(2)} USDT',
            valueColor: trade.isProfit ? Colors.green : Colors.red,
          ),
          _buildHistoryMetric(
            'Total PnL:',
            '${trade.totalPnl >= 0 ? '+' : ''}${trade.totalPnl.toStringAsFixed(2)} USDT',
            valueColor: trade.totalPnl >= 0 ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _viewTradeDetails(trade),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA1CD3B),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'View',
                style: TextStyle(
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
            width: 80,
            height: 80,
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
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Investments Found',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start investing in strategies to see your trade history',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 16,
            ),
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
                    child: const Text('Clear All'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C1C1E),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF84BD00)),
                    ),
                    child: const Text('Close'),
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
    // Calculate initial date for the picker
    DateTime initialDate;
    if (isStartDate) {
      initialDate = _startDate ?? DateTime.now();
    } else {
      // For end date, if start date is selected, default to start date or later
      if (_startDate != null) {
        initialDate = _endDate ?? (_startDate!.isAfter(DateTime.now()) ? _startDate! : DateTime.now());
      } else {
        initialDate = _endDate ?? DateTime.now();
      }
    }
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: isStartDate ? DateTime(2020) : (_startDate ?? DateTime(2020)),
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
          // If end date is before new start date, clear it
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
      // Automatically apply the filter when date is selected
      _loadTradeHistory();
    }
  }

  void _showPnlFilterOptions() {
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
              'Filter by PnL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildPnlFilterOption('All', 'all'),
            _buildPnlFilterOption('Profitable Only', 'profit'),
            _buildPnlFilterOption('Losses Only', 'loss'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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

  Widget _buildPnlFilterOption(String title, String value) {
    final isSelected = _selectedPnlFilter == value;
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        setState(() {
          _selectedPnlFilter = value;
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
              const Icon(
                Icons.check,
                color: Color(0xFF84BD00),
                size: 20,
              ),
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
    // Extract shares from distribution
    double yourShare = 0.0;
    double adminShare = 0.0;
    double uplineShare = 0.0;

    if (trade.distribution != null) {
      for (var item in trade.distribution!) {
        final type = item['type']?.toString() ?? '';
        final share = double.tryParse(item['share']?.toString() ?? '0') ?? 0.0;

        switch (type.toLowerCase()) {
          case 'user':
            yourShare = share;
            break;
          case 'admin':
            adminShare = share;
            break;
          case 'upline':
            uplineShare = share;
            break;
        }
      }
    }

    // Show bottom sheet with distribution details
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Distribution Details',
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
            const SizedBox(height: 24),
            _buildDistributionRow('Your Share', yourShare),
            const SizedBox(height: 16),
            _buildDistributionRow('Admin Share', adminShare),
            const SizedBox(height: 16),
            _buildDistributionRow('Upline Share', uplineShare),
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: Colors.white.withOpacity(0.1),
            ),
            const SizedBox(height: 16),
            _buildDistributionRow('Total', yourShare + adminShare + uplineShare),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionRow(String label, double value) {
    final isPositive = value >= 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 16,
          ),
        ),
        Text(
          '${isPositive ? '+' : ''}${value.toStringAsFixed(4)} USDT',
          style: TextStyle(
            color: isPositive ? const Color(0xFFA1CD3B) : Colors.red,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTradesContent() {
    // Fallback to prevent white screen
    if (!_isLoading && _errorMessage == null && _trades.isEmpty && _availablePairs.isEmpty) {
      return _buildEmptyWidget();
    }
    
    return _isLoading 
      ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
      : _errorMessage != null
        ? _buildErrorWidget()
        : RefreshIndicator(
            onRefresh: _loadTradeHistory,
            color: const Color(0xFF84BD00),
            backgroundColor: const Color(0xFF1C1C1E),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                // Headers Section
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Pair selector
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1C1C1E),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _availablePairs?.length ?? 0,
                                  physics: const BouncingScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    if (_availablePairs == null || _availablePairs!.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    final pair = _availablePairs![index];
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
                      const SizedBox(height: 8),
                      // Filter buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _buildFilterButton(
                              icon: Icons.date_range,
                              label: 'Date',
                              isActive: _startDate != null || _endDate != null,
                              onTap: _showDateFilterOptions,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterButton(
                              icon: Icons.trending_up,
                              label: 'PnL',
                              isActive: _selectedPnlFilter != 'all',
                              onTap: _showPnlFilterOptions,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterButton(
                              icon: Icons.sort,
                              label: 'Sort',
                              isActive: false,
                              onTap: _showSortOptions,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterButton(
                              icon: Icons.download,
                              label: 'Export',
                              isActive: false,
                              onTap: _exportTradeLogs,
                              isExpanded: false,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Comparison Toggle
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildBtcEthComparisonSection(),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                
                // Trades List Section
                _trades.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyWidget(),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final trade = _trades[index];
                            return _buildTradeCard(trade);
                          },
                          childCount: _trades.length,
                        ),
                      ),
                    ),
              ],
            ),
          );
  }

  Widget _buildFilterButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    bool isExpanded = true,
  }) {
    Widget button = GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isActive 
              ? const Color(0xFF84BD00).withOpacity(0.2) 
              : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive 
                ? const Color(0xFF84BD00) 
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive 
                  ? const Color(0xFF84BD00) 
                  : Colors.white.withOpacity(0.7),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive 
                    ? const Color(0xFF84BD00) 
                    : Colors.white.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );

    return isExpanded ? Expanded(child: button) : button;
  }

  Widget _buildTransactionsContent() {
    // Fallback to prevent white screen
    if (!_isLoading && _errorMessage == null && _transactions.isEmpty) {
      return _buildEmptyTransactionsWidget();
    }
    
    return _isLoading 
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

  Widget _buildReferralEarningsContent() {
    if (_isLoadingIncome) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)));
    }

    if (_incomeError != null) {
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
              _incomeError!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadIncomeData,
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trading Income Section
          _buildIncomeSection(
            'Trading Income',
            _tradingIncome,
            Icons.trending_up,
            const Color(0xFF00C851),
            isTrading: true,
          ),
          const SizedBox(height: 24),
          // Subscription Income Section
          _buildIncomeSection(
            'Referral Subscription Income',
            _subscriptionIncome,
            Icons.people,
            const Color(0xFF84BD00),
            isTrading: false,
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeSection(
    String title,
    Map<String, dynamic> incomeData,
    IconData icon,
    Color color, {
    required bool isTrading,
  }) {
    final total = incomeData['total'] ?? 0.0;
    final transactions = incomeData['transactions'] as List? ?? [];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
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
                      const SizedBox(height: 4),
                      Text(
                        'Total: \$${total.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Transactions List
          if (transactions.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    isTrading ? Icons.trending_flat : Icons.person_off,
                    color: Colors.white.withOpacity(0.3),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isTrading ? 'No trading income yet' : 'No referral income yet',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.length,
              padding: const EdgeInsets.all(16),
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final transaction = transactions[index];
                return _buildIncomeTransactionCard(transaction, isTrading);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildIncomeTransactionCard(Map<String, dynamic> transaction, bool isTrading) {
    final amount = transaction['amount'] ?? 0.0;
    final createdAt = transaction['createdAt'] ?? '';
    DateTime? date;
    try {
      date = DateTime.parse(createdAt);
    } catch (e) {
      date = null;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isTrading ? 'Trading Profit' : 'Referral Commission',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '+\$${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF00C851),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (date != null)
            Text(
              DateFormat('dd MMM yyyy, hh:mm a').format(date),
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          if (!isTrading && transaction['name'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'From: ${transaction['name']}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
          if (!isTrading && transaction['email'] != null) ...[
            const SizedBox(height: 2),
            Text(
              transaction['email'],
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
          ],
          if (!isTrading && transaction['level'] != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF84BD00).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Level ${transaction['level']}',
                style: const TextStyle(
                  color: Color(0xFF84BD00),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Benchmark Comparison Methods ---

  Widget _buildBtcEthComparisonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle Button
        GestureDetector(
          onTap: () {
            setState(() {
              _showComparison = !_showComparison;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showComparison ? const Color(0xFF84BD00).withOpacity(0.3) : Colors.white.withOpacity(0.05),
              ),
              boxShadow: _showComparison ? [
                BoxShadow(
                  color: const Color(0xFF84BD00).withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ] : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _showComparison ? const Color(0xFF84BD00).withOpacity(0.1) : Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.compare_arrows,
                        color: _showComparison ? const Color(0xFF84BD00) : Colors.white.withOpacity(0.6),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Comparison with BTC/ETH',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _showComparison ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.white.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
        
        // Expandable Comparison Card with Animation
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Performance vs Benchmarks',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF84BD00).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'This Week',
                            style: TextStyle(
                              color: Color(0xFF84BD00),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildBenchmarkComparison(),
                  ],
                ),
              ),
            ],
          ),
          crossFadeState: _showComparison ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
      ],
    );
  }

  Widget _buildBenchmarkComparison() {
    return GestureDetector(
      onTap: _showBenchmarkComparisonDialog,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E).withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
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
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF84BD00),
                  size: 16,
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
    // Calculate Bot ROI from trades if possible, or use a realistic value
    double totalUserPnl = 0;
    for (var trade in _trades) {
      totalUserPnl += trade.userPnl;
    }
    
    // Fallback ROI if no trades or investment is zero
    double botRoi = 0.60;
    if (_userInvestment > 0) {
      botRoi = (totalUserPnl / _userInvestment) * 100;
    } else if (_trades.isNotEmpty) {
      // If we have trades but investment is not explicitly set in the response,
      // maybe we can estimate or use a default. For now, use 0.60 as per dashboard.
      botRoi = 0.60;
    }
    
    final botVsBtc = botRoi - _btcRoi;
    final botVsEth = botRoi - _ethRoi;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildComparisonRow('Omega-3X Bot ROI', '${botRoi.toStringAsFixed(2)}%', const Color(0xFF84BD00)),
        const SizedBox(height: 8),
        _buildComparisonRow('BTC ROI', '${_btcRoi.toStringAsFixed(2)}%', const Color(0xFF84BD00)),
        const SizedBox(height: 8),
        _buildComparisonRow('ETH ROI', '${_ethRoi.toStringAsFixed(2)}%', const Color(0xFF84BD00)),
        const SizedBox(height: 12),
        Container(
          height: 1,
          color: Colors.white.withOpacity(0.05),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              botVsBtc >= 0 && botVsEth >= 0 ? Icons.check_circle : Icons.info,
              color: botVsBtc >= 0 && botVsEth >= 0 ? const Color(0xFF84BD00) : const Color(0xFFFF9500),
              size: 14,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                botVsBtc >= 0 
                  ? 'Bot outperformed BTC by ${botVsBtc.toStringAsFixed(2)}%'
                  : 'Bot trailing BTC by ${botVsBtc.abs().toStringAsFixed(2)}%',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildComparisonRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showBenchmarkComparisonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Benchmark Comparison (This Week)',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This comparison shows how your bot performance stacks up against simple buy-and-hold strategies for BTC and ETH over the current week.',
              style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
            ),
            const SizedBox(height: 20),
            _buildComparisonSummary(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF84BD00))),
          ),
        ],
      ),
    );
  }

  void _exportTradeLogs() {
    if (_trades.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No trades to export'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
              'Export Trade Logs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Choose export format:',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _exportToCSV();
                    },
                    icon: const Icon(Icons.table_chart, size: 20),
                    label: const Text('CSV'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF84BD00),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _exportToJSON();
                    },
                    icon: const Icon(Icons.code, size: 20),
                    label: const Text('JSON'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C1C1E),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF84BD00)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _exportToCSV() async {
    try {
      final csvData = _generateCSVData();
      final fileName = 'trade_logs_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      
      await _saveAndShareFile(csvData, fileName, 'text/csv');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trade logs exported successfully!'),
          backgroundColor: Color(0xFF84BD00),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _exportToJSON() async {
    try {
      final jsonData = _generateJSONData();
      final fileName = 'trade_logs_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
      
      await _saveAndShareFile(jsonData, fileName, 'application/json');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trade logs exported successfully!'),
          backgroundColor: Color(0xFF84BD00),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _generateCSVData() {
    final buffer = StringBuffer();
    
    // CSV Header
    buffer.writeln('Date,Pair,Bot Name,Status,Entry Price,Exit Price,Your PnL,Total PnL,Strategy');
    
    // CSV Data
    for (final trade in _trades) {
      buffer.writeln(
        '${trade.formattedRawTime},'
        '${trade.pair},'
        '${trade.botName},'
        '${trade.status},'
        '${trade.formattedOpenPrice},'
        '${trade.formattedClosePrice},'
        '${trade.userPnl.toStringAsFixed(2)},'
        '${trade.totalPnl.toStringAsFixed(2)},'
        '${trade.strategy}'
      );
    }
    
    return buffer.toString();
  }

  String _generateJSONData() {
    final tradesData = _trades.map((trade) => {
      'date': trade.date.toIso8601String(),
      'formattedDate': trade.formattedRawTime,
      'pair': trade.pair,
      'botName': trade.botName,
      'status': trade.status,
      'openPrice': trade.openPrice,
      'closePrice': trade.closePrice,
      'formattedOpenPrice': trade.formattedOpenPrice,
      'formattedClosePrice': trade.formattedClosePrice,
      'userPnl': trade.userPnl,
      'totalPnl': trade.totalPnl,
      'isProfit': trade.isProfit,
      'strategy': trade.strategy,
      'distribution': trade.distribution,
    }).toList();

    final exportData = {
      'exportDate': DateTime.now().toIso8601String(),
      'totalTrades': _trades.length,
      'selectedPair': _selectedHistoryPair,
      'filters': {
        'pnlFilter': _selectedPnlFilter,
        'sortBy': _selectedSortBy,
        'sortOrder': _selectedSortOrder,
        'startDate': _startDate?.toIso8601String(),
        'endDate': _endDate?.toIso8601String(),
      },
      'trades': tradesData,
    };

    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  Future<void> _saveAndShareFile(String content, String fileName, String mimeType) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content);
      
      // Use share_plus to allow user to save or share the file
      // Adding the name parameter helps the system identify the file type correctly
      final XFile xFile = XFile(file.path, name: fileName, mimeType: mimeType);
      
      debugPrint('Sharing file: ${file.path} as $fileName');
      await Share.shareXFiles([xFile], text: 'Creddx Bot Trade Logs: $fileName');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File ready: $fileName. Use the menu to Save or Send.'),
          backgroundColor: const Color(0xFF84BD00),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Error exporting file: $e');
      // Fallback to clipboard if sharing fails
      await Clipboard.setData(ClipboardData(text: content));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export error: $e. Data copied to clipboard instead.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

}
