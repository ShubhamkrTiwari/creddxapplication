import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'invite_friends_screen.dart';
import 'refer_earn_modal.dart';
import '../services/user_service.dart';

class ReferralHubScreen extends StatefulWidget {
  const ReferralHubScreen({super.key});

  @override
  State<ReferralHubScreen> createState() => _ReferralHubScreenState();
}

class _ReferralHubScreenState extends State<ReferralHubScreen> {
  final UserService _userService = UserService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _referredFriends = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchReferredFriends();
  }

  Future<void> _fetchReferredFriends() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _userService.getReferredFriends();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result['success'] == true) {
            final data = result['data'];
            if (data['friends'] != null) {
              _referredFriends = List<Map<String, dynamic>>.from(data['friends']);
            } else if (data is List) {
              _referredFriends = List<Map<String, dynamic>>.from(data);
            } else if (data['referredFriends'] != null) {
              _referredFriends = List<Map<String, dynamic>>.from(data['referredFriends']);
            }
          } else {
            _errorMessage = result['error'] ?? 'Failed to load referred friends';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Network error: $e';
        });
      }
    }
  }

  void _showInviteFriendsModal() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const InviteFriendsScreen()),
    );
    // Refresh referred friends list after inviting
    _fetchReferredFriends();
  }

  void _showReferEarnModal() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ReferEarnModal(email: _userService.userEmail),
      barrierDismissible: false,
    );

    // If referral was successfully claimed, refresh the referred friends list
    if (result == true) {
      _fetchReferredFriends();
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
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
        ),
        title: const Text(
          'Refer & Earn',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  const Text(
                    'Refer & Share the Opportunity,\nEarn CreddX Points',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Invite your friends and fellow traders to join CreddX, and earn CreddX Points for every successful referral.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildStepCard(
                    '1',
                    'For every friend who joins and completes a challenge, you earn CreddX Points.',
                  ),
                  const SizedBox(height: 16),
                  _buildStepCard(
                    '2',
                    'Every CreddX Point adds up toward exclusive rewards, merchandise, and bonuses.',
                  ),
                  const SizedBox(height: 16),
                  _buildStepCard(
                    '3',
                    'Top referrers are featured monthly on our Referral Hall of Fame.',
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'The more you share, the more you earn.',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'No limits. No expiry. Your network = your passive income.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 32),
                  // Referred Friends Section
                  _buildReferredFriendsSection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Invite Friends Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _showInviteFriendsModal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF84BD00),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Invite Friends',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Claim Referral Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _showReferEarnModal,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF84BD00)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Claim Referral Code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF84BD00),
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

  Widget _buildStepCard(String number, String description) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            number,
            style: TextStyle(
              color: Colors.white.withOpacity(0.15),
              fontSize: 80,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferredFriendsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Your Referred Friends',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Color(0xFF84BD00), strokeWidth: 2),
                )
              else
                GestureDetector(
                  onTap: _fetchReferredFriends,
                  child: const Icon(Icons.refresh, color: Color(0xFF84BD00), size: 20),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(color: Color(0xFF84BD00)),
              ),
            )
          else if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _fetchReferredFriends,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF84BD00),
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_referredFriends.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(Icons.people_outline, color: Colors.white54, size: 48),
                    SizedBox(height: 8),
                    Text(
                      'No referred friends yet',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Start inviting friends to earn rewards!',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _referredFriends.length,
              itemBuilder: (context, index) {
                final friend = _referredFriends[index];
                return _buildFriendItem(friend);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFriendItem(Map<String, dynamic> friend) {
    final name = friend['name']?.toString() ?? friend['fullName']?.toString() ?? 'Unknown';
    final email = friend['email']?.toString() ?? friend['emailId']?.toString() ?? 'No email';
    final status = friend['status']?.toString() ?? friend['referralStatus']?.toString() ?? 'pending';
    final joinedAt = friend['joinedAt']?.toString() ?? friend['createdAt']?.toString() ?? friend['registeredAt']?.toString();
    final points = friend['points']?.toString() ?? friend['rewardPoints']?.toString() ?? '0';
    
    String formattedDate = 'Unknown';
    if (joinedAt != null) {
      try {
        final dateTime = DateTime.parse(joinedAt);
        formattedDate = DateFormat('MMM dd, yyyy').format(dateTime);
      } catch (e) {
        formattedDate = joinedAt;
      }
    }

    Color statusColor = status == 'active' || status == 'completed' ? const Color(0xFF84BD00) : 
                       status == 'pending' ? Colors.orange : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF84BD00).withOpacity(0.2),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: Color(0xFF84BD00),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Points',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                points,
                style: const TextStyle(
                  color: Color(0xFF84BD00),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
