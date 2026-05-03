import 'package:flutter/material.dart';
import '../services/bot_service.dart';
import '../widgets/balance_growth_chart.dart';
import '../widgets/trading_view_chart.dart';
import 'dart:math' as math;

class BotPositionsScreen extends StatefulWidget {
  const BotPositionsScreen({super.key});

  @override
  State<BotPositionsScreen> createState() => _BotPositionsScreenState();
}

class _BotPositionsScreenState extends State<BotPositionsScreen> {
  final String _selectedPair = 'BTC-USDT';
  String _selectedTimeframe = '1h';
  bool _isLoading = false;
  List<BotPosition> _positions = [];
  String? _errorMessage;
  Map<String, dynamic>? _positionData;
  bool _showBalanceChart = false;
  List<Map<String, dynamic>> _balanceHistory = [];
  bool _isLoadingBalance = false;
  double _totalBotInvestment = 0.0; // Total investment from API

  final List<String> _timeframes = ['1m', '30m', '1h', '3m', '15m', '4h', '1d'];

  @override
  void initState() {
    super.initState();
    _loadPositions();
  }

  Future<void> _loadPositions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      const String strategy = 'Omega-3X';
      final String symbol = _selectedPair; // Use the exact format from API

      final result = await BotService.getUserBotPositions(
        strategy: strategy,
        symbol: symbol,
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
            List<BotPosition> parsedPositions = [];
            
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
            
            // Also fetch total investment from trades endpoint
            final totalInvestment = await BotService.getTotalBotInvestment(
              strategy: strategy,
              symbol: symbol,
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
              _errorMessage = 'No data received from server';
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _errorMessage = result['error'] ?? 'Failed to load positions';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
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
        days: 90, // Get 90 days of data for weekly view
      );

      if (mounted) {
        if (result['success'] == true) {
          // New API returns data array directly
          final List<Map<String, dynamic>> history = 
              List<Map<String, dynamic>>.from(result['data'] ?? result['history'] ?? []);
          setState(() {
            _balanceHistory = history;
            _isLoadingBalance = false;
          });
        } else {
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
      body: _showBalanceChart
          ? _buildBalanceGrowthView()
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildStrategyHeader(),
                  _buildTradingChart(),
                  _buildPositionDetails(),
                  const SizedBox(height: 20),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
                      : _errorMessage != null
                          ? _buildErrorWidget()
                          : _positions.isEmpty
                              ? _buildEmptyWidget()
                              : _buildPositionsList(),
                ],
              ),
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
      margin: const EdgeInsets.all(16),
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
              Expanded(
                child: Text(
                  'Strategy: $strategy',
                  style: const TextStyle(
                    color: Color(0xFF84BD00),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Balance Growth', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(8),
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
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${userInvestment.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFF84BD00),
                            fontSize: 20,
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
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${totalUnrealizedPnL >= 0 ? '+' : ''}\$${totalUnrealizedPnL.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: totalUnrealizedPnL >= 0 ? const Color(0xFF84BD00) : const Color(0xFFFF3B30),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 1,
                  color: Colors.white.withOpacity(0.1),
                ),
                const SizedBox(height: 12),
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
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_positions.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
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
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _positions.first.symbol,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
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
                      '${(_positions.isNotEmpty ? _positions.first.markPrice : 0.0).toStringAsFixed(2)}',
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
                              ? '${(_positions.first.userUnrealizedProfit >= 0 ? '+' : '')}${_positions.first.userUnrealizedProfit.toStringAsFixed(2)}'
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    position.symbol,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '${isProfit ? '+' : ''}\$${position.userUnrealizedProfit.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isProfit ? const Color(0xFF84BD00) : const Color(0xFFFF3B30),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetric('Entry Price', '\$${position.avgPrice.toStringAsFixed(2)}'),
              ),
              Expanded(
                child: _buildMetric('Mark Price', '\$${position.markPrice.toStringAsFixed(2)}'),
              ),
              Expanded(
                child: _buildMetric('Liq Price', '\$${position.liqPrice.toStringAsFixed(2)}'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetric('Invest Amount', '\$${position.size}'),
              ),
              Expanded(
                child: _buildMetric('Margin', '\$${position.userMargin.toStringAsFixed(2)}'),
              ),
              Expanded(
                child: _buildMetric('Leverage', '${position.leverage}x'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetric('Updated', _formatTime(position.updateTime)),
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
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF84BD00)),
            )
          else
            BalanceGrowthChart(
              data: _balanceHistory,
              viewType: ChartViewType.weekly,
              title: 'Performance',
              lineColor: const Color(0xFF84BD00),
            ),
          const SizedBox(height: 20),
          if (_balanceHistory.isNotEmpty) _buildPerformanceSummary(),
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
