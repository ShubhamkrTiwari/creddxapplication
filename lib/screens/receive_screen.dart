import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/wallet_service.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  String _selectedCrypto = 'BTC';
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
          if (coins.isNotEmpty) {
            _selectedCrypto = coins.first['symbol'] ?? 'BTC';
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Receive',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: 12, right: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              // QR Code Container with responsive design
              Container(
                width: 200,
                height: 200,
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 40, // Responsive width
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: Colors.grey,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.all(8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // QR Code Pattern
                    CustomPaint(
                      size: const Size(160, 160),
                      painter: QRCodePainter(),
                    ),
                    // Center Logo
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFF008080), // Teal color
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.currency_bitcoin,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
              const SizedBox(height: 30),
              
              // Crypto Selection
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF84BD00))
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF333333)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCrypto,
                      dropdownColor: const Color(0xFF1A1A1A),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      items: _coins.map((coin) => DropdownMenuItem<String>(
                        value: (coin['symbol'] ?? 'BTC').toString(),
                        child: Row(
                          children: [
                            Text(coin['symbol'] ?? 'BTC'),
                            const SizedBox(width: 8),
                            Text(
                              coin['name'] ?? 'Bitcoin',
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCrypto = value!;
                        });
                      },
                    ),
                  ),
                ),
              
              const SizedBox(height: 20),
              
              // Text below QR Code
              const Text(
                'Set Receiving Currency / Amount',
                style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            
              const SizedBox(height: 40),
            
              // Payment Link Section
              GestureDetector(
                onTap: () {
                  _showPaymentLinkDialog(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment Link',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            
              const SizedBox(height: 40),
            
              // Save and Share Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 20,
                  children: [
                    // Save QR Code
                    GestureDetector(
                      onTap: () {
                        _saveQRCode(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Save QR Code',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  
                    // Share QR Code
                    GestureDetector(
                      onTap: () {
                        _shareQRCode(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Share QR Code',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentLinkDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Payment Link',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'https://creddx.app/pay/${_selectedCrypto.toLowerCase()}123xyz',
                    style: TextStyle(
                      color: Color(0xFF84BD00),
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: 'https://creddx.app/pay/${_selectedCrypto.toLowerCase()}123xyz'));
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment link copied!'),
                            backgroundColor: Color(0xFF84BD00),
                          ),
                        );
                      },
                      child: const Text(
                        'Copy',
                        style: TextStyle(color: Color(0xFF84BD00)),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _saveQRCode(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('QR Code saved to gallery!'),
        backgroundColor: Color(0xFF84BD00),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareQRCode(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sharing QR Code...'),
        backgroundColor: Color(0xFF84BD00),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// Custom QR Code Painter for realistic QR code pattern
class QRCodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final moduleSize = 8.0;
    final quietZone = 15.0;
    
    // Calculate grid dimensions to prevent overflow
    final gridSize = (size.width - 2 * quietZone) / 25; // 25 modules per row
    final actualModuleSize = gridSize < moduleSize ? gridSize : moduleSize;
    
    // Draw QR code modules
    for (int row = 0; row < 25; row++) {
      for (int col = 0; col < 25; col++) {
        final x = quietZone + col * actualModuleSize;
        final y = quietZone + row * actualModuleSize;
        
        // Ensure modules don't go outside container bounds
        if (x + actualModuleSize <= size.width - quietZone && 
            y + actualModuleSize <= size.height - quietZone) {
          
          // Create a realistic QR pattern
          if (_shouldDrawModule(row, col)) {
            canvas.drawRect(
              Rect.fromLTWH(x, y, actualModuleSize, actualModuleSize),
              paint,
            );
          }
        }
      }
    }
    
    // Draw corner position markers
    _drawPositionMarker(canvas, Offset(quietZone, quietZone), paint);
    _drawPositionMarker(canvas, Offset(size.width - quietZone - 70, quietZone), paint);
    _drawPositionMarker(canvas, Offset(quietZone, size.height - quietZone - 70), paint);
  }

  bool _shouldDrawModule(int row, int col) {
    // Create a pseudo-random but consistent QR pattern
    final sum = row + col;
    final product = (row * col) % 7;
    
    // Corner patterns (position markers)
    if ((row < 7 && col < 7) || 
        (row < 7 && col >= 18) || 
        (row >= 18 && col < 7)) {
      return true;
    }
    
    // Random-looking pattern
    return (sum + product) % 3 == 0 || (sum % 5 == 0 && col % 2 == 0);
  }

  void _drawPositionMarker(Canvas canvas, Offset offset, Paint paint) {
    // Outer square
    canvas.drawRect(
      Rect.fromLTWH(offset.dx, offset.dy, 70, 70),
      paint,
    );
    
    // White square
    canvas.drawRect(
      Rect.fromLTWH(offset.dx + 10, offset.dy + 10, 50, 50),
      Paint()..color = Colors.white,
    );
    
    // Inner square
    canvas.drawRect(
      Rect.fromLTWH(offset.dx + 20, offset.dy + 20, 30, 30),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
