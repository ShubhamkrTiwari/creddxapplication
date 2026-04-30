import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/wallet_service.dart';
import '../services/unified_wallet_service.dart' as unified;
import '../services/socket_service.dart';
import '../services/auto_refresh_service.dart';

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
  double _toAmount = 0;
  double _inrToUsdtRate = 0.011; // Fixed conversion rate
  double _usdtToInrRate = 90.0; // Fixed conversion rate
  double _inrBalance = 0.00;
  double _usdtBalance = 0.00;
  bool _isLoading = false;
  bool _isLoadingRate = false;
  StreamSubscription? _balanceSubscription;
  StreamSubscription? _socketBalanceSubscription;

  Future<void> _bruteForceBalanceFetch() async {
    try {
      final bruteForce = await WalletService.getINRBalance();
      if (bruteForce['success'] == true && mounted) {
        setState(() {
          _inrBalance = bruteForce['inrBalance'] ?? 0.0;
        });
        debugPrint('ConversionScreen: Brute-force INR fetch successful: $_inrBalance');
      }
    } catch (e) {
      debugPrint('ConversionScreen: Brute-force error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _fromController.addListener(_calculateConversion);
    _loadConversionRates();
    _setupStreams();
    
    // Immediate brute-force fetch
    _bruteForceBalanceFetch();
    
    // Trigger socket requests to force immediate balance update
    SocketService.requestWalletSummary();
    SocketService.requestWalletBalance();

    // Regular initialization
    unified.UnifiedWalletService.initialize().then((_) {
      unified.UnifiedWalletService.refreshAllBalances();
      
      if (mounted) {
        setState(() {
          _inrBalance = unified.UnifiedWalletService.totalINRBalance;
          _usdtBalance = unified.UnifiedWalletService.mainUSDTBalance;
        });
      }
    });

    // Secondary brute-force after delay
    Future.delayed(const Duration(seconds: 2), _bruteForceBalanceFetch);
  }

  /// Set up real-time balance streams — mirrors WalletScreen._setupStreams()
  void _setupStreams() {
    // 1. Listen to UnifiedWalletService stream for real-time balance updates
    _balanceSubscription = unified.UnifiedWalletService.walletBalanceStream.listen((balance) {
      if (mounted) {
        // Use totalINRBalance to ensure we see all available INR (Main + Bot + Spot)
        final newInrBalance = unified.UnifiedWalletService.totalINRBalance;
        final newUsdtBalance = unified.UnifiedWalletService.mainUSDTBalance;

        setState(() {
          _inrBalance = newInrBalance;
          _usdtBalance = newUsdtBalance;
        });
      }
    });

    // 2. Initial value from service cache
    final cachedInr = unified.UnifiedWalletService.totalINRBalance;
    final cachedUsdt = unified.UnifiedWalletService.mainUSDTBalance;

    setState(() {
      _inrBalance = cachedInr;
      _usdtBalance = cachedUsdt;
    });
  }


  
  @override
  void dispose() {
    _balanceSubscription?.cancel();
    _socketBalanceSubscription?.cancel();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Trigger a fresh fetch whenever dependencies change (e.g. route resumes)
    unified.UnifiedWalletService.refreshAllBalances();
  }
  
  Future<void> _loadConversionRates() async {
    try {
      debugPrint('=== Using fixed conversion rates ===');
      setState(() => _isLoadingRate = true);
      
      // Use fixed rates as specified: 
      // INR to USDT buy rate: 92
      // USDT to INR sell rate: 90
      const fixedInrToUsdtRate = 92.0; 
      const fixedUsdtToInrRate = 90.0; 
      
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
  
  Future<void> _performConversion() async {
    final amount = double.tryParse(_fromController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    // Always read the latest live balance from the service at conversion time.
    setState(() => _isLoading = true);
    
    // We only care about main balances for conversion
    final liveInrBalance = unified.UnifiedWalletService.totalINRBalance;
    final liveMainUsdt = unified.UnifiedWalletService.mainUSDTBalance;

    debugPrint('_performConversion: liveINR=$liveInrBalance, liveMainUSDT=$liveMainUsdt, amount=$amount, from=$_fromCurrency');

    // Sync local state so the UI reflects the latest values too
    if (mounted) {
      setState(() {
        _inrBalance = liveInrBalance;
        _usdtBalance = liveMainUsdt;
      });
    }

    // Check if user has sufficient balance using live values
    if (_fromCurrency == 'INR' && amount > liveInrBalance) {
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient INR balance. Available: ₹${liveInrBalance.toStringAsFixed(2)}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_fromCurrency == 'USDT' && amount > liveMainUsdt) {
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient USDT balance. Available: ${liveMainUsdt.toStringAsFixed(4)} USDT'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      final isInrToUsdt = _fromCurrency == 'INR';
      Map<String, dynamic> result;

      if (isInrToUsdt) {
        result = await WalletService.convertINRtoUSDT(amount: amount);
      } else {
        result = await WalletService.convertUSDTtoINR(amount: amount);
      }
      
      if (result['success'] == true) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversion successful!'),
            backgroundColor: Color(0xFF84BD00),
          ),
        );
        
        // IMMEDIATE BALANCE REFRESH AFTER CONVERSION
        debugPrint('ConversionScreen: Triggering immediate balance refresh after conversion...');
        final previousInrBalance = _inrBalance;
        final previousUsdtBalance = _usdtBalance;
        final conversionAmount = amount;
        final conversionWasInrToUsdt = isInrToUsdt;
        
        // Wait a moment for backend to process the conversion
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Multiple attempts to refresh balances
        for (int attempt = 1; attempt <= 3; attempt++) {
          debugPrint('ConversionScreen: Balance refresh attempt $attempt...');
          
          await Future.wait([
            unified.UnifiedWalletService.refreshAllBalances(),
            AutoRefreshService.forceRefreshAll(),
          ]);
          
          // Wait for socket updates to potentially arrive
          await Future.delayed(const Duration(milliseconds: 1000));
          
          // Check if balances actually updated
          final newInrBalance = unified.UnifiedWalletService.totalINRBalance;
          final newUsdtBalance = unified.UnifiedWalletService.mainUSDTBalance;
          
          debugPrint('ConversionScreen: After refresh attempt $attempt - INR: $newInrBalance, USDT: $newUsdtBalance');
          
          // Update local state
          if (mounted) {
            setState(() {
              _inrBalance = newInrBalance;
              _usdtBalance = newUsdtBalance;
            });
          }
          
          // If balances changed significantly, we're done
          if ((newInrBalance - previousInrBalance).abs() > 0.01 ||
              (newUsdtBalance - previousUsdtBalance).abs() > 0.01) {
            debugPrint('ConversionScreen: Balances updated successfully on attempt $attempt');
            break;
          }
          
          // If this is the last attempt, we still update with latest balances
          if (attempt == 3) {
            debugPrint('ConversionScreen: Final update with latest balances');
            
            // Manual balance calculation as fallback
            if (conversionAmount > 0) {
              if (conversionWasInrToUsdt) {
                // INR to USDT conversion
                final calculatedUsdtIncrease = conversionAmount / _inrToUsdtRate;
                final calculatedInrDecrease = conversionAmount;
                
                setState(() {
                  _inrBalance = (_inrBalance - calculatedInrDecrease).clamp(0.0, double.infinity);
                  _usdtBalance = _usdtBalance + calculatedUsdtIncrease;
                });
                
                debugPrint('ConversionScreen: Manual calculation - INR decreased by $calculatedInrDecrease, USDT increased by $calculatedUsdtIncrease');
              } else {
                // USDT to INR conversion
                final calculatedInrIncrease = conversionAmount * _usdtToInrRate;
                final calculatedUsdtDecrease = conversionAmount;
                
                setState(() {
                  _inrBalance = _inrBalance + calculatedInrIncrease;
                  _usdtBalance = (_usdtBalance - calculatedUsdtDecrease).clamp(0.0, double.infinity);
                });
                
                debugPrint('ConversionScreen: Manual calculation - USDT decreased by $calculatedUsdtDecrease, INR increased by $calculatedInrIncrease');
              }
            }
          }
        }
        _fromController.clear();
        _toController.text = '0';
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Conversion failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Conversion error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
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
      // Use dynamic conversion rates
      if (_fromCurrency == 'INR' && _toCurrency == 'USDT') {
        // INR to USDT: divide amount by the buy rate (92)
        _toAmount = amount / _inrToUsdtRate;
      } else if (_fromCurrency == 'USDT' && _toCurrency == 'INR') {
        // USDT to INR: multiply amount by the sell rate (90)
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
    // Force sync if local balance is 0 but service has value
    if (_inrBalance == 0.0 && unified.UnifiedWalletService.totalINRBalance > 0) {
      _inrBalance = unified.UnifiedWalletService.totalINRBalance;
    }
    if (_usdtBalance == 0.0 && unified.UnifiedWalletService.mainUSDTBalance > 0) {
      _usdtBalance = unified.UnifiedWalletService.mainUSDTBalance;
    }

    debugPrint('ConversionScreen: BUILD — _inrBalance: $_inrBalance, serviceInr: ${unified.UnifiedWalletService.totalINRBalance}');
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () async {
              await unified.UnifiedWalletService.refreshAllBalances();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Balances refreshed')),
                );
              }
            },
          ),
        ],
        centerTitle: true,
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await unified.UnifiedWalletService.refreshAllBalances();
          },
          color: const Color(0xFF84BD00),
          backgroundColor: const Color(0xFF1A1A1A),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                      ? (_inrBalance > 0 ? 'INR = ${_inrBalance.toStringAsFixed(2)}' : (_isLoading ? 'Syncing INR...' : 'INR = 0.00'))
                      : (_usdtBalance > 0 ? 'USDT = ${_usdtBalance.toStringAsFixed(4)}' : (_isLoading ? 'Syncing USDT...' : 'USDT = 0.00')),

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
                      ? 'INR = ${_inrBalance.toStringAsFixed(2)}' 
                      : 'USDT = ${_usdtBalance.toStringAsFixed(4)}',

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
        'Convert between INR and USDT at live market value rates. Rates are updated in real-time from global markets.',
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
              Row(
                children: [
                  Text(
                    available,
                    style: const TextStyle(
                      color: Color(0xFF84BD00), // Change to brand green for better visibility
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  if (!isReadOnly) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        if (currency == 'INR') {
                          controller.text = _inrBalance.toStringAsFixed(2);
                        } else {
                          controller.text = _usdtBalance.toStringAsFixed(4);
                        }
                      },

                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF84BD00).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF84BD00).withOpacity(0.5)),
                        ),
                        child: const Text(
                          'MAX',
                          style: TextStyle(
                            color: Color(0xFF84BD00),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
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
                ? '1 USDT = ${_inrToUsdtRate.toStringAsFixed(2)} INR'
                : '1 USDT = ${_usdtToInrRate.toStringAsFixed(2)} INR',
            isGreen: true,
          ),

          const Divider(color: Color(0xFF2A2A2C), height: 16),
          _buildDetailRow('You will receive', '${_toAmount.toStringAsFixed(4)} $_toCurrency', isBold: true),
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
