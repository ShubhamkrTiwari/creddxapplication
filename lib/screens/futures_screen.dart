import 'dart:math';

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class FuturesScreen extends StatefulWidget {
  const FuturesScreen({super.key});

  @override
  State<FuturesScreen> createState() => _FuturesScreenState();
}

class _FuturesScreenState extends State<FuturesScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedTradingPair = 'BTC/USDT';
  String _selectedMarginMode = 'Isolated';
  String _selectedLeverage = '20X';
  String _selectedOrderType = 'Market';
  String _selectedTimeframe = '15 Min';
  String _selectedTab = 'Open';
  
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  
  List<Map<String, dynamic>> _orderBookBids = [];
  List<Map<String, dynamic>> _orderBookAsks = [];
  List<Map<String, dynamic>> _candleData = [];
  double _currentPrice = 4890.12;
  double _priceChange = 12.1;
  double _high24h = 4933.09;
  double _low24h = 4721.90;
  double _volume24h = 40311;
  
  bool _isLoading = true;
  Timer? _priceTimer;
  
  final List<String> _timeframes = ['Line', '15 Min', '1 Hour', '4 Hour', '1 Day', 'More'];
  final List<String> _marginModes = ['Isolated', 'Cross'];
  final List<String> _leverages = ['5X', '10X', '20X', '50X', '100X'];
  final List<String> _orderTypes = ['Market', 'Limit', 'Stop Limit'];
  
  // Mock open orders
  final List<Map<String, dynamic>> _openOrders = [
    {
      'type': 'Buy',
      'time': '11:09 19/08',
      'status': 'Cancel',
      'price': '300.6756.088',
      'amount': '0.85677',
      'executed': '0.5322',
    },
    {
      'type': 'Buy',
      'time': '09:09 19/08',
      'status': 'Success',
      'price': '301.2345.678',
      'amount': '1.23456',
      'executed': '0.8900',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _generateMockData();
    _startPriceUpdates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _priceTimer?.cancel();
    _amountController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _generateMockData() {
    // Generate mock order book data
    final random = math.Random();
    
    // Bids (green - buy orders)
    double baseBid = _currentPrice * 0.999;
    _orderBookBids = List.generate(5, (index) {
      final price = baseBid - (index * 0.05);
      final amount = 0.5 + random.nextDouble() * 4;
      return {
        'price': price.toStringAsFixed(2),
        'amount': amount.toStringAsFixed(3),
        'total': (price * amount).toStringAsFixed(3),
      };
    });
    
    // Asks (red - sell orders)
    double baseAsk = _currentPrice * 1.001;
    _orderBookAsks = List.generate(5, (index) {
      final price = baseAsk + (index * 0.05);
      final amount = 0.5 + random.nextDouble() * 4;
      return {
        'price': price.toStringAsFixed(2),
        'amount': amount.toStringAsFixed(3),
        'total': (price * amount).toStringAsFixed(3),
      };
    });
    
    // Generate mock candle data
    _candleData = _generateCandleData();
    
    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> _generateCandleData() {
    final random = math.Random();
    final List<Map<String, dynamic>> candles = [];
    double price = _currentPrice * 0.85;
    
    for (int i = 0; i < 30; i++) {
      final open = price;
      final change = (random.nextDouble() - 0.5) * 200;
      final close = price + change;
      final high = math.max(open, close) + random.nextDouble() * 50;
      final low = math.min(open, close) - random.nextDouble() * 50;
      
      candles.add({
        'open': open,
        'close': close,
        'high': high,
        'low': low,
        'volume': 1000 + random.nextDouble() * 5000,
      });
      
      price = close;
    }
    
    return candles;
  }

  void _startPriceUpdates() {
    _priceTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          final random = math.Random();
          final change = (random.nextDouble() - 0.5) * 10;
          _currentPrice += change;
          _generateMockData();
        });
      }
    });
  }

  Future<void> _fetchMarketData() async {
    try {
      // Try to fetch from Binance API
      final response = await http.get(
        Uri.parse('https://api.binance.com/api/v3/ticker/24hr?symbol=BTCUSDT')
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _currentPrice = double.tryParse(data['lastPrice'] ?? '0') ?? _currentPrice;
          _priceChange = double.tryParse(data['priceChangePercent'] ?? '0') ?? _priceChange;
          _high24h = double.tryParse(data['highPrice'] ?? '0') ?? _high24h;
          _low24h = double.tryParse(data['lowPrice'] ?? '0') ?? _low24h;
          _volume24h = double.tryParse(data['volume'] ?? '0') ?? _volume24h;
        });
      }
    } catch (e) {
      debugPrint('Error fetching market data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopTabs(),
            _buildTradingPairHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // For Std. Futures (index 1), show only chart
                    if (_tabController.index == 1) ...[
                      _buildChartSection(),
                      const SizedBox(height: 74),
                      // Long and Short buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF84BD00),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: const Text(
                                  'Long',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF020202),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: const Text(
                                  'Short',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      _buildTradingSection(),
                      const SizedBox(height: 16),
                      _buildOpenOrdersSection(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: const Color(0xFF84BD00),
              labelColor: const Color(0xFF84BD00),
              unselectedLabelColor: Colors.white54,
              indicatorWeight: 2,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Prep Futures'),
                Tab(text: 'Std. Futures'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradingPairHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                _selectedTradingPair,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_priceChange >= 0 ? '+' : ''}${_priceChange.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: _priceChange >= 0 ? const Color(0xFF00C087) : const Color(0xFFFF3B30),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.bar_chart, color: Colors.white70, size: 20),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white70, size: 20),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTradingSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side - Trading controls
            Expanded(
              flex: 3,
              child: _buildTradingControls(),
            ),
            const SizedBox(width: 8),
            // Right side - Order book
            Expanded(
              flex: 4,
              child: _buildOrderBook(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTradingControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Margin Mode & Leverage
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildDropdownButton(_selectedMarginMode, _marginModes, (value) {
                setState(() => _selectedMarginMode = value);
              }),
              const SizedBox(width: 8),
              _buildDropdownButton(_selectedLeverage, _leverages, (value) {
                setState(() => _selectedLeverage = value);
              }, isLeverage: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // Open/Close tabs
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildToggleTab('Open', _selectedTab == 'Open', () {
                  setState(() => _selectedTab = 'Open');
                }),
              ),
              Expanded(
                child: _buildToggleTab('Close', _selectedTab == 'Close', () {
                  setState(() => _selectedTab = 'Close');
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        
        // Order Type
        _buildDropdownButton(_selectedOrderType, _orderTypes, (value) {
          setState(() => _selectedOrderType = value);
        }, fullWidth: true),
        const SizedBox(height: 10),
        
        // Amount Input
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _amountController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Amount',
              hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffixText: 'BTC',
              suffixStyle: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // Slider
        _buildAmountSlider(),
        const SizedBox(height: 12),
        
        // Available info
        _buildAvailableInfo(),
        const SizedBox(height: 14),
        
        // Open Long Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF84BD00),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Open Long',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 6),
        
        // Open Short Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Open Short',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownButton(String value, List<String> items, Function(String) onChanged, {bool isLeverage = false, bool fullWidth = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          dropdownColor: const Color(0xFF1E1E20),
          style: TextStyle(
            color: isLeverage ? const Color(0xFF84BD00) : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 16),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: TextStyle(
                  color: isLeverage ? const Color(0xFF84BD00) : Colors.white,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) onChanged(newValue);
          },
        ),
      ),
    );
  }

  Widget _buildToggleTab(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF84BD00) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildAmountSlider() {
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFF84BD00),
            inactiveTrackColor: const Color(0xFF2A2A2C),
            thumbColor: const Color(0xFF84BD00),
            overlayColor: const Color(0xFF84BD00).withOpacity(0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: 0.3,
            onChanged: (value) {},
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Max', style: TextStyle(color: Colors.white54, fontSize: 8)),
            Text('22.5071/22.5071 BTC', style: TextStyle(color: Color(0xFF84BD00), fontSize: 8)),
          ],
        ),
      ],
    );
  }

  Widget _buildAvailableInfo() {
    return Column(
      children: [
        _buildInfoRow('Avail.', '46912.9872000 USDT'),
        const SizedBox(height: 4),
        _buildInfoRow('Total', '45768.7648900 USDT'),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
        Text(value, style: const TextStyle(color: Colors.white70, fontSize: 9)),
      ],
    );
  }

  Widget _buildOrderBook() {
    return Column(
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Price', style: TextStyle(color: Colors.white54, fontSize: 10)),
            const Text('Amount', style: TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 8),
        
        // Asks (Sell orders - red)
        ..._orderBookAsks.reversed.map((ask) => _buildOrderBookRow(
          ask['price']!,
          ask['amount']!,
          isAsk: true,
          intensity: double.parse(ask['amount']!) / 5.0,
        )).toList(),
        
        // Current Price
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            _currentPrice.toStringAsFixed(2),
            style: const TextStyle(
              color: Color(0xFFFF3B30),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        // Bids (Buy orders - green)
        ..._orderBookBids.map((bid) => _buildOrderBookRow(
          bid['price']!,
          bid['amount']!,
          isAsk: false,
          intensity: double.parse(bid['amount']!) / 5.0,
        )).toList(),
      ],
    );
  }

  Widget _buildOrderBookRow(String price, String amount, {required bool isAsk, required double intensity}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Stack(
        children: [
          // Background bar
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 60 * intensity.clamp(0.0, 1.0),
              color: isAsk 
                ? const Color(0xFFFF3B30).withOpacity(0.15)
                : const Color(0xFF84BD00).withOpacity(0.15),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    color: isAsk ? const Color(0xFFFF3B30) : const Color(0xFF84BD00),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  amount,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Price info row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _currentPrice.toStringAsFixed(2),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildPriceInfoRow('H', _high24h.toStringAsFixed(2)),
                  _buildPriceInfoRow('L', _low24h.toStringAsFixed(2)),
                  _buildPriceInfoRow('24H', _volume24h.toStringAsFixed(0)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          
          // Price change row
          Row(
            children: [
              Text(
                '${(_currentPrice * 6.45).toStringAsFixed(2)} CNY ',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                '${_priceChange >= 0 ? '+' : ''}${_priceChange.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: _priceChange >= 0 ? const Color(0xFF84BD00) : const Color(0xFFFF3B30),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Timeframe buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _timeframes.map((tf) {
                final isSelected = _selectedTimeframe == tf;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTimeframe = tf),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      tf,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF84BD00) : Colors.white54,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          
          // Professional Chart with MA lines
          Container(
            height: 280,
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildProfessionalChart(),
          ),
          const SizedBox(height: 8),
          
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(const Color(0xFF84BD00), 'Buy'),
              const SizedBox(width: 16),
              _buildLegendItem(const Color(0xFFFF3B30), 'Sell'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalChart() {
    return CustomPaint(
      size: const Size(double.infinity, 280),
      painter: ProfessionalChartPainter(_candleData, _currentPrice),
    );
  }

  Widget _buildPriceInfoRow(String label, String value) {
    return Row(
      children: [
        Text('$label ', style: const TextStyle(color: Colors.white54, fontSize: 10)),
        Text(value, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  Widget _buildCandlestickChart() {
    return CustomPaint(
      size: const Size(double.infinity, 180),
      painter: CandlestickPainter(_candleData, _currentPrice),
    );
  }

  Widget _buildVolumeChart() {
    return CustomPaint(
      size: const Size(double.infinity, 60),
      painter: VolumePainter(_candleData),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }

  Widget _buildOpenOrdersSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Open Orders',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'All',
                  style: TextStyle(color: Color(0xFF84BD00), fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text('Type', style: TextStyle(color: Colors.white54, fontSize: 10)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Time', style: TextStyle(color: Colors.white54, fontSize: 10)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Price (USDT)', style: TextStyle(color: Colors.white54, fontSize: 10)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Amount (BTC)', style: TextStyle(color: Colors.white54, fontSize: 10)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Executed (BTC)', style: TextStyle(color: Colors.white54, fontSize: 10)),
                ),
                Expanded(
                  flex: 1,
                  child: Text('', style: TextStyle(color: Colors.white54, fontSize: 10)),
                ),
              ],
            ),
          ),
          
          // Orders list
          ..._openOrders.map((order) => _buildOrderRow(order)).toList(),
        ],
      ),
    );
  }

  Widget _buildOrderRow(Map<String, dynamic> order) {
    final isBuy = order['type'] == 'Buy';
    final isCancel = order['status'] == 'Cancel';
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              order['type']!,
              style: TextStyle(
                color: isBuy ? const Color(0xFF84BD00) : const Color(0xFFFF3B30),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              order['time']!,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              order['price']!,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              order['amount']!,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              order['executed']!,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: () {},
              child: Text(
                order['status']!,
                style: TextStyle(
                  color: isCancel ? const Color(0xFF84BD00) : const Color(0xFF00C087),
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Candlestick Chart Painter
class CandlestickPainter extends CustomPainter {
  final List<Map<String, dynamic>> candles;
  final double currentPrice;
  
  CandlestickPainter(this.candles, this.currentPrice);
  
  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    
    final paint = Paint()
      ..strokeWidth = 1.0;
    
    final candleWidth = size.width / (candles.length + 2);
    
    // Find min and max for scaling
    double minPrice = double.infinity;
    double maxPrice = 0;
    for (var candle in candles) {
      minPrice = math.min(minPrice, candle['low'] as double);
      maxPrice = math.max(maxPrice, candle['high'] as double);
    }
    
    final priceRange = maxPrice - minPrice;
    final padding = priceRange * 0.1;
    minPrice -= padding;
    maxPrice += padding;
    
    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 0.5;
    
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    
    // Draw candles
    for (int i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final x = (i + 1) * candleWidth;
      
      final open = candle['open'] as double;
      final close = candle['close'] as double;
      final high = candle['high'] as double;
      final low = candle['low'] as double;
      
      final isGreen = close >= open;
      final color = isGreen ? const Color(0xFF84BD00) : const Color(0xFFFF3B30);
      
      final yHigh = size.height - ((high - minPrice) / (maxPrice - minPrice)) * size.height;
      final yLow = size.height - ((low - minPrice) / (maxPrice - minPrice)) * size.height;
      final yOpen = size.height - ((open - minPrice) / (maxPrice - minPrice)) * size.height;
      final yClose = size.height - ((close - minPrice) / (maxPrice - minPrice)) * size.height;
      
      paint.color = color;
      
      // Draw wick
      canvas.drawLine(
        Offset(x + candleWidth / 2, yHigh),
        Offset(x + candleWidth / 2, yLow),
        paint,
      );
      
      // Draw body
      final bodyTop = math.min(yOpen, yClose);
      final bodyBottom = math.max(yOpen, yClose);
      final bodyHeight = math.max(bodyBottom - bodyTop, 2);
      
      final bodyRect = Rect.fromLTWH(
        x + candleWidth * 0.2,
        bodyTop,
        candleWidth * 0.6,
        bodyHeight.toDouble(),
      );
      
      if (isGreen) {
        canvas.drawRect(bodyRect, paint);
      } else {
        canvas.drawRect(bodyRect, paint);
        // Fill red candles
        final fillPaint = Paint()..color = color;
        canvas.drawRect(bodyRect, fillPaint);
      }
    }
    
    // Draw current price indicator line
    final currentY = size.height - ((currentPrice - minPrice) / (maxPrice - minPrice)) * size.height;
    final indicatorPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(
      Offset(0, currentY),
      Offset(size.width, currentY),
      indicatorPaint,
    );
    
    // Draw price label
    final textPainter = TextPainter(
      text: TextSpan(
        text: currentPrice.toStringAsFixed(2),
        style: const TextStyle(color: Colors.white54, fontSize: 10),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width - 50, currentY - 12));
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Volume Chart Painter
class VolumePainter extends CustomPainter {
  final List<Map<String, dynamic>> candles;
  
  VolumePainter(this.candles);
  
  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    
    final barWidth = size.width / (candles.length + 2);
    
    // Find max volume
    double maxVolume = 0;
    for (var candle in candles) {
      maxVolume = math.max(maxVolume, candle['volume'] as double);
    }
    
    // Draw volume bars
    for (int i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final x = (i + 1) * barWidth;
      final volume = candle['volume'] as double;
      final open = candle['open'] as double;
      final close = candle['close'] as double;
      
      final isGreen = close >= open;
      final color = isGreen ? const Color(0xFF84BD00) : const Color(0xFFFF3B30);
      
      final barHeight = (volume / maxVolume) * size.height * 0.8;
      
      final paint = Paint()..color = color.withOpacity(0.7);
      
      final barRect = Rect.fromLTWH(
        x + barWidth * 0.2,
        size.height - barHeight,
        barWidth * 0.6,
        barHeight,
      );
      
      canvas.drawRect(barRect, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter) => true;
}

// Professional Chart Painter with MA lines, Volume, and Price labels
class ProfessionalChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> candles;
  final double currentPrice;
  
  ProfessionalChartPainter(this.candles, this.currentPrice);
  
  // Calculate Moving Average
  List<double> _calculateMA(int period) {
    List<double> ma = [];
    for (int i = 0; i < candles.length; i++) {
      if (i < period - 1) {
        ma.add(0);
        continue;
      }
      double sum = 0;
      for (int j = 0; j < period; j++) {
        sum += candles[i - j]['close'] as double;
      }
      ma.add(sum / period);
    }
    return ma;
  }
  
  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    
    final chartHeight = size.height * 0.70;
    final volumeHeight = size.height * 0.18;
    final labelWidth = 45.0;
    final chartWidth = size.width - labelWidth;
    final chartTop = 8.0;
    
    final candleWidth = chartWidth / (candles.length + 1);
    
    // Find min and max for scaling
    double minPrice = double.infinity;
    double maxPrice = 0;
    double maxVolume = 0;
    for (var candle in candles) {
      minPrice = min(minPrice, candle['low'] as double);
      maxPrice = max(maxPrice, candle['high'] as double);
      maxVolume = max(maxVolume, candle['volume'] as double);
    }
    
    // Add MA values to min/max calculation
    final ma5 = _calculateMA(5);
    final ma10 = _calculateMA(10);
    final ma30 = _calculateMA(30);
    for (var ma in [ma5, ma10, ma30]) {
      for (var val in ma) {
        if (val > 0) {
          minPrice = min(minPrice, val);
          maxPrice = max(maxPrice, val);
        }
      }
    }
    
    final priceRange = maxPrice - minPrice;
    final padding = priceRange * 0.05;
    minPrice -= padding;
    maxPrice += padding;
    
    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 0.5;
    
    for (int i = 0; i <= 5; i++) {
      final y = chartTop + (chartHeight * i / 5);
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
    }
    
    // Draw MA lines
    void drawMALine(List<double> ma, Color color) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      
      final path = Path();
      bool first = true;
      
      for (int i = 0; i < ma.length; i++) {
        if (ma[i] == 0) continue;
        final x = (i + 1) * candleWidth;
        final y = chartTop + chartHeight - ((ma[i] - minPrice) / priceRange) * chartHeight;
        if (first) {
          path.moveTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
    
    // Draw MA lines (Yellow=MA5, Blue=MA10, Purple=MA30)
    drawMALine(ma5, const Color(0xFFFFD700));
    drawMALine(ma10, const Color(0xFF4169E1));
    drawMALine(ma30, const Color(0xFF9370DB));
    
    // Draw candles and volume
    for (int i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final x = (i + 1) * candleWidth;
      
      final open = candle['open'] as double;
      final close = candle['close'] as double;
      final high = candle['high'] as double;
      final low = candle['low'] as double;
      final volume = candle['volume'] as double;
      
      final isGreen = close >= open;
      final color = isGreen ? const Color(0xFF84BD00) : const Color(0xFFFF3B30);
      
      final yHigh = chartTop + chartHeight - ((high - minPrice) / priceRange) * chartHeight;
      final yLow = chartTop + chartHeight - ((low - minPrice) / priceRange) * chartHeight;
      final yOpen = chartTop + chartHeight - ((open - minPrice) / priceRange) * chartHeight;
      final yClose = chartTop + chartHeight - ((close - minPrice) / priceRange) * chartHeight;
      
      // Draw wick
      final wickPaint = Paint()
        ..color = color
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x, yHigh), Offset(x, yLow), wickPaint);
      
      // Draw body
      final bodyTop = min(yOpen, yClose);
      final bodyBottom = max(yOpen, yClose);
      final bodyHeight = max(bodyBottom - bodyTop, 2).toDouble();
      
      final bodyRect = Rect.fromLTWH(
        x - candleWidth * 0.35,
        bodyTop,
        candleWidth * 0.7,
        bodyHeight,
      );
      
      final bodyPaint = Paint()..color = color;
      canvas.drawRect(bodyRect, bodyPaint);
      
      // Draw volume bar at bottom
      final volY = chartTop + chartHeight + 8;
      final volHeight = (volume / maxVolume) * volumeHeight;
      final volRect = Rect.fromLTWH(
        x - candleWidth * 0.35,
        volY + volumeHeight - volHeight,
        candleWidth * 0.7,
        volHeight,
      );
      final volPaint = Paint()..color = color.withOpacity(0.6);
      canvas.drawRect(volRect, volPaint);
    }
    
    // Draw current price line
    final currentY = chartTop + chartHeight - ((currentPrice - minPrice) / priceRange) * chartHeight;
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(Offset(0, currentY), Offset(chartWidth, currentY), linePaint);
    
    // Draw price labels on right side
    for (int i = 0; i <= 5; i++) {
      final price = maxPrice - (priceRange * i / 5);
      final y = chartTop + (chartHeight * i / 5);
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: price.toStringAsFixed(0),
          style: const TextStyle(color: Colors.white54, fontSize: 9),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(chartWidth + 4, y - 5));
    }
    
    // Draw time labels at bottom
    final timeLabels = ['06:20', '13:08', '08:00', '13:08', '08:30'];
    for (int i = 0; i < timeLabels.length && i < 5; i++) {
      final x = chartWidth * (i + 1) / 6;
      final y = chartTop + chartHeight + volumeHeight + 16;
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: timeLabels[i],
          style: const TextStyle(color: Colors.white54, fontSize: 9),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - 15, y));
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
