import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/wallet_service.dart';
import '../services/notification_service.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchDepositAddress();
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
    final qrCodeUrl = _address != null 
        ? 'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=$_address'
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
                    // Real QR Code Image
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.network(
                        qrCodeUrl,
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const SizedBox(
                            width: 200,
                            height: 200,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF84BD00),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox(
                            width: 200,
                            height: 200,
                            child: Center(
                              child: Icon(Icons.error_outline, color: Colors.red, size: 48),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Network',
                      style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.network,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 32),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Deposit Address',
                        style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _address != null ? () {
                          Share.share(
                            'Deposit ${widget.coin} on ${widget.network} network:\n$_address',
                            subject: '${widget.coin} Deposit Address',
                          );
                        } : null,
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
}
