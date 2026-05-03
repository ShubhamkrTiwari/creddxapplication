import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/p2p_service.dart';
import '../services/kyc_service.dart';
import 'login_screen.dart';
import 'affiliate_program_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId; // Added userId parameter
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;
  int _selectedAdsTabIndex = 1; // 0 for Buy, 1 for Sell
  
  bool _isLoading = true;
  Map<String, dynamic>? _userDetails;
  Map<String, dynamic>? _tradesSummary;
  Map<String, dynamic>? _feedbackStats;
  List<dynamic> _myAds = [];
  String _avgPayTime = 'N/A';
  String _avgReleaseTime = 'N/A';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    setState(() => _isLoading = true);
    try {
      final String? targetUserId = widget.userId;
      
      // If we have a userId, fetch that user's details, otherwise use logged-in user
      final results = await Future.wait([
        P2PService.getP2PUserDetails(userId: targetUserId ?? ''),
        P2PService.getUserAllTradesSummary(),
        P2PService.getUserFeedbackStatistics(userId: targetUserId),
        P2PService.getMyAdsWithFilters(),
      ]);

      _userDetails = results[0];
      _tradesSummary = results[1];
      _feedbackStats = results[2];
      _myAds = results[3]?['docs']?['docs'] ?? []; // Based on common response structure

      // Fetch average times if we have a userId
      if (targetUserId != null) {
        final payTimeResult = await P2PService.getAveragePayTime(targetUserId);
        final releaseTimeResult = await P2PService.getAverageReleaseTime(targetUserId);
        
        if (payTimeResult['success'] == true) {
          _avgPayTime = payTimeResult['averagePayTime'] ?? 'N/A';
        }
        if (releaseTimeResult['success'] == true) {
          _avgReleaseTime = releaseTimeResult['averagePayTime'] ?? 'N/A'; // API doc says 'averagePayTime' for release too
        }
      }

      // Fetch real-time KYC status from API
      await _checkAndUpdateKYCStatus();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching profile data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkAndUpdateKYCStatus() async {
    try {
      final kycResult = await KYCService.getKYCStatus();
      if (kycResult['success'] == true) {
        final responseData = kycResult['data'];
        final status = responseData?['status']?.toString().toLowerCase() ?? '';
        
        // Update KYC status in user details based on API response
        final bool isKycVerified = status == 'completed' || status == 'already_completed';
        final bool isKycRejected = status == 'rejected';
        
        if (_userDetails != null && _userDetails!['userDetails'] != null) {
          _userDetails!['userDetails']['isKycVerified'] = isKycVerified;
          _userDetails!['userDetails']['kycStatus'] = status;
          debugPrint('KYC Status updated from API: $status, isKycVerified: $isKycVerified, isKycRejected: $isKycRejected');
          
          // Update UI to reflect new KYC status
          if (mounted) {
            setState(() {});
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking KYC status from API: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF161618),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF84BD00)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF161618),
      body: Stack(
        children: [
          Column(
            children: [
              _buildCustomAppBar(),
              _buildUserInfo(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDetailTab(),
                    _buildAdsTab(),
                  ],
                ),
              ),
            ],
          ),
          _buildTabs(),
        ],
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return SafeArea(
      child: Container(
        height: 44,
        color: const Color(0xFF161618),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
                size: 20,
              ),
            ),
            GestureDetector(
              onTap: () => _showLogoutConfirmDialog(),
              child: const Icon(
                Icons.logout,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text(
            'Logout',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _handleLogout();
              },
              child: const Text(
                'Logout',
                style: TextStyle(color: Color(0xFFFF3B30)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    final result = await AuthService.logout();
    if (result['success'] == true) {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (route) => false,
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Logout failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildUserInfo() {
    final user = _userDetails?['userDetails'] ?? {};
    final name = user['fullName'] ?? 'User';
    final registrationDays = _tradesSummary?['firstTradeDaysAgo'] ?? 'N/A';
    final kycStatus = user['kycStatus']?.toString().toLowerCase() ?? '';
    final isKycVerified = kycStatus == 'completed' || kycStatus == 'already_completed';
    final isKycRejected = kycStatus == 'rejected';

    return Container(
      color: const Color(0xFF161618),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF84BD00),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C851),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF161618), width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isKycVerified) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFF84BD00),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Online',
                      style: TextStyle(
                        color: Color(0xFF00C851),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatusItem('Email', user['isEmailVerified'] == true ? 'Done' : 'Pending', 
                  user['isEmailVerified'] == true ? const Color(0xFF00C851) : const Color(0xFF8E8E93)),
              const SizedBox(width: 24),
              _buildStatusItem('Phone', 'Done', const Color(0xFF00C851)), // Assume phone is verified if logged in
              const SizedBox(width: 24),
              _buildStatusItem('KYC', 
                  isKycVerified ? 'Complete' : (isKycRejected ? 'Rejected' : 'Pending'), 
                  isKycVerified ? const Color(0xFF00C851) : (isKycRejected ? const Color(0xFFFF3B30) : const Color(0xFFFF9500))),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            registrationDays.contains('Ago') ? '$registrationDays since the first trade' : 'New User',
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String status, Color statusColor) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          TextSpan(
            text: status,
            style: TextStyle(
              color: statusColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Positioned(
      top: 240,
      left: 22,
      child: Container(
        width: 140,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          labelColor: Colors.black,
          unselectedLabelColor: Colors.white,
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Detail'),
            Tab(text: 'Ads'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTab() {
    final user = _userDetails?['userDetails'] ?? {};
    final trades30d = user['total30dBuySell'] ?? 0;
    final counterparties = user['uniqueCounterpartiesCount'] ?? 0;
    final totalTrades = user['totalOrdersCount'] ?? 0;
    final buyTrades = user['buyOrdersCount'] ?? 0;
    final sellTrades = user['sellOrdersCount'] ?? 0;

    return Container(
      color: const Color(0xFF161618),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Affiliate Program Button
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AffiliateProgramScreen(),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF84BD00), Color(0xFF6A9600)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Affiliate Program',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'View your referral income',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
            _buildDetailItem('30D Trades', trades30d.toString()),
            _buildDetailItem('Trade Counterparties', counterparties.toString()),
            _buildDetailItem('Total Completed Trades', totalTrades.toString()),
            _buildDetailItem('Buy', buyTrades.toString(), color: const Color(0xFF00C851)),
            _buildDetailItem('Sell', sellTrades.toString(), color: const Color(0xFFFF3B30)),
            _buildDetailItem('Avg. Release Time', _avgReleaseTime),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (color != null)
            Container(
              width: 4,
              height: 16,
              color: color,
              margin: const EdgeInsets.only(right: 16),
            ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdsTab() {
    final filteredAds = _myAds.where((ad) {
      if (_selectedAdsTabIndex == 0) {
        return ad['direction'] == 1; // Buy
      } else {
        return ad['direction'] == 2; // Sell
      }
    }).toList();

    return Container(
      color: const Color(0xFF161618),
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildTabButton('Buy', 0),
                  const SizedBox(width: 16),
                  _buildTabButton('Sell', 1),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (filteredAds.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Text(
                    'No advertisements found',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ),
              )
            else
              ...filteredAds.map((ad) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildRealAdCard(ad),
              )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRealAdCard(dynamic ad) {
    final bool isBuy = ad['direction'] == 1;
    final price = ad['price'] ?? 0;
    final coin = ad['coinSymbol'] ?? 'USDT';
    final currency = ad['currency'] ?? 'INR';
    final minLimit = ad['minOrder'] ?? 0;
    final maxLimit = ad['maxOrder'] ?? 0;
    final available = ad['quantity'] ?? 0;
    final payModes = ad['payModes'] ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹$price',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '/$coin',
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ...payModes.map((mode) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 4,
                          height: 16,
                          color: _getPayModeColor(mode.toString()),
                          margin: const EdgeInsets.only(right: 8),
                        ),
                        Text(
                          mode.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                    decoration: BoxDecoration(
                      color: isBuy ? const Color(0xFF84BD00) : Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isBuy ? 'Buy' : 'Sell',
                      style: TextStyle(
                        color: isBuy ? Colors.black : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Limit: ₹$minLimit - ₹$maxLimit',
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Available: $available $coin',
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPayModeColor(String mode) {
    if (mode.contains('UPI')) return Colors.deepPurpleAccent;
    if (mode.contains('Bank')) return Colors.orangeAccent;
    return Colors.blueAccent;
  }

  Widget _buildSellAdCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '₹99.990',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    '/USDT',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        color: Colors.deepPurpleAccent,
                        margin: const EdgeInsets.only(right: 8),
                      ),
                      const Text(
                        'UPI Payment',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        color: Colors.orangeAccent,
                        margin: const EdgeInsets.only(right: 8),
                      ),
                      const Text(
                        'Bank Transfer (India)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Handle Sell button press
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      'Sell',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Limit: ₹20,000.00 - ₹1,00,000.00',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Available: 103.60 USDT',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, int index) {
    bool isSelected = _selectedAdsTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAdsTabIndex = index;
        });
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 3,
              width: 30,
              color: Colors.lightGreenAccent,
            ),
        ],
      ),
    );
  }

  Widget _buildAdCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '₹99.990',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            '/USDT',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Limit: ₹20,000.00 - ₹1,00,000.00',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Available: 103.60 USDT',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPaymentMethod('UPI Payment', const Color(0xFF9C27B0)),
                  const SizedBox(height: 8),
                  _buildPaymentMethod('Bank Transfer (India)', const Color(0xFFFF9800)),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF84BD00),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                  child: Text(
                    'Buy',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod(String method, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 12,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(
          method,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
