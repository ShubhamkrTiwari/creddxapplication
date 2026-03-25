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

class _BotHistoryScreenState extends State<BotHistoryScreen> {
  String _selectedHistoryPair = 'BTC-USDT';
  String _selectedSortBy = 'date';
  String _selectedSortOrder = 'desc';
  bool _isLoading = false;
  List<BotTrade> _trades = [];
  List<String> _availablePairs = [];
  String? _errorMessage;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadTradeHistory();
    _loadAvailablePairs();
  }

  Future<void> _loadAvailablePairs() async {
    final pairs = await BotService.getAvailablePairs();
    if (mounted) {
      setState(() {
        _availablePairs = pairs;
        if (_availablePairs.isNotEmpty && !_availablePairs.contains(_selectedHistoryPair)) {
          _selectedHistoryPair = _availablePairs.first;
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
      
      // Map pairs to their strategies and symbols
      switch (_selectedHistoryPair) {
        case 'BTC-USDT':
          strategy = 'Omega';
          symbol = 'BTCUSDT';
          break;
        case 'ETH-USDT':
          strategy = 'Alpha';
          symbol = 'ETHUSDT';
          break;
        case 'SOL-USDT':
          strategy = 'Ranger';
          symbol = 'SOLUSDT';
          break;
        default:
          strategy = 'Omega';
          symbol = 'BTCUSDT';
      }

      final result = await BotService.getUserBotTrades(
        strategy: strategy,
        symbol: symbol,
      );

      if (mounted) {
        if (result['success'] == true) {
          final data = result['data'];
          final List<dynamic> tradesList = data['userTrades'] ?? data['trades'] ?? data ?? [];
          setState(() {
            _trades = tradesList.map((trade) => BotTrade.fromJson(trade)).toList();
            _isLoading = false;
          });
        } else if (result['error']?.contains('No investment found') == true) {
          setState(() {
            _errorMessage = 'No investments found. Start investing in strategies to see your trade history.';
            _isLoading = false;
            _trades = []; // Ensure empty list
          });
        } else {
          setState(() {
            _errorMessage = result['error'] ?? 'Failed to load trade history';
            _isLoading = false;
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
          // Horizontal Pair Selector and Sort button
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
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _showSortOptions,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Sort',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.keyboard_arrow_down, color: Colors.white.withOpacity(0.7), size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showDateFilterOptions,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Date',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.calendar_today, color: Colors.white.withOpacity(0.7), size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: Colors.white.withOpacity(0.05), height: 1),
          ),
          const SizedBox(height: 12),
          
          // History List
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
      ),
    );
  }

  Widget _buildHistoryMetric(String label, String value) {
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
            style: const TextStyle(
              color: Colors.white,
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
                  Text(
                    trade.pair,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    trade.formattedDate,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _viewTradeDetails(trade),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF84BD00),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'View',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildHistoryMetric('Open Price:', trade.formattedOpenPrice),
          _buildHistoryMetric('Close Price:', trade.formattedClosePrice),
          _buildHistoryMetric('Total PnL:', trade.formattedTotalPnl),
          _buildHistoryMetric('Your PnL:', trade.formattedUserPnl),
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
}
