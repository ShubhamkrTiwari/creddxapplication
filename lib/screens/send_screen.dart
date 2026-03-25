import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'confirm_order_screen.dart';
import '../services/wallet_service.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCrypto = 'BTC';
  String _selectedNetwork = 'Bitcoin Network';
  List<String> _cryptoOptions = ['BTC', 'ETH', 'USDT', 'BNB'];
  List<String> _networkOptions = ['Bitcoin Network', 'Ethereum Network', 'BNB Smart Chain'];
  List<Map<String, dynamic>> _coins = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _fetchCryptoData();
  }
  
  Future<void> _fetchCryptoData() async {
    try {
      final coins = await WalletService.getAllCoins();
      if (mounted) {
        setState(() {
          _coins = coins;
          _cryptoOptions = coins.map((coin) => (coin['symbol'] ?? 'BTC').toString()).toList();
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
        title: Text(
          'Send $_selectedCrypto',
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Crypto Selection
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      _selectedCrypto == 'BTC' ? 'assets/images/btc.png' :
                      _selectedCrypto == 'ETH' ? 'assets/images/eth.png' :
                      _selectedCrypto == 'BNB' ? 'assets/images/bnb.png' :
                      'assets/images/btc.png', // default for USDT
                      width: 20,
                      height: 20,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.currency_bitcoin, color: Colors.orange, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _isLoading 
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFF84BD00))
                        )
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCrypto,
                            dropdownColor: const Color(0xFF1A1A1A),
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            items: _cryptoOptions.map((crypto) => DropdownMenuItem(
                              value: crypto,
                              child: Text(crypto),
                            )).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCrypto = value!;
                              });
                            },
                          ),
                        ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Recipient Address
            const Text(
              'Recipient Address',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: TextField(
                controller: _recipientController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter wallet address',
                  hintStyle: const TextStyle(color: Color(0xFF6C7278)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF6C7278)),
                        onPressed: () => _scanQRCode(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.paste, color: Color(0xFF6C7278)),
                        onPressed: () async {
                          final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
                          if (clipboardData?.text != null) {
                            _recipientController.text = clipboardData!.text!;
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Network Field
            const Text(
              'Network',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: TextField(
                readOnly: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Automatically match network',
                  hintStyle: const TextStyle(color: Color(0xFF6C7278)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                  suffixIcon: Container(
                    padding: const EdgeInsets.all(8),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedNetwork,
                        dropdownColor: const Color(0xFF1A1A1A),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        items: _networkOptions.map((network) => DropdownMenuItem(
                          value: network,
                          child: Text(network),
                        )).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedNetwork = value!;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Amount
            const Text(
              'Amount',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
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
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: const TextStyle(color: Color(0xFF6C7278), fontSize: 16),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                  prefixIcon: Container(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _selectedCrypto,
                      style: const TextStyle(color: Color(0xFF6C7278), fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Balance Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Available',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const Text(
                    '100 BTC',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
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
                      const Text(
                        '0.00 BTC',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
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
                      const Text(
                        '0.00 BTC',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Send Button
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ConfirmOrderScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF84BD00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Withdraw',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
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
    _recipientController.dispose();
    _amountController.dispose();
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
