import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/p2p_service.dart';
import 'saved_payment_methods_screen.dart';

class P2PSellScreen extends StatefulWidget {
  const P2PSellScreen({super.key});

  @override
  State<P2PSellScreen> createState() => _P2PSellScreenState();
}

class _P2PSellScreenState extends State<P2PSellScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _depositController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _minLimitController = TextEditingController();
  final TextEditingController _maxLimitController = TextEditingController();
  
  String _selectedPaymentMethod = 'Bank';
  String _selectedCountry = 'India';
  bool _isLoading = false;
  String _selectedCoin = 'USDT';
  String? _errorMessage;
  List<Map<String, dynamic>> _savedPaymentMethods = [];
  bool _isPaymentMethodsLoading = true;
  List<String> _availablePaymentModes = [];

  final List<Map<String, String>> countries = [
    {'name': 'India', 'code': 'IN'},
    {'name': 'United States', 'code': 'US'},
    {'name': 'United Kingdom', 'code': 'UK'},
    {'name': 'Canada', 'code': 'CA'},
    {'name': 'Australia', 'code': 'AU'},
    {'name': 'Germany', 'code': 'DE'},
    {'name': 'France', 'code': 'FR'},
    {'name': 'United Arab Emirates', 'code': 'AE'},
    {'name': 'Singapore', 'code': 'SG'},
    {'name': 'Japan', 'code': 'JP'},
  ];

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_calculateDeposit);
    _fetchSavedPaymentMethods();
    _fetchPaymentModes();
  }

  void _calculateDeposit() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final deposit = amount * price;
    _depositController.text = deposit.toStringAsFixed(2);
    _validateAmount();
  }

  void _validateAmount() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final minLimit = double.tryParse(_minLimitController.text) ?? 0.0;
    final maxLimit = double.tryParse(_maxLimitController.text) ?? 0.0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final inrValue = amount * price;
    
    if (minLimit > 0 && inrValue < minLimit) {
      setState(() => _errorMessage = 'Amount must be between ${_minLimitController.text} and ${_maxLimitController.text} INR');
    } else if (maxLimit > 0 && inrValue > maxLimit) {
      setState(() => _errorMessage = 'Amount must be between ${_minLimitController.text} and ${_maxLimitController.text} INR');
    } else {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _fetchPaymentModes() async {
    try {
      debugPrint('Fetching payment modes for country: $_selectedCountry');
      
      // For India, show both UPI and Bank
      if (_selectedCountry == 'India') {
        setState(() {
          _availablePaymentModes = ['Bank Transfer', 'UPI Payment'];
        });
        debugPrint('Available payment modes for India: $_availablePaymentModes');
        return;
      }
      
      // For other countries, always show Bank Transfer as minimum
      setState(() {
        _availablePaymentModes = ['Bank Transfer'];
      });
      
      // Try to get additional payment modes from API
      try {
        final response = await P2PService.getPaymentModes(_selectedCountry);
        
        if (response != null && response['success'] == true) {
          final data = response['data'] ?? {};
          final modes = data['paymentModes'] ?? data['modes'] ?? [];
          
          if (modes.isNotEmpty) {
            setState(() {
              _availablePaymentModes = List<String>.from(modes);
              // Ensure Bank Transfer is always included
              if (!_availablePaymentModes.contains('Bank Transfer')) {
                _availablePaymentModes.add('Bank Transfer');
              }
            });
            debugPrint('Available payment modes from API: $_availablePaymentModes');
          } else {
            debugPrint('API returned empty modes, using Bank Transfer fallback');
          }
        } else {
          debugPrint('API call failed or returned no success, using Bank Transfer fallback');
        }
      } catch (apiError) {
        debugPrint('API call failed: $apiError, using Bank Transfer fallback');
      }
    } catch (e) {
      debugPrint('Error fetching payment modes: $e');
      // Always ensure Bank Transfer is available
      setState(() {
        _availablePaymentModes = ['Bank Transfer'];
      });
      debugPrint('Using Bank Transfer fallback due to error: $_availablePaymentModes');
    }
  }

  Future<void> _fetchSavedPaymentMethods() async {
    debugPrint('=== P2P Sell Screen: Fetching saved payment methods ===');
    try {
      debugPrint('Fetching saved payment methods...');
      
      final userDetails = await P2PService.getPaymentUserDetails();
      debugPrint('User details response: $userDetails');
      
      List<dynamic> methods = [];
      
      if (userDetails != null && userDetails['paymentMethods'] != null) {
        methods = userDetails['paymentMethods'] is List 
            ? userDetails['paymentMethods'] 
            : (userDetails['data']?['paymentMethods'] ?? []);
        debugPrint('Payment methods from user details: $methods');
      } else {
        methods = await P2PService.getPaymentMethods();
        debugPrint('Payment methods from fallback endpoint: $methods');
      }
      
      debugPrint('Total methods found: ${methods.length}');
      
      setState(() {
        _savedPaymentMethods = methods.map<Map<String, dynamic>>((method) {
          if (method['type'] == 'UPI' || method['paymentType'] == 'UPI') {
            return {
              'type': 'UPI Payment',
              'details': method['upiId'] ?? method['paymentId'] ?? 'Unknown UPI',
              'holderName': method['accountHolder'] ?? method['holderName'] ?? 'Unknown Holder',
              'isDefault': method['isDefault'] ?? method['default'] ?? false,
              'id': method['id'] ?? method['_id'],
            };
          } else if (method['type'] == 'Bank' || method['paymentType'] == 'Bank') {
            final accountNumber = method['accountNumber'] ?? '';
            final maskedNumber = accountNumber.length > 4 
                ? '****${accountNumber.substring(accountNumber.length - 4)}'
                : '****1234';
            return {
              'type': 'Bank Transfer',
              'details': '${method['bankName'] ?? method['bankName'] ?? 'Unknown Bank'} $maskedNumber',
              'holderName': method['accountHolder'] ?? method['holderName'] ?? 'Unknown Holder',
              'isDefault': method['isDefault'] ?? method['default'] ?? false,
              'id': method['id'] ?? method['_id'],
            };
          }
          return method as Map<String, dynamic>;
        }).toList();
        _isPaymentMethodsLoading = false;
        debugPrint('Processed payment methods: ${_savedPaymentMethods.length}');
        debugPrint('Payment methods list: $_savedPaymentMethods');
      });
    } catch (e) {
      debugPrint('Error fetching payment methods: $e');
      setState(() {
        _savedPaymentMethods = [];
        _isPaymentMethodsLoading = false;
      });
    }
    debugPrint('=== P2P Sell Screen: Payment methods fetch complete ===');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _depositController.dispose();
    _priceController.dispose();
    _minLimitController.dispose();
    _maxLimitController.dispose();
    super.dispose();
  }

  Future<void> _createSellAd() async {
    if (_amountController.text.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final adData = {
        "coin": _selectedCoin,
        "price": double.tryParse(_priceController.text) ?? 0.0,
        "amount": double.tryParse(_amountController.text) ?? 0.0,
        "min": double.tryParse(_minLimitController.text) ?? 0.0,
        "max": double.tryParse(_maxLimitController.text) ?? 0.0,
        "paymentMode": [_selectedPaymentMethod],
        "type": "sell",
        "paytime": 15,
        "status": "active", // Set advertisement as active
      };

      debugPrint('Creating sell advertisement with data: ${json.encode(adData)}');
      
      final success = await P2PService.createAdvertisement(adData);

      if (mounted) {
        setState(() => _isLoading = false);
        if (success['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sell advertisement created successfully!'), backgroundColor: Color(0xFF84BD00)),
          );
          
          // Clear form after successful creation
          _amountController.clear();
          _priceController.clear();
          _depositController.clear();
          _minLimitController.clear();
          _maxLimitController.clear();
          
          // Navigate back to refresh advertisements list
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create advertisement'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Sell USDT', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildAmountInput(),
                const SizedBox(height: 16),
                _buildDepositInput(),
                const SizedBox(height: 24),
                _buildCountrySelection(),
                const SizedBox(height: 24),
                _buildPlacedPaymentMethodsSection(),
                const SizedBox(height: 24),
                _buildTradeInfo(),
                const SizedBox(height: 32),
                _buildPlaceOrderButton(),
              ],
            ),
          ),
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Crypto Amount', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Enter amount', hintStyle: TextStyle(color: Color(0xFF8E8E93)), border: InputBorder.none),
                ),
              ),
              const Text('USDT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (_priceController.text.isNotEmpty)
              Text('Price: ${_priceController.text} INR', style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12))
            else
              const Text('Set price below', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
            const Text(' | ', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
            if (_minLimitController.text.isNotEmpty && _maxLimitController.text.isNotEmpty)
              Text('Limit: ${_minLimitController.text} - ${_maxLimitController.text} INR', style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12))
            else
              const Text('Set limits below', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildDepositInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Amount to Receive', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _depositController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  enabled: false,
                  decoration: const InputDecoration(hintText: '0.00', hintStyle: TextStyle(color: Color(0xFF8E8E93)), border: InputBorder.none),
                ),
              ),
              const Text('INR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCountrySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Country', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12)),
          child: DropdownButton<String>(
            value: _selectedCountry,
            isExpanded: true,
            dropdownColor: const Color(0xFF1C1C1E),
            underline: const SizedBox(),
            icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF8E8E93)),
            items: countries.map((country) {
              return DropdownMenuItem<String>(
                value: country['name'],
                child: Row(
                  children: [
                    Text(
                      country['name']!,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${country['code']})',
                      style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedCountry = value;
                });
                _fetchPaymentModes(); // Fetch payment modes for new country
                _fetchSavedPaymentMethods(); // Refresh saved payment methods
              }
            },
          ),
        ),
        if (_availablePaymentModes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Available payment modes: ${_availablePaymentModes.join(", ")}',
            style: const TextStyle(color: Color(0xFF84BD00), fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildTradeInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Trade Information', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Price per USDT', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _priceController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(hintText: '0', hintStyle: TextStyle(color: Color(0xFF8E8E93)), border: InputBorder.none, contentPadding: EdgeInsets.zero),
                      onChanged: (_) => _calculateDeposit(),
                    ),
                  ),
                  const Text('INR', style: TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF2C2C2E)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Min Limit', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _minLimitController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(hintText: '0', hintStyle: TextStyle(color: Color(0xFF8E8E93)), border: InputBorder.none, contentPadding: EdgeInsets.zero),
                      onChanged: (_) => _validateAmount(),
                    ),
                  ),
                  const Text('INR', style: TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF2C2C2E)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Max Limit', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _maxLimitController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(hintText: '0', hintStyle: TextStyle(color: Color(0xFF8E8E93)), border: InputBorder.none, contentPadding: EdgeInsets.zero),
                      onChanged: (_) => _validateAmount(),
                    ),
                  ),
                  const Text('INR', style: TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF2C2C2E)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('EST Time', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Color(0xFF84BD00), size: 16),
                      const SizedBox(width: 4),
                      Text('15 min', style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF2C2C2E)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payment Method', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF2C2C2E), borderRadius: BorderRadius.circular(8)),
                    child: DropdownButton<String>(
                      value: _selectedPaymentMethod,
                      dropdownColor: const Color(0xFF2C2C2E),
                      underline: const SizedBox(),
                      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF8E8E93)),
                      items: _availablePaymentModes.map((mode) {
                        return DropdownMenuItem<String>(
                          value: mode,
                          child: Text(mode, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _selectedPaymentMethod = value);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceOrderButton() {
    return GestureDetector(
      onTap: _errorMessage == null && _amountController.text.isNotEmpty && _priceController.text.isNotEmpty ? _createSellAd : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _errorMessage == null && _amountController.text.isNotEmpty && _priceController.text.isNotEmpty ? const Color(0xFFFF3B30) : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('Next Step', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildPlacedPaymentMethodsSection() {
    debugPrint('=== Building Placed Payment Methods Section ===');
    debugPrint('Is loading: $_isPaymentMethodsLoading');
    debugPrint('Payment methods count: ${_savedPaymentMethods.length}');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Placed Payment Methods', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SavedPaymentMethodsScreen()),
                ).then((_) => _fetchSavedPaymentMethods());
              },
              child: const Text('View All', style: TextStyle(color: Color(0xFF84BD00), fontSize: 14)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12)),
          child: _isPaymentMethodsLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00), strokeWidth: 2))
              : _savedPaymentMethods.isEmpty
                  ? _buildEmptyPaymentMethodsState()
                  : _buildSavedPaymentMethodsList(),
        ),
      ],
    );
  }

  Widget _buildEmptyPaymentMethodsState() {
    return Column(
      children: [
        Icon(Icons.payment_outlined, size: 40, color: Colors.grey[600]),
        const SizedBox(height: 8),
        Text(
          'No payment methods added',
          style: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          'Add payment methods to receive payments',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SavedPaymentMethodsScreen()),
            ).then((_) => _fetchSavedPaymentMethods());
          },
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Payment Method'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF84BD00),
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 36),
          ),
        ),
      ],
    );
  }

  Widget _buildSavedPaymentMethodsList() {
    final displayMethods = _savedPaymentMethods.take(3).toList();
    
    return Column(
      children: [
        ...displayMethods.map((method) => _buildPaymentMethodItem(method)).toList(),
        if (_savedPaymentMethods.length > 3) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SavedPaymentMethodsScreen()),
              );
            },
            child: Text(
              'View ${_savedPaymentMethods.length - 3} more',
              style: const TextStyle(color: Color(0xFF84BD00), fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentMethodItem(Map<String, dynamic> method) {
    final isDefault = method['isDefault'] ?? false;
    final type = method['type'] ?? '';
    final details = method['details'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(8),
        border: isDefault ? Border.all(color: const Color(0xFF84BD00), width: 1) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: type == 'Bank Transfer' ? Colors.blue.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              type == 'Bank Transfer' ? Icons.account_balance : Icons.phone_android,
              color: type == 'Bank Transfer' ? Colors.blue : Colors.orange,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      type,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF84BD00),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Default',
                          style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  details,
                  style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

