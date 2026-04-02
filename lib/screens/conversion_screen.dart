import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../services/user_service.dart';

class ConversionScreen extends StatefulWidget {
  const ConversionScreen({super.key});

  @override
  State<ConversionScreen> createState() => _ConversionScreenState();
}

class _ConversionScreenState extends State<ConversionScreen> {
  final TextEditingController _fromController = TextEditingController(text: '0.00');
  final TextEditingController _toController = TextEditingController(text: '0');
  
  String _fromCurrency = 'INR';
  String _toCurrency = 'USDT';
  double _fromAmount = 0.00;
  double _toAmount = 0;
  double _conversionRate = 0.012;
  double _inrBalance = 0.00;
  double _usdtBalance = 0.00;
  bool _isLoading = false;
  
  final String _baseUrl = 'http://52.66.230.156:9000';
  
  @override
  void initState() {
    super.initState();
    _fromController.addListener(_calculateConversion);
    _fetchBalances();
    _fetchExchangeRate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchBalances();
  }

  Future<void> _fetchBalances() async {
    try {
      final token = await UserService().getToken();
      final response = await http.get(
        Uri.parse('http://52.66.230.156:8085/wallet/v1/wallet/all-wallet-balance'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Wallet API Response: ${response.body}');
        if (data['success'] == true) {
          setState(() {
            _inrBalance = double.tryParse(data['data']['inr_balance']?.toString() ?? '0') ?? 0;
            _usdtBalance = double.tryParse(data['data']['usdt_balance']?.toString() ?? '0') ?? 0;
          });
          debugPrint('Balances updated - INR: $_inrBalance, USDT: $_usdtBalance');
        }
      }
    } catch (e) {
      debugPrint('Error fetching balances: $e');
    }
  }
  
  Future<void> _fetchExchangeRate() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.coingecko.com/api/v3/simple/price?ids=tether&vs_currencies=inr'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rate = data['tether']['inr'];
        setState(() {
          _conversionRate = 1 / rate; // INR to USDT rate
        });
      }
    } catch (e) {
      debugPrint('Error fetching exchange rate: $e');
    }
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
      final token = await UserService().getToken();
      final isInrToUsdt = _fromCurrency == 'INR';
      
      final endpoint = isInrToUsdt 
          ? 'http://localhost:8085/v1/wallet/inr/convert/inr-to-usdt'
          : 'http://localhost:8085/v1/wallet/inr/convert/usdt-to-inr';
      
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'amount': amount}),
      );
      
      debugPrint('Conversion API Response: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversion successful! ${data['message'] ?? ''}'),
            backgroundColor: const Color(0xFF84BD00),
          ),
        );
        _fetchBalances();
        _fromController.clear();
        _toController.text = '0';
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Conversion failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _calculateConversion() {
    final amount = double.tryParse(_fromController.text) ?? 0;
    setState(() {
      _fromAmount = amount;
      _toAmount = amount * _conversionRate;
      _toController.text = _toAmount.toStringAsFixed(4);
    });
  }
  
  void _swapCurrencies() {
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;
      
      // Recalculate with new rate
      _conversionRate = 1 / _conversionRate;
      _calculateConversion();
    });
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
        title: const Text(
          'Conversion',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Banner
              _buildInfoBanner(),
              const SizedBox(height: 20),
              
              // From Card
              _buildConversionCard(
                label: 'From',
                available: _fromCurrency == 'INR' 
                    ? 'Available: ₹${_inrBalance.toStringAsFixed(4)}' 
                    : 'Available: ${_usdtBalance.toStringAsFixed(4)} USDT',
                controller: _fromController,
                currency: _fromCurrency,
                onCurrencyChanged: (value) {
                  setState(() => _fromCurrency = value!);
                },
              ),
              
              // Swap Button
              _buildSwapButton(),
              
              // To Card
              _buildConversionCard(
                label: 'To',
                available: _toCurrency == 'INR' 
                    ? 'Available: ₹${_inrBalance.toStringAsFixed(4)}' 
                    : 'Available: ${_usdtBalance.toStringAsFixed(4)} USDT',
                controller: _toController,
                currency: _toCurrency,
                onCurrencyChanged: (value) {
                  setState(() => _toCurrency = value!);
                },
                isReadOnly: true,
              ),
              
              const SizedBox(height: 20),
              
              // Conversion Details
              _buildConversionDetails(),
              
              const SizedBox(height: 30),
              
              // Conversion Button
              _buildConversionButton(),
              
              const SizedBox(height: 16),
              
              // Disclaimer
              _buildDisclaimer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF84BD00).withOpacity(0.3), width: 1),
      ),
      child: const Text(
        'Convert between INR and USDT instantly at real-time market rates. No trading fees are applied. Final value may vary slightly depending on market movement.',
        style: TextStyle(
          color: Color(0xFF84BD00),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildConversionCard({
    required String label,
    required String available,
    required TextEditingController controller,
    required String currency,
    required ValueChanged<String?> onCurrencyChanged,
    bool isReadOnly = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2C), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
              Text(
                'Available: $available',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Amount Input Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  readOnly: isReadOnly,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                ),
              ),
              
              // Currency Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2C),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currency,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwapButton() {
    return Center(
      child: GestureDetector(
        onTap: _swapCurrencies,
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2C),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF3A3A3C), width: 1),
          ),
          child: const Icon(
            Icons.sync_alt,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildConversionDetails() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2C), width: 1),
      ),
      child: Column(
        children: [
          _buildDetailRow('Conversion Fee', '0%', isGreen: true),
          const Divider(color: Color(0xFF2A2A2C), height: 16),
          _buildDetailRow('Price Type', 'Real-time market price'),
          const Divider(color: Color(0xFF2A2A2C), height: 16),
          _buildDetailRow('You will receive', '${_toAmount.toStringAsFixed(4)} USDT', isBold: true),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isGreen = false, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isGreen ? const Color(0xFF00C087) : Colors.white,
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildConversionButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _performConversion,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF84BD00), Color(0xFF6A9A00)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Conversion',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return const Text(
      'Conversion happens instantly at current market rate. Final value may slightly vary.',
      style: TextStyle(
        color: Colors.white54,
        fontSize: 12,
      ),
      textAlign: TextAlign.center,
    );
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }
}
