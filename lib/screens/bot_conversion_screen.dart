import 'dart:async';

import 'package:flutter/material.dart';

import '../services/bot_service.dart';
import '../services/unified_wallet_service.dart' as unified;
import 'bot_conversion_history_screen.dart';

class BotConversionScreen extends StatefulWidget {
  const BotConversionScreen({super.key});

  @override
  State<BotConversionScreen> createState() => _BotConversionScreenState();
}

class _BotConversionScreenState extends State<BotConversionScreen> {
  final TextEditingController _fromController = TextEditingController(text: '0.00');
  final TextEditingController _toController = TextEditingController(text: '0');
  
  String _fromCurrency = 'INR';
  String _toCurrency = 'USDT';
  double _toAmount = 0;
  double _inrToUsdtRate = 92.0; 
  double _usdtToInrRate = 90.0; 
  double _inrBalance = 0.00;
  double _botUsdtBalance = 0.00;
  bool _isLoading = false;
  bool _isLoadingRate = false;
  StreamSubscription? _balanceSubscription;

  @override
  void initState() {
    super.initState();
    _fromController.addListener(_calculateConversion);
    _setupStreams();
    
    // Initial fetch
    unified.UnifiedWalletService.refreshAllBalances();
    
    // Sync with service
    if (unified.UnifiedWalletService.walletBalance != null) {
      _inrBalance = unified.UnifiedWalletService.totalINRBalance;
      _botUsdtBalance = unified.UnifiedWalletService.walletBalance!.botBalance;
    }
  }

  void _setupStreams() {
    _balanceSubscription = unified.UnifiedWalletService.walletBalanceStream.listen((balance) {
      if (mounted && balance != null) {
        setState(() {
          _inrBalance = unified.UnifiedWalletService.totalINRBalance;
          _botUsdtBalance = balance.botBalance;
        });
      }
    });
  }

  @override
  void dispose() {
    _balanceSubscription?.cancel();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }
  
  void _calculateConversion() {
    final amount = double.tryParse(_fromController.text) ?? 0;
    setState(() {
      if (_fromCurrency == 'INR') {
        _toAmount = amount / _inrToUsdtRate;
      } else {
        _toAmount = amount * _usdtToInrRate;
      }
      _toController.text = _toAmount.toStringAsFixed(4);
    });
  }
  
  void _swapCurrencies() {
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;
      _calculateConversion();
    });
  }

  Future<void> _performConversion() async {
    final amount = double.tryParse(_fromController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final isInrToUsdt = _fromCurrency == 'INR';
      
      // Check balance
      if (isInrToUsdt && amount > _inrBalance) {
        throw 'Insufficient INR balance';
      } else if (!isInrToUsdt && amount > _botUsdtBalance) {
        throw 'Insufficient Bot USDT balance';
      }

      Map<String, dynamic> result;
      if (isInrToUsdt) {
        result = await BotService.convertINRtoUSDT(amount: amount);
      } else {
        result = await BotService.convertUSDTtoINR(amount: amount);
      }
      
      if (result['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversion successful!'), backgroundColor: Color(0xFF84BD00)),
        );
        
        _fromController.clear();
        _toController.text = '0';
        
        // Refresh balances
        await unified.UnifiedWalletService.refreshAllBalances();
      } else {
        throw result['error'] ?? 'Conversion failed';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Bot Conversion', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BotConversionHistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildBalanceCard(),
            const SizedBox(height: 24),
            _buildConversionSection(),
            const SizedBox(height: 32),
            _buildConversionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF84BD00).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bot USDT Balance', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 4),
                Text('${_botUsdtBalance.toStringAsFixed(2)} USDT', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('INR Balance', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 4),
                Text('₹${_inrBalance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversionSection() {
    return Column(
      children: [
        _buildInputBox(
          label: 'From',
          currency: _fromCurrency,
          controller: _fromController,
          balance: _fromCurrency == 'INR' ? _inrBalance : _botUsdtBalance,
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _swapCurrencies,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFF84BD00), shape: BoxShape.circle),
            child: const Icon(Icons.swap_vert, color: Colors.black, size: 24),
          ),
        ),
        const SizedBox(height: 12),
        _buildInputBox(
          label: 'To',
          currency: _toCurrency,
          controller: _toController,
          readOnly: true,
          balance: _toCurrency == 'INR' ? _inrBalance : _botUsdtBalance,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Exchange Rate', style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text(
                _fromCurrency == 'INR' ? '1 USDT = ₹$_inrToUsdtRate' : '1 USDT = ₹$_usdtToInrRate',
                style: const TextStyle(color: Color(0xFF84BD00), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputBox({
    required String label,
    required String currency,
    required TextEditingController controller,
    required double balance,
    bool readOnly = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              GestureDetector(
                onTap: readOnly ? null : () {
                  controller.text = balance.toStringAsFixed(2);
                },
                child: Text('Available: ${balance.toStringAsFixed(2)} $currency', style: const TextStyle(color: Color(0xFF84BD00), fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  readOnly: readOnly,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(border: InputBorder.none, hintText: '0.00', hintStyle: TextStyle(color: Colors.white24)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                child: Text(currency, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConversionButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _performConversion,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF84BD00),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
            : const Text('Convert Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
