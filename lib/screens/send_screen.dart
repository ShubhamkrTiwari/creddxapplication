import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'confirm_order_screen.dart';
import 'otp_verification_screen.dart';
import '../services/wallet_service.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> with SingleTickerProviderStateMixin {
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _recipientUidController = TextEditingController();
  final _internalAmountController = TextEditingController();
  String _selectedCrypto = 'BTC';
  String _selectedNetwork = 'Bitcoin Network';
  String _selectedInternalCoin = 'USDT';
  List<String> _cryptoOptions = ['BTC', 'ETH', 'USDT', 'BNB'];
  List<String> _networkOptions = ['Bitcoin Network', 'Ethereum Network', 'BNB Smart Chain'];
  List<Map<String, dynamic>> _coins = [];
  bool _isLoading = true;
  bool _isInternalLoading = false;
  double _availableBalance = 0.0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchCryptoData();
    _fetchBalance();
  }

  Future<void> _fetchBalance() async {
    try {
      final result = await WalletService.getAllWalletBalances();
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        double totalAvailable = 0.0;

        final walletTypeMap = {
          'spot': 'spotBalance',
          'main': 'mainBalance',
          'p2p': 'p2pBalance',
          'bot': 'botBalance',
        };

        for (String type in walletTypeMap.keys) {
          final fieldName = walletTypeMap[type]!;
          final walletData = data[fieldName];

          if (walletData != null) {
            if (walletData is Map && walletData['USDT'] != null) {
              totalAvailable += double.tryParse(walletData['USDT'].toString()) ?? 0.0;
            } else if (walletData is num) {
              totalAvailable += walletData.toDouble();
            }
          }
        }

        setState(() {
          _availableBalance = totalAvailable;
        });
      }
    } catch (e) {
      print('Error fetching balance: $e');
    }
  }

  Future<void> _sendInternalTransfer() async {
    if (_recipientUidController.text.isEmpty) {
      _showError('Please enter recipient UID');
      return;
    }

    if (_internalAmountController.text.isEmpty) {
      _showError('Please enter amount');
      return;
    }

    final amount = double.tryParse(_internalAmountController.text);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    if (amount > _availableBalance) {
      _showError('Insufficient balance');
      return;
    }

    setState(() => _isInternalLoading = true);

    try {
      final otpResult = await WalletService.sendOtp(purpose: 'internal_send');

      if (otpResult['success'] == true) {
        if (!mounted) return;

        final bool? verified = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(
              onVerify: (otp) => WalletService.internalTransfer(
                receiverUid: _recipientUidController.text.trim(),
                amount: amount,
                otp: otp,
              ),
              onResend: () => WalletService.sendOtp(purpose: 'internal_send'),
            ),
          ),
        );

        if (verified == true) {
          if (mounted) {
            _showSuccess('Transfer successful!');
            _recipientUidController.clear();
            _internalAmountController.clear();
          }
        }
      } else {
        _showError(otpResult['error'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      if (mounted) {
        _showError('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isInternalLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF84BD00),
        ),
      );
    }
  }
  
  Future<void> _fetchCryptoData() async {
    try {
      final coins = await WalletService.getAllCoins();
      if (mounted) {
        setState(() {
          _coins = coins;
          _cryptoOptions = coins.map((coin) => (coin['symbol'] ?? 'BTC').toString()).toSet().toList();
          if (!_cryptoOptions.contains(_selectedCrypto)) {
            _selectedCrypto = _cryptoOptions.isNotEmpty ? _cryptoOptions.first : 'BTC';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching crypto data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Send',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF84BD00),
          indicatorWeight: 3,
          labelColor: const Color(0xFF84BD00),
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
          tabs: const [
            Tab(text: 'Send'),
            Tab(text: 'Inter Send'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Regular Send Tab
          _buildRegularSendTab(),
          // Inter Send Tab
          _buildInterSendTab(),
        ],
      ),
    );
  }

  Widget _buildRegularSendTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF84BD00).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.access_time,
              color: Color(0xFF84BD00),
              size: 50,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Coming Soon',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'External crypto withdrawals will be available soon',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInterSendTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF84BD00).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF84BD00).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send,
                    color: Color(0xFF84BD00),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Internal Transfer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Send crypto instantly to another CreddX user with 0 fees',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Coin Selection
          const Text(
            'Select Coin',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A2C)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedInternalCoin,
                isExpanded: true,
                dropdownColor: const Color(0xFF1C1C1E),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                items: ['USDT'].map((coin) {
                  return DropdownMenuItem(
                    value: coin,
                    child: Row(
                      children: [
                        _buildCoinIcon(coin),
                        const SizedBox(width: 12),
                        Text(coin),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedInternalCoin = value!;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Recipient UID
          const Text(
            'Recipient UID',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A2C)),
            ),
            child: TextField(
              controller: _recipientUidController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter recipient UID (e.g., CRDX123456)',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.paste, color: Color(0xFF84BD00)),
                      onPressed: () async {
                        final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
                        if (clipboardData?.text != null) {
                          _recipientUidController.text = clipboardData!.text!;
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Amount
          const Text(
            'Amount',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A2C)),
            ),
            child: TextField(
              controller: _internalAmountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: Text(
                    _selectedInternalCoin,
                    style: const TextStyle(
                      color: Color(0xFF84BD00),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Available balance
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available: ${_availableBalance.toStringAsFixed(2)} $_selectedInternalCoin',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _internalAmountController.text = _availableBalance.toStringAsFixed(2);
                  },
                  child: const Text(
                    'MAX',
                    style: TextStyle(
                      color: Color(0xFF84BD00),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Send Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isInternalLoading ? null : _sendInternalTransfer,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
                disabledBackgroundColor: const Color(0xFF84BD00).withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isInternalLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Send Now',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Info text
          Center(
            child: Text(
              'Transfers are instant and irreversible',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinIcon(String coin) {
    String imagePath = 'assets/images/';
    switch (coin) {
      case 'BTC':
        imagePath += 'btc.png';
        break;
      case 'ETH':
        imagePath += 'eth.png';
        break;
      case 'BNB':
        imagePath += 'bnb.png';
        break;
      case 'USDT':
        imagePath += 'usdt.png';
        break;
      default:
        imagePath += 'btc.png';
    }

    return Image.asset(
      imagePath,
      width: 24,
      height: 24,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF84BD00).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              coin[0],
              style: const TextStyle(
                color: Color(0xFF84BD00),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _recipientController.dispose();
    _amountController.dispose();
    _recipientUidController.dispose();
    _internalAmountController.dispose();
    super.dispose();
  }

  Future<void> _scanQRCode() async {
    // Request camera permission
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required to scan QR codes'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // Navigate to QR scan screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScanScreen()),
    );

    if (result != null && result is String) {
      _recipientController.text = result;
    }
  }
}

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  bool isScanning = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null && isScanning) {
                    setState(() {
                      isScanning = false;
                    });
                    Navigator.of(context).pop(barcode.rawValue);
                    break;
                  }
                }
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: isScanning
                  ? const Text(
                      'Scanning...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    )
                  : const Text(
                      'QR Code Found!',
                      style: TextStyle(color: Color(0xFF84BD00), fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
