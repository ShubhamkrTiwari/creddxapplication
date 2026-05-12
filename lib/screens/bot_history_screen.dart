import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/bot_service.dart';
import '../services/pagination_service.dart';
import '../widgets/progressive_pagination_widget.dart';

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
  List<Transaction> _transactions = [];
  List<String> _availablePairs = [];
  String? _errorMessage;
  late PaginationService<BotTrade> _tradesPaginationService = PaginationService<BotTrade>(
    fetchData: _fetchTradesFromAPI,
    itemsPerPage: 10, // Reduced for 16KB compliance
    filterFunction: _filterTrades,
    sortFunction: _sortTrades,
  );
  double _userInvestment = 0.0;
  DateTime? _startDate;
  DateTime? _endDate;
  
  // Referral Earnings data
  Map<String, dynamic> _tradingIncome = {};
  Map<String, dynamic> _subscriptionIncome = {};
  bool _isLoadingIncome = false;
  String? _incomeError;
  late PaginationService<Map<String, dynamic>> _tradingPaginationService = PaginationService<Map<String, dynamic>>(
    fetchData: (page, limit) async => {'success': true, 'data': []},
    itemsPerPage: 10,
  );
  late PaginationService<Map<String, dynamic>> _subscriptionPaginationService = PaginationService<Map<String, dynamic>>(
    fetchData: (page, limit) async => {'success': true, 'data': []},
    itemsPerPage: 10,
  );
  
  // Benchmark ROI data
  double _btcRoi = 3.70;
  double _ethRoi = 0.61;
  bool _showComparison = false;
  bool _isLoadingWeeklyBenchmark = false;
  String? _weeklyBenchmarkError;
  double? _weeklyBotRoi;
  double? _weeklyBtcRoi;
  double? _weeklyEthRoi;
  double? _weeklyVsBtc;
  double? _weeklyVsEth;
  bool _isMockWeeklyBenchmark = false;
  List<Map<String, dynamic>> _weeklySnapshots = const [];

  @override
  void initState() {
    super.initState();
    _initializeTabController();
    _startProgressiveLoading();
  }

  void _startProgressiveLoading() {
    // Load UI elements immediately, then data progressively
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load available pairs first (quick and needed for UI)
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) _loadAvailablePairs();
      });
      
      // Load first page of trades quickly to show immediate content
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _loadTradeHistory(initialOnly: true);
      });
      
      // Load transactions after a short delay
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _loadTransactions();
      });
      
      // Load income data last (might be heavier)
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _loadIncomeData();
      });
    });
  }

  void _initializePagination() {
    // Already initialized at declaration
  }

  Future<void> _loadWeeklyBenchmark({bool force = false}) async {
    if (_isLoadingWeeklyBenchmark) return;
    if (!force && (_weeklyBotRoi != null || _weeklyBenchmarkError != null)) return;

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
          _isMockWeeklyBenchmark = data['isMock'] == true;
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

  void _initializeTabController() {
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _isTabControllerInitialized = true;
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
    if (_tabController.index < 0 || _tabController.index >= 2) {
      return;
    }
    
    // Refresh data when switching tabs
    if (_tabController.index == 0) {
      // Transactions tab - refresh transactions
      _loadTransactions();
    } else if (_tabController.index == 1) {
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

  Future<void> _loadTradeHistory({bool initialOnly = false}) async {
    if (initialOnly) {
      // Load only first page quickly
      await _tradesPaginationService.fetchInitialData();
    } else {
      // Full refresh
      await _tradesPaginationService.fetchInitialData();
    }
  }

  Future<void> _loadTransactions() async {
    if (_isLoading) return;
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
    if (_isLoadingIncome) return;
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
          final tradingTrans = (result['tradingIncome']?['transactions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final subTrans = (result['subscriptionIncome']?['transactions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          
          setState(() {
            _tradingIncome = result['tradingIncome'] ?? {};
            _subscriptionIncome = result['subscriptionIncome'] ?? {};
            
            _tradingPaginationService.allItems = tradingTrans;
            _tradingPaginationService.applyFiltersAndSorting();
            
            _subscriptionPaginationService.allItems = subTrans;
            _subscriptionPaginationService.applyFiltersAndSorting();
            
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

  // Pagination helper methods
  Future<Map<String, dynamic>> _fetchTradesFromAPI(int page, int limit) async {
    try {
      // Extract strategy and symbol from selected pair
      String? strategy;
      String? symbol;
      
      final pairMappings = {
        'BTC-USDT': {'strategy': 'Omega-3X', 'symbol': 'BTC-USDT'},
        'ETH-USDT': {'strategy': 'Omega-3X', 'symbol': 'ETH-USDT'},
        'SOL-USDT': {'strategy': 'Omega-3X', 'symbol': 'SOL-USDT'},
      };
      
      final mapping = pairMappings[_selectedHistoryPair];
      if (mapping != null) {
        strategy = mapping['strategy'];
        symbol = mapping['symbol'];
      } else {
        strategy = 'Omega-3X';
        symbol = 'BTC-USDT';
      }

      final result = await BotService.getUserBotTrades(
        strategy: strategy,
        symbol: symbol,
        startDate: _startDate != null 
            ? '${_startDate!.year.toString().padLeft(4, '0')}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}'
            : null,
        endDate: _endDate != null 
            ? '${_endDate!.year.toString().padLeft(4, '0')}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'
            : null,
      );

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        final List<dynamic> tradesList = data is List
            ? data
            : (data['userTrades'] ?? data['trades'] ?? []);
        final parentStrategy = data is Map ? data['strategy']?.toString() : null;
        
        List<BotTrade> parsedTrades = [];
        for (var tradeData in tradesList) {
          try {
            final trade = BotTrade.fromJson(tradeData, strategy: parentStrategy ?? strategy);
            parsedTrades.add(trade);
          } catch (e) {
            debugPrint('Error parsing trade: $e');
            continue;
          }
        }

        return {
          'success': true,
          'data': parsedTrades,
        };
      } else {
        return {
          'success': false,
          'error': result['error'] ?? 'Failed to fetch trades',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error fetching trades: $e',
      };
    }
  }

  bool _filterTrades(BotTrade trade) {
    // Apply date filter
    if (_startDate != null || _endDate != null) {
      final tradeDate = trade.date;
      final tradeDateOnly = DateTime(tradeDate.year, tradeDate.month, tradeDate.day);
      final startDateOnly = _startDate != null ? DateTime(_startDate!.year, _startDate!.month, _startDate!.day) : null;
      final endDateOnly = _endDate != null ? DateTime(_endDate!.year, _endDate!.month, _endDate!.day) : null;
      
      if (startDateOnly != null && tradeDateOnly.isBefore(startDateOnly)) {
        return false;
      }
      if (endDateOnly != null && tradeDateOnly.isAfter(endDateOnly)) {
        return false;
      }
    }

    // Apply PnL filter
    if (_selectedPnlFilter != 'all') {
      if (_selectedPnlFilter == 'profit') {
        return trade.userPnl > 0;
      } else if (_selectedPnlFilter == 'loss') {
        return trade.userPnl < 0;
      }
    }

    return true;
  }

  int _sortTrades(BotTrade a, BotTrade b) {
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
          'Portfolio',
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
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF84BD00),
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.white.withOpacity(0.7),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              tabs: const [
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
              physics: const NeverScrollableScrollPhysics(),
              children: [
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
            '${trade.isProfit ? '+' : ''}${trade.userPnl.toStringAsFixed(4)} USDT',
            valueColor: trade.isProfit ? Colors.green : Colors.red,
          ),
          _buildHistoryMetric(
            'Total PnL:',
            '${trade.totalPnl >= 0 ? '+' : ''}${trade.totalPnl.toStringAsFixed(4)} USDT',
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
            'No Trades Found',
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
    if (!_isLoading && _errorMessage == null && _tradesPaginationService.filteredItems.isEmpty && _availablePairs.isEmpty) {
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
                                    if (_availablePairs == null || 
                                        _availablePairs!.isEmpty || 
                                        index >= _availablePairs!.length) {
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
                _tradesPaginationService.filteredItems.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyWidget(),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverToBoxAdapter(
                        child: ProgressivePaginationWidget<BotTrade>(
                          paginationService: _tradesPaginationService,
                          itemBuilder: (context, index, trade) => _buildTradeCard(trade),
                          initialLoadDelay: 300,
                          itemsPerBatch: 5,
                        ),
                      ),
                    ),
                    // Page Navigation
                    if (_tradesPaginationService.totalPages > 1)
                      SliverToBoxAdapter(
                        child: PageNavigationWidget(
                          paginationService: _tradesPaginationService,
                          onPageChanged: () => setState(() {}),
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
    debugPrint('=== BUILDING TRANSACTIONS CONTENT ===');
    debugPrint('_isLoading: $_isLoading');
    debugPrint('_errorMessage: $_errorMessage');
    debugPrint('_transactions.length: ${_transactions.length}');
    
    // Fallback to prevent white screen
    if (!_isLoading && _errorMessage == null && _transactions.isEmpty) {
      debugPrint('Showing empty transactions widget');
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
                  if (index >= _transactions.length) {
                    return const SizedBox.shrink();
                  }
                  final transaction = _transactions[index];
                  return _buildTransactionCard(transaction);
                },
              );

  }

  Widget _buildTransactionCard(Transaction transaction) {
    final String label = _getTransactionTypeLabel(transaction.type);
    final bool isInvest = label == 'Invest';
    final Color typeColor = isInvest ? const Color(0xFF00C851) : const Color(0xFFFF3B30);
    // Force status to COMPLETED
    const String statusMsg = 'COMPLETED';
    const Color statusColor = Color(0xFF00C851);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: typeColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    isInvest ? Icons.arrow_downward : Icons.arrow_upward,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: typeColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: statusColor.withOpacity(0.3),
                            width: 0.5,
                          ),
                        ),
                        child: const Text(
                          statusMsg,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${transaction.formattedDate} • ${transaction.formattedTime}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                transaction.formattedAmount,
                style: TextStyle(
                  color: typeColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'USDT',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getTransactionTypeLabel(String type) {
    final lowerType = type.toLowerCase().trim();
    switch (lowerType) {
      case '6':
      case 'invest':
      case 'deposit':
      case 'investment':
        return 'Invest';
      case '5':
      case '7':
      case 'withdraw':
      case 'withdrawal':
      case 'debit':
      case 'transfer':
        return 'Withdraw';
      case 'subscription':
      case 'sub':
      case 'plan':
        return 'Subscribe';
      default:
        // Capitalize the first letter if it's text, or return as is
        if (type.isEmpty) return 'Unknown';
        if (RegExp(r'^[0-9]+$').hasMatch(type)) return 'Subscription';
        return type[0].toUpperCase() + type.substring(1);
    }
  }

  String _getStatusMessage(String status) {
    final lowerStatus = status.toLowerCase().trim();
    switch (lowerStatus) {
      case '6':
      case 'completed':
      case 'success':
      case '1':
        return 'Completed';
      case '5':
      case 'pending':
      case 'processing':
      case '0':
        return 'Pending';
      case '7':
      case 'failed':
      case 'error':
      case 'rejected':
      case '2':
        return 'Failed';
      default:
        return status.isEmpty ? 'Pending' : status;
    }
  }

  Color _getStatusColor(String status) {
    if (status.isEmpty) {
      return const Color(0xFFFF9500);
    }
    final lowerStatus = status.toLowerCase().trim();
    if (lowerStatus == '6' || lowerStatus == 'completed' || lowerStatus == 'success' || lowerStatus == '1') {
      return const Color(0xFF00C851);
    } else if (lowerStatus == '5' || lowerStatus == 'pending' || lowerStatus == 'processing' || lowerStatus == '0') {
      return const Color(0xFFFF9500);
    } else if (lowerStatus == '7' || lowerStatus == 'failed' || lowerStatus == 'error' || lowerStatus == 'rejected' || lowerStatus == '2') {
      return const Color(0xFFFF3B30);
    } else {
      return const Color(0xFFFF9500);
    }
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

    final tradingTotal = ((_tradingIncome['total'] ?? 0.0) as num).toDouble();
    final subscriptionTotal = ((_subscriptionIncome['total'] ?? 0.0) as num).toDouble();
    final grandTotal = tradingTotal + subscriptionTotal;

    final tradingTransactions = _tradingPaginationService.currentPageItems;
    final subscriptionTransactions = _subscriptionPaginationService.currentPageItems;

    return RefreshIndicator(
      onRefresh: _loadIncomeData,
      color: const Color(0xFF84BD00),
      backgroundColor: const Color(0xFF1C1C1E),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Grand Total Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF84BD00),
                          Color(0xFF6A9900),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF84BD00).withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Earnings',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '\$${grandTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Trading Income',
                          '\$${tradingTotal.toStringAsFixed(4)}',
                          Icons.trending_up,
                          const Color(0xFF00C851),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard(
                          'Subscription',
                          '\$${subscriptionTotal.toStringAsFixed(4)}',
                          Icons.people,
                          const Color(0xFF84BD00),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          
          // Trading Income Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildIncomeHeaderOnly(
                'Trading Income',
                tradingTotal,
                _tradingPaginationService.allItems.length,
                Icons.trending_up,
                const Color(0xFF00C851),
              ),
            ),
          ),
          
          // Trading Transactions List
          if (_tradingPaginationService.allItems.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildEmptyIncomeContent(true),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              sliver: SliverToBoxAdapter(
                child: ProgressivePaginationWidget<Map<String, dynamic>>(
                  paginationService: _tradingPaginationService,
                  itemBuilder: (context, index, transaction) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildIncomeTransactionCard(transaction, true, const Color(0xFF00C851)),
                  ),
                  initialLoadDelay: 300,
                  itemsPerBatch: 5,
                ),
              ),
            ),

          if (_tradingPaginationService.totalPages > 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: PageNavigationWidget(
                  paginationService: _tradingPaginationService,
                  onPageChanged: () => setState(() {}),
                ),
              ),
            ),
            
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          
          // Subscription Income Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildIncomeHeaderOnly(
                'Referral Subscription Income',
                subscriptionTotal,
                _subscriptionPaginationService.allItems.length,
                Icons.people,
                const Color(0xFF84BD00),
              ),
            ),
          ),
          
          // Subscription Transactions List
          if (_subscriptionPaginationService.allItems.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildEmptyIncomeContent(false),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              sliver: SliverToBoxAdapter(
                child: ProgressivePaginationWidget<Map<String, dynamic>>(
                  paginationService: _subscriptionPaginationService,
                  itemBuilder: (context, index, transaction) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildIncomeTransactionCard(transaction, false, const Color(0xFF84BD00)),
                  ),
                  initialLoadDelay: 300,
                  itemsPerBatch: 5,
                ),
              ),
            ),

          if (_subscriptionPaginationService.totalPages > 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: PageNavigationWidget(
                  paginationService: _subscriptionPaginationService,
                  onPageChanged: () => setState(() {}),
                ),
              ),
            ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }


  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeHeaderOnly(
    String title,
    double total,
    int count,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.02),
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
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
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '\$${total.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$count ${count == 1 ? 'txn' : 'txns'}',
                          style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyIncomeContent(bool isTrading) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isTrading ? Icons.trending_flat : Icons.person_off,
              color: Colors.white.withOpacity(0.2),
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isTrading ? 'No trading income yet' : 'No referral income yet',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildIncomeTransactionCard(Map<String, dynamic> transaction, bool isTrading, Color accentColor) {
    final amount = ((transaction['amount'] ?? 0.0) as num).toDouble();
    final createdAt = transaction['createdAt'] ?? '';
    DateTime? date;
    try {
      date = DateTime.parse(createdAt);
    } catch (e) {
      date = null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isTrading ? Icons.trending_up : Icons.person,
              color: accentColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTrading ? 'Trading Profit' : 'Referral Commission',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                if (date != null)
                  Text(
                    DateFormat('dd MMM, hh:mm a').format(date),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 10,
                    ),
                  ),
                if (transaction['email'] != null || transaction['userEmail'] != null || transaction['name'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    transaction['email'] ?? transaction['userEmail'] ?? transaction['name'] ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (transaction['level'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Level ${transaction['level']}',
                    style: TextStyle(
                      color: accentColor.withOpacity(0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+\$${amount.toStringAsFixed(5)}',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'USDT',
                style: TextStyle(
                  color: accentColor.withOpacity(0.6),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
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
            if (_showComparison) {
              _loadWeeklyBenchmark();
            }
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
    // If we're using mock data, don't show the detailed comparison rows
    if (_isMockWeeklyBenchmark) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'Benchmark will appear once you have more weekly activity.',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
      );
    }

    // Prefer weekly benchmark API values; fallback to local computed ROI.
    double? botRoi = _weeklyBotRoi;
    if (botRoi == null) {
      double totalUserPnl = 0;
      for (var trade in _tradesPaginationService.filteredItems) {
        totalUserPnl += trade.userPnl;
      }

      if (_userInvestment > 0) {
        botRoi = (totalUserPnl / _userInvestment) * 100;
      } else {
        botRoi = 0.60;
      }
    }

    final btcRoi = _weeklyBtcRoi ?? _btcRoi;
    final ethRoi = _weeklyEthRoi ?? _ethRoi;
    final botVsBtc = _weeklyVsBtc ?? (botRoi - btcRoi);
    final botVsEth = _weeklyVsEth ?? (botRoi - ethRoi);
    
    // Check if we're using mock data (has snapshots but came from fallback)
    final bool isUsingMockData = _weeklySnapshots.isNotEmpty && _weeklyBenchmarkError != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isLoadingWeeklyBenchmark)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF84BD00)),
                ),
                const SizedBox(width: 10),
                Text(
                  'Loading benchmark...',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                ),
              ],
            ),
          )
        else if (_weeklyBenchmarkError != null && !isUsingMockData)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _weeklyBenchmarkError!,
              style: TextStyle(
                color: (_weeklyBenchmarkError!.toLowerCase().contains('not enough data'))
                    ? Colors.white.withOpacity(0.5)
                    : const Color(0xFFFF9500),
                fontSize: 12,
              ),
            ),
          ),
        if (_weeklyBenchmarkError != null && !isUsingMockData &&
            _weeklyBenchmarkError!.toLowerCase().contains('not enough data'))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Benchmark will appear once you have more weekly activity.',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
          ),
        if (isUsingMockData)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: const Color(0xFF84BD00),
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Showing simulated weekly performance data',
                    style: TextStyle(color: const Color(0xFF84BD00).withOpacity(0.8), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        _buildComparisonRow('Omega-3X Bot ROI', _fmtPct(botRoi), const Color(0xFF84BD00)),
        const SizedBox(height: 8),
        _buildComparisonRow('BTC ROI', _fmtPct(btcRoi), const Color(0xFF84BD00)),
        const SizedBox(height: 8),
        _buildComparisonRow('ETH ROI', _fmtPct(ethRoi), const Color(0xFF84BD00)),
        const SizedBox(height: 12),
        Container(
          height: 1,
          color: Colors.white.withOpacity(0.05),
        ),
        const SizedBox(height: 12),
        if (_weeklySnapshots.isNotEmpty) ...[
          Text(
            'Weekly balance snapshots',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
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
                  Text(date, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  Text(balance, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.05),
          ),
          const SizedBox(height: 12),
        ],
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
        const SizedBox(height: 6),
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
                botVsEth >= 0
                    ? 'Bot outperformed ETH by ${botVsEth.toStringAsFixed(2)}%'
                    : 'Bot trailing ETH by ${botVsEth.abs().toStringAsFixed(2)}%',
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
    if (_tradesPaginationService.filteredItems.isEmpty) {
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
    for (final trade in _tradesPaginationService.filteredItems) {
      buffer.writeln(
        '${trade.formattedRawTime},'
        '${trade.pair},'
        '${trade.botName},'
        '${trade.status},'
        '${trade.formattedOpenPrice},'
        '${trade.formattedClosePrice},'
        '${trade.userPnl.toStringAsFixed(4)},'
        '${trade.totalPnl.toStringAsFixed(4)},'
        '${trade.strategy}'
      );
    }
    
    return buffer.toString();
  }

  String _generateJSONData() {
    final tradesData = _tradesPaginationService.filteredItems.map((trade) => {
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
      'totalTrades': _tradesPaginationService.filteredItems.length,
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
