import 'package:flutter/material.dart';
import '../services/bot_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _isSubscribing = false;
  List<SubscriptionPlan> _plans = [];
  Map<String, dynamic>? _userSubscription;
  Map<String, dynamic>? _userData;
  String? _selectedPlanId;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSubscriptionData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSubscriptionData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load user data
      final userResponse = await BotService.getUserData();
      if (userResponse['success']) {
        setState(() {
          _userData = userResponse['data'];
        });
      }

      // Load available plans
      final plansResponse = await BotService.getSubscriptionPlans();
      if (plansResponse['success'] == true) {
        setState(() {
          _plans = (plansResponse['plans'] as List?)
                  ?.map((plan) => SubscriptionPlan(
                        id: plan['id']?.toString() ?? '',
                        name: plan['name']?.toString() ?? '',
                        price: double.tryParse(plan['price']?.toString() ?? '0') ?? 0.0,
                        duration: int.tryParse(plan['duration']?.toString() ?? '365') ?? 365,
                        description: plan['description']?.toString() ?? '',
                        features: List<String>.from(plan['features'] ?? []),
                      ))
                  .toList() ??
              [];
        });
      }

      // Load user's current subscription
      final userSubResponse = await BotService.getUserSubscription();
      if (userSubResponse['success'] == true) {
        setState(() {
          _userSubscription = userSubResponse['subscription'];
        });
      }
    } catch (e) {
      debugPrint('Error loading subscription data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _subscribeToPlan(String planId, {double? price}) async {
    setState(() => _isSubscribing = true);
    
    try {
      final response = await BotService.subscribeToPlan(
        plan: planId,
        price: price,
      );
      
      if (response['success'] == true) {
        _showSuccessDialog('Subscription successful!', response['message']);
        await _loadSubscriptionData(); // Refresh data
      } else {
        _showErrorDialog('Subscription failed', response['error']);
      }
    } catch (e) {
      _showErrorDialog('Error', 'Something went wrong. Please try again.');
    } finally {
      setState(() => _isSubscribing = false);
    }
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(
          title,
          style: const TextStyle(color: Color(0xFF84BD00)),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF84BD00)),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(
          title,
          style: const TextStyle(color: Color(0xFFFF3B30)),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFFFF3B30)),
            ),
          ),
        ],
      ),
    );
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
          'Subscription Plans',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF84BD00),
          labelColor: const Color(0xFF84BD00),
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          tabs: const [
            Tab(text: 'Plans'),
            Tab(text: 'My Subscription'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF84BD00)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPlansTab(),
                _buildMySubscriptionTab(),
              ],
            ),
    );
  }

  Widget _buildPlansTab() {
    return RefreshIndicator(
      onRefresh: _loadSubscriptionData,
      color: const Color(0xFF84BD00),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose Your Trading Plan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select the perfect plan for your trading needs',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            
            // Free Trial Plan
            _buildPlanCard(
              plan: SubscriptionPlan(
                id: 'free_trial',
                name: 'Free Trial',
                price: 0.0,
                duration: 30,
                description: 'Try our premium features for 30 days',
                features: [
                  'All trading algorithms',
                  'Real-time market data',
                  'Basic analytics',
                  'Email support',
                ],
              ),
              isPopular: false,
              isFree: true,
            ),
            
            const SizedBox(height: 16),
            
            // Premium Plans
            ..._plans.map((plan) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildPlanCard(
                plan: plan,
                isPopular: plan.name.toLowerCase().contains('premium'),
                isFree: false,
              ),
            )),
            
            const SizedBox(height: 32),
            
            // Features Comparison
            _buildFeaturesComparison(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required SubscriptionPlan plan,
    required bool isPopular,
    required bool isFree,
  }) {
    final isSelected = _selectedPlanId == plan.id;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF84BD00).withOpacity(0.1) : const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected 
              ? const Color(0xFF84BD00)
              : isPopular 
                  ? const Color(0xFF84BD00)
                  : Colors.white.withOpacity(0.2),
          width: isSelected || isPopular ? 2 : 1,
        ),
        boxShadow: [
          if (isPopular)
            BoxShadow(
              color: const Color(0xFF84BD00).withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Stack(
        children: [
          if (isPopular)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF84BD00),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'POPULAR',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      plan.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isFree)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF84BD00),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'FREE',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  plan.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isFree ? 'FREE' : '\$${plan.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: const Color(0xFF84BD00),
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!isFree) ...[
                      const SizedBox(width: 8),
                      Text(
                        '/${plan.duration} days',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                ...plan.features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF84BD00),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          feature,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubscribing
                        ? null
                        : () {
                            setState(() => _selectedPlanId = plan.id);
                            _subscribeToPlan(
                              plan.id,
                              price: isFree ? null : plan.price,
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected 
                          ? const Color(0xFF84BD00)
                          : isFree
                              ? Colors.transparent
                              : null,
                      foregroundColor: isSelected || isFree
                          ? Colors.black
                          : Colors.white,
                      side: isFree
                          ? const BorderSide(color: Color(0xFF84BD00))
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: isPopular ? 8 : 0,
                    ),
                    child: _isSubscribing
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                isFree ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
                              ),
                            ),
                          )
                        : Text(
                            isFree ? 'Start Free Trial' : 'Subscribe Now',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesComparison() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Compare Features',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildFeatureRow('Trading Algorithms', ['Basic', 'Advanced', 'Premium']),
          _buildFeatureRow('Real-time Data', ['Limited', 'Full', 'Full']),
          _buildFeatureRow('Analytics', ['Basic', 'Advanced', 'Premium']),
          _buildFeatureRow('Support', ['Email', 'Priority', '24/7']),
          _buildFeatureRow('API Access', ['No', 'Yes', 'Yes']),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String feature, List<String> plans) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              feature,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                plans[0],
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                plans[1],
                style: const TextStyle(
                  color: Color(0xFF84BD00),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                plans[2],
                style: const TextStyle(
                  color: Color(0xFF84BD00),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMySubscriptionTab() {
    if (_userSubscription == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.subscriptions_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Active Subscription',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a plan to start trading',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _tabController.animateTo(0);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Browse Plans',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    final subscription = _userSubscription!;
    final startDate = DateTime.tryParse(subscription['startDate'] ?? '');
    final endDate = startDate?.add(Duration(days: subscription['duration'] ?? 365));
    final isExpired = endDate?.isBefore(DateTime.now()) ?? true;
    final daysLeft = endDate?.difference(DateTime.now()).inDays ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF84BD00),
                  const Color(0xFF84BD00).withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      subscription['planName'] ?? 'Active Plan',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isExpired ? Colors.red : Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isExpired ? 'EXPIRED' : 'ACTIVE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '\$${(subscription['price'] ?? 0).toStringAsFixed(2)}/${subscription['duration'] ?? 365} days',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!isExpired && daysLeft > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    '$daysLeft days remaining',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSubscriptionDetails(subscription),
        ],
      ),
    );
  }

  Widget _buildSubscriptionDetails(Map<String, dynamic> subscription) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Subscription Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Plan ID', subscription['id']?.toString() ?? 'N/A'),
          _buildDetailRow('Start Date', _formatDate(subscription['startDate'])),
          _buildDetailRow('End Date', _formatDate(subscription['endDate'])),
          _buildDetailRow('Transaction ID', subscription['transactionId']?.toString() ?? 'N/A'),
          _buildDetailRow('Payment Method', subscription['paymentMethod']?.toString() ?? 'Wallet'),
          _buildDetailRow('Auto-renewal', subscription['autoRenewal'] == true ? 'Enabled' : 'Disabled'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString!);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }
}
