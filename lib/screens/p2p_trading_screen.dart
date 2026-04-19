import 'package:flutter/material.dart';
import 'package:gif/gif.dart';

class P2PTradingScreen extends StatefulWidget {
  const P2PTradingScreen({super.key});

  @override
  State<P2PTradingScreen> createState() => _P2PTradingScreenState();
}

class _P2PTradingScreenState extends State<P2PTradingScreen> with TickerProviderStateMixin {
  late GifController _gifController;

  @override
  void initState() {
    super.initState();
    _gifController = GifController(vsync: this);
  }

  @override
  void dispose() {
    _gifController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text('P2P Trading', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Center(
        child: Gif(
          controller: _gifController,
          image: const AssetImage('assets/images/comingsoon.gif'),
          autostart: Autostart.loop,
          placeholder: (context) => const Text(
            'Coming Soon',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

/*
  // All original methods preserved below for future reference when re-enabling P2P
  
  Widget _buildTypeToggle() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _buildToggleButton('Buy', _isBuySelected, () => setState(() => _isBuySelected = true)),
          _buildToggleButton('Sell', !_isBuySelected, () => setState(() => _isBuySelected = false)),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
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
            onTap: () => setState(() => _selectedCrypto = symbol),
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
    
    // API logic based filtering
    final type = _isBuySelected ? 'sell' : 'buy'; // If I want to BUY, I look for ads of people who want to SELL
    
    List<dynamic> filteredAds = [];
    
    for (var ad in _offers) {
      print('DEBUG: Processing ad: ${ad}');
      
      // Handle different field names for type
      String adType = '';
      if (ad['type'] != null) {
        adType = ad['type'].toString().toLowerCase();
      } else if (ad['tradeType'] != null) {
        adType = ad['tradeType'].toString().toLowerCase();
      } else if (ad['advertisementType'] != null) {
        adType = ad['advertisementType'].toString().toLowerCase();
      }
      
      // Handle different field names for coin
      String adCoin = '';
      if (ad['coin'] != null) {
        adCoin = ad['coin'].toString().toUpperCase();
      } else if (ad['coinSymbol'] != null) {
        adCoin = ad['coinSymbol'].toString().toUpperCase();
      } else if (ad['cryptocurrency'] != null) {
        adCoin = ad['cryptocurrency'].toString().toUpperCase();
      }
      
      print('DEBUG: Ad type: $adType, expected: $type');
      print('DEBUG: Ad coin: $adCoin, expected: $_selectedCrypto');
      
      if (adType == type && adCoin == _selectedCrypto.toUpperCase()) {
        filteredAds.add(ad);
      }
    }
    
    print('DEBUG: Filtered ads count: ${filteredAds.length}');

    if (filteredAds.isEmpty) {
      String message = 'No active advertisements found';
      
      // Check if authentication might be the issue
      if (!_isLoggedIn) {
        message = 'Please log in to view advertisements';
      } else if (_offers.isEmpty) {
        message = 'No advertisements available. Try refreshing or create a new ad.';
      } else {
        message = 'No $type advertisements found for $_selectedCrypto. Try different filters.';
      }
      
      return RefreshIndicator(
        onRefresh: _checkAuthAndFetchData,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Center(child: Text(message, style: const TextStyle(color: Colors.white54))),
            if (!_isLoggedIn)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    ).then((_) {
                      _checkAuthAndFetchData();
                    });
                  },
                  child: const Text('Login to View Ads'),
                ),
              ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _checkAuthAndFetchData,
                child: const Text('Refresh'),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _checkAuthAndFetchData,
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
                     'Trader';
    
    // Handle different field names for price
    final price = ad['price'] ?? 
                  ad['rate'] ?? 
                  ad['pricePerUnit'] ?? 
                  ad['unitPrice'] ?? 0;
    
    // Handle different field names for limits
    final minLimit = ad['min'] ?? 
                     ad['minAmount'] ?? 
                     ad['minimumLimit'] ?? 
                     ad['minLimit'] ?? 0;
    final maxLimit = ad['max'] ?? 
                     ad['maxAmount'] ?? 
                     ad['maximumLimit'] ?? 
                     ad['maxLimit'] ?? 0;
    
    // Handle different field names for available amount
    final available = ad['amount'] ?? 
                      ad['availableAmount'] ?? 
                      ad['quantity'] ?? 
                      ad['available'] ?? 0;
    
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 14, backgroundColor: const Color(0xFF5C4B2A), child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'T', style: const TextStyle(color: Colors.white, fontSize: 12))),
              const SizedBox(width: 8),
              Expanded(child: Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              const Text('98% completion', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Price', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text('₹$price', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Available: $available $_selectedCrypto', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  Text('Limit: ₹$minLimit - ₹$maxLimit', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: paymentModes.map<Widget>((mode) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                      child: Text(mode.toString(), style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    );
                  }).toList(),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => P2PPlaceOrderScreen(
                        adId: ad['_id'] ?? ad['id'] ?? ad['advertisementId'] ?? '',
                        orderType: _isBuySelected ? 'buy' : 'sell',
                        userName: userName,
                        price: price.toString(),
                        available: available.toString(),
                        paymentMethods: paymentModes.map<String>((e) => e.toString()).toList(),
                        minLimit: minLimit.toDouble(),
                        maxLimit: maxLimit.toDouble(),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isBuySelected ? const Color(0xFF84BD00) : Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                child: Text(_isBuySelected ? 'Buy' : 'Sell', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFF1C1C1E),
      selectedItemColor: const Color(0xFF84BD00),
      unselectedItemColor: Colors.white54,
      type: BottomNavigationBarType.fixed,
      currentIndex: 0,
      onTap: (index) {
        switch (index) {
          case 1:
            Navigator.push(context, MaterialPageRoute(builder: (context) => const OrderHistoryScreen()));
            break;
          case 2:
            Navigator.push(context, MaterialPageRoute(builder: (context) => const P2PChatListScreen()));
            break;
          case 3:
            Navigator.push(context, MaterialPageRoute(builder: (context) => const DisputeManagementScreen()));
            break;
          case 4:
            Navigator.push(context, MaterialPageRoute(builder: (context) => const UserProfileScreen()));
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'P2P'),
        BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Orders'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chats'),
        BottomNavigationBarItem(icon: Icon(Icons.gavel), label: 'Disputes'),
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
                Navigator.push(context, MaterialPageRoute(builder: (context) => const P2PBuyScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward, color: Colors.redAccent),
              title: const Text('Sell USDT', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const P2PSellScreen()));
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
*/
}
