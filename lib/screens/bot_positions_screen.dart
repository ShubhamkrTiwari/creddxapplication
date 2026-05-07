import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/bot_service.dart';
import '../widgets/balance_growth_chart.dart';
import '../widgets/trading_view_chart.dart';
import 'dart:math' as math;
import 'bot_trade_detail_screen.dart';
import 'bot_history_screen.dart';
import 'bot_algorithm_screen.dart';
import '../services/user_service.dart';
import 'user_profile_screen.dart';

class BotPositionsScreen extends StatefulWidget {
  const BotPositionsScreen({super.key});

  @override
  State<BotPositionsScreen> createState() => _BotPositionsScreenState();
}

class _BotPositionsScreenState extends State<BotPositionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPair = 'BTC-USDT';
  String _selectedTimeframe = '1h';
  bool _isLoading = false;
  bool _isLoadingTrades = false;
  List<BotPosition> _positions = [];
  List<BotTrade> _trades = [];
  List<BotTrade> _allTrades = []; // Store all trades
  int _currentPage = 1;
  int _tradesPerPage = 5;
  int get _totalPages => (_allTrades.length / _tradesPerPage).ceil();
  String? _errorMessage;
  Map<String, dynamic>? _positionData;
  bool _showBalanceChart = false;
  List<Map<String, dynamic>> _balanceHistory = [];
  bool _isLoadingBalance = false;
  double _totalBotInvestment = 0.0;
  
  // Trade filters
  String _selectedSortBy = 'date';
  String _selectedSortOrder = 'desc';
  String _selectedPnlFilter = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  
  // Benchmark comparison
  bool _showComparison = false;
  bool _isLoadingWeeklyBenchmark = false;
  String? _weeklyBenchmarkError;
  bool _isMockWeeklyBenchmark = false;
  double? _weeklyBotRoi;
  double? _weeklyBtcRoi;
  double? _weeklyEthRoi;
  double? _weeklyVsBtc;
  double? _weeklyVsEth;
  List<Map<String, dynamic>> _weeklySnapshots = const [];

  final List<String> _timeframes = ['1m', '30m', '1h', '3m', '15m', '4h', '1d'];
  final List<String> _availablePairs = ['BTC-USDT', 'ETH-USDT', 'SOL-USDT'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPositions();
    _loadTrades(); // Load trades
  }

  Future<void> _loadPositions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      const String strategy = 'Omega-3X';
      // Only pass symbol if not 'ALL'
      final String? symbol = _selectedPair == 'ALL' ? null : _selectedPair;

      final result = await BotService.getUserBotPositions(
        strategy: strategy,
        symbol: symbol ?? 'BTC-USDT', // Default to BTC-USDT for API call
      );

      if (mounted) {
        debugPrint('=== API RESULT ===');
        debugPrint('Result success: ${result['success']}');
        debugPrint('Result data: ${result['data']}');
        if (result['success'] == true) {
          final data = result['data'];
          if (data != null) {
            final List<dynamic> positionsList = data['adjustedPositions'] ?? [];
            debugPrint('Positions list count: ${positionsList.length}');
            debugPrint('Raw positions: $positionsList');
            
            // CRITICAL: Only parse if list is NOT empty
            List<BotPosition> parsedPositions = [];
            if (positionsList.isNotEmpty) {
              for (var positionData in positionsList) {
                try {
                  final position = BotPosition.fromJson(positionData);
                  parsedPositions.add(position);
                } catch (e) {
                  debugPrint('Error parsing position: $e');
                  debugPrint('Position data: $positionData');
                  continue;
                }
              }
            }
            
            debugPrint('=== PARSED POSITIONS COUNT: ${parsedPositions.length} ===');
            
            // Also fetch total investment from trades endpoint
            final totalInvestment = await BotService.getTotalBotInvestment(
              strategy: strategy,
              symbol: symbol ?? 'BTC-USDT',
            );
            
            setState(() {
              _positions = parsedPositions;
              _positionData = data;
              _totalBotInvestment = totalInvestment;
              _isLoading = false;
              _errorMessage = null;
            });

            // Pre-load balance history
            _loadBalanceHistory();
          } else {
            setState(() {
              _positions = [];
              _errorMessage = 'No data received from server';
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _positions = [];
            _errorMessage = result['error'] ?? 'Failed to load positions';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _positions = [];
          _errorMessage = 'Error loading positions: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadBalanceHistory() async {
    setState(() {
      _isLoadingBalance = true;
    });

    try {
      final strategy = _positionData?['strategy']?.toString() ?? 'Omega-3X';
      final result = await BotService.getBotBalanceHistory(
        strategy: strategy,
        days: 133, // Get 133 days (19 weeks) of data for weekly view
      );

      if (mounted) {
        if (result['success'] == true) {
          // New API returns data array directly
          final List<Map<String, dynamic>> history = 
              List<Map<String, dynamic>>.from(result['data'] ?? result['history'] ?? []);
          debugPrint('BalanceHistory: Successfully fetched ${history.length} data points');
          debugPrint('BalanceHistory: First data point: ${history.isNotEmpty ? history.first : 'None'}');
          debugPrint('BalanceHistory: Last data point: ${history.isNotEmpty ? history.last : 'None'}');
          setState(() {
            _balanceHistory = history;
            _isLoadingBalance = false;
          });
        } else {
          debugPrint('BalanceHistory: API Error - ${result['error']}');
          setState(() {
            _balanceHistory = [];
            _isLoadingBalance = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _balanceHistory = [];
          _isLoadingBalance = false;
        });
      }
    }
  }

  Future<void> _loadTrades() async {
    setState(() {
      _isLoadingTrades = true;
    });
    
    try {
      const String strategy = 'Omega-3X';
      // Only pass symbol if not 'ALL'
      final String? symbol = _selectedPair == 'ALL' ? null : _selectedPair;

      debugPrint('=== LOADING TRADES ===');
      debugPrint('Strategy: $strategy');
      debugPrint('Symbol: ${symbol ?? "ALL"}');

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

      debugPrint('=== TRADES API RESULT ===');
      debugPrint('Success: ${result['success']}');
      debugPrint('Data: ${result['data']}');

      if (mounted) {
        if (result['success'] == true) {
          final data = result['data'];
          if (data != null) {
            final List<dynamic> tradesList = data is List
                ? data
                : (data['userTrades'] ?? data['trades'] ?? []);
            final parentStrategy = data is Map ? data['strategy']?.toString() : null;
            
            debugPrint('=== TRADES LIST ===');
            debugPrint('Trades count: ${tradesList.length}');
            debugPrint('Parent strategy: $parentStrategy');
            if (tradesList.isNotEmpty) {
              debugPrint('First trade: ${tradesList[0]}');
            }
            
            List<BotTrade> parsedTrades = [];
            for (var tradeData in tradesList) {
              try {
                final trade = BotTrade.fromJson(tradeData, strategy: parentStrategy ?? strategy);
                parsedTrades.add(trade);
                debugPrint('Parsed trade: ${trade.pair} - ${trade.userPnl}');
              } catch (e) {
                debugPrint('Error parsing trade: $e');
                debugPrint('Trade data: $tradeData');
                continue;
              }
            }
            
            debugPrint('=== PARSED TRADES COUNT: ${parsedTrades.length} ===');
            
            // Apply PnL filter
            if (_selectedPnlFilter != 'all') {
              parsedTrades = parsedTrades.where((trade) {
                if (_selectedPnlFilter == 'profit') {
                  return trade.userPnl > 0;
                } else if (_selectedPnlFilter == 'loss') {
                  return trade.userPnl < 0;
                }
                return true;
              }).toList();
            }

            // Apply sorting
            parsedTrades.sort((a, b) {
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
            
            setState(() {
              _allTrades = parsedTrades;
              _currentPage = 1; // Reset to first page
              _updateDisplayedTrades();
              _isLoadingTrades = false;
            });
            
            debugPrint('=== FINAL STATE ===');
            debugPrint('All trades: ${_allTrades.length}');
            debugPrint('Displayed trades: ${_trades.length}');
          } else {
            debugPrint('Data is null');
            setState(() {
              _allTrades = [];
              _trades = [];
              _isLoadingTrades = false;
            });
          }
        } else {
          debugPrint('API returned success=false');
          debugPrint('Error: ${result['error']}');
          setState(() {
            _allTrades = [];
            _trades = [];
            _isLoadingTrades = false;
          });
        }
      }
    } catch (e) {
      debugPrint('=== EXCEPTION LOADING TRADES ===');
      debugPrint('Error: $e');
      if (mounted) {
        setState(() {
          _allTrades = [];
          _trades = [];
          _isLoadingTrades = false;
        });
      }
    }
  }

  void _updateDisplayedTrades() {
    final startIndex = (_currentPage - 1) * _tradesPerPage;
    final endIndex = (startIndex + _tradesPerPage).clamp(0, _allTrades.length);
    _trades = _allTrades.sublist(startIndex, endIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Export Methods ---

  void _exportTradeLogs() {
    if (_allTrades.isEmpty) {
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
    } catch (e) {
      if (!mounted) return;
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
    } catch (e) {
      if (!mounted) return;
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
    for (final trade in _allTrades) {
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
    final tradesData = _allTrades.map((trade) => {
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
      'totalTrades': _allTrades.length,
      'selectedPair': _selectedPair,
      'trades': tradesData,
    };

    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  Future<void> _saveAndShareFile(String content, String fileName, String mimeType) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content);
      
      final XFile xFile = XFile(file.path, name: fileName, mimeType: mimeType);
      
      await Share.shareXFiles([xFile], text: 'Creddx Bot Trade Logs: $fileName');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File ready: $fileName. Use the menu to Save or Send.'),
            backgroundColor: const Color(0xFF84BD00),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error exporting file: $e');
      await Clipboard.setData(ClipboardData(text: content));
      
      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          _showBalanceChart ? 'Balance Growth' : 'Open Positions',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: _showBalanceChart
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _showBalanceChart = false;
                  });
                },
              )
            : null,
      ),
      body: SafeArea(
        child: _showBalanceChart
            ? _buildBalanceGrowthView()
            : Column(
                children: [
                  _buildTabs(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPositionsTab(),
                        const BotHistoryScreen(showHeader: false),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
          Tab(text: 'Positions'),
          Tab(text: 'Portfolio'),
        ],
      ),
    );
  }

  Widget _buildPositionsTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildStrategyHeader(),
          _buildTradingChart(),
          _buildPositionDetails(),
          const SizedBox(height: 20),
          // Open Positions Section
          if (_positions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Open Positions',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          if (_positions.isNotEmpty) _buildPositionsList(),
          const SizedBox(height: 20),
          // Realized Trade History Section - Show header even if loading
          if (_isLoadingTrades || _allTrades.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Realized Trade History',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          // Pair Selector - Always show
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: _availablePairs.map((pair) {
                  final isSelected = _selectedPair == pair;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        debugPrint('\n=== PAIR SELECTED: $pair ===\n');
                        if (_selectedPair != pair) {
                          setState(() {
                            _selectedPair = pair;
                          });
                          _loadTrades();
                          if (pair != 'ALL') {
                            _loadPositions();
                          }
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF84BD00) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          pair,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white.withOpacity(0.6),
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Filter buttons - Always show
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
                  isActive: _selectedSortBy != 'date' || _selectedSortOrder != 'desc',
                  onTap: _showSortOptions,
                ),
                const SizedBox(width: 8),
                _buildFilterButton(
                  icon: Icons.download,
                  label: 'Export',
                  isActive: false,
                  onTap: _exportTradeLogs,
                  isExpanded: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // BTC/ETH Comparison - Always show
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildBtcEthComparisonSection(),
          ),
          const SizedBox(height: 12),
          // Show trades list or loading/empty state
          if (_isLoadingTrades)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF84BD00)),
              ),
            )
          else if (_allTrades.isNotEmpty)
            _buildTradesList()
          else if (!_isLoading)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(
                    Icons.history,
                    color: Colors.white.withOpacity(0.3),
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Trade History',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your realized trades will appear here',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          if (_positions.isEmpty && _trades.isEmpty)
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
                : _errorMessage != null
                    ? _buildErrorWidget()
                    : _buildEmptyWidget(),
        ],
      ),
    );
  }

  Widget _buildStrategyHeader() {
    // Use total investment from API (user-trades endpoint)
    final double userInvestment = _totalBotInvestment;
    final strategy = _positionData?['strategy'] ?? 'Omega-3X';

    // Calculate total unrealized PnL only if positions exist
    double totalUnrealizedPnL = 0.0;
    for (var pos in _positions) {
      totalUnrealizedPnL += pos.userUnrealizedProfit;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Strategy: $strategy',
                  style: const TextStyle(
                    color: Color(0xFF84BD00),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showBalanceChart = true;
                  });
                  _loadBalanceHistory();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF84BD00),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Balance', style: TextStyle(fontSize: 9)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Invested',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 9,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '\$${userInvestment.toStringAsFixed(5)}',
                          style: const TextStyle(
                            color: Color(0xFF84BD00),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (_positions.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Unrealized PnL',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 9,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${totalUnrealizedPnL >= 0 ? '+' : ''}\$${totalUnrealizedPnL.toStringAsFixed(5)}',
                            style: TextStyle(
                              color: totalUnrealizedPnL >= 0 ? const Color(0xFF84BD00) : const Color(0xFFFF3B30),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  height: 1,
                  color: Colors.white.withOpacity(0.1),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Open Positions',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 9,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${_positions.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (_positions.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Current Symbol',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 9,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            _positions.first.symbol,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _timeframes.length,
        itemBuilder: (context, index) {
          final timeframe = _timeframes[index];
          final isSelected = _selectedTimeframe == timeframe;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedTimeframe = timeframe;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF84BD00) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? const Color(0xFF84BD00) : Colors.white.withOpacity(0.3),
                ),
              ),
              child: Text(
                timeframe,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTradingChart() {
    // Only show chart if there are open positions
    if (_positions.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final chartSymbol = _positions.first.symbol;
    
    return Container(
      height: 600,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF84BD00).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF84BD00).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chartSymbol.replaceAll('-', '/'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Live Price',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(_positions.isNotEmpty ? _positions.first.markPrice : 0.0).toStringAsFixed(5)}',
                      style: const TextStyle(
                        color: Color(0xFF84BD00),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          _positions.isNotEmpty && _positions.first.userUnrealizedProfit >= 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                          color: _positions.isNotEmpty && _positions.first.userUnrealizedProfit >= 0
                              ? const Color(0xFF84BD00)
                              : const Color(0xFFFF3B30),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _positions.isNotEmpty
                              ? '${(_positions.first.userUnrealizedProfit >= 0 ? '+' : '')}${_positions.first.userUnrealizedProfit.toStringAsFixed(5)}'
                              : '+0.00',
                          style: TextStyle(
                            color: _positions.isNotEmpty && _positions.first.userUnrealizedProfit >= 0
                                ? const Color(0xFF84BD00)
                                : const Color(0xFFFF3B30),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.1),
          ),
          Expanded(
            child: TradingViewChart(
              symbol: chartSymbol.replaceAll('-', ''),
              theme: 'dark',
              interval: _getTradingViewInterval(),
              allowSymbolChange: false,
              hideSideToolbar: false,
            ),
          ),
        ],
      ),
    );
  }

  String _getTradingViewInterval() {
    switch (_selectedTimeframe) {
      case '1m':
        return '1';
      case '30m':
        return '30';
      case '1h':
        return '60';
      case '3m':
        return '3';
      case '15m':
        return '15';
      case '4h':
        return '240';
      case '1d':
        return 'D';
      default:
        return '60';
    }
  }

  Widget _buildPositionDetails() {
    if (_positions.isEmpty) return const SizedBox.shrink();
    
    final position = _positions.first;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${position.symbol} - ${position.positionSide}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Size: ${position.size}',
                style: const TextStyle(color: Color(0xFF8E8E93)),
              ),
              Text(
                'Entry: ${position.avgPrice}',
                style: const TextStyle(color: Color(0xFF8E8E93)),
              ),
              Text(
                'Mark: ${position.markPrice}',
                style: const TextStyle(color: Color(0xFF8E8E93)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPositionsList() {
    return ListView.builder(
      itemCount: _positions.length,
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final position = _positions[index];
        return _buildPositionCard(position);
      },
    );
  }

  Widget _buildPositionCard(BotPosition position) {
    final isProfit = position.userUnrealizedProfit >= 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isProfit ? const Color(0xFF84BD00) : const Color(0xFFFF3B30),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: position.positionSide == 'LONG' 
                          ? const Color(0xFF84BD00).withOpacity(0.2)
                          : const Color(0xFFFF3B30).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      position.positionSide,
                      style: TextStyle(
                        color: position.positionSide == 'LONG' 
                            ? const Color(0xFF84BD00)
                            : const Color(0xFFFF3B30),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    position.symbol,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '${isProfit ? '+' : ''}\$${position.userUnrealizedProfit.toStringAsFixed(5)}',
                style: TextStyle(
                  color: isProfit ? const Color(0xFF84BD00) : const Color(0xFFFF3B30),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetric('Entry', '\$${position.avgPrice.toStringAsFixed(5)}'),
              ),
              Expanded(
                child: _buildMetric('Mark', '\$${position.markPrice.toStringAsFixed(5)}'),
              ),
              Expanded(
                child: _buildMetric('Margin', '\$${position.userMargin.toStringAsFixed(5)}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
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
            onPressed: _loadPositions,
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

  Widget _buildBalanceGrowthView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_isLoadingBalance)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 100),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF84BD00)),
              ),
            )
          else
            BalanceGrowthChart(
              data: _balanceHistory,
              viewType: ChartViewType.daily,
              title: 'Balance Growth',
              lineColor: const Color(0xFF84BD00),
            ),
        ],
      ),
    );
  }

  Widget _buildPerformanceSummary() {
    if (_balanceHistory.isEmpty) return const SizedBox();

    // Sort by timestamp if available to ensure correct order
    final sortedHistory = List<Map<String, dynamic>>.from(_balanceHistory);
    sortedHistory.sort((a, b) {
      final aTime = a['timestamp']?.toString() ?? '';
      final bTime = b['timestamp']?.toString() ?? '';
      if (aTime.isNotEmpty && bTime.isNotEmpty) {
        return DateTime.tryParse(aTime)?.compareTo(DateTime.tryParse(bTime) ?? DateTime.now()) ?? 0;
      }
      return 0;
    });

    final firstBalance = double.tryParse(sortedHistory.first['balance']?.toString() ?? '0') ?? 0.0;
    final lastBalance = double.tryParse(sortedHistory.last['balance']?.toString() ?? '0') ?? 0.0;
    final totalProfit = lastBalance - firstBalance;
    final roi = firstBalance > 0 ? (totalProfit / firstBalance) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem('Starting Balance', '\$${firstBalance.toStringAsFixed(2)}'),
              ),
              Expanded(
                child: _buildSummaryItem('Current Balance', '\$${lastBalance.toStringAsFixed(2)}'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Total Profit', 
                  '${totalProfit >= 0 ? '+' : ''}\$${totalProfit.toStringAsFixed(2)}',
                  totalProfit >= 0 ? const Color(0xFF84BD00) : const Color(0xFFFF3B30),
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'ROI',
                  '${roi >= 0 ? '+' : ''}${roi.toStringAsFixed(2)}%',
                  roi >= 0 ? const Color(0xFF84BD00) : const Color(0xFFFF3B30),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, [Color? valueColor]) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmptyWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.trending_up,
            color: Color(0xFF8E8E93),
            size: 50,
          ),
          SizedBox(height: 16),
          Text(
            'No Open Positions',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You don\'t have any open positions',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradesList() {
    return Column(
      children: [
        ListView.builder(
          itemCount: _trades.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final trade = _trades[index];
            return _buildTradeCard(trade);
          },
        ),
        if (_totalPages > 1) _buildPagination(),
      ],
    );
  }

  Widget _buildPagination() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous button
          IconButton(
            onPressed: _currentPage > 1
                ? () {
                    setState(() {
                      _currentPage--;
                      _updateDisplayedTrades();
                    });
                  }
                : null,
            icon: Icon(
              Icons.chevron_left,
              color: _currentPage > 1
                  ? const Color(0xFF84BD00)
                  : Colors.white.withOpacity(0.3),
            ),
          ),
          const SizedBox(width: 8),
          // Page numbers
          ..._buildPageNumbers(),
          const SizedBox(width: 4),
          // Next button
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _currentPage < _totalPages
                ? () {
                    setState(() {
                      _currentPage++;
                      _updateDisplayedTrades();
                    });
                  }
                : null,
            icon: Icon(
              Icons.chevron_right,
              color: _currentPage < _totalPages
                  ? const Color(0xFF84BD00)
                  : Colors.white.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    List<Widget> pages = [];
    
    // Show max 5 page numbers at a time
    int startPage = (_currentPage - 2).clamp(1, _totalPages);
    int endPage = (startPage + 4).clamp(1, _totalPages);
    
    // Adjust start if we're near the end
    if (endPage - startPage < 4) {
      startPage = (endPage - 4).clamp(1, _totalPages);
    }
    
    for (int i = startPage; i <= endPage; i++) {
      pages.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _currentPage = i;
              _updateDisplayedTrades();
            });
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _currentPage == i
                  ? const Color(0xFF84BD00)
                  : const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _currentPage == i
                    ? const Color(0xFF84BD00)
                    : Colors.white.withOpacity(0.2),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              i.toString(),
              style: TextStyle(
                color: _currentPage == i ? Colors.black : Colors.white,
                fontSize: 14,
                fontWeight: _currentPage == i ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }
    
    return pages;
  }

  Widget _buildTradeCard(BotTrade trade) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
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
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (trade.botName.isNotEmpty)
                        Text(
                          trade.botName,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  if (trade.status.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                          fontSize: 9,
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
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildTradeMetricCompact('Entry', trade.formattedOpenPrice),
              ),
              Expanded(
                child: _buildTradeMetricCompact('Exit', trade.formattedClosePrice),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildTradeMetricCompact(
                  'Your PnL',
                  '${trade.isProfit ? '+' : ''}${trade.userPnl.toStringAsFixed(4)} USDT',
                  valueColor: trade.isProfit ? Colors.green : Colors.red,
                ),
              ),
              Expanded(
                child: _buildTradeMetricCompact(
                  'Total PnL',
                  '${trade.totalPnl >= 0 ? '+' : ''}${trade.totalPnl.toStringAsFixed(4)} USDT',
                  valueColor: trade.totalPnl >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _viewTradeDetails(trade),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'View Details',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeMetricCompact(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
                const Text(
                  'Distribution Details',
                  style: TextStyle(
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
            color: isPositive ? const Color(0xFF84BD00) : Colors.red,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTradeMetric(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
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
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isActive 
              ? const Color(0xFF84BD00).withOpacity(0.2) 
              : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive 
                ? const Color(0xFF84BD00) 
                : Colors.white.withOpacity(0.15),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive 
                  ? const Color(0xFF84BD00) 
                  : Colors.white.withOpacity(0.7),
            ),
            const SizedBox(width: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: isActive 
                      ? const Color(0xFF84BD00) 
                      : Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return isExpanded ? Expanded(child: button) : button;
  }

  void _showDateFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
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
                      onTap: () => _selectDate(true, setDialogState),
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
                      onTap: () => _selectDate(false, setDialogState),
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
                        _loadTrades();
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
      ),
    );
  }

  Future<void> _selectDate(bool isStartDate, [StateSetter? setDialogState]) async {
    DateTime initialDate;
    if (isStartDate) {
      initialDate = _startDate ?? DateTime.now();
    } else {
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
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
      if (setDialogState != null) {
        setDialogState(() {});
      }
      _loadTrades();
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

  Widget _buildPnlFilterOption(String title, String value) {
    final isSelected = _selectedPnlFilter == value;
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        setState(() {
          _selectedPnlFilter = value;
        });
        _loadTrades();
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
        _loadTrades();
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

  Widget _buildBtcEthComparisonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                child: _buildBenchmarkComparison(),
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
    // If we're using mock data or data is not yet available, don't show the detailed comparison
    if (_isMockWeeklyBenchmark || _weeklyBtcRoi == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(
          'Benchmark will appear once you have more weekly activity.',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
      );
    }

    // Calculate bot ROI from all trades (not just current page)
    double? botRoi = _weeklyBotRoi;
    if (botRoi == null) {
      double totalUserPnl = 0;
      for (var trade in _allTrades) { // Use _allTrades instead of _trades
        totalUserPnl += trade.userPnl;
      }
      if (_totalBotInvestment > 0) {
        botRoi = (totalUserPnl / _totalBotInvestment) * 100;
      } else {
        botRoi = 0.0;
      }
    }

    final btcRoi = _weeklyBtcRoi!;
    final ethRoi = _weeklyEthRoi!;
    
    // Calculate correct comparison values
    final botVsBtc = _weeklyVsBtc ?? (botRoi - btcRoi);
    final botVsEth = _weeklyVsEth ?? (botRoi - ethRoi);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isLoadingWeeklyBenchmark)
          const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00), strokeWidth: 2))
        else ...[
          _buildComparisonRow('Omega-3X Bot ROI', '${botRoi.toStringAsFixed(2)}%', 
            botRoi >= 0 ? const Color(0xFF84BD00) : const Color(0xFFFF3B30)),
          const SizedBox(height: 8),
          _buildComparisonRow('BTC ROI', '${btcRoi.toStringAsFixed(2)}%', 
            btcRoi >= 0 ? const Color(0xFF84BD00) : const Color(0xFFFF3B30)),
          const SizedBox(height: 8),
          _buildComparisonRow('ETH ROI', '${ethRoi.toStringAsFixed(2)}%', 
            ethRoi >= 0 ? const Color(0xFF84BD00) : const Color(0xFFFF3B30)),
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 12),
          // Single line comparison message
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
                  'Bot ${botVsBtc >= 0 ? 'outperformed' : 'trailing'} BTC by ${botVsBtc.toStringAsFixed(2)}%, ETH by ${botVsEth.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
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

  Future<void> _loadWeeklyBenchmark({bool force = false}) async {
    if (_isLoadingWeeklyBenchmark) return;
    if (!force && (_weeklyBotRoi != null || _weeklyBenchmarkError != null)) return;

    setState(() {
      _isLoadingWeeklyBenchmark = true;
      _weeklyBenchmarkError = null;
    });

    try {
      final res = await BotService.getWeeklyBenchmark(strategy: 'Omega-3X');
      if (!mounted) return;

      if (res['success'] == true && res['data'] is Map<String, dynamic>) {
        final data = res['data'] as Map<String, dynamic>;
        setState(() {
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
        _weeklyBenchmarkError = res['error']?.toString() ?? 'Failed to load benchmark';
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
}

class EnhancedTradingChartPainter extends CustomPainter {
  final List<BotPosition> positions;
  final String selectedTimeframe;
  late double _minPrice;
  late double _maxPrice;
  
  EnhancedTradingChartPainter({
    required this.positions,
    required this.selectedTimeframe,
  }) {
    _calculatePriceRange();
  }

  void _calculatePriceRange() {
    if (positions.isEmpty) {
      _minPrice = 0.0;
      _maxPrice = 200.0;
      return;
    }

    double min = double.infinity;
    double max = double.negativeInfinity;

    for (final pos in positions) {
      if (pos.avgPrice < min) min = pos.avgPrice;
      if (pos.markPrice < min) min = pos.markPrice;
      if (pos.liqPrice > 0 && pos.liqPrice < min) min = pos.liqPrice;

      if (pos.avgPrice > max) max = pos.avgPrice;
      if (pos.markPrice > max) max = pos.markPrice;
      if (pos.liqPrice > max) max = pos.liqPrice;
    }

    // Add padding (5%)
    double padding = (max - min).abs();
    if (padding == 0) padding = max * 0.1; // If all prices are same, use 10% of price
    if (padding == 0) padding = 100.0; // Fallback if price is also 0

    _minPrice = min - (padding * 0.5);
    _maxPrice = max + (padding * 0.5);
    
    // Ensure min price doesn't go below 0
    if (_minPrice < 0) _minPrice = 0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Background gradient
    final bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF1C1C1E),
        const Color(0xFF2C2C2E).withOpacity(0.3),
      ],
    );
    
    final bgPaint = Paint()
      ..shader = bgGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Grid paint with improved styling
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Price level paints
    final supportPaint = Paint()
      ..color = const Color(0xFF84BD00).withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
      
    final resistancePaint = Paint()
      ..color = const Color(0xFFFF3B30).withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw improved grid
    _drawGrid(canvas, size, gridPaint);
    
    // Draw price levels if we have position data
    if (positions.isNotEmpty) {
      _drawPriceLevels(canvas, size, positions.first, supportPaint, resistancePaint);
    }
    
    // Draw enhanced candlesticks or line chart
    if (positions.isNotEmpty) {
      _drawPositionChart(canvas, size);
    } else {
      _drawNoDataMessage(canvas, size);
    }
    
    // Draw axis labels
    _drawAxisLabels(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size, Paint gridPaint) {
    // Horizontal grid lines with price levels
    for (int i = 0; i <= 8; i++) {
      final y = (size.height / 8) * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Vertical grid lines for time
    for (int i = 0; i <= 6; i++) {
      final x = (size.width / 6) * i;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }
  }

  void _drawPriceLevels(Canvas canvas, Size size, BotPosition position, Paint supportPaint, Paint resistancePaint) {
    // Draw entry price line
    final entryPriceY = _priceToY(position.avgPrice, size);
    canvas.drawLine(
      Offset(0, entryPriceY),
      Offset(size.width, entryPriceY),
      supportPaint,
    );
    
    // Draw current price line
    final currentPriceY = _priceToY(position.markPrice, size);
    canvas.drawLine(
      Offset(0, currentPriceY),
      Offset(size.width, currentPriceY),
      resistancePaint,
    );
    
    // Draw liquidation price if available
    if (position.liqPrice > 0) {
      final liqPriceY = _priceToY(position.liqPrice, size);
      final liqPaint = Paint()
        ..color = const Color(0xFFFF9500).withOpacity(0.4)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(0, liqPriceY),
        Offset(size.width, liqPriceY),
        liqPaint,
      );
    }
  }

  void _drawPositionChart(Canvas canvas, Size size) {
    if (positions.isEmpty) return;
    
    final linePaint = Paint()
      ..color = positions.first.userUnrealizedProfit >= 0 
          ? const Color(0xFF84BD00)
          : const Color(0xFFFF3B30)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Generate realistic price data based on position
    final points = _generatePricePoints(size);
    
    if (points.length > 1) {
      // Draw gradient fill under the line
      final gradientPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (positions.first.userUnrealizedProfit >= 0 
                ? const Color(0xFF84BD00)
                : const Color(0xFFFF3B30)).withOpacity(0.3),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      
      final path = Path()
        ..addPolygon(points, false)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      
      canvas.drawPath(path, gradientPaint);
      
      // Draw the main line
      for (int i = 0; i < points.length - 1; i++) {
        canvas.drawLine(points[i], points[i + 1], linePaint);
      }
      
      // Draw points at each data point
      final pointPaint = Paint()
        ..color = positions.first.userUnrealizedProfit >= 0 
            ? const Color(0xFF84BD00)
            : const Color(0xFFFF3B30)
        ..style = PaintingStyle.fill;
        
      for (final point in points) {
        canvas.drawCircle(point, 3, pointPaint);
      }
    }
  }

  void _drawNoDataMessage(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'No position data available',
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 14,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  void _drawAxisLabels(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    // Price labels on the right
    for (int i = 0; i <= 4; i++) {
      final price = _yToPrice((size.height / 4) * i, size);
      textPainter.text = TextSpan(
        text: '\$${price.toStringAsFixed(2)}',
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 10,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(size.width - textPainter.width - 8, (size.height / 4) * i - 6),
      );
    }
    
    // Time labels at the bottom
    final timeLabels = ['12:00', '14:00', '16:00', '18:00', '20:00', '22:00'];
    for (int i = 0; i < timeLabels.length && i < 6; i++) {
      textPainter.text = TextSpan(
        text: timeLabels[i],
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 10,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset((size.width / 6) * i + 8, size.height - 20),
      );
    }
  }

  List<Offset> _generatePricePoints(Size size) {
    final points = <Offset>[];
    final pointCount = 20;
    
    if (positions.isNotEmpty) {
      final basePrice = positions.first.avgPrice;
      final currentPrice = positions.first.markPrice;
      final priceSpread = (currentPrice - basePrice).abs();
      final variationBase = priceSpread > 0 ? priceSpread * 0.2 : basePrice * 0.001;
      
      for (int i = 0; i < pointCount; i++) {
        final x = (size.width / (pointCount - 1)) * i;
        // Create realistic price movement
        final progress = i / (pointCount - 1);
        final variation = math.sin(progress * math.pi * 2) * variationBase + 
                         math.sin(progress * math.pi * 4) * (variationBase * 0.4);
        final price = basePrice + (currentPrice - basePrice) * progress + variation;
        final y = _priceToY(price, size);
        points.add(Offset(x, y));
      }
    }
    
    return points;
  }

  double _priceToY(double price, Size size) {
    // Map price range to Y coordinate (inverted because canvas Y starts at top)
    if (_maxPrice == _minPrice) return size.height / 2;
    final normalizedPrice = (price - _minPrice) / (_maxPrice - _minPrice);
    return size.height * (1 - normalizedPrice.clamp(0.0, 1.0));
  }

  double _yToPrice(double y, Size size) {
    // Map Y coordinate back to price
    final normalizedY = 1 - (y / size.height);
    return _minPrice + normalizedY * (_maxPrice - _minPrice);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CandleData {
  final double open;
  final double close;
  final double high;
  final double low;
  final bool isGreen;

  CandleData({
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.isGreen,
  });
}



