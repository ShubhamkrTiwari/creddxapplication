import 'package:flutter/material.dart';
import 'bot_trade_detail_screen.dart';

class PackageProgramScreen extends StatefulWidget {
  const PackageProgramScreen({super.key});

  @override
  State<PackageProgramScreen> createState() => _PackageProgramScreenState();
}

class _PackageProgramScreenState extends State<PackageProgramScreen> {
  bool _isLoading = false;

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
          'Package Program',
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Package Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Basic Package',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF84BD00),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '\$50',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildFeatureItem(
                        'Advanced Edge',
                        'Enhanced AI decision-making based on real-time signals.',
                      ),
                      _buildFeatureItem(
                        'Trade Pro',
                        'Access to professional-grade trade execution tools.',
                      ),
                      _buildFeatureItem(
                        '70-30 Ratio',
                        'Keep 70% of profits while 30% goes to strategy fees.',
                      ),
                      _buildFeatureItem(
                        'Cap 100\$ - 2000\$',
                        'Designed for small-to-mid-sized portfolios.',
                      ),
                      _buildFeatureItem(
                        '1 Month',
                        'Full-month access to premium features',
                      ),
                      _buildFeatureItem(
                        'Profit Master',
                        'Auto-optimization strategies for maximum ROI.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Button
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleGetFreePlan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF84BD00),
                        disabledBackgroundColor: const Color(0xFF84BD00).withOpacity(0.5),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Get a Free Plan',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGetFreePlan() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Simulate API call for free plan subscription
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        // Set the global package state to true
        BotTradeDetailScreen.hasPackage = true;

        // Show activation message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Free plan activated successfully!'),
            backgroundColor: Color(0xFF84BD00),
            duration: Duration(seconds: 1),
          ),
        );
        
        await Future.delayed(const Duration(seconds: 1));
        
        if (mounted) {
          // Go back to the Bot Trading Details screen
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to activate free plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
