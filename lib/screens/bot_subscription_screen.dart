import 'package:flutter/material.dart';
import '../services/bot_service.dart';

class BotSubscriptionScreen extends StatefulWidget {
  const BotSubscriptionScreen({super.key});

  @override
  State<BotSubscriptionScreen> createState() => _BotSubscriptionScreenState();
}

class _BotSubscriptionScreenState extends State<BotSubscriptionScreen> {
  bool _isLoading = true;
  bool _isSubscribed = false;
  String? _planName;
  double? _planPrice;
  int _remainingDays = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionDetails();
  }

  Future<void> _loadSubscriptionDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await BotService.getSubscriptionDetails();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _isSubscribed = result['isSubscribed'] ?? false;
          _planName = result['planName'];
          _planPrice = result['planPrice'];
          _remainingDays = result['remainingDays'] ?? 0;
        } else {
          _errorMessage = result['error'] ?? 'Could not load subscription details';
        }
      });
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Subscription',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadSubscriptionDetails,
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingView() : _buildContent(),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF84BD00)),
          ),
          SizedBox(height: 16),
          Text(
            'Loading subscription details...',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadSubscriptionDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _isSubscribed ? _buildSubscribedView() : _buildNotSubscribedView(),
    );
  }

  Widget _buildSubscribedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Active Subscription Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF84BD00), Color(0xFF6BA300)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF84BD00).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Subscription',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'You have access to all bot features',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                _planName ?? 'Premium Plan',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (_planPrice != null)
                Text(
                  '\$${_planPrice!.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Days Remaining Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF84BD00).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              const Text(
                'Days Remaining',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_remainingDays',
                style: TextStyle(
                  color: _remainingDays <= 3 ? Colors.orange : const Color(0xFF84BD00),
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _remainingDays == 1 ? 'day' : 'days',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Warning if expiring soon
        if (_remainingDays <= 7)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _remainingDays <= 0
                            ? 'Subscription Expired'
                            : 'Expiring Soon',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _remainingDays <= 0
                            ? 'Please renew your subscription to continue using bot features.'
                            : 'Your subscription expires in $_remainingDays days. Consider renewing soon.',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 32),

        // Renew Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              // Navigate to subscription plans
              Navigator.pushNamed(context, '/subscription-plans');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF84BD00),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _remainingDays <= 0 ? 'Renew Now' : 'Extend Subscription',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotSubscribedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // No Subscription Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.grey.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: Colors.grey,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Active Subscription',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Subscribe to access premium bot trading features',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Features List
        const Text(
          'Premium Features',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(Icons.smart_toy, 'AI-Powered Trading Bots', 'Automated trading with advanced algorithms'),
        const SizedBox(height: 12),
        _buildFeatureItem(Icons.trending_up, 'Multiple Strategies', 'Omega, Alpha, Ranger, and Delta strategies'),
        const SizedBox(height: 12),
        _buildFeatureItem(Icons.shield, 'Risk Management', 'Stop-loss and take-profit automation'),
        const SizedBox(height: 12),
        _buildFeatureItem(Icons.analytics, 'Real-time Analytics', 'Detailed performance tracking and insights'),
        const SizedBox(height: 12),
        _buildFeatureItem(Icons.support_agent, 'Priority Support', '24/7 dedicated customer support'),
        const SizedBox(height: 32),

        // Subscribe Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              // Navigate to subscription plans
              Navigator.pushNamed(context, '/subscription-plans');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF84BD00),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'View Plans',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF84BD00).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF84BD00),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
