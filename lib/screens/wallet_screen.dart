import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'send_screen.dart';
import 'receive_screen.dart';
import 'deposit_screen.dart';
import 'internal_transfer_screen.dart';
import 'wallet_history_screen.dart';
import '../services/wallet_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  
  bool _isLoading = true;
  String _walletAddress = '0x2340....3420';
  double _totalBalance = 0.0;
  Map<String, dynamic> _walletBalances = {};
  List<Map<String, dynamic>> _cryptoHoldings = [];
  List<Map<String, dynamic>> _transferHistory = [];
  List<Map<String, dynamic>> _transactionHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchWalletData();
  }

  String _getCoinFullName(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'BTC': return 'Bitcoin';
      case 'ETH': return 'Ethereum';
      case 'USDT': return 'Tether';
      case 'BNB': return 'Binance Coin';
      case 'SOL': return 'Solana';
      default: return symbol;
    }
  }

  Future<void> _fetchWalletData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final results = await Future.wait([
        WalletService.getAllWalletBalances(),
        WalletService.getWalletTransferHistory(),
      ]);

      final balanceResult = results[0] as Map<String, dynamic>;
      final historyResult = results[1] as Map<String, dynamic>;
      
      double totalEquityUSDT = 0.0;
      Map<String, dynamic> walletBreakdowns = {};
      Map<String, Map<String, dynamic>> allAssets = {};
      
      if (balanceResult['success'] == true && balanceResult['data'] != null) {
        final data = balanceResult['data'];
        final walletTypes = ['spot', 'p2p', 'bot', 'demo_bot', 'main'];
        
        Map<String, dynamic> walletData = {};
        
        // Normalize API data
        if (data is Map && (data.containsKey('spotBalance') || data.containsKey('mainBalance'))) {
          walletData = {
            'spot': {'balances': [{'coin': 'USDT', 'total': data['spotBalance'] ?? '0.00'}]},
            'p2p': {'balances': [{'coin': 'USDT', 'total': data['p2pBalance'] ?? '0.00'}]},
            'bot': {'balances': [{'coin': 'USDT', 'total': data['botBalance'] ?? '0.00'}]},
            'main': {'balances': [{'coin': 'USDT', 'total': data['mainBalance'] ?? '0.00'}]},
          };
        } else if (data is Map) {
          walletData = Map<String, dynamic>.from(data);
        }

        for (String type in walletTypes) {
          if (walletData[type] != null && walletData[type]['balances'] != null) {
            final balances = walletData[type]['balances'] as List;
            for (var b in balances) {
              final coin = b['coin']?.toString().toUpperCase() ?? '';
              if (coin.isEmpty) continue;
              
              final total = double.tryParse(b['total']?.toString() ?? '0') ?? 0.0;
              
              // Aggregate for Assets list
              if (allAssets.containsKey(coin)) {
                final currentAmount = double.parse(allAssets[coin]!['amount']);
                allAssets[coin]!['amount'] = (currentAmount + total).toString();
              } else {
                allAssets[coin] = {
                  'symbol': coin,
                  'name': _getCoinFullName(coin),
                  'amount': total.toString(),
                  'usdValue': 0.0, 
                  'icon': _getCoinSymbol(coin),
                  'color': _getCoinColor(coin),
                };
              }

              // Specifically track USDT for wallet breakdowns and total equity
              if (coin == 'USDT') {
                if (type != 'demo_bot') totalEquityUSDT += total;
                walletBreakdowns[type] = {
                  'total': total.toStringAsFixed(2),
                };
                allAssets[coin]!['usdValue'] = double.parse(allAssets[coin]!['amount']);
              }
            }
          } else {
            walletBreakdowns[type] = {'total': '0.00'};
          }
        }
      }

      if (historyResult['success'] == true && historyResult['data'] != null) {
        final data = historyResult['data'];
        if (data is List) {
          _transferHistory = data.map((item) => Map<String, dynamic>.from(item)).toList();
        } else if (data is Map && data['transfers'] != null) {
          _transferHistory = (data['transfers'] as List).map((item) => Map<String, dynamic>.from(item)).toList();
        }
      }

      if (mounted) {
        setState(() {
          _totalBalance = totalEquityUSDT;
          _walletBalances = walletBreakdowns;
          _cryptoHoldings = allAssets.values.toList();
          // If no assets found, put a placeholder USDT
          if (_cryptoHoldings.isEmpty) {
            _cryptoHoldings = [{
              'symbol': 'USDT',
              'name': 'Tether',
              'amount': '0.00',
              'usdValue': 0.0,
              'icon': '₮',
              'color': const Color(0xFF26A17B),
            }];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching wallet data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _copyAddress() {
    Clipboard.setData(ClipboardData(text: _walletAddress));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text(
          'Wallet',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchWalletData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
          : RefreshIndicator(
              onRefresh: _fetchWalletData,
              color: const Color(0xFF84BD00),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildBalanceSection(),
                    const SizedBox(height: 16),
                    _buildWalletBalancesSection(),
                    const SizedBox(height: 20),
                    _buildActionButtons(),
                    const SizedBox(height: 20),
                    _buildCryptoHoldings(),
                    const SizedBox(height: 20),
                    _buildHistorySection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBalanceSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF84BD00).withValues(alpha: 0.15),
            const Color(0xFF84BD00).withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF84BD00).withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Equity Balance',
                style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                _currencyFormat.format(_totalBalance),
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          GestureDetector(
            onTap: _copyAddress,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _walletAddress,
                    style: const TextStyle(color: Colors.white38, fontSize: 9),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy, color: Color(0xFF84BD00), size: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _actionButton(Icons.send, 'Send', () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const SendScreen()));
        }),
        _actionButton(Icons.request_page, 'Receive', () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ReceiveScreen()));
        }),
        _actionButton(Icons.add_circle_outline, 'Deposit', () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const DepositScreen()));
        }),
        _actionButton(Icons.swap_horiz, 'Transfer', () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const InternalTransferScreen())).then((_) => _fetchWalletData());
        }),
      ],
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Icon(icon, color: const Color(0xFF84BD00), size: 20),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildWalletBalancesSection() {
    final walletTypes = [
      {'code': 'main', 'name': 'Main', 'icon': Icons.account_balance},
      {'code': 'spot', 'name': 'Spot', 'icon': Icons.trending_up},
      {'code': 'p2p', 'name': 'P2P', 'icon': Icons.people},
      {'code': 'bot', 'name': 'Bot', 'icon': Icons.smart_toy},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Wallets',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.8,
          ),
          itemCount: walletTypes.length,
          itemBuilder: (context, index) {
            final wallet = walletTypes[index];
            final walletCode = wallet['code'] as String;
            final balance = _walletBalances[walletCode] ?? {'total': '0.00'};
            
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF84BD00).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(wallet['icon'] as IconData, color: const Color(0xFF84BD00), size: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          wallet['name'] as String,
                          style: const TextStyle(color: Colors.white54, fontSize: 9),
                        ),
                        Text(
                          '${balance['total']}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCryptoHoldings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assets',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ..._cryptoHoldings.map((crypto) => _cryptoListItem(crypto)).toList(),
      ],
    );
  }

  Widget _cryptoListItem(Map<String, dynamic> crypto) {
    final amount = double.tryParse(crypto['amount'].toString()) ?? 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: crypto['color'].withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                crypto['icon'],
                style: TextStyle(
                  color: crypto['color'],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  crypto['symbol'],
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  crypto['name'],
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount.toStringAsFixed(coinDecimals(crypto['symbol'])),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                _currencyFormat.format(crypto['usdValue']),
                style: const TextStyle(color: Color(0xFF84BD00), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int coinDecimals(String symbol) {
    if (symbol.toUpperCase() == 'BTC' || symbol.toUpperCase() == 'ETH') return 8;
    return 2;
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF84BD00),
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: const Color(0xFF84BD00),
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Transfer'),
            Tab(text: 'Transaction'),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 300,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTransferHistory(),
              _buildTransactionHistory(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransferHistory() {
    if (_transferHistory.isEmpty) {
      return const Center(child: Text('No transfers found', style: TextStyle(color: Colors.white54, fontSize: 11)));
    }
    return ListView.builder(
      itemCount: _transferHistory.length,
      itemBuilder: (context, index) {
        final transfer = _transferHistory[index];
        return _transferHistoryItem(transfer);
      },
    );
  }

  Widget _buildTransactionHistory() {
    if (_transactionHistory.isEmpty) {
      return const Center(child: Text('No transactions found', style: TextStyle(color: Colors.white54, fontSize: 11)));
    }
    return ListView.builder(
      itemCount: _transactionHistory.length,
      itemBuilder: (context, index) {
        final transaction = _transactionHistory[index];
        return _transactionHistoryItem(transaction);
      },
    );
  }

  Widget _transferHistoryItem(Map<String, dynamic> transfer) {
    final String fromWallet = transfer['fromWallet']?.toString() ?? 'Unknown';
    final String toWallet = transfer['toWallet']?.toString() ?? 'Unknown';
    final String coin = transfer['coin']?.toString() ?? '';
    final double amount = double.tryParse(transfer['amount']?.toString() ?? '0') ?? 0;
    final DateTime date = transfer['createdAt'] != null 
        ? DateTime.parse(transfer['createdAt'])
        : DateTime.now();
    final String dateStr = DateFormat('dd MMM, HH:mm').format(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getCoinColor(coin).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(Icons.swap_horiz, color: _getCoinColor(coin), size: 16),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${fromWallet.toUpperCase()} → ${toWallet.toUpperCase()}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(color: Colors.white54, fontSize: 9),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${amount.toString()} $coin',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Completed',
                  style: TextStyle(color: Color(0xFF84BD00), fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getCoinSymbol(String coin) {
    switch (coin.toUpperCase()) {
      case 'BTC': return '₿';
      case 'ETH': return 'Ξ';
      case 'USDT': return '₮';
      default: return coin.isNotEmpty ? coin.substring(0, 1).toUpperCase() : '?';
    }
  }

  Color _getCoinColor(String coin) {
    switch (coin.toUpperCase()) {
      case 'BTC': return const Color(0xFFF7931A);
      case 'ETH': return const Color(0xFF627EEA);
      case 'USDT': return const Color(0xFF26A17B);
      default: return const Color(0xFF84BD00);
    }
  }

  Widget _transactionHistoryItem(Map<String, dynamic> transaction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF84BD00).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history, color: Color(0xFF84BD00), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['type'] ?? 'Transaction',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  transaction['date'] ?? '',
                  style: const TextStyle(color: Colors.white54, fontSize: 9),
                ),
              ],
            ),
          ),
          Text(
            transaction['amount'] ?? '',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
