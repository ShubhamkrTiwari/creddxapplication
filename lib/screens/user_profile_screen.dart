import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'update_profile_screen.dart';
import 'referral_hub_screen.dart';
import 'kyc_document_screen.dart';
import '../services/user_service.dart';
import '../services/p2p_service.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isAssetsAllocationExpanded = false;
  final UserService _userService = UserService();
  List<dynamic> _trustedDevices = [];
  bool _isLoadingDevices = true;

  @override
  void initState() {
    super.initState();
    // Initialize user data if not already done
    _loadUserData();
    _loadTrustedDevices();
  }

  Future<void> _loadUserData() async {
    await _userService.initUserData();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadTrustedDevices() async {
    try {
      debugPrint('Loading trusted devices...'); // Debug log
      final devices = await P2PService.getTrustedDevices();
      debugPrint('Fetched trusted devices: $devices'); // Debug log
      
      setState(() {
        _trustedDevices = devices;
        _isLoadingDevices = false;
      });
    } catch (e) {
      debugPrint('Error loading trusted devices: $e'); // Debug log
      setState(() {
        _trustedDevices = [];
        _isLoadingDevices = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh user data when screen regains focus
    _loadUserData();
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
        title: const Text('Profile', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hello ${_userService.userName ?? 'User'}',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const UpdateProfileScreen()));
                        },
                        child: const Text(
                          'Edit',
                          style: TextStyle(color: Color(0xFF84BD00), fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('User ID', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_userService.userId ?? '5a4e882d', style: const TextStyle(color: Colors.white, fontSize: 15)),
                        const Icon(Icons.copy, color: Colors.white54, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildProfileInfoRow('Email', _userService.userEmail ?? 'Not provided'),
                  const SizedBox(height: 12),
                  _buildProfileInfoRow('Sign-Up Time', _userService.signUpTime ?? '12/11/2025 | 12:30:45'),
                  const SizedBox(height: 12),
                  _buildProfileInfoRow('Last Log-In', _userService.lastLogin ?? '11/12/2025 | 11:02:12'),
                  const SizedBox(height: 24),
                  _buildKYCTile(),
                  const SizedBox(height: 24),
                  _buildReferralHubTile(),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            _buildExpandableSection(
              title: 'Assets Allocation',
              isExpanded: _isAssetsAllocationExpanded,
              onTap: () => setState(() => _isAssetsAllocationExpanded = !_isAssetsAllocationExpanded),
              content: _buildAssetsAllocationContent(),
            ),
            const Divider(color: Colors.white10, height: 1),
            _buildUSMESection(),
            const Divider(color: Colors.white10, height: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildKYCTile() {
    return GestureDetector(
      onTap: () async {
        if (_userService.isKYCNotStarted() || _userService.isKYCRejected()) {
          final result = await Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => const KYCDocumentScreen())
          );
          // KYC flow will handle status updates automatically
          if (result != null) {
            setState(() {});
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _userService.getKYCStatusColor().withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getKYCIcon(),
                color: _userService.getKYCStatusColor(),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KYC Verification',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getKYCDescription(),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _userService.kycStatus,
                  style: TextStyle(
                    color: _userService.getKYCStatusColor(),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_userService.kycSubmittedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _userService.kycSubmittedAt!,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ],
            ),
            if (_userService.isKYCNotStarted() || _userService.isKYCRejected())
              const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
          ],
        ),
      ),
    );
  }

  IconData _getKYCIcon() {
    switch (_userService.kycStatus) {
      case 'Verified':
        return Icons.verified;
      case 'Pending':
        return Icons.pending;
      case 'Rejected':
        return Icons.cancel;
      default:
        return Icons.fact_check;
    }
  }

  String _getKYCDescription() {
    switch (_userService.kycStatus) {
      case 'Verified':
        return 'Your identity has been verified';
      case 'Pending':
        return 'Verification in progress';
      case 'Rejected':
        return 'Please resubmit your documents';
      default:
        return 'Complete verification to unlock all features';
    }
  }

  Widget _buildReferralHubTile() {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const ReferralHubScreen()));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.hub_outlined, color: Color(0xFF84BD00), size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Referral Hub',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget content,
  }) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          trailing: Icon(
            isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: Colors.white54,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        ),
        if (isExpanded) content,
      ],
    );
  }

  Widget _buildAssetsAllocationContent() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              _buildToggleButton('Wallet View', true),
              const SizedBox(width: 8),
              _buildToggleButton('Coin View', false),
              const Spacer(),
              const Icon(Icons.search, color: Colors.white54, size: 20),
            ],
          ),
          const SizedBox(height: 24),
          _buildAssetRow('ETH', 'Wallet Balance', '***', '***'),
          const SizedBox(height: 20),
          _buildAssetRow('USDT', 'Wallet Balance', '***', '***'),
          const SizedBox(height: 20),
          _buildAssetRow('USDC', 'Wallet Balance', '***', '***'),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {},
              icon: const Text('Next', style: TextStyle(color: Colors.white70)),
              label: const Icon(Icons.arrow_forward, color: Colors.white70, size: 16),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white10,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String text, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? Colors.black : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isSelected ? Colors.white10 : Colors.transparent),
      ),
      child: Text(
        text,
        style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildAssetRow(String symbol, String label, String balance, String price) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(symbol, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('USDT Price: $price', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 4),
              Text(balance, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Column(
          children: [
            _buildAssetActionButton('Withdraw', const Color(0xFF84BD00)),
            const SizedBox(height: 8),
            _buildAssetActionButton('Deposit', Colors.white10),
          ],
        ),
      ],
    );
  }

  Widget _buildAssetActionButton(String text, Color color) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(color: color == const Color(0xFF84BD00) ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTrustedDevicesContent() {
    if (_isLoadingDevices) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF84BD00)),
        ),
      );
    }

    if (_trustedDevices.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.devices_outlined,
                size: 48,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 12),
              Text(
                'No trusted devices found',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your trusted devices will appear here',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: _trustedDevices.map((device) {
          // Extract data from API response
          final trusted = device['isTrusted'] == true || device['trusted'] == true ? 'YES' : 'NO';
          final ip = device['ipAddress'] ?? device['ip'] ?? 'Unknown IP';
          final date = device['lastLoginAt'] ?? device['createdAt'] ?? 'Unknown Date';
          final deviceName = device['deviceName'] ?? device['deviceType'] ?? 'Unknown Device';
          final deviceId = device['id']?.toString() ?? device['_id']?.toString() ?? '';
          
          return Column(
            children: [
              _buildDeviceItem(trusted, ip, date, deviceName, deviceId),
              if (device != _trustedDevices.last) 
                const Divider(color: Colors.white10, height: 32),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDeviceItem(String trusted, String ip, String date, String device, String deviceId) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Trusted Device', style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 4),
              Text(trusted, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Recent Activity', style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 4),
              Text(date, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Login IP', style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 4),
              Text(ip, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Recent Activity Device', style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(device, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  if (deviceId.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.verified_user_outlined,
                      color: trusted == 'YES' ? const Color(0xFF84BD00) : Colors.grey[600],
                      size: 16,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUSMESection() {
    return _buildExpandableSection(
      title: 'Security & Devices',
      isExpanded: true,
      onTap: () {},
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          
          // Section Header
          Row(
            children: [
              Icon(
                Icons.security_outlined,
                color: const Color(0xFF84BD00),
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text(
                'User Security & Management Environment',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Trusted Devices Subsection
          const Text(
            'Trusted Devices',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          
          // Trusted Devices Content
          if (_isLoadingDevices)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF84BD00)),
              ),
            )
          else if (_trustedDevices.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.devices_outlined,
                      size: 32,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No trusted devices found',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: _trustedDevices.map((device) {
                final trusted = device['isTrusted'] == true || device['trusted'] == true ? 'YES' : 'NO';
                final ip = device['ipAddress'] ?? device['ip'] ?? 'Unknown IP';
                final date = device['lastLoginAt'] ?? device['createdAt'] ?? 'Unknown Date';
                final deviceName = device['deviceName'] ?? device['deviceType'] ?? 'Unknown Device';
                final deviceId = device['id']?.toString() ?? device['_id']?.toString() ?? '';
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: trusted == 'YES' ? const Color(0xFF84BD00) : const Color(0xFF2C2C2E),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Device: $deviceName',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Status: $trusted',
                                  style: TextStyle(
                                    color: trusted == 'YES' ? const Color(0xFF84BD00) : Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Last Activity: $date',
                                  style: const TextStyle(
                                    color: Color(0xFF8E8E93),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.verified_user_outlined,
                            color: trusted == 'YES' ? const Color(0xFF84BD00) : Colors.grey[600],
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            color: const Color(0xFF8E8E93),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'IP Address: $ip',
                            style: const TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          
          const SizedBox(height: 32),
          
          // IP Address Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2C2C2E)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.network_check_outlined,
                      color: const Color(0xFF84BD00),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'IP Address Summary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Session IP',
                            style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '192.168.1.1', // This could be dynamic from API
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF84BD00).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Secure',
                        style: TextStyle(
                          color: const Color(0xFF84BD00),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
