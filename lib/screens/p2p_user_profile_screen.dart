import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/p2p_service.dart';
import '../widgets/bitcoin_loading_indicator.dart';
import 'feedback_screen.dart';
import 'blocked_users_screen.dart';
import 'saved_payment_methods_screen.dart';

class P2PUserProfileScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const P2PUserProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<P2PUserProfileScreen> createState() => _P2PUserProfileScreenState();
}

class _P2PUserProfileScreenState extends State<P2PUserProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _userDetails;
  Map<String, dynamic>? _trades30d;
  Map<String, dynamic>? _walletBalance;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    debugPrint('=== Fetching P2P User Details ===');
    debugPrint('UserId: ${widget.userId}');

    try {
      final results = await Future.wait([
        P2PService.getP2PUserDetails(userId: widget.userId),
        P2PService.getUser30dTrades(userId: widget.userId),
        P2PService.getWalletBalance(),
      ]);

      final details = results[0];
      final trades30d = results[1];
      final walletBalance = results[2];

      debugPrint('User Details: $details');
      debugPrint('30d Trades: $trades30d');
      debugPrint('Wallet Balance: $walletBalance');

      if (mounted) {
        setState(() {
          _userDetails = details;
          _trades30d = trades30d;
          _walletBalance = walletBalance;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user details: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load user details: $e';
          _isLoading = false;
        });
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
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: const Text('User Profile', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: BitcoinLoadingIndicator(size: 40))
          : _error != null
              ? _buildErrorView()
              : _buildProfileContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 42),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchUserDetails();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF84BD00),
              foregroundColor: Colors.black,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    debugPrint('=== Building Profile Content ===');
    debugPrint('_userDetails: $_userDetails');

    if (_userDetails == null || _userDetails!.isEmpty) {
      return _buildNoDataView();
    }

    final user = _userDetails?['user'] ?? _userDetails;
    final stats = _userDetails?['stats'] ?? _userDetails?['userStats'] ?? {};

    debugPrint('Parsed user: $user');
    debugPrint('Parsed stats: $stats');

    final displayName = user?['userName'] ?? user?['name'] ?? user?['firstName'] ??
                        user?['username'] ?? widget.userName;
    final email = user?['email'] ?? '';
    final joinedDate = user?['createdAt'] ?? user?['joinDate'] ?? user?['joinedAt'];
    final daysRegistered = _calculateDaysRegistered(joinedDate);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDashboardCard(displayName, email, daysRegistered, stats),
          const SizedBox(height: 24),
          _buildMenuSections(),
        ],
      ),
    );
  }

  int _calculateDaysRegistered(dynamic joinedDate) {
    if (joinedDate == null) return 0;
    try {
      final date = DateTime.parse(joinedDate.toString());
      return DateTime.now().difference(date).inDays;
    } catch (e) {
      return 0;
    }
  }

  Widget _buildNoDataView() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_off_outlined, color: Colors.white54, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'No user data available',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'User ID: ${widget.userId.isEmpty ? "(empty)" : widget.userId}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'API Response:\n${_userDetails?.toString() ?? "null"}',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _isLoading = true);
                    _fetchUserDetails();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF84BD00),
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoAdsView() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text(
          'No active advertisements',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildDashboardCard(String name, String email, int daysRegistered, Map stats) {
    final trades30dData = _trades30d ?? {};
    final allTrades = stats['allTrades'] ?? stats['totalTrades'] ?? 0;
    final trades30d = trades30dData['trades30d'] ?? trades30dData['thirtyDayTrades'] ?? stats['trades30d'] ?? 0;
    final completionRate30d = trades30dData['completionRate30d'] ?? trades30dData['thirtyDayCompletionRate'] ?? stats['completionRate30d'] ?? 0;
    final firstTradeDate = stats['firstTradeDate'] ?? 'N/A';
    final buyTrades = trades30dData['buyTrades'] ?? stats['buyTrades'] ?? 0;
    final sellTrades = trades30dData['sellTrades'] ?? stats['sellTrades'] ?? 0;
    final positiveCount = stats['positiveCount'] ?? stats['positive'] ?? 0;
    final negativeCount = stats['negativeCount'] ?? stats['negative'] ?? 0;
    final paymentMethodsCount = stats['paymentMethods'] ?? stats['paymentMethodCount'] ?? 0;

    // Get wallet balance for estimated value
    final walletData = _walletBalance ?? {};
    final balanceData = walletData['data'] ?? walletData['balance'] ?? walletData;
    final p2pValueInr = balanceData['inrValue'] ?? balanceData['estimatedValueInr'] ?? balanceData['totalInr'] ?? '****';
    final p2pValueUsdt = balanceData['usdtValue'] ?? balanceData['estimatedValueUsdt'] ?? balanceData['totalUsdt'] ?? balanceData['usdt'] ?? '****';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF1A1A1A),
            const Color(0xFF84BD00).withOpacity(0.3),
            const Color(0xFF84BD00).withOpacity(0.5),
          ],
          stops: const [0.3, 0.7, 1.0],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Shield icon on right
            Positioned(
              right: -20,
              top: 0,
              bottom: 0,
              child: Container(
                width: 180,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.centerRight,
                    radius: 0.8,
                    colors: [
                      const Color(0xFF84BD00).withOpacity(0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.verified_user,
                    size: 80,
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info row
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFF84BD00),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, color: Color(0xFF84BD00), size: 16),
                              ],
                            ),
                            if (email.isNotEmpty)
                              Text(
                                email,
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // P2P Estimated Value
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'P2P Estimated Value (INR)',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '$p2pValueInr INR = $p2pValueUsdt USDT',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 12),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Stats Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('All Trades', '$allTrades Time(s)'),
                      ),
                      Expanded(
                        child: _buildStatItemRight('Buy', '$buyTrades'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('30d Trade(s)', '$trades30d'),
                      ),
                      Expanded(
                        child: _buildStatItemRight('Sell', '$sellTrades'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('30d Completion Rate', '$completionRate30d%'),
                      ),
                      Expanded(
                        child: _buildStatItemRight('Positive', '$positiveCount'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('First Trade', firstTradeDate.toString()),
                      ),
                      Expanded(
                        child: _buildStatItemRight('Negative', '$negativeCount'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('Registered', '$daysRegistered day(s)'),
                      ),
                      Expanded(
                        child: _buildStatItemRight('Payment method', '$paymentMethodsCount day(s)'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildStatItemRight(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildMenuSections() {
    return Column(
      children: [
        _buildMenuItem(
          icon: Icons.thumb_up_outlined,
          title: 'Received Feedback',
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen()));
          },
        ),
        _buildMenuItem(
          icon: Icons.block,
          title: 'Blocked User',
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedUsersScreen()));
          },
        ),
        _buildMenuItem(
          icon: Icons.payment,
          title: 'Your Payment Method',
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedPaymentMethodsScreen()));
          },
        ),
      ],
    );
  }

  Widget _buildMenuItem({required IconData icon, required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white54, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(Map stats) {
    // Merge 30d trades API data with user details stats
    final trades30dData = _trades30d ?? {};
    
    final allTrades = stats['allTrades'] ?? stats['totalTrades'] ?? 0;
    final trades30d = trades30dData['trades30d'] ?? 
                      trades30dData['thirtyDayTrades'] ?? 
                      trades30dData['tradeCount'] ??
                      stats['trades30d'] ?? 
                      stats['thirtyDayTrades'] ?? 0;
    final completionRate30d = trades30dData['completionRate30d'] ?? 
                              trades30dData['thirtyDayCompletionRate'] ??
                              trades30dData['completionRate'] ??
                              stats['completionRate30d'] ?? 
                              stats['thirtyDayCompletionRate'] ?? 0;
    final avgReleaseTime = trades30dData['avgReleaseTime'] ?? 
                           trades30dData['averageReleaseTime'] ??
                           stats['avgReleaseTime'] ?? 
                           stats['averageReleaseTime'] ?? 'N/A';
    final avgPayTime = trades30dData['avgPayTime'] ?? 
                       trades30dData['averagePayTime'] ??
                       stats['avgPayTime'] ?? 
                       stats['averagePayTime'] ?? '0.00 Minute';
    final buyTrades = trades30dData['buyTrades'] ?? 
                      trades30dData['buyCount'] ??
                      stats['buyTrades'] ?? 
                      stats['buyCount'] ?? 0;
    final sellTrades = trades30dData['sellTrades'] ?? 
                       trades30dData['sellCount'] ??
                       stats['sellTrades'] ?? 
                       stats['sellCount'] ?? 0;

    final statsList = [
      {'title': 'All Trades', 'value': '$allTrades Time(s)', 'subtitle': 'Buy $buyTrades / Sell $sellTrades'},
      {'title': '30d Trades', 'value': '$trades30d Time(s)', 'subtitle': null},
      {'title': '30d Completion Rate', 'value': '$completionRate30d%', 'subtitle': null},
      {'title': 'Avg. Release Time', 'value': avgReleaseTime.toString(), 'subtitle': null},
      {'title': 'Avg. Pay Time', 'value': avgPayTime.toString(), 'subtitle': null},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statsList.map((stat) {
          return Container(
            width: 140,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2C2C2E)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat['title'] as String,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Text(
                  stat['value'] as String,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (stat['subtitle'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    stat['subtitle'] as String,
                    style: const TextStyle(color: Color(0xFF84BD00), fontSize: 10),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAdsSection(String title, List<dynamic> ads, bool isBuy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        // Header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: const Row(
            children: [
              Expanded(flex: 2, child: Text('Coin', style: TextStyle(color: Colors.white54, fontSize: 11))),
              Expanded(flex: 2, child: Text('Price', style: TextStyle(color: Colors.white54, fontSize: 11))),
              Expanded(flex: 3, child: Text('Order Limit/Available', style: TextStyle(color: Colors.white54, fontSize: 11))),
              Expanded(flex: 3, child: Text('Payment', style: TextStyle(color: Colors.white54, fontSize: 11))),
              Expanded(flex: 2, child: Text('Trade', style: TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center)),
            ],
          ),
        ),
        // Ads list
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: ads.length,
          separatorBuilder: (_, __) => const Divider(color: Color(0xFF2C2C2E), height: 1),
          itemBuilder: (context, index) {
            final ad = ads[index];
            return _buildAdRow(ad, isBuy);
          },
        ),
      ],
    );
  }

  Widget _buildAdRow(dynamic ad, bool isBuy) {
    final coin = ad['coin'] ?? ad['coinSymbol'] ?? 'USDT';
    final price = ad['price'] ?? ad['rate'] ?? 0;
    final minLimit = ad['min'] ?? ad['minAmount'] ?? ad['minOrder'] ?? 0;
    final maxLimit = ad['max'] ?? ad['maxAmount'] ?? ad['maxOrder'] ?? 0;
    final available = ad['amount'] ?? ad['quantity'] ?? ad['available'] ?? 0;
    final paymentModes = ad['paymentMode'] ?? ad['paymentMethods'] ?? ['Bank Transfer'];

    String paymentText = '';
    if (paymentModes is List && paymentModes.isNotEmpty) {
      paymentText = '| ${paymentModes.first}';
    } else if (paymentModes is String) {
      paymentText = '| $paymentModes';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          // Coin
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(coin.toString(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          // Price
          Expanded(
            flex: 2,
            child: Text(
              '${price.toString()} INR',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          // Order Limit/Available
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$minLimit-$maxLimit INR',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Text(
                  '$available $coin',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
          // Payment
          Expanded(
            flex: 3,
            child: Text(
              paymentText,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          // Trade button
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () {
                // Navigate to place order screen
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isBuy ? const Color(0xFF84BD00) : Colors.redAccent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isBuy ? 'BUY' : 'SELL',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isBuy ? Colors.black : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
