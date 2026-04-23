import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../services/socket_service.dart';
import '../services/user_service.dart';
import '../services/wallet_service.dart';
import '../services/auth_service.dart';
import '../services/unified_wallet_service.dart' as unified;
import '../services/temp_wallet_socket_service.dart';
import '../services/spot_socket_service.dart';

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
  StreamSubscription? _directSocketSubscription;
  
  // Base URL for wallet APIs (use same as WalletService)
  static const String _baseUrl = 'https://api11.hathmetech.com/api';
  // Conversion API endpoints
  static const String _inrToUsdtApiUrl = '$_baseUrl/wallet/v1/wallet/inr/convert/inr-to-usdt';
  static const String _usdtToInrApiUrl = '$_baseUrl/wallet/v1/wallet/inr/convert/usdt-to-inr';

  // Wallet breakdown balances
  double _mainINR = 0.00;
  double _mainUSDT = 0.00;
  double _spotUSDT = 0.00;
  double _p2pUSDT = 0.00;
  double _demoUSDT = 0.00;
  double _botUSDT = 0.00;
  
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fromController.addListener(_calculateConversion);
    _loadConversionRates();
    _initializeAndFetch();
    
    // Set up periodic refresh every 3 seconds to ensure INR balance is fetched
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        debugPrint('=== Periodic INR refresh ===');
        _fetchINRBalanceDirectly();
      }
    });
  }

  Future<void> _initializeAndFetch() async {
    debugPrint('=== CONVERSION SCREEN INIT ===');
    
    // Step 1: Websocket connect
    debugPrint('Step 1: Connecting to websocket...');
    await SocketService.connect();
    debugPrint('✅ Wallet Connected: ${SocketService.isConnected}');
    
    // Step 2: Connect wallet (emit join event happens automatically on connect in SocketService)
    debugPrint('Step 2: Join event emitted (handled by SocketService onConnect)');
    
    // Step 3: Wallet summary update socket listener
    debugPrint('Step 3: Setting up wallet summary update socket listener...');
    _subscribeToBalanceUpdates();
    
    // Step 4: Initialize UnifiedWalletService (sets up additional socket listeners)
    await unified.UnifiedWalletService.initialize();
    
    // Step 5: Request wallet balance from socket
    debugPrint('Step 5: Requesting wallet balance from socket...');
    SocketService.requestWalletBalance();
    SocketService.requestWalletSummary();
    
    // Step 6: Fetch INR balance directly from API FIRST (from mainBalance.INR)
    await _fetchInrDirectly();
    
    // Step 7: Fetch all other balances
    await _fetchBalances();
    
    // Step 8: Wait a moment for socket to receive initial balance update
    await Future.delayed(const Duration(seconds: 2));
    
    // Step 9: If INR is still 0, try fetching from socket cache
    if (_inrBalance == 0) {
      debugPrint('INR still 0 after initial fetch, trying socket cache...');
      final socketINR = unified.UnifiedWalletService.totalINRBalance;
      if (socketINR > 0 && mounted) {
        setState(() {
          _inrBalance = socketINR;
          _mainINR = unified.UnifiedWalletService.mainINRBalance;
        });
        debugPrint('✅ INR updated from socket cache: $_inrBalance');
      }
    }
  }

  // Direct INR balance fetch from API
  Future<void> _fetchINRBalanceDirectly() async {
    try {
      debugPrint('=== DIRECT INR BALANCE FETCH ===');
      final result = await WalletService.getINRBalance();
      debugPrint('INR Balance API Result: $result');
      debugPrint('Success: ${result['success']}, INR: ${result['inrBalance']}, Source: ${result['source']}');
      debugPrint('Result keys: ${result.keys.toList()}');
      
      if (result['success'] == true && result['inrBalance'] != null) {
        final inr = result['inrBalance'];
        debugPrint('Parsed INR value: $inr (type: ${inr.runtimeType}), mounted: $mounted');
        
        double inrDouble = 0.0;
        if (inr is num) {
          inrDouble = inr.toDouble();
        } else if (inr is String) {
          inrDouble = double.tryParse(inr) ?? 0.0;
        }
        
        debugPrint('Final INR double value: $inrDouble');
        
        if (mounted) {
          setState(() {
            _inrBalance = inrDouble;
            _mainINR = inrDouble;
          });
          debugPrint('✅ INR Balance updated from API: $_inrBalance');
        }
      } else {
        debugPrint('❌ INR Balance fetch failed or returned null');
        debugPrint('Error: ${result['error']}');
        // Fallback: Try to get INR from UnifiedWalletService totalINRBalance
        final fallbackINR = unified.UnifiedWalletService.totalINRBalance;
        if (fallbackINR > 0 && mounted) {
          setState(() {
            _inrBalance = fallbackINR;
            _mainINR = fallbackINR;
          });
          debugPrint('✅ INR Balance updated from UnifiedWalletService fallback: $_inrBalance');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching INR balance directly: $e');
      debugPrint('Stack trace: $stackTrace');
      // Fallback on error
      final fallbackINR = unified.UnifiedWalletService.totalINRBalance;
      if (fallbackINR > 0 && mounted) {
        setState(() {
          _inrBalance = fallbackINR;
          _mainINR = fallbackINR;
        });
        debugPrint('✅ INR Balance updated from UnifiedWalletService fallback on error: $_inrBalance');
      }
    }
  }

  Future<void> _fetchInrDirectly() async {
    try {
      debugPrint('=== DIRECT INR FETCH ===');
      // Use WalletService.getINRBalance which has better fallback logic including INR holding API
      final result = await WalletService.getINRBalance();
      debugPrint('INR Balance Result: $result');
      debugPrint('Success: ${result['success']}, INR: ${result['inrBalance']}, Source: ${result['source']}');
      
      if (result['success'] == true && result['inrBalance'] != null) {
        final inr = result['inrBalance'];
        debugPrint('INR value: $inr (type: ${inr.runtimeType})');
        
        double inrDouble = 0.0;
        if (inr is num) {
          inrDouble = inr.toDouble();
        } else if (inr is String) {
          inrDouble = double.tryParse(inr) ?? 0.0;
        }
        
        debugPrint('Parsed INR: $inrDouble');
        if (mounted) {
          setState(() {
            _inrBalance = inrDouble;
            _mainINR = inrDouble;
          });
          debugPrint('✅ INR updated from direct fetch: $_inrBalance (source: ${result['source']})');
        }
      } else {
        debugPrint('❌ INR fetch failed or returned null');
        debugPrint('Error: ${result['error']}');
        // Fallback to UnifiedWalletService
        final fallbackINR = unified.UnifiedWalletService.totalINRBalance;
        if (fallbackINR > 0 && mounted) {
          setState(() {
            _inrBalance = fallbackINR;
            _mainINR = fallbackINR;
          });
          debugPrint('✅ INR updated from UnifiedWalletService fallback: $_inrBalance');
        }
      }
    } catch (e) {
      debugPrint('❌ Error in direct INR fetch: $e');
      // Fallback to UnifiedWalletService on error
      final fallbackINR = unified.UnifiedWalletService.totalINRBalance;
      if (fallbackINR > 0 && mounted) {
        setState(() {
          _inrBalance = fallbackINR;
          _mainINR = fallbackINR;
        });
        debugPrint('✅ INR updated from UnifiedWalletService fallback on error: $_inrBalance');
      }
    }
  }
  
  void _subscribeToBalanceUpdates() {
    // Subscribe to UnifiedWalletService stream
    _balanceSubscription = unified.UnifiedWalletService.walletBalanceStream.listen((walletBalance) {
      if (mounted) {
        setState(() {
          // Use totalINRBalance which includes INR from all sources (mainBalance + INR holding API + spot + bot)
          _inrBalance = unified.UnifiedWalletService.totalINRBalance;
          _mainINR = unified.UnifiedWalletService.mainINRBalance;
          _usdtBalance = unified.UnifiedWalletService.mainUSDTBalance;
          _totalUsdtBalance = unified.UnifiedWalletService.totalUSDTBalance;
        });
        debugPrint('ConversionScreen: INR updated from UnifiedWalletService stream: $_inrBalance');
      }
    });

    // Subscribe to specific INR balance update events from wallet socket
    _directSocketSubscription = SocketService.balanceStream.listen((data) {
      debugPrint('=== CONVERSION SCREEN SOCKET UPDATE ===');
      debugPrint('Event type: ${data['type']}');
      debugPrint('Full socket data: $data');
      
      // Check for INR-specific balance updates
      if (data['type'] == 'balance_update' || data['type'] == 'wallet_summary' || data['type'] == 'wallet_summary_update') {
        final balanceData = data['data'];
        
        if (balanceData != null && balanceData is Map) {
          debugPrint('Balance data keys: ${balanceData.keys.toList()}');
          
          // Extract INR from mainBalance
          final mainBalance = balanceData['mainBalance'] ?? balanceData['main'];
          if (mainBalance != null && mainBalance is Map) {
            final inrValue = mainBalance['INR'] ?? mainBalance['inr'] ?? mainBalance['Inr'];
            if (inrValue != null && mounted) {
              double inrDouble = 0.0;
              if (inrValue is num) {
                inrDouble = inrValue.toDouble();
              } else if (inrValue is String) {
                inrDouble = double.tryParse(inrValue) ?? 0.0;
              } else if (inrValue is Map) {
                final nestedInr = inrValue['total'] ?? inrValue['balance'] ?? inrValue['available'] ?? inrValue['free'];
                inrDouble = double.tryParse(nestedInr?.toString() ?? '0') ?? 0.0;
              }
              
              if (inrDouble > 0) {
                setState(() {
                  _inrBalance = inrDouble;
                  _mainINR = inrDouble;
                });
                debugPrint('✅ ConversionScreen: INR updated from socket mainBalance: $_inrBalance');
              }
            }
          }
          
          // Also check for INR in holding/balance fields
          final inrHolding = balanceData['inrHolding'] ?? balanceData['inr'] ?? balanceData['INR'];
          if (inrHolding != null && mounted) {
            double inrDouble = 0.0;
            if (inrHolding is num) {
              inrDouble = inrHolding.toDouble();
            } else if (inrHolding is String) {
              inrDouble = double.tryParse(inrHolding) ?? 0.0;
            }
            
            if (inrDouble > 0) {
              setState(() {
                _inrBalance = inrDouble;
                _mainINR = inrDouble;
              });
              debugPrint('✅ ConversionScreen: INR updated from socket holding: $_inrBalance');
            }
          }
        }
      }
      
      // Fallback: Always check UnifiedWalletService totalINRBalance on any socket update
      if (mounted) {
        final fallbackINR = unified.UnifiedWalletService.totalINRBalance;
        if (fallbackINR > 0 && fallbackINR != _inrBalance) {
          setState(() {
            _inrBalance = fallbackINR;
            _mainINR = unified.UnifiedWalletService.mainINRBalance;
          });
          debugPrint('✅ ConversionScreen: INR updated from UnifiedWalletService fallback: $_inrBalance');
        }
      }
    });

    // Initial state from cache
    final currentBalance = unified.UnifiedWalletService.walletBalance;
    if (currentBalance?.mainBalance != null) {
      final inrValue = currentBalance!.mainBalance!['INR'] ?? currentBalance.mainBalance!['inr'];
      if (inrValue is num) {
        _inrBalance = inrValue.toDouble();
        _mainINR = inrValue.toDouble();
      }
    }
    // Fallback to totalINRBalance if mainBalance doesn't have INR
    if (_inrBalance == 0) {
      _inrBalance = unified.UnifiedWalletService.totalINRBalance;
      _mainINR = unified.UnifiedWalletService.mainINRBalance;
    }
    debugPrint('ConversionScreen: Initial main INR: $_inrBalance');
  }

  void _updateWalletBreakdown(unified.WalletBalance walletBalance) {
    // Sirf INR extract karo main balance se
    final mainBalance = walletBalance.mainBalance;
    if (mainBalance != null) {
      final inrData = mainBalance['INR'] ?? mainBalance['inr'];
      if (inrData is num) {
        _mainINR = inrData.toDouble();
        _inrBalance = inrData.toDouble(); // Available INR dikhane ke liye
      } else if (inrData is Map) {
        _mainINR = double.tryParse(inrData['total']?.toString() ?? inrData['available']?.toString() ?? '0') ?? 0.0;
        _inrBalance = _mainINR;
      }
    }
    debugPrint('ConversionScreen: INR from socket - Main: $_mainINR, Available: $_inrBalance');
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    _balanceSubscription?.cancel();
    _directSocketSubscription?.cancel();
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
      debugPrint('=== Fetching balances via unified.UnifiedWalletService ===');
      
      // First, refresh INR balance directly from API using WalletService.getINRBalance
      await _fetchInrDirectly();
      
      // Use unified.UnifiedWalletService to refresh all balances
      await unified.UnifiedWalletService.refreshAllBalances();
      
      if (mounted) {
        setState(() {
          // Use directly fetched INR, but also check UnifiedWalletService totalINRBalance
          // which includes INR from mainBalance + INR holding API + spot + bot
          final serviceINR = unified.UnifiedWalletService.totalINRBalance;
          if (serviceINR > 0) {
            _inrBalance = serviceINR;
            _mainINR = unified.UnifiedWalletService.mainINRBalance;
          }
          _usdtBalance = unified.UnifiedWalletService.mainUSDTBalance;
          _totalUsdtBalance = unified.UnifiedWalletService.totalUSDTBalance;
          
          debugPrint('=== FINAL BALANCES UPDATED ===');
          debugPrint('INR Balance: $_inrBalance (from totalINRBalance)');
          debugPrint('Main INR: $_mainINR (from mainINRBalance)');
          debugPrint('USDT Balance: $_usdtBalance');
          debugPrint('Total USDT Balance: $_totalUsdtBalance');
        });
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
          'fee': 0.0, // Conversion fee (0% as shown in UI)
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
      } else if (e.toString().contains('404')) {
        errorMessage = 'Conversion service unavailable. Please try again later.';
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
