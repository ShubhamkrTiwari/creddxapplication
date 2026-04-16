import 'package:flutter/material.dart';
import '../services/p2p_service.dart';
import '../services/user_service.dart';
import '../widgets/bitcoin_loading_indicator.dart';
import 'p2p_chat_list_screen.dart';
import 'p2p_place_order_screen.dart';
import 'order_history_screen.dart';
import 'merchant_application_screen.dart';
import 'p2p_trading_orders_screen.dart';
import 'p2p_buy_screen.dart';
import 'p2p_sell_screen.dart';
import 'create_advertisement_screen.dart';
import 'p2p_user_profile_screen.dart';

class P2PTradingScreen extends StatefulWidget {
  const P2PTradingScreen({super.key});

  @override
  State<P2PTradingScreen> createState() => _P2PTradingScreenState();
}

class _P2PTradingScreenState extends State<P2PTradingScreen> {
  bool _isBuySelected = true;
  String _selectedCrypto = 'USDT';
  List<dynamic> _cryptoList = [];
  bool _isLoading = true;
  List<dynamic> _offers = [];
  
  // Filter states
  final TextEditingController _amountController = TextEditingController();
  String _selectedFiat = 'INR';
  String _selectedPayment = 'All';
  String _selectedCountry = 'All';
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      // Step 1: Fetch Coins first
      _cryptoList = await P2PService.getP2PCoins();
      print('DEBUG: Real API Crypto list length: ${_cryptoList.length}');

      // Set default crypto if empty
      if (_cryptoList.isEmpty) {
        _cryptoList = [
          {'_id': 'USDT', 'coinSymbol': 'USDT', 'coinName': 'Tether', 'icon': ''},
          {'_id': 'BTC', 'coinSymbol': 'BTC', 'coinName': 'Bitcoin', 'icon': ''},
          {'_id': 'ETH', 'coinSymbol': 'ETH', 'coinName': 'Ethereum', 'icon': ''},
        ];
      }

      // Find selected coin's id - try multiple possible field names
      String coinId = _selectedCrypto; // fallback to symbol
      final selectedCoin = _cryptoList.firstWhere(
        (c) => (c['coinSymbol'] ?? c['symbol'] ?? '') == _selectedCrypto,
        orElse: () => null,
      );
      if (selectedCoin != null) {
        coinId = selectedCoin['_id']?.toString() ??
                 selectedCoin['id']?.toString() ??
                 selectedCoin['coinId']?.toString() ??
                 selectedCoin['coinSymbol']?.toString() ??
                 _selectedCrypto;
      }
      print('DEBUG: Selected crypto: $_selectedCrypto, CoinId: $coinId');

      // Step 2: Fetch Ads with proper coinId and direction
      // direction: 1 = Buy ads (posted by buyers), 2 = Sell ads (posted by sellers)
      // When user wants to Buy -> show Sell ads (direction: 2)
      // When user wants to Sell -> show Buy ads (direction: 1)
      final int direction = _isBuySelected ? 2 : 1;

      _offers = await P2PService.getAllAdvertisements(
        coin: coinId,
        direction: direction,
      );

      // Fallback: If no ads found with coinId, try with coinSymbol
      if (_offers.isEmpty && coinId != _selectedCrypto) {
        print('DEBUG: No ads with coinId, trying with coinSymbol: $_selectedCrypto');
        _offers = await P2PService.getAllAdvertisements(
          coin: _selectedCrypto,
          direction: direction,
        );
      }

      print('DEBUG: Real API Offers list length: ${_offers.length}');
      print('DEBUG: Sample offer: ${_offers.isNotEmpty ? _offers[0] : 'No offers'}');

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('DEBUG: Real API fetch error: $e');
      if (mounted) {
        setState(() {
          _cryptoList = [
            {'_id': 'USDT', 'coinSymbol': 'USDT', 'coinName': 'Tether', 'icon': ''},
            {'_id': 'BTC', 'coinSymbol': 'BTC', 'coinName': 'Bitcoin', 'icon': ''},
            {'_id': 'ETH', 'coinSymbol': 'ETH', 'coinName': 'Ethereum', 'icon': ''},
          ];
          _selectedCrypto = 'USDT';
          _offers = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text('Trade USDT with P2P', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => setState(() => _showFilters = !_showFilters),
            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list, color: Colors.white),
            tooltip: 'Filters',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTypeToggle(),
          _buildCryptoSelector(),
          if (_showFilters) _buildFiltersSection(),
          Expanded(
            child: _isLoading 
                ? const Center(child: BitcoinLoadingIndicator(size: 40))
                : _buildAdsList(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _buildToggleButton('Buy', _isBuySelected, () {
            setState(() => _isBuySelected = true);
            _fetchData();
          }),
          _buildToggleButton('Sell', !_isBuySelected, () {
            setState(() => _isBuySelected = false);
            _fetchData();
          }),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? (label == 'Buy' ? const Color(0xFF84BD00) : Colors.redAccent) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: isSelected ? Colors.black : Colors.white54, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildCryptoSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _cryptoList.map((coin) {
          final symbol = coin['coinSymbol'] ?? 'USDT';
          final isSelected = _selectedCrypto == symbol;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCrypto = symbol);
              _fetchData();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isSelected ? const Color(0xFF84BD00) : Colors.transparent, width: 2)),
              ),
              child: Text(symbol, style: TextStyle(color: isSelected ? const Color(0xFF84BD00) : Colors.white54, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAdsList() {
    print('DEBUG: Building ads list with ${_offers.length} offers');
    print('DEBUG: Is buy selected: $_isBuySelected');
    print('DEBUG: Selected crypto: $_selectedCrypto');

    // API already filters by coinId and direction, so show all offers directly
    List<dynamic> filteredAds = _offers;

    if (filteredAds.isEmpty) {
      String message;
      if (_offers.isEmpty) {
        message = 'No advertisements available. Try refreshing or create a new ad.';
      } else {
        message = 'No ${_isBuySelected ? 'sell' : 'buy'} advertisements found for $_selectedCrypto. Try different filters.';
      }
      
      return RefreshIndicator(
        onRefresh: _fetchData,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Center(child: Text(message, style: const TextStyle(color: Colors.white54))),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _fetchData,
                child: const Text('Refresh'),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredAds.length,
        itemBuilder: (context, index) => _buildAdCard(filteredAds[index]),
      ),
    );
  }

  Widget _buildAdCard(dynamic ad) {
    print('DEBUG: Building ad card for: ${ad}');
    
    // Handle different field names for user/advertiser info
    final advertiser = ad['advertiser'] ?? {};
    final userName = ad['advertiserName'] ?? 
                     ad['userName'] ?? 
                     ad['name'] ?? 
                     ad['sellerName'] ?? 
                     ad['buyerName'] ??
                     advertiser['userName'] ?? 
                     advertiser['name'] ?? 
                     advertiser['firstName'] ??
                     'Trader';
    final userId = ad['userId'] ?? 
                   ad['user_id'] ?? 
                   ad['advertiserId'] ?? 
                   ad['advertiser']?['_id'] ??
                   advertiser['_id'] ??
                   ad['_id'] ?? '';
    
    // Handle different field names for completion rate/trade count from advertiser object
    final completionRate = advertiser['tradeCompletionPercentage'] ?? 
                          advertiser['completionRate'] ?? 
                          ad['tradeCompletionPercentage'] ?? 
                          ad['completionRate'] ?? 
                          ad['successRate'] ?? 
                          '98%';
    final tradeCount = advertiser['totalTrades'] ?? 
                      advertiser['tradeCount'] ?? 
                      ad['totalTrades'] ?? 
                      ad['tradeCount'] ?? 
                      ad['completedTrades'] ?? 
                      '1000+';
    
    // Handle different field names for price
    final price = ad['price'] ?? 
                  ad['rate'] ?? 
                  ad['pricePerUnit'] ?? 
                  ad['unitPrice'] ?? 89.0;
    
    // Handle different field names for limits
    final minLimit = ad['min'] ?? 
                     ad['minAmount'] ?? 
                     ad['minimumLimit'] ?? 
                     ad['minLimit'] ?? 1000;
    final maxLimit = ad['max'] ?? 
                     ad['maxAmount'] ?? 
                     ad['maximumLimit'] ?? 
                     ad['maxLimit'] ?? 50000;
    
    // Handle different field names for available amount
    final available = ad['amount'] ?? 
                      ad['availableAmount'] ?? 
                      ad['quantity'] ?? 
                      ad['available'] ?? 10000;
    
    // Handle different field names for payment methods
    var paymentModes = ad['paymentMode'] ?? 
                      ad['paymentMethods'] ?? 
                      ad['paymentMethodsList'] ?? 
                      ad['paymentOptions'] ?? 
                      ['Bank Transfer'];
    
    if (paymentModes is! List) {
      paymentModes = [paymentModes.toString()];
    }

    print('DEBUG: Parsed ad data - User: $userName, Price: $price, Available: $available');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E), 
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info row - clickable to view profile
          GestureDetector(
            onTap: () {
              debugPrint('=== Ad Clicked ===');
              debugPrint('userId extracted: $userId');
              debugPrint('userName: $userName');
              debugPrint('Full ad data: $ad');
              if (userId.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => P2PUserProfileScreen(
                      userId: userId,
                      userName: userName,
                    ),
                  ),
                );
              } else {
                debugPrint('ERROR: userId is empty!');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User ID not available')),
                );
              }
            },
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16, 
                  backgroundColor: const Color(0xFF5C4B2A), 
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'T', 
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)
                  )
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Text('$completionRate completion', style: const TextStyle(color: Color(0xFF84BD00), fontSize: 11)),
                          const SizedBox(width: 6),
                          Text('($tradeCount orders)', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          
          // Price and availability row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Price', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text('₹${price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Available: ${available.toStringAsFixed(2)} $_selectedCrypto', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('Limit: ₹${minLimit.toStringAsFixed(0)} - ₹${maxLimit.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          // Payment methods and action button
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: paymentModes.map<Widget>((mode) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF3A3A3C), width: 1),
                      ),
                      child: Text(
                        mode.toString(), 
                        style: const TextStyle(color: Colors.white70, fontSize: 10)
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final extractedAdId = ad['_id'] ?? ad['id'] ?? ad['advertisementId'] ?? '';
                  final payTime = ad['payTime'] ?? ad['paymentTime'] ?? 15;
                  debugPrint('DEBUG: Full ad data: $ad');
                  debugPrint('DEBUG: Extracted adId: $extractedAdId');
                  debugPrint('DEBUG: ad._id: ${ad['_id']}, ad.id: ${ad['id']}, ad.advertisementId: ${ad['advertisementId']}');
                  if (extractedAdId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Ad ID is missing'), backgroundColor: Colors.red));
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => P2PPlaceOrderScreen(
                        adId: extractedAdId,
                        orderType: _isBuySelected ? 'buy' : 'sell',
                        userName: userName,
                        price: price.toString(),
                        available: available.toString(),
                        paymentMethods: paymentModes.map<String>((e) => e.toString()).toList(),
                        minLimit: (minLimit is num) ? minLimit.toDouble() : double.tryParse(minLimit.toString()) ?? 100.0,
                        maxLimit: (maxLimit is num) ? maxLimit.toDouble() : double.tryParse(maxLimit.toString()) ?? 4800.0,
                        payTime: payTime is int ? payTime : int.tryParse(payTime.toString()) ?? 15,
                        advertiserId: userId.toString(),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isBuySelected ? const Color(0xFF84BD00) : Colors.redAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: const Size(50, 32),
                ),
                child: Text(
                  _isBuySelected ? 'Buy' : 'Sell', 
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filters', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          // Amount filter
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter Amount',
                    hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF84BD00)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_selectedCrypto, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Filter chips row
          Row(
            children: [
              Expanded(
                child: _buildFilterChip('Fiat', _selectedFiat, ['INR', 'USD', 'EUR', 'GBP']),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterChip('Payment', _selectedPayment, ['All', 'Bank Transfer', 'UPI', 'PayTM']),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildFilterChip('Country', _selectedCountry, ['All', 'India', 'USA', 'UK', 'Canada']),
              ),
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()), // Balance the layout
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String selectedValue, List<String> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: selectedValue,
            isExpanded: true,
            dropdownColor: const Color(0xFF2C2C2E),
            underline: const SizedBox(),
            icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF8E8E93), size: 20),
            items: options.map((option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(option, style: const TextStyle(color: Colors.white, fontSize: 12)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  if (label == 'Fiat') _selectedFiat = value;
                  if (label == 'Payment') _selectedPayment = value;
                  if (label == 'Country') _selectedCountry = value;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFF1C1C1E),
      selectedItemColor: const Color(0xFF84BD00),
      unselectedItemColor: Colors.white54,
      type: BottomNavigationBarType.fixed,
      currentIndex: 0,
      onTap: (index) async {
        switch (index) {
          case 1:
            Navigator.push(context, MaterialPageRoute(builder: (context) => const OrderHistoryScreen()));
            break;
          case 2:
            Navigator.push(context, MaterialPageRoute(builder: (context) => const MerchantApplicationScreen()));
            break;
          case 3:
            final userService = UserService();
            await userService.initUserData();
            final userId = userService.userId ?? '';
            final userName = userService.userName ?? 'User';
            if (userId.isNotEmpty && mounted) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => P2PUserProfileScreen(userId: userId, userName: userName)));
            }
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'P2P'),
        BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Orders'),
        BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'Merchant'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
      ],
    );
  }

  void _showCreateAdDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Create Advertisement', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.arrow_downward, color: Color(0xFF84BD00)),
              title: const Text('Buy USDT', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateAdvertisementScreen(initialType: 'buy')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward, color: Colors.redAccent),
              title: const Text('Sell USDT', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateAdvertisementScreen(initialType: 'sell')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.list, color: Colors.blue),
              title: const Text('My Advertisements', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const P2PTradingOrdersScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}
