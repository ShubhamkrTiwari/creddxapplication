import 'package:flutter/material.dart';
import '../services/unified_wallet_service.dart';
import 'conversion_screen.dart';
import 'deposit_screen.dart';

class UnifiedWalletScreen extends StatefulWidget {
  const UnifiedWalletScreen({super.key});

  @override
  State<UnifiedWalletScreen> createState() => _UnifiedWalletScreenState();
}

class _UnifiedWalletScreenState extends State<UnifiedWalletScreen> {
  double _inrBalance = 0.0;
  double _usdtBalance = 0.0;
  double _conversionRate = 90.0; // 1 USDT = 90 INR
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWallet();
  }

  Future<void> _initializeWallet() async {
    await UnifiedWalletService.initialize();
    _fetchBalances();
    
    // Listen to balance updates
    UnifiedWalletService.walletBalanceStream.listen((_) {
      if (mounted) {
        _fetchBalances();
      }
    });
  }

  void _fetchBalances() {
    setState(() {
      _inrBalance = UnifiedWalletService.totalINRBalance;
      _usdtBalance = UnifiedWalletService.totalUSDTBalance;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1F26),
        elevation: 0,
        title: const Text(
          'Wallet',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // INR Balance Card
                  _buildBalanceCard(
                    currency: 'INR',
                    balance: _inrBalance,
                    symbol: '₹',
                    color: const Color(0xFF4CAF50),
                  ),
                  const SizedBox(height: 16),
                  
                  // USDT Balance Card
                  _buildBalanceCard(
                    currency: 'USDT',
                    balance: _usdtBalance,
                    symbol: 'T',
                    color: const Color(0xFF26A17B),
                  ),
                  const SizedBox(height: 24),
                  
                  // Conversion Rate
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F26),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2A3038)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Conversion Rate',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '1 USDT = ₹$_conversionRate',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '1 INR = ${(1 / _conversionRate).toStringAsFixed(4)} USDT',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          label: 'Add Funds',
                          icon: Icons.add,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DepositScreen(),
                              ),
                            );
                          },
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionButton(
                          label: 'Convert',
                          icon: Icons.swap_horiz,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ConversionScreen(),
                              ),
                            );
                          },
                          color: const Color(0xFF2196F3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceCard({
    required String currency,
    required double balance,
    required String symbol,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A3038)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    symbol,
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                currency,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Available Balance',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currency == 'INR'
                ? '₹${balance.toStringAsFixed(2)}'
                : '${balance.toStringAsFixed(4)} $currency',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
