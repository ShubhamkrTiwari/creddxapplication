import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'payment_proof_screen.dart';

class PayBankTransferScreen extends StatefulWidget {
  final String amount;
  final String? accountHolderName;
  final String? accountNumber;
  final String? bankName;
  final String? ifscCode;
  
  const PayBankTransferScreen({
    super.key, 
    required this.amount,
    this.accountHolderName,
    this.accountNumber,
    this.bankName,
    this.ifscCode,
  });

  @override
  State<PayBankTransferScreen> createState() => _PayBankTransferScreenState();
}

class _PayBankTransferScreenState extends State<PayBankTransferScreen> {
  // Seller's bank details from selected or defaults
  String get _accountHolderName => widget.accountHolderName ?? 'Ravindersingh1023';
  String get _accountNumber => widget.accountNumber ?? '123456789012';
  String get _bankName => widget.bankName ?? 'State Bank of India';
  String get _ifscCode => widget.ifscCode ?? 'SBIN0001234';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Pay Using Bank Transfer',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timer
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Order will be cancelled in ',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const Text(
                  '14:59',
                  style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Bank Details Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bank Account Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildDetailRow('Account Holder', _accountHolderName),
                  const SizedBox(height: 16),
                  _buildDetailRow('Account Number', _accountNumber),
                  const SizedBox(height: 16),
                  _buildDetailRow('Bank Name', _bankName),
                  const SizedBox(height: 16),
                  _buildDetailRow('IFSC Code', _ifscCode),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Amount to Pay
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'You Pay',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${widget.amount} USDT',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: widget.amount));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Amount copied'),
                              backgroundColor: Color(0xFF84BD00),
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.copy,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentProofScreen(
                      amount: widget.amount,
                      paymentMethod: 'Bank Transfer',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text(
                'I have Paid',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$label copied'),
                      backgroundColor: const Color(0xFF84BD00),
                    ),
                  );
                },
                child: const Icon(
                  Icons.copy,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
