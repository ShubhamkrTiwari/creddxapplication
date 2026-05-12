import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import '../services/wallet_service.dart';
import '../services/notification_service.dart';
import 'dart:convert';

class DepositAddressScreen extends StatefulWidget {
  final String coin;
  final String coinId;
  final String network;
  final String networkId;

  const DepositAddressScreen({
    super.key,
    required this.coin,
    required this.coinId,
    required this.network,
    required this.networkId,
  });

  @override
  State<DepositAddressScreen> createState() => _DepositAddressScreenState();
}

class _DepositAddressScreenState extends State<DepositAddressScreen> {
  String? _address;
  bool _isLoading = true;
  String? _errorMessage;
  final GlobalKey _shareCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchDepositAddress();
  }

  Future<void> _shareAddressImage() async {
    try {
      // Find the RenderRepaintBoundary
      final RenderRepaintBoundary boundary = _shareCardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      // Capture the widget as an image
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to generate image');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final filePath = path.join(tempDir.path, 'deposit_address_${widget.coin}.png');
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      // Share the image file
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: '${widget.coin} Deposit Address',
        text: 'Deposit ${widget.coin} on ${widget.network}',
      );
    } catch (e) {
      // Fallback to text sharing if image generation fails
      await Share.share(
        'Deposit ${widget.coin} on ${widget.network} network:\n$_address',
        subject: '${widget.coin} Deposit Address',
      );
    }
  }

  Future<void> _fetchDepositAddress() async {
    final result = await WalletService.getDepositAddress(
      coin: widget.coin,
      coinId: widget.coinId,
      networkId: widget.networkId,
    );
    
    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          final data = result['data'] ?? result['doc'];
          if (data != null) {
            _address = data['address'] ?? data['depositAddress'] ?? data['walletAddress'];
          }
          if (_address == null || _address!.isEmpty) {
            _errorMessage = 'No deposit address returned from server';
          } else {
            NotificationService.addNotification(
              title: 'Deposit Address Generated',
              message: 'Your ${widget.coin} deposit address on ${widget.network} has been generated.',
              type: NotificationType.info,
            );
          }
        } else {
          _errorMessage = result['error'] ?? 'Failed to fetch deposit address';
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Generate QR code URL using a public API
    // URL encode the address to handle special characters properly
    final qrCodeUrl = _address != null 
        ? 'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${Uri.encodeComponent(_address!)}'
        : '';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Deposit ${widget.coin}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
        : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchDepositAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF84BD00),
                    ),
                    child: const Text('Retry', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    // Shareable Card (similar to BingX design)
                    RepaintBoundary(
                      key: _shareCardKey,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF2C2C2E)),
                        ),
                        child: Column(
                          children: [
                            // Title
                            Text(
                              'Deposit ${widget.coin} to CreddX',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Warning text
                            Text(
                              'Please ensure the sender enters the correct information. Any incorrect info may result in asset loss.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // QR Code with coin logo in center
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Image.network(
                                    qrCodeUrl,
                                    width: 180,
                                    height: 180,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const SizedBox(
                                        width: 180,
                                        height: 180,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: Color(0xFF84BD00),
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return const SizedBox(
                                        width: 180,
                                        height: 180,
                                        child: Center(
                                          child: Icon(Icons.error_outline, color: Colors.red, size: 48),
                                        ),
                                      );
                                    },
                                  ),
                                  // Coin logo in center
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: Center(
                                      child: widget.coin.toUpperCase() == 'USDT'
                                          ? const Icon(
                                              Icons.currency_exchange,
                                              color: Color(0xFF26A17B),
                                              size: 24,
                                            )
                                          : Text(
                                              widget.coin.length > 2
                                                  ? widget.coin.substring(0, 2).toUpperCase()
                                                  : widget.coin.toUpperCase(),
                                              style: const TextStyle(
                                                color: Color(0xFF84BD00),
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Currency row
                            _buildInfoRow('Currency', widget.coin.toUpperCase()),
                            const SizedBox(height: 12),
                            // Network row
                            _buildInfoRow('Network', widget.network),
                            const SizedBox(height: 12),
                            // Address row
                            _buildAddressRow(_address!),
                            const SizedBox(height: 16),
                            // Warning about contract address
                            Text(
                              'Please do not deposit to the above address through a contract address.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // CreddX logo
                            Image.asset(
                              'assets/images/Creddxlogo.png',
                              height: 30,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Copy Address button
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _address!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: _address!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Address copied to clipboard'),
                                  backgroundColor: Color(0xFF84BD00),
                                ),
                              );
                            },
                            child: const Icon(Icons.copy, color: Color(0xFF84BD00), size: 20),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _address != null ? _shareAddressImage : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF84BD00),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Share Address',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Send only ${widget.coin} to this deposit address. Sending any other coin or token to this address may result in the loss of your deposit.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 12),
        // ye use kre - Expanded with ellipsis to prevent overflow
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildAddressRow(String address) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Address',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                address,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
