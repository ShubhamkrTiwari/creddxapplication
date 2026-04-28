import 'package:flutter/material.dart';
import 'deposit_address_screen.dart';
import 'crypto_deposit_history_screen.dart';
import '../services/wallet_service.dart';
import '../services/user_service.dart';
import '../widgets/bitcoin_loading_indicator.dart';
import 'user_profile_screen.dart';

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
  
  final UserService _userService = UserService();
  
  @override
  void initState() {
    super.initState();
    _fetchData();
  }
  
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      print('=== Fetching deposit data ===');
      // Fetch coins with their networks from API
      final List<Map<String, dynamic>> coinsData = await WalletService.getAllCoins();
      print('Coins data count: ${coinsData.length}');
      
      if (mounted) {
        setState(() {
          // Parse all coins first
          final allCoins = coinsData.map((data) => Coin.fromJson(data)).toList();
          print('All coins parsed: ${allCoins.length}');
          
          // Filter only USDT coins
          _coins = allCoins.where((coin) => coin.symbol.toUpperCase() == 'USDT').toList();
          print('Filtered USDT coins: ${_coins.length}');
          
          // Get networks from the first USDT coin (which has networks embedded)
          if (_coins.isNotEmpty) {
            final usdtCoin = _coins.first;
            _selectedCoinId = usdtCoin.id;
            
            // Extract networks from the coin's networks field
            _networks = usdtCoin.networks.where((n) => n.isActive).toList();
            print('Networks from USDT coin: ${_networks.length}');
            for (var net in _networks) {
              print('Network: ${net.name} (${net.id})');
            }
            
            if (_networks.isNotEmpty) {
              _selectedNetworkId = _networks.first.id;
            }
          }
          
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('Error fetching data: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _coins = [];
          _networks = [];
          _isLoading = false;
        });
      }
    }
  }

  
  void _updateNetworksForCoin(Coin coin) {
    // Networks are now fetched separately from sub-admin API
    // This method can be used for any coin-specific network filtering if needed
    if (_networks.isNotEmpty) {
      setState(() {
        _selectedNetworkId = _networks.first.id;
      });
    }
  }

  // Check if profile is complete
  bool _isProfileComplete() {
    return _userService.hasEmail() && 
           _userService.userPhone != null && 
           _userService.userPhone!.isNotEmpty;
  }

  // Validate profile before proceeding
  bool _validateUserRequirements() {
    if (!_isProfileComplete()) {
      _showProfileRequiredDialog();
      return false;
    }
    return true;
  }

  // Show profile required dialog
  void _showProfileRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Profile Incomplete',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Please complete your profile (email and phone number) to access deposit features.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const UserProfileScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF84BD00),
            ),
            child: const Text('Complete Profile', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
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
        ? const Center(child: BitcoinLoadingIndicator(size: 40))
        : _coins.isEmpty 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'No coins available',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Unable to fetch coins from server',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF84BD00),
                    ),
                    child: const Text('Retry', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            )
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
        CircleAvatar(
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
    return Row(
      children: [
        const Icon(Icons.hub_outlined, color: Color(0xFF84BD00), size: 18),
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
          if (_validateUserRequirements()) {
            final network = _networks.firstWhere((n) => n.id == networkId);
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => DepositAddressScreen(
              coin: coin.symbol, 
              coinId: coin.id,
              network: network.name,
              networkId: network.id,
            )));
          }
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
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const CryptoDepositHistoryScreen(),
            ),
          );
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
