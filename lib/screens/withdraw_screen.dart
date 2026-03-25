import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'qr_scanner_screen.dart';
import '../services/wallet_service.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCoin = 'BTC';
  String _selectedNetwork = 'Bitcoin Network';
  List<Coin> _coins = [];
  List<Network> _networks = [];
  bool _isLoading = true;
  bool _isFetchingBalance = false;
  bool _isFetchingFees = false;
  double _availableBalance = 0.0;
  double _withdrawalFees = 0.0;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _fetchData();
  }
  
  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });
    
    // Fetch coins with their networks from single API
    final coinsData = await WalletService.getAllCoins();
    
    if (mounted) {
      setState(() {
        _coins = coinsData.map((data) => Coin.fromJson(data)).toList();
        
        if (_coins.isNotEmpty) {
          _selectedCoin = _coins.first.symbol;
          _updateNetworksForCoin(_coins.first);
        }
        
        _isLoading = false;
      });
      _fetchAvailableBalance();
    }
  }
  
  void _updateNetworksForCoin(Coin coin) {
    setState(() {
      // Use networks directly from the selected coin
      _networks = coin.networks.where((network) => network.isActive).toList();
      
      if (_networks.isNotEmpty) {
        _selectedNetwork = _networks.first.name;
      } else {
        _selectedNetwork = '';
      }
    });
  }
  
  void _onCoinChanged(String coinSymbol) {
    setState(() {
      _selectedCoin = coinSymbol;
      final selectedCoin = _coins.firstWhere((coin) => coin.symbol == coinSymbol);
      _updateNetworksForCoin(selectedCoin);
    });
    _fetchAvailableBalance();
  }
  
  void _onNetworkChanged(String networkName) {
    setState(() {
      _selectedNetwork = networkName;
    });
    _fetchAvailableBalance();
    _fetchWithdrawalFees();
  }
  
  Future<void> _fetchAvailableBalance() async {
    setState(() {
      _isFetchingBalance = true;
      _errorMessage = null;
    });
    
    final result = await WalletService.getAllWalletBalances();
    
    if (mounted) {
      setState(() {
        if (result['success'] == true && result['data'] != null) {
          // Extract balance from the API response
          final balanceData = result['data'];
          
          if (balanceData is Map) {
            _availableBalance = double.tryParse(balanceData['balance']?.toString() ?? '0.0') ?? 0.0;
          } else if (balanceData is List && balanceData.isNotEmpty) {
            // If it's a list, get the first item's balance
            final firstItem = balanceData[0] as Map<String, dynamic>;
            _availableBalance = double.tryParse(firstItem['balance']?.toString() ?? '0.0') ?? 0.0;
          }
        }
        _isFetchingBalance = false;
      });
    }
  }
  
  Future<void> _fetchWithdrawalFees() async {
    if (_amountController.text.isEmpty) return;
    
    setState(() {
      _isFetchingFees = true;
    });
    
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final result = await WalletService.getWithdrawalFees(
      coin: _selectedCoin,
      network: _selectedNetwork,
      amount: amount,
    );
    
    if (mounted) {
      setState(() {
        if (result != null) {
          _withdrawalFees = double.tryParse(result['fee']?.toString() ?? '0.0') ?? 0.0;
        }
        _isFetchingFees = false;
      });
    }
  }
  
  void _onAmountChanged(String value) {
    if (value.isNotEmpty) {
      _fetchWithdrawalFees();
    } else {
      setState(() {
        _withdrawalFees = 0.0;
      });
    }
  }
  
  void _setMaxAmount() {
    if (_availableBalance > 0) {
      _amountController.text = _availableBalance.toString();
      _fetchWithdrawalFees();
    }
  }
  
  Future<void> _scanQRCode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QRScannerScreen()),
    );
    
    if (result != null && result is String) {
      setState(() {
        _addressController.text = result;
      });
    }
  }
  
  Future<void> _handleWithdraw() async {
    if (_addressController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount > _availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient balance'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final result = await WalletService.withdrawCrypto(
      coin: _selectedCoin,
      network: _selectedNetwork,
      address: _addressController.text,
      amount: amount,
      otp: null,
    );
    
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Withdrawal successful'),
          backgroundColor: Color(0xFF84BD00),
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Withdrawal failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Withdraw',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading 
      ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
      : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coin Selector
              const Text(
                'Coin',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: ListTile(
                  title: Text(_selectedCoin, style: const TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6C7278)),
                  onTap: _showCoinSelector,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Address Field
              const Text(
                'Address',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: TextField(
                  controller: _addressController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Long press to paste',
                    hintStyle: const TextStyle(color: Color(0xFF6C7278)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    prefixIcon: Container(
                      padding: const EdgeInsets.all(12),
                      child: IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF6C7278), size: 20),
                        onPressed: _scanQRCode,
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Network Field
              const Text(
                'Network',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: ListTile(
                  title: Text(_selectedNetwork, style: const TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6C7278)),
                  onTap: _showNetworkSelector,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Withdrawal Amount
              const Text(
                'Withdrawal Amount',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  onChanged: _onAmountChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'Minimum 0',
                    hintStyle: const TextStyle(color: Color(0xFF6C7278), fontSize: 18),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    suffixIcon: Container(
                      padding: const EdgeInsets.all(12),
                      child: ElevatedButton(
                        onPressed: _setMaxAmount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1A1A),
                          side: const BorderSide(color: Color(0xFF6C7278)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Text(
                          '$_selectedCoin Max',
                          style: const TextStyle(color: Color(0xFF6C7278), fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Available Balance
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Color(0xFF6C7278), size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'Available: ',
                      style: TextStyle(color: Color(0xFF6C7278), fontSize: 12),
                    ),
                    _isFetchingBalance
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              color: Color(0xFF84BD00),
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            '$_availableBalance $_selectedCoin',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Summary Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Receive Amount',
                          style: TextStyle(color: Color(0xFF6C7278), fontSize: 14),
                        ),
                        Text(
                          '${(_amountController.text.isNotEmpty ? (double.tryParse(_amountController.text) ?? 0.0) - _withdrawalFees : 0.0).toStringAsFixed(6)} $_selectedCoin',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Network Fee',
                          style: TextStyle(color: Color(0xFF6C7278), fontSize: 14),
                        ),
                        _isFetchingFees
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  color: Color(0xFF84BD00),
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                '$_withdrawalFees $_selectedCoin',
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Withdraw Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _handleWithdraw,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF84BD00),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Withdraw',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }
  
  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }
  
  void _showCoinSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Coin',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ..._coins.map((coin) => ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF84BD00).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    coin.symbol.substring(0, 2).toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF84BD00),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              title: Text(
                coin.name,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              subtitle: Text(
                coin.symbol,
                style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
              ),
              onTap: () {
                Navigator.pop(context);
                _onCoinChanged(coin.symbol);
              },
            )),
          ],
        ),
      ),
    );
  }
  
  void _showNetworkSelector() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Network',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: _networks.map((network) => ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: network.isActive ? const Color(0xFF84BD00).withOpacity(0.2) : const Color(0xFF6C7278).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.network_check,
                        color: network.isActive ? const Color(0xFF84BD00) : const Color(0xFF6C7278),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      network.name,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    subtitle: Text(
                      network.type,
                      style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
                    ),
                    trailing: network.isActive
                        ? const Icon(Icons.check_circle, color: Color(0xFF84BD00), size: 20)
                        : null,
                    onTap: network.isActive
                        ? () {
                            Navigator.pop(context);
                            _onNetworkChanged(network.name);
                          }
                        : null,
                  )).toList(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF333333),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
