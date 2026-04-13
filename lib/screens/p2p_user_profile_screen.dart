import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/p2p_service.dart';
import '../widgets/bitcoin_loading_indicator.dart';

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
      ]);
      
      final details = results[0];
      final trades30d = results[1];
      
      debugPrint('User Details: $details');
      debugPrint('30d Trades: $trades30d');
      
      if (mounted) {
        setState(() {
          _userDetails = details;
          _trades30d = trades30d;
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
    // Debug logging
    debugPrint('=== Building Profile Content ===');
    debugPrint('_userDetails: $_userDetails');
    
    if (_userDetails == null || _userDetails!.isEmpty) {
      return _buildNoDataView();
    }

    final user = _userDetails?['user'] ?? _userDetails;
    final stats = _userDetails?['stats'] ?? _userDetails?['userStats'] ?? {};
    final buyAds = _userDetails?['buyAds'] ?? 
                    _userDetails?['advertisements']?['buy'] ?? 
                    _userDetails?['buyAdvertisements'] ?? 
                    _userDetails?['data']?['buyAds'] ?? [];
    final sellAds = _userDetails?['sellAds'] ?? 
                     _userDetails?['advertisements']?['sell'] ?? 
                     _userDetails?['sellAdvertisements'] ?? 
                     _userDetails?['data']?['sellAds'] ?? [];

    debugPrint('Parsed user: $user');
    debugPrint('Parsed stats: $stats');
    debugPrint('Parsed buyAds: $buyAds');
    debugPrint('Parsed sellAds: $sellAds');

    final displayName = user?['userName'] ?? user?['name'] ?? user?['firstName'] ?? 
                        user?['username'] ?? widget.userName;
    final joinedDate = user?['createdAt'] ?? user?['joinDate'] ?? user?['joinedAt'] ?? 'Jan 2026';
    final emailVerified = user?['emailVerified'] ?? user?['isEmailVerified'] ?? 
                          user?['email_verified'] ?? false;
    final smsVerified = user?['smsVerified'] ?? user?['isSmsVerified'] ?? 
                        user?['phoneVerified'] ?? user?['phone_verified'] ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(displayName, joinedDate, emailVerified, smsVerified, stats),
          const SizedBox(height: 16),
          _buildStatsGrid(stats),
          const SizedBox(height: 24),
          if (buyAds.isNotEmpty) ...[
            _buildAdsSection('Online Buy Ads', buyAds, true),
            const SizedBox(height: 24),
          ],
          if (sellAds.isNotEmpty)
            _buildAdsSection('Online Sell Ads', sellAds, false),
          if (buyAds.isEmpty && sellAds.isEmpty)
            _buildNoAdsView(),
        ],
      ),
    );
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

  Widget _buildProfileHeader(String name, String joinedDate, bool emailVerified, bool smsVerified, Map stats) {
    final positiveFeedback = stats['positiveFeedback'] ?? stats['positivePercentage'] ?? 0;
    final totalFeedback = stats['totalFeedback'] ?? stats['totalReviews'] ?? 0;
    final positiveCount = stats['positiveCount'] ?? stats['positive'] ?? 0;
    final negativeCount = stats['negativeCount'] ?? stats['negative'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row with avatar, name, block button, and feedback card
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side - Avatar and name
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF84BD00),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
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
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Block',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Joined on $joinedDate',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (emailVerified) ...[
                                const Icon(Icons.check, color: Color(0xFF84BD00), size: 14),
                                const SizedBox(width: 4),
                                const Text('Email', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                const SizedBox(width: 12),
                              ],
                              if (smsVerified) ...[
                                const Icon(Icons.check, color: Color(0xFF84BD00), size: 14),
                                const SizedBox(width: 4),
                                const Text('SMS', style: TextStyle(color: Colors.white54, fontSize: 11)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right side - Feedback card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF3A3A3C)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Positive Feedback',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$positiveFeedback%',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '($totalFeedback)',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Positive $positiveCount',
                          style: const TextStyle(color: Color(0xFF84BD00), fontSize: 10),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Negative $negativeCount',
                          style: const TextStyle(color: Colors.red, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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
