import 'package:flutter/material.dart';
import 'package_program_screen.dart';

class BotTradeDetailScreen extends StatefulWidget {
  final String name;
  final String multiplier;

  const BotTradeDetailScreen({
    super.key,
    required this.name,
    required this.multiplier,
  });

  // Simple static states to simulate persistence for this demo session
  static bool hasPackage = false;
  static bool isInvested = false;

  @override
  State<BotTradeDetailScreen> createState() => _BotTradeDetailScreenState();
}

class _BotTradeDetailScreenState extends State<BotTradeDetailScreen> {
  final TextEditingController _investController = TextEditingController();
  final TextEditingController _withdrawController = TextEditingController();

  @override
  void dispose() {
    _investController.dispose();
    _withdrawController.dispose();
    super.dispose();
  }

  void _showAmountDialog({
    required String title, 
    required String hint, 
    required TextEditingController controller, 
    required bool isConfirmingInvestment
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: Colors.white38),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: InputBorder.none,
                    suffixIcon: TextButton(
                      onPressed: () {
                        setState(() {
                          controller.text = hint.replaceAll('Max: \$', '').replaceAll('Total: \$', '');
                        });
                      },
                      child: const Text(
                        'Max value',
                        style: TextStyle(color: Color(0xFF4A90E2), fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (isConfirmingInvestment) {
                            setState(() {
                              BotTradeDetailScreen.isInvested = true;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Investment successful!'),
                                backgroundColor: Color(0xFF84BD00),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          } else {
                            // Logic for withdrawal confirmation
                            setState(() {
                              BotTradeDetailScreen.isInvested = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Withdrawal successful!'),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF84BD00),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleInvestClick() {
    if (BotTradeDetailScreen.hasPackage) {
      _showAmountDialog(
        title: 'Enter Investment Amount',
        hint: 'Max: \$19.00',
        controller: _investController,
        isConfirmingInvestment: true,
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PackageProgramScreen()),
      ).then((_) => setState(() {})); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.name}- ${widget.multiplier}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Algo Overview',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildOverviewItem('Pair:', 'Multiple Alt Pairs'),
            _buildOverviewItem('AUM:', '805.99K'),
            _buildOverviewItem('Volume:', 'InfinityM'),
            _buildOverviewItem('Drawdown:', '172.94%'),
            _buildOverviewItem('Recovery:', '137d Max / 73d Avg'),
            _buildOverviewItem('Trades:', '40'),
            _buildOverviewItem('Win Rate:', '95.00%'),
            _buildOverviewItem('Profit Comm:', '20%'),
            _buildOverviewItem('Max Risk:', '47.20%'),
            
            const Spacer(),
            
            if (BotTradeDetailScreen.isInvested) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Invested:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '50.00 USDT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            Padding(
              padding: const EdgeInsets.only(bottom: 30.0),
              child: BotTradeDetailScreen.isInvested
                ? Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            onPressed: _handleInvestClick,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white.withOpacity(0.2)),
                              backgroundColor: const Color(0xFF1C1C1E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Invest',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () => _showAmountDialog(
                              title: 'Enter Withdrawal Amount',
                              hint: 'Total: \$50.00',
                              controller: _withdrawController,
                              isConfirmingInvestment: false,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF84BD00),
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Withdraw',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _handleInvestClick,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF84BD00),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Invest',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 15,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
