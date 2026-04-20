import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../services/socket_service.dart';
import '../services/user_service.dart';
import '../services/wallet_service.dart';
import '../services/auth_service.dart';

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
  double _inrToUsdtRate = 0.011; // Fixed conversion rate: 1 INR = 0.011 USDT (1/90)
  double _usdtToInrRate = 90.0; // Fixed conversion rate: 1 USDT = 90 INR
  double _inrBalance = 0.00;
  double _usdtBalance = 0.00;
  double _totalUsdtBalance = 0.00; // Total USDT across all wallets
  bool _isLoading = false;
  bool _isLoadingRate = false;
  StreamSubscription? _balanceSubscription;
  
  // Base URL for wallet APIs (use same as WalletService)
  static const String _baseUrl = 'https://api11.hathmetech.com/api';
  // Conversion API endpoints
  static const String _inrToUsdtApiUrl = '$_baseUrl/wallet/v1/wallet/inr/convert/inr-to-usdt';
  static const String _usdtToInrApiUrl = '$_baseUrl/wallet/v1/wallet/inr/convert/usdt-to-inr';
  
  @override
  void initState() {
    super.initState();
    _fromController.addListener(_calculateConversion);
    _fetchBalances();
    _loadConversionRates();
    _subscribeToBalanceUpdates();
  }
  
  void _subscribeToBalanceUpdates() {
    _balanceSubscription = SocketService.balanceStream.listen((data) {
      if (mounted && data['type'] == 'balance_update') {
        debugPrint('ConversionScreen: Received balance update via Socket');
        final payload = data['data'] ?? data;
        
        setState(() {
          // If it's a spot balance update or has USDT info
          if (payload['wallet_type'] == 'spot' || payload['usdt_available'] != null) {
            _usdtBalance = double.tryParse(payload['usdt_available']?.toString() ?? 
                           payload['available']?.toString() ?? '0') ?? _usdtBalance;
            
            // Re-calculate total USDT balance if spot updated
            // Note: In a real app, you'd want to keep track of other wallets too
            // for now we'll just update this one as it's the most frequent
            _totalUsdtBalance = _usdtBalance; 
          }
          
          // If it's an INR balance update (if supported by socket)
          if (payload['asset']?.toString().toUpperCase() == 'INR' || payload['inr_available'] != null) {
             _inrBalance = double.tryParse(payload['inr_available']?.toString() ?? 
                           payload['available']?.toString() ?? '0') ?? _inrBalance;
          }
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchBalances();
  }

  Future<void> _fetchBalances() async {
    try {
      debugPrint('=== Fetching balances via WalletService (INR excluded - socket only) ===');
      
      // Use WalletService to fetch all wallet balances
      final result = await WalletService.getAllWalletBalances();
      
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        debugPrint('=== WALLET API RESPONSE ===');
        debugPrint('Data: $data');
        
        setState(() {
          // NOTE: INR balance is NOT fetched from API - only from sockets
          // Keep existing INR balance from socket, don't overwrite with API data
          // _inrBalance remains unchanged from socket updates
          
          // Try different balance field names for USDT
          double mainUsdt = 0.0;
          if (data['mainBalance'] is Map) {
            mainUsdt = double.tryParse(data['mainBalance']['USDT']?.toString() ?? '0') ?? 0.0;
          }
          
          _usdtBalance = mainUsdt > 0 ? mainUsdt : (double.tryParse(
            data['usdt_balance']?.toString() ??
            data['usdt']?.toString() ??
            data['usdt_available']?.toString() ??
            data['main_usdt_balance']?.toString() ??
            data['total_usdt']?.toString() ??
            '0'
          ) ?? 0);

          // Calculate total USDT from all wallets if available
          double spotUsdt = double.tryParse(data['spot_usdt']?.toString() ?? '0') ?? 0;
          double p2pUsdt = double.tryParse(data['p2p_usdt']?.toString() ?? '0') ?? 0;
          double fundingUsdt = double.tryParse(data['funding_usdt']?.toString() ?? '0') ?? 0;
          
          _totalUsdtBalance = mainUsdt + spotUsdt + p2pUsdt + fundingUsdt;
          
          // If total is 0, fall back to usdtBalance
          if (_totalUsdtBalance == 0.0) {
            _totalUsdtBalance = _usdtBalance;
          }
          
          // Also update individual usdtBalance for compatibility
          if (_usdtBalance == 0.0) {
            _usdtBalance = 0.0;
          }
        });
        
        debugPrint('=== FINAL BALANCES ===');
        debugPrint('INR Balance: $_inrBalance');
        debugPrint('USDT Balance: $_usdtBalance');
        debugPrint('Total USDT Balance: $_totalUsdtBalance');
      } else {
        debugPrint('WalletService returned error: ${result['error']}');
        // Use fallback mock data when API returns error
        _setFallbackBalances();
      }
    } catch (e) {
      debugPrint('Error fetching balances: $e');
      // Use fallback mock data when API fails
      _setFallbackBalances();
    }
  }
  
  void _setFallbackBalances() {
    if (mounted) {
      setState(() {
        _inrBalance = 0.00; // Reset fallback to 0.0
        _usdtBalance = 0.00; // Reset fallback to 0.0
        _totalUsdtBalance = 0.00; // Reset fallback to 0.0
      });
      debugPrint('=== USING FALLBACK BALANCES (0.0) ===');
      debugPrint('INR Balance: $_inrBalance');
      debugPrint('USDT Balance: $_usdtBalance');
      debugPrint('Total USDT Balance: $_totalUsdtBalance');
    }
  }
  
  Future<void> _loadConversionRates() async {
    try {
      debugPrint('=== Using fixed conversion rates ===');
      setState(() => _isLoadingRate = true);
      
      // Use fixed rates as specified
      // 1 USDT = 90 INR, so 1 INR = 1/90 USDT ≈ 0.011 USDT
      const fixedInrToUsdtRate = 0.011; // 1 INR = 0.011 USDT (1/90)
      const fixedUsdtToInrRate = 90.0; // 1 USDT = 90 INR
      
      if (mounted) {
        setState(() {
          _inrToUsdtRate = fixedInrToUsdtRate;
          _usdtToInrRate = fixedUsdtToInrRate;
          _isLoadingRate = false;
        });
        // Recalculate conversion with fixed rates
        _calculateConversion();
      }
      debugPrint('Using fixed conversion rates:');
      debugPrint('1 INR = $_inrToUsdtRate USDT');
      debugPrint('1 USDT = $_usdtToInrRate INR');
    } catch (e) {
      debugPrint('Error setting conversion rates: $e');
      if (mounted) {
        setState(() => _isLoadingRate = false);
      }
    }
  }
  
  // Fetch local conversion rates as fallback
  Future<void> _fetchLocalConversionRates() async {
    try {
      final token = await AuthService.getToken();

      // Fetch INR to USDT rate
      final inrResponse = await http.get(
        Uri.parse(_inrToUsdtApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('Local INR to USDT API Response Status: ${inrResponse.statusCode}');
      debugPrint('Local INR to USDT API Response Body: ${inrResponse.body}');
      
      // Fetch USDT to INR rate
      final usdtResponse = await http.get(
        Uri.parse(_usdtToInrApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('Local USDT to INR API Response Status: ${usdtResponse.statusCode}');
      debugPrint('Local USDT to INR API Response Body: ${usdtResponse.body}');
      
      double newInrToUsdtRate = 52.0; // fallback rate
      double newUsdtToInrRate = 1.0 / 52.0; // fallback rate
      
      // Parse INR to USDT response
      if (inrResponse.statusCode == 200) {
        final data = json.decode(inrResponse.body);
        debugPrint('Parsed local INR to USDT data: $data');
        
        if (data['success'] == true && data['data'] != null) {
          final rateData = data['data'];
          if (rateData['rate'] != null) {
            newInrToUsdtRate = double.tryParse(rateData['rate'].toString()) ?? 52.0;
          } else if (rateData['conversion_rate'] != null) {
            newInrToUsdtRate = double.tryParse(rateData['conversion_rate'].toString()) ?? 52.0;
          } else if (rateData['inr_to_usdt'] != null) {
            newInrToUsdtRate = double.tryParse(rateData['inr_to_usdt'].toString()) ?? 52.0;
          }
        } else if (data['rate'] != null) {
          newInrToUsdtRate = double.tryParse(data['rate'].toString()) ?? 52.0;
        } else if (data['conversion_rate'] != null) {
          newInrToUsdtRate = double.tryParse(data['conversion_rate'].toString()) ?? 52.0;
        } else if (data['inr_to_usdt'] != null) {
          newInrToUsdtRate = double.tryParse(data['inr_to_usdt'].toString()) ?? 52.0;
        }
      }
      
      // Parse USDT to INR response
      if (usdtResponse.statusCode == 200) {
        final data = json.decode(usdtResponse.body);
        debugPrint('Parsed local USDT to INR data: $data');
        
        if (data['success'] == true && data['data'] != null) {
          final rateData = data['data'];
          if (rateData['rate'] != null) {
            newUsdtToInrRate = double.tryParse(rateData['rate'].toString()) ?? (1.0 / 52.0);
          } else if (rateData['conversion_rate'] != null) {
            newUsdtToInrRate = double.tryParse(rateData['conversion_rate'].toString()) ?? (1.0 / 52.0);
          } else if (rateData['usdt_to_inr'] != null) {
            newUsdtToInrRate = double.tryParse(rateData['usdt_to_inr'].toString()) ?? (1.0 / 52.0);
          }
        } else if (data['rate'] != null) {
          newUsdtToInrRate = double.tryParse(data['rate'].toString()) ?? (1.0 / 52.0);
        } else if (data['conversion_rate'] != null) {
          newUsdtToInrRate = double.tryParse(data['conversion_rate'].toString()) ?? (1.0 / 52.0);
        } else if (data['usdt_to_inr'] != null) {
          newUsdtToInrRate = double.tryParse(data['usdt_to_inr'].toString()) ?? (1.0 / 52.0);
        }
      }
      
      if (mounted) {
        setState(() {
          _inrToUsdtRate = newInrToUsdtRate;
          _usdtToInrRate = newUsdtToInrRate;
          _isLoadingRate = false;
        });
        // Recalculate conversion with new rates
        _calculateConversion();
      }
      debugPrint('Updated local conversion rates:');
      debugPrint('INR to USDT: $_inrToUsdtRate');
      debugPrint('USDT to INR: $_usdtToInrRate');
    } catch (e) {
      debugPrint('Error fetching local conversion rates: $e');
      if (mounted) {
        setState(() => _isLoadingRate = false);
      }
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
    
    // Check if user has sufficient balance
    if (_fromCurrency == 'INR' && amount > _inrBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient INR balance. Available: ₹${_inrBalance.toStringAsFixed(2)}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_fromCurrency == 'USDT' && amount > _totalUsdtBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient USDT balance. Total Available: ${_totalUsdtBalance.toStringAsFixed(4)} USDT'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final token = await AuthService.getToken();
      final isInrToUsdt = _fromCurrency == 'INR';
      
      // Calculate expected amount using fixed rates
      double expectedAmount = 0.0;
      if (isInrToUsdt) {
        expectedAmount = amount / _usdtToInrRate; // INR to USDT: divide by 90
      } else {
        expectedAmount = amount * _usdtToInrRate; // USDT to INR: multiply by 90
      }
      
      debugPrint('Converting $amount $_fromCurrency using fixed rates');
      debugPrint('Expected to receive: $expectedAmount $_toCurrency');
      
      // Use local API for actual conversion transaction
      final endpoint = isInrToUsdt 
          ? _inrToUsdtApiUrl
          : _usdtToInrApiUrl;
      
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'amount': amount,
          'use_fixed_rate': true, // Use fixed rates
          'inr_to_usdt_rate': _inrToUsdtRate, // 92
          'usdt_to_inr_rate': _usdtToInrRate, // 90
        }),
      ).timeout(const Duration(seconds: 30));
      
      debugPrint('Conversion API Response: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        // Verify the conversion used fixed rates
        final actualAmount = data['data']?['converted_amount'] ?? expectedAmount;
        final usedRate = data['data']?['rate'] ?? (isInrToUsdt ? _inrToUsdtRate : _usdtToInrRate);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversion successful! Fixed rate: $usedRate'),
            backgroundColor: const Color(0xFF84BD00),
          ),
        );
        
        debugPrint('Conversion completed with fixed rate: $usedRate');
        debugPrint('Actual amount received: $actualAmount');
        
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
      debugPrint('Conversion error: $e');
      String errorMessage = 'Conversion failed';
      
      if (e.toString().contains('SocketException')) {
        errorMessage = 'Network error. Please check your connection.';
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Request timed out. Please try again.';
      } else if (e.toString().contains('401')) {
        errorMessage = 'Authentication failed. Please login again.';
      } else if (e.toString().contains('403')) {
        errorMessage = 'Permission denied. Please contact support.';
      } else if (e.toString().contains('500')) {
        errorMessage = 'Server error. Please try again later.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _calculateConversion() {
    final amount = double.tryParse(_fromController.text) ?? 0;
    setState(() {
      _fromAmount = amount;
      
      // Use dynamic conversion rates
      if (_fromCurrency == 'INR' && _toCurrency == 'USDT') {
        // INR to USDT: divide amount by USDT rate (90)
        _toAmount = amount / _usdtToInrRate;
      } else if (_fromCurrency == 'USDT' && _toCurrency == 'INR') {
        // USDT to INR: multiply amount by USDT rate (90)
        _toAmount = amount * _usdtToInrRate;
      } else {
        _toAmount = amount; // fallback
      }
      
      _toController.text = _toAmount.toStringAsFixed(8);
    });
  }
  
  void _swapCurrencies() {
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;
      
      // Recalculate with swapped currencies
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
                    ? 'Available: ₹${_inrBalance.toStringAsFixed(2)}' 
                    : 'Total Available: ${_totalUsdtBalance.toStringAsFixed(4)} USDT',
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
                    ? 'Available: ₹${_inrBalance.toStringAsFixed(2)}' 
                    : 'Total Available: ${_totalUsdtBalance.toStringAsFixed(4)} USDT',
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
        'Convert between INR and USDT at live market value rates. Rates are updated in real-time from global markets. Final value may vary slightly depending on market movement.',
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
                available,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailRow('Conversion Fee', '0%', isGreen: true),
              GestureDetector(
                onTap: _loadConversionRates,
                child: _isLoadingRate 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Color(0xFF84BD00),
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.refresh,
                        color: Color(0xFF84BD00),
                        size: 16,
                      ),
              ),
            ],
          ),
          const Divider(color: Color(0xFF2A2A2C), height: 16),
          _buildDetailRow('Price Type', 'Live market value', isGreen: true),
          const Divider(color: Color(0xFF2A2A2C), height: 16),
          _buildDetailRow(
            'Exchange Rate', 
            _fromCurrency == 'INR' 
                ? '1 INR = ${_inrToUsdtRate.toStringAsFixed(4)} USDT'
                : '1 USDT = ${_usdtToInrRate.toStringAsFixed(2)} INR',
            isGreen: true,
          ),
          const Divider(color: Color(0xFF2A2A2C), height: 16),
          _buildDetailRow('You will receive', '${_toAmount.toStringAsFixed(4)} ${_toCurrency}', isBold: true),
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
}
