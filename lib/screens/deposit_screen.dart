import 'package:flutter/material.dart';
import 'deposit_address_screen.dart';
import 'crypto_deposit_history_screen.dart';
import '../services/wallet_service.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  String? _selectedCoinId;
  String? _selectedNetworkId;
  List<Coin> _coins = [];
  List<Network> _networks = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch coins with their networks from single API
      final List<Map<String, dynamic>> coinsData = await WalletService.getAllCoins();
      
      if (mounted) {
        setState(() {
          _coins = coinsData.map((data) => Coin.fromJson(data)).toList();
          
          // Filter only USDT coins
          _coins = _coins.where((coin) => coin.symbol.toUpperCase() == 'USDT').toList();
          
          if (_coins.isEmpty) {
            // Create fallback data with USDT only
            _coins = [
              Coin(id: '3', name: 'Tether', symbol: 'USDT', icon: 'usdt', networks: [
                Network(id: '3', name: 'Ethereum', type: 'ERC20', isActive: true),
                Network(id: '4', name: 'Binance Smart Chain', type: 'BEP20', isActive: true),
                Network(id: '5', name: 'Tron', type: 'TRC20', isActive: true),
              ]),
            ];
          }
          
          if (_coins.isNotEmpty) {
            _selectedCoinId = _coins.first.id;
            _updateNetworksForCoin(_coins.first);
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching data: $e');
      if (mounted) {
        setState(() {
          // Fallback data on error with USDT only
          _coins = [
            Coin(id: '3', name: 'Tether', symbol: 'USDT', icon: 'usdt', networks: [
              Network(id: '3', name: 'Ethereum', type: 'ERC20', isActive: true),
              Network(id: '4', name: 'Binance Smart Chain', type: 'BEP20', isActive: true),
              Network(id: '5', name: 'Tron', type: 'TRC20', isActive: true),
            ]),
          ];
          _selectedCoinId = '3';
          _updateNetworksForCoin(_coins.first);
          _isLoading = false;
        });
      }
    }
  }

  
  void _updateNetworksForCoin(Coin coin) {
    setState(() {
      // Use only active networks from the selected coin
      _networks = coin.networks.where((network) => network.isActive).toList();
      
      if (_networks.isNotEmpty) {
        _selectedNetworkId = _networks.first.id;
      } else {
        _selectedNetworkId = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Current valid selections
    final currentCoin = _coins.isEmpty ? null : _coins.firstWhere((c) => c.id == _selectedCoinId, orElse: () => _coins.first);
    final coinValue = currentCoin?.id;
    final networkValue = _networks.any((n) => n.id == _selectedNetworkId) ? _selectedNetworkId : (_networks.isNotEmpty ? _networks.first.id : null);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Deposit', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
        : Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Coin', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
                const SizedBox(height: 12),
                _buildDropdown(
                  value: coinValue,
                  hint: 'Select Coin',
                  items: _coins.map((coin) => DropdownMenuItem(
                    value: coin.id,
                    child: _buildCoinRow(coin),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedCoinId = value;
                        _updateNetworksForCoin(_coins.firstWhere((c) => c.id == value));
                      });
                    }
                  },
                ),
                const SizedBox(height: 24),
                const Text('Select Network', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
                const SizedBox(height: 12),
                _buildDropdown(
                  value: networkValue,
                  hint: 'Select Network',
                  items: _networks.map((network) => DropdownMenuItem(
                    value: network.id,
                    child: _buildNetworkRow(network),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedNetworkId = value);
                    }
                  },
                ),
                const Spacer(),
                _buildDepositButton(currentCoin, networkValue),
                const SizedBox(height: 12),
                _buildHistoryButton(),
              ],
            ),
          ),
    );
  }

  Widget _buildDropdown({required String? value, required List<DropdownMenuItem<String>> items, required void Function(String?) onChanged, String? hint}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButton<String>(
        value: value,
        items: items,
        onChanged: onChanged,
        hint: hint != null ? Text(hint, style: const TextStyle(color: Color(0xFF8E8E93))) : null,
        dropdownColor: const Color(0xFF1C1C1E),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        isExpanded: true,
        underline: const SizedBox(),
        menuMaxHeight: 400,
        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF84BD00)),
      ),
    );
  }

  Widget _buildCoinRow(Coin coin) {
    return Row(
      children: [
        coin.symbol.toUpperCase() == 'USDT'
            ? Image.asset('assets/images/usdt.png', width: 28, height: 28, fit: BoxFit.contain)
            : CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF84BD00).withOpacity(0.2),
                child: Text(coin.symbol.length > 2 ? coin.symbol.substring(0, 2).toUpperCase() : coin.symbol, style: const TextStyle(fontSize: 10, color: Color(0xFF84BD00), fontWeight: FontWeight.bold)),
              ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(coin.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
            Text(coin.symbol, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _buildNetworkRow(Network network) {
    String? logoPath;
    if (network.type.toUpperCase().contains('ERC') || network.name.toLowerCase().contains('ethereum')) {
      logoPath = 'assets/images/eth.png';
    } else if (network.type.toUpperCase().contains('BEP') || network.name.toLowerCase().contains('binance') || network.name.toLowerCase().contains('bsc')) {
      logoPath = 'assets/images/bnb.png';
    } else if (network.type.toUpperCase().contains('POLYGON') || network.name.toLowerCase().contains('polygon') || network.name.toLowerCase().contains('matic')) {
      logoPath = 'assets/images/matic.png';
    }

    return Row(
      children: [
        logoPath != null
            ? Image.asset(logoPath, width: 20, height: 20, fit: BoxFit.contain)
            : const Icon(Icons.hub_outlined, color: Color(0xFF84BD00), size: 20),
        const SizedBox(width: 12),
        Text(network.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }

  Widget _buildDepositButton(Coin? coin, String? networkId) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: (coin != null && networkId != null) ? () {
          final network = _networks.firstWhere((n) => n.id == networkId);
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => DepositAddressScreen(coin: coin.symbol, network: network.name, coinId: coin.id, networkId: network.id,)));
        } : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF84BD00),
          disabledBackgroundColor: Colors.white10,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Deposit', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildHistoryButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const CryptoDepositHistoryScreen(),
          ));
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: Color(0xFF84BD00)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('View History', style: TextStyle(color: Color(0xFF84BD00), fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
