import 'package:flutter/material.dart';
import '../services/p2p_service.dart';
import 'p2p_buy_screen.dart';
import 'p2p_sell_screen.dart';
import 'p2p_chat_detail_screen.dart';
import 'p2p_place_order_screen.dart';

class P2PTradingOrdersScreen extends StatefulWidget {
  const P2PTradingOrdersScreen({super.key});

  @override
  State<P2PTradingOrdersScreen> createState() => _P2PTradingOrdersScreenState();
}

class _P2PTradingOrdersScreenState extends State<P2PTradingOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _myAds = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchMyAds();
  }

  Future<void> _fetchMyAds() async {
    setState(() => _isLoading = true);
    final ads = await P2PService.getMyAdvertisements();
    if (mounted) {
      setState(() {
        _myAds = ads;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text('My P2P Advertisements', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _showCreateOrderDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAdsList('buy'),
                    _buildAdsList('sell'),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12)),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(color: const Color(0xFF84BD00), borderRadius: BorderRadius.circular(12)),
        labelColor: Colors.black,
        unselectedLabelColor: const Color(0xFF8E8E93),
        tabs: const [Tab(text: 'My Buy Ads'), Tab(text: 'My Sell Ads')],
      ),
    );
  }

  Widget _buildAdsList(String type) {
    final filteredAds = _myAds.where((ad) => ad['type'] == type).toList();
    
    if (filteredAds.isEmpty) {
      return const Center(child: Text('No advertisements found', style: TextStyle(color: Colors.white54)));
    }

    return RefreshIndicator(
      onRefresh: _fetchMyAds,
      color: const Color(0xFF84BD00),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredAds.length,
        itemBuilder: (context, index) {
          final ad = filteredAds[index];
          return _buildAdCard(ad);
        },
      ),
    );
  }

  Widget _buildAdCard(dynamic ad) {
    final type = ad['type'] ?? 'buy';
    final isBuy = type == 'buy';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${ad['coin'] ?? 'USDT'} / INR',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isBuy ? const Color(0xFF84BD00).withOpacity(0.2) : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isBuy ? 'BUYING' : 'SELLING',
                  style: TextStyle(color: isBuy ? const Color(0xFF84BD00) : Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Price', '₹${ad['price']}'),
          _buildInfoRow('Amount', '${ad['amount']} ${ad['coin']}'),
          _buildInfoRow('Limits', '₹${ad['min']} - ₹${ad['max']}'),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white54, size: 14),
              const SizedBox(width: 4),
              Text('Payment Time: ${ad['paymentTime']} min', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showCreateOrderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Create New Advertisement', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Buy USDT', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const P2PBuyScreen()));
              },
            ),
            ListTile(
              title: const Text('Sell USDT', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const P2PSellScreen()));
              },
            ),
          ],
        ),
      ),
    ).then((_) => _fetchMyAds());
  }
}
