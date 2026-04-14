import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/p2p_service.dart';
import 'chart_screen.dart';
import 'p2p_place_order_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../utils/coin_icon_mapper.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _marketData = [];
  List<dynamic> _p2pAds = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final String _spotBaseUrl = 'http://13.202.34.205:9000';
  Timer? _priceUpdateTimer;
  final NumberFormat _priceFormat = NumberFormat.currency(symbol: "₹", decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchInitialData();
    _startPriceUpdates();
    _connectToTradingView();
  }

  @override
  void dispose() {
    _priceUpdateTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _connectToTradingView() {
    try {
      debugPrint('TradingView WebSocket is blocked, using fallback APIs instead');
      // Direct TradingView WebSocket connection is blocked (403 error)
      // Use fallback APIs for real-time data
      _fetchTradingViewData();
    } catch (e) {
      debugPrint('Failed to connect to TradingView: $e');
      // Fallback to HTTP polling
      _fetchTradingViewData();
    }
  }

  
  Future<void> _fetchTradingViewData() async {
    try {
      // Method 1: Try CoinGecko API (most reliable)
      final response = await http.get(
        Uri.parse('https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=20&page=1&sparkline=false')
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _processCoinGeckoResponse(data);
      } else {
        // Fallback to Binance API
        await _fetchBinanceData();
      }
    } catch (e) {
      debugPrint('Error fetching TradingView data: $e');
      // Fallback to local API
      await _fetchBinanceData();
    }
  }

  void _processCoinGeckoResponse(dynamic data) {
    try {
      if (data is List) {
        for (var item in data) {
          final symbol = item['symbol']?.toString().toUpperCase() ?? '';
          final price = item['current_price'] ?? 0.0;
          final changePercent = item['price_change_percentage_24h'] ?? 0.0;
          final volume = item['total_volume']?.toString() ?? '0';
          final high = item['high_24h'] ?? 0.0;
          final low = item['low_24h'] ?? 0.0;
          
          _updateMarketData(symbol, price, changePercent, volume, high, low);
        }
      }
    } catch (e) {
      debugPrint('Error processing CoinGecko response: $e');
    }
  }

  Future<void> _fetchBinanceData() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.binance.com/api/v3/ticker/24hr')
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        for (var item in data) {
          final symbol = item['symbol']?.toString().replaceAll('USDT', '') ?? '';
          final price = double.tryParse(item['lastPrice']?.toString() ?? '0') ?? 0.0;
          final changePercent = double.tryParse(item['priceChangePercent']?.toString() ?? '0') ?? 0.0;
          final volume = item['volume']?.toString() ?? '0';
          final high = double.tryParse(item['highPrice']?.toString() ?? '0') ?? 0.0;
          final low = double.tryParse(item['lowPrice']?.toString() ?? '0') ?? 0.0;
          
          _updateMarketData(symbol, price, changePercent, volume, high, low);
        }
      }
    } catch (e) {
      debugPrint('Error fetching Binance data: $e');
    }
  }

  void _updateMarketData(String symbol, double price, double change, String volume, [double? high, double? low]) {
    if (mounted) {
      setState(() {
        final existingIndex = _marketData.indexWhere((m) => m['symbol'] == symbol);
        
        if (existingIndex >= 0) {
          _marketData[existingIndex] = {
            ..._marketData[existingIndex],
            'price': price.toStringAsFixed(2),
            'change': change,
            'volume': volume,
            'high': (high ?? price * 1.02).toStringAsFixed(2),
            'low': (low ?? price * 0.98).toStringAsFixed(2),
          };
        } else {
          _marketData.add({
            'symbol': symbol,
            'price': price.toStringAsFixed(2),
            'change': change,
            'volume': volume,
            'high': (high ?? price * 1.02).toStringAsFixed(2),
            'low': (low ?? price * 0.98).toStringAsFixed(2),
            'isFavorite': false,
          });
        }
      });
    }
  }

  void _startPriceUpdates() {
    _priceUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchTradingViewData(); // Refresh data every 5 seconds
    });
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchTradingViewData(),
      _fetchP2PAds(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchSpotData() async {
    try {
      final response = await http.get(Uri.parse('$_spotBaseUrl/ticker/24hr'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> rawList = data['data'] is List ? data['data'] : data['data'].values.toList();
          _marketData = rawList.map<Map<String, dynamic>>((item) => {
            'symbol': item['symbol'],
            'price': item['last_price']?.toString() ?? '0.00',
            'change': double.tryParse(item['price_change_percent']?.toString() ?? '0') ?? 0.0,
            'volume': item['volume']?.toString() ?? '0',
            'isFavorite': false,
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('Spot fetch error: $e');
    }
  }

  Future<void> _fetchP2PAds() async {
    final ads = await P2PService.getAllAdvertisements();
    if (mounted) setState(() => _p2pAds = ads);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: _buildAppBar(),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
        : Column(
            children: [
              _buildMarketOverview(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSpotList(_marketData.where((m) => m['isFavorite']).toList()),
                    _buildSpotList(_marketData),
                    _buildP2PAdsList(),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D0D0D),
      elevation: 0,
      title: _isSearching 
        ? TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search coins...',
              border: InputBorder.none,
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
            ),
            onChanged: (value) {
              setState(() {}); // Trigger rebuild for filtering
            },
          )
        : const Text('Markets', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search), 
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _searchController.clear();
            });
          }
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF84BD00)),
          onPressed: _fetchInitialData,
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF84BD00),
        labelColor: const Color(0xFF84BD00),
        unselectedLabelColor: Colors.white54,
        indicatorWeight: 2,
        tabs: const [
          Tab(text: 'Favorites'), 
          Tab(text: 'Spot'), 
          Tab(text: 'P2P')
        ],
      ),
    );
  }

  Widget _buildMarketOverview() {
    if (_marketData.isEmpty) return const SizedBox.shrink();
    
    final topGainers = _marketData.where((m) => m['change'] > 0).toList()
      ..sort((a, b) => b['change'].compareTo(a['change']));
    final topLosers = _marketData.where((m) => m['change'] < 0).toList()
      ..sort((a, b) => a['change'].compareTo(b['change']));
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF84BD00).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Market Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMarketSection('🔥 Top Gainers', topGainers.take(3).toList(), true)),
              const SizedBox(width: 12),
              Expanded(child: _buildMarketSection('📉 Top Losers', topLosers.take(3).toList(), false)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarketSection(String title, List<Map<String, dynamic>> data, bool isGainer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...data.map((item) => _buildOverviewItem(item, isGainer)),
      ],
    );
  }

  Widget _buildOverviewItem(Map<String, dynamic> item, bool isGainer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CoinIconMapper.getCoinIcon(
                item['symbol']?.toString().replaceAll('USDT', '') ?? '',
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item['symbol']?.toString().replaceAll('USDT', '') ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    _priceFormat.format(double.tryParse(item['price'] ?? '0') ?? 0),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isGainer ? const Color(0xFF84BD00).withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${isGainer ? "+" : ""}${item['change']?.toStringAsFixed(2) ?? "0.00"}%',
                    style: TextStyle(
                      color: isGainer ? const Color(0xFF84BD00) : Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSpotList(List<Map<String, dynamic>> data) {
    // Filter data based on search
    List<Map<String, dynamic>> filteredData = data;
    if (_isSearching && _searchController.text.isNotEmpty) {
      final searchQuery = _searchController.text.toLowerCase();
      filteredData = data.where((item) {
        final symbol = item['symbol']?.toString().toLowerCase() ?? '';
        return symbol.contains(searchQuery);
      }).toList();
    }
    
    if (filteredData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              color: Colors.white54,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _isSearching ? 'No coins found' : 'No data found',
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _fetchSpotData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filteredData.length,
        itemBuilder: (context, index) {
          final item = filteredData[index];
          final isPositive = item['change'] >= 0;
          return _buildTradingViewCard(item, isPositive);
        },
      ),
    );
  }

  Widget _buildTradingViewCard(Map<String, dynamic> item, bool isPositive) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPositive 
            ? const Color(0xFF84BD00).withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context, 
              MaterialPageRoute(
                builder: (context) => ChartScreen(symbol: item['symbol'])
              )
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CoinIconMapper.getCoinIcon(
                          item['symbol']?.toString().replaceAll('USDT', '') ?? '',
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['symbol']?.toString() ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Vol: ${item['volume'] ?? '0'}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          item['isFavorite'] = !(item['isFavorite'] ?? false);
                        });
                      },
                      child: Icon(
                        item['isFavorite'] ?? false ? Icons.star : Icons.star_border,
                        color: item['isFavorite'] ?? false ? Colors.amber : Colors.white54,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _priceFormat.format(double.tryParse(item['price'] ?? '0') ?? 0),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (item['high'] != null && item['low'] != null)
                          Text(
                            'H: ${_priceFormat.format(double.tryParse(item['high']) ?? 0)} L: ${_priceFormat.format(double.tryParse(item['low']) ?? 0)}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isPositive 
                          ? const Color(0xFF84BD00).withOpacity(0.15)
                          : Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${isPositive ? "+" : ""}${item['change']?.toStringAsFixed(2) ?? "0.00"}%',
                        style: TextStyle(
                          color: isPositive ? const Color(0xFF84BD00) : Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildP2PAdsList() {
    if (_p2pAds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              color: Colors.white54,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'No P2P ads available',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _fetchP2PAds,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _p2pAds.length,
        itemBuilder: (context, index) => _buildEnhancedP2PAdCard(_p2pAds[index]),
      ),
    );
  }

  Widget _buildEnhancedP2PAdCard(dynamic ad) {
    final advertiser = ad['advertiser'] ?? {};
    final userName = ad['advertiserName'] ?? advertiser['userName'] ?? 'Trader';
    final price = double.tryParse(ad['price']?.toString() ?? '0') ?? 0;
    final minAmount = double.tryParse(ad['min']?.toString() ?? '0') ?? 0;
    final maxAmount = double.tryParse(ad['max']?.toString() ?? '0') ?? 0;
    final rating = double.tryParse(ad['rating']?.toString() ?? '4.5') ?? 4.5;
    final orders = int.tryParse(ad['orders']?.toString() ?? '0') ?? 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF84BD00).withOpacity(0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context, 
              MaterialPageRoute(
                builder: (context) => P2PPlaceOrderScreen(
                  adId: ad['_id'] ?? '',
                  orderType: 'buy',
                  userName: userName,
                  price: price.toString(),
                  available: ad['amount'].toString(),
                  paymentMethods: ad['paymentMode'] is List
                    ? List<String>.from(ad['paymentMode'])
                    : [ad['paymentMode'] ?? 'Bank Transfer'],
                  minLimit: minAmount,
                  maxLimit: maxAmount,
                )
              )
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF84BD00).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'T',
                          style: const TextStyle(
                            color: Color(0xFF84BD00),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star, color: Colors.amber, size: 14),
                                  const SizedBox(width: 2),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$orders orders',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF84BD00).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'BUY',
                        style: const TextStyle(
                          color: Color(0xFF84BD00),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252525),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Price',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '₹${price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Limits',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '₹${minAmount.toStringAsFixed(0)} - ₹${maxAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Color(0xFF84BD00),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (ad['paymentMode'] != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Payment: ',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: (ad['paymentMode'] is List 
                            ? List<String>.from(ad['paymentMode']) 
                            : [ad['paymentMode'].toString()]
                          ).map((method) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF84BD00).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              method,
                              style: const TextStyle(
                                color: Color(0xFF84BD00),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
