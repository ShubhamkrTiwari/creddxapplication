import 'package:flutter/material.dart';

class ConfirmOrderScreen extends StatelessWidget {
  const ConfirmOrderScreen({super.key});

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
          'Confirm Order',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Receive Amount Section
            Center(
              child: Column(
                children: [
                  const Text(
                    'Receive Amount',
                    style: TextStyle(color: Color(0xFF6C7278), fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '100.00 BTC',
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '~ \$ 187,345,233.00',
                    style: TextStyle(color: Color(0xFF6C7278), fontSize: 16),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Order Details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Receive Amount', 'CREDDX Smart Chain (CMC)'),
                  const Divider(color: Color(0xFF333333), height: 24),
                  _buildDetailRow('Address', '0x42591acecdcc69d426ad7 26a612ffed10136c111'),
                  const Divider(color: Color(0xFF333333), height: 24),
                  _buildDetailRow('Withdrawal Amount', '100 BTC'),
                  const Divider(color: Color(0xFF333333), height: 24),
                  _buildDetailRow('Network Fee', '0.0001 BTC'),
                  const Divider(color: Color(0xFF333333), height: 24),
                  _buildDetailRow('Wallet', 'Spot Wallet'),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Confirm Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // Handle confirm logic
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF84BD00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Confirm',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF6C7278), fontSize: 14),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
