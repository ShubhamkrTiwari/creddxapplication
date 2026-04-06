import 'package:flutter/material.dart';
import 'utils/coin_icon_mapper.dart';

class TestIconsScreen extends StatelessWidget {
  const TestIconsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final testCoins = ['BTC', 'ETH', 'BNB', 'SOL', 'ADA', 'DOT', 'USDT', 'USDC'];
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Coin Icons'),
        backgroundColor: const Color(0xFF1A1A1A),
      ),
      backgroundColor: const Color(0xFF0A0A0A),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: testCoins.length,
        itemBuilder: (context, index) {
          final coin = testCoins[index];
          return Card(
            color: const Color(0xFF1A1A1A),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CoinIconMapper.getCoinIcon(coin, size: 40),
              title: Text(
                coin,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'assets/images/${coin.toLowerCase()}.png',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          );
        },
      ),
    );
  }
}
