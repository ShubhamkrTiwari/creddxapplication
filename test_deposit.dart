import 'package:flutter/material.dart';
import 'lib/screens/deposit_screen.dart';
import 'lib/services/wallet_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Creddx Deposit Test',
      theme: ThemeData(
        primarySwatch: Colors.green,
        brightness: Brightness.dark,
      ),
      home: const DepositTestScreen(),
    );
  }
}

class DepositTestScreen extends StatefulWidget {
  const DepositTestScreen({super.key});

  @override
  State<DepositTestScreen> createState() => _DepositTestScreenState();
}

class _DepositTestScreenState extends State<DepositTestScreen> {
  String _testResult = 'Test not run yet';

  Future<void> _testDepositAPIs() async {
    setState(() => _testResult = 'Testing APIs...');
    
    try {
      // Test 1: Get all coins
      final coins = await WalletService.getAllCoins();
      debugPrint('Coins fetched: ${coins.length}');
      
      // Test 2: Get deposit address for USDT on Ethereum
      final address = await WalletService.getDepositAddress(
        coin: 'USDT',
        network: 'Ethereum',
      );
      debugPrint('Deposit address: $address');
      
      setState(() {
        _testResult = '✅ APIs working!\n'
                     'Coins: ${coins.length} found\n'
                     'Deposit Address: ${address != null ? "Generated" : "Failed"}';
      });
    } catch (e) {
      setState(() => _testResult = '❌ Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text('Deposit API Test', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0D0D0D),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _testDepositAPIs,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
              ),
              child: const Text('Test Deposit APIs'),
            ),
            const SizedBox(height: 20),
            Text(
              _testResult,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const DepositScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
              ),
              child: const Text('Open Deposit Screen'),
            ),
          ],
        ),
      ),
    );
  }
}
