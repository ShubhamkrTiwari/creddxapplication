import 'package:flutter/material.dart';
import '../services/p2p_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../utils/kyc_unlock_mixin.dart';
import 'login_screen.dart';
import 'order_history_screen.dart';
import 'p2p_chat_list_screen.dart';
import 'dispute_management_screen.dart';
import 'user_profile_screen.dart';
import 'update_profile_screen.dart';
import 'p2p_place_order_screen.dart';
import 'p2p_buy_screen.dart';
import 'p2p_sell_screen.dart';
import 'p2p_trading_orders_screen.dart';
import 'kyc_digilocker_instruction_screen.dart';
import 'kyc_document_screen.dart';

// Refresh Status Enum for UI state management
enum RefreshStatus { idle, loading, success, error }

// API Response State for tracking each section
class ApiSectionState {
  final String name;
  RefreshStatus status;
  dynamic data;
  String? errorMessage;
  DateTime? lastUpdated;

  ApiSectionState({
    required this.name,
    this.status = RefreshStatus.idle,
    this.data,
    this.errorMessage,
    this.lastUpdated,
  });
}

class P2PTradingScreen extends StatefulWidget {
  const P2PTradingScreen({super.key});

  @override
  State<P2PTradingScreen> createState() => _P2PTradingScreenState();
}

class _P2PTradingScreenState extends State<P2PTradingScreen> with SingleTickerProviderStateMixin, KYCUnlockMixin {
  final bool _isComingSoon = true;
  late AnimationController _comingSoonController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _fadeAnimation;

  bool _isBuySelected = true;
  String _selectedCrypto = 'USDT';
  List<dynamic> _cryptoList = [];
  List<dynamic> _offers = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isLoggedIn = false;
  bool _showAllAds = false; // Bypass filtering and show all ads
  
  // API Section States for granular refresh UI
  final Map<String, ApiSectionState> _apiStates = {
    'coins': ApiSectionState(name: 'Coins'),
    'advertisements': ApiSectionState(name: 'Advertisements'),
    'wallet': ApiSectionState(name: 'Wallet'),
  };
  
  // Pull to refresh controller
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();

    _comingSoonController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: -20).animate(
      CurvedAnimation(
        parent: _comingSoonController,
        curve: Curves.easeInOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _comingSoonController,
        curve: Curves.easeInOut,
      ),
    );

    if (_isComingSoon) return;
    _checkAuthAndFetchData();
  }

  @override
  void dispose() {
    _comingSoonController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndFetchData() async {
    setState(() {
      _isLoading = true;
      _showAllAds = false; // Reset filter bypass on refresh
    });
    
    final token = await AuthService.getToken();
    _isLoggedIn = token != null && token.isNotEmpty;
    
    // Fetch all data in parallel for better performance
    await Future.wait([
      _fetchCryptoList(),
      _fetchAdvertisements(),
    ]);
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // Enhanced refresh method with individual section tracking
  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    
    try {
      // Refresh all sections in parallel
      await Future.wait([
        _refreshCryptoList(),
        _refreshAdvertisements(),
      ]);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data refreshed successfully'),
            backgroundColor: Color(0xFF84BD00),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _refreshCryptoList() async {
    _apiStates['coins']!.status = RefreshStatus.loading;
    setState(() {});
    
    try {
      final coins = await P2PService.getP2PCoins();
      if (mounted) {
        setState(() {
          _cryptoList = coins;
          if (coins.isNotEmpty && !_cryptoList.any((c) => c['coinSymbol'] == _selectedCrypto)) {
            _selectedCrypto = coins[0]['coinSymbol'] ?? 'USDT';
          }
          _apiStates['coins']!.status = RefreshStatus.success;
          _apiStates['coins']!.data = coins;
          _apiStates['coins']!.lastUpdated = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _apiStates['coins']!.status = RefreshStatus.error;
          _apiStates['coins']!.errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _refreshAdvertisements() async {
    _apiStates['advertisements']!.status = RefreshStatus.loading;
    setState(() {});
    
    try {
      final ads = await P2PService.getAllAdvertisements(
        coin: _selectedCrypto,
        direction: _isBuySelected ? 2 : 1,
      );
      if (mounted) {
        setState(() {
          _offers = ads;
          _apiStates['advertisements']!.status = RefreshStatus.success;
          _apiStates['advertisements']!.data = ads;
          _apiStates['advertisements']!.lastUpdated = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _apiStates['advertisements']!.status = RefreshStatus.error;
          _apiStates['advertisements']!.errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _fetchCryptoList() async {
    _apiStates['coins']!.status = RefreshStatus.loading;
    
    try {
      final coins = await P2PService.getP2PCoins();
      if (mounted) {
        setState(() {
          _cryptoList = coins;
          if (coins.isNotEmpty && !_cryptoList.any((c) => c['coinSymbol'] == _selectedCrypto)) {
            _selectedCrypto = coins[0]['coinSymbol'] ?? 'USDT';
          }
          _apiStates['coins']!.status = RefreshStatus.success;
          _apiStates['coins']!.data = coins;
          _apiStates['coins']!.lastUpdated = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('Error fetching crypto list: $e');
      if (mounted) {
        setState(() {
          _apiStates['coins']!.status = RefreshStatus.error;
          _apiStates['coins']!.errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _fetchAdvertisements() async {
    _apiStates['advertisements']!.status = RefreshStatus.loading;
    
    try {
      final ads = await P2PService.getAllAdvertisements(
        coin: _selectedCrypto,
        direction: _isBuySelected ? 2 : 1, // 2 = buy, 1 = sell
      );
      if (mounted) {
        setState(() {
          _offers = ads;
          _apiStates['advertisements']!.status = RefreshStatus.success;
          _apiStates['advertisements']!.data = ads;
          _apiStates['advertisements']!.lastUpdated = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('Error fetching advertisements: $e');
      if (mounted) {
        setState(() {
          _apiStates['advertisements']!.status = RefreshStatus.error;
          _apiStates['advertisements']!.errorMessage = e.toString();
        });
      }
    }
  }

  // Check if KYC is completed
  bool _isKYCCompleted() {
    return isKYCCompleted(); // Use the mixin method
  }

  // Check if profile is complete
  bool _isProfileComplete() {
    return _userService.hasEmail() && 
           _userService.userPhone != null && 
           _userService.userPhone!.isNotEmpty;
  }

  // Validate KYC and profile before proceeding
  bool _validateUserRequirements() {
    if (!_isKYCCompleted()) {
      _showKYCRequiredDialog();
      return false;
    }
    
    if (!_isProfileComplete()) {
      _showProfileRequiredDialog();
      return false;
    }
    
    return true;
  }

  // Show KYC required dialog
  void _showKYCRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'KYC Verification Required',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You need to complete KYC verification to access P2P trading features.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const KYCDocumentScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF84BD00),
            ),
            child: const Text('Complete KYC', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // Show profile required dialog
  void _showProfileRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Profile Incomplete',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Please complete your profile (email and phone number) to access P2P trading features.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const UpdateProfileScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF84BD00),
            ),
            child: const Text('Complete Profile', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isComingSoon) {
      return _buildComingSoonScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text('P2P Trading', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          // Refresh indicator icon
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Color(0xFF84BD00),
                  strokeWidth: 2,
                ),
              ),
          )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF84BD00)),
              onPressed: _refreshData,
              tooltip: 'Refresh Data',
            ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF84BD00)),
            onPressed: () {
              if (_validateUserRequirements()) {
                _showCreateAdDialog();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildApiStatusBar(),
          _buildTypeToggle(),
          _buildCryptoSelector(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
                : _buildAdsList(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // Build API status indicator bar at the top
  Widget _buildApiStatusBar() {
    final hasErrors = _apiStates.values.any((state) => state.status == RefreshStatus.error);
    final isLoading = _apiStates.values.any((state) => state.status == RefreshStatus.loading);
    
    if (!hasErrors && !isLoading) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: hasErrors ? Colors.redAccent.withOpacity(0.1) : const Color(0xFF84BD00).withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: hasErrors ? Colors.redAccent : const Color(0xFF84BD00),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasErrors ? Icons.error_outline : Icons.sync,
            color: hasErrors ? Colors.redAccent : const Color(0xFF84BD00),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasErrors
                  ? 'Some data failed to load. Pull down to retry.'
                  : 'Updating data...',
              style: TextStyle(
                color: hasErrors ? Colors.redAccent : const Color(0xFF84BD00),
                fontSize: 12,
              ),
            ),
          ),
          if (hasErrors)
            TextButton(
              onPressed: _refreshData,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'RETRY',
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _buildToggleButton('Buy', _isBuySelected, () => setState(() {
            _isBuySelected = true;
            _fetchAdvertisements();
          })),
          _buildToggleButton('Sell', !_isBuySelected, () => setState(() {
            _isBuySelected = false;
            _fetchAdvertisements();
          })),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? (label == 'Buy' ? const Color(0xFF84BD00) : Colors.redAccent) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: isSelected ? Colors.black : Colors.white54, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildCryptoSelector() {
    if (_cryptoList.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (_apiStates['coins']?.status == RefreshStatus.loading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Color(0xFF84BD00),
                  strokeWidth: 2,
                ),
              )
            else if (_apiStates['coins']?.status == RefreshStatus.error)
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.redAccent, size: 18),
                onPressed: _refreshCryptoList,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            else
              const Icon(Icons.monetization_on, color: Colors.white54, size: 16),
            const SizedBox(width: 8),
            Text(
              _apiStates['coins']?.status == RefreshStatus.loading
                  ? 'Loading coins...'
                  : _apiStates['coins']?.status == RefreshStatus.error
                      ? 'Failed to load coins'
                      : 'No coins available',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _cryptoList.map((coin) {
          final symbol = coin['coinSymbol'] ?? 'USDT';
          final isSelected = _selectedCrypto == symbol;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCrypto = symbol);
              _fetchAdvertisements();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isSelected ? const Color(0xFF84BD00) : Colors.transparent, width: 2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    symbol,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF84BD00) : Colors.white54,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (isSelected && _apiStates['advertisements']?.status == RefreshStatus.loading)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          color: Color(0xFF84BD00),
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAdsList() {
    debugPrint('=== BUILDING ADS LIST ===');
    debugPrint('Total offers from API: ${_offers.length}');
    debugPrint('Buy selected: $_isBuySelected (looking for ${_isBuySelected ? "sell" : "buy"} ads)');
    debugPrint('Selected crypto: $_selectedCrypto');
    
    // Print first offer structure for debugging
    if (_offers.isNotEmpty) {
      debugPrint('First offer structure: ${_offers.first}');
    }
    
    final type = _isBuySelected ? 'sell' : 'buy';
    
    List<dynamic> filteredAds = [];
    List<dynamic> sameTypeAds = []; // Same type but different coin
    List<dynamic> sameCoinAds = []; // Same coin but different type
    
    for (var ad in _offers) {
      String adType = '';
      if (ad['type'] != null) {
        adType = ad['type'].toString().toLowerCase();
      } else if (ad['tradeType'] != null) {
        adType = ad['tradeType'].toString().toLowerCase();
      } else if (ad['advertisementType'] != null) {
        adType = ad['advertisementType'].toString().toLowerCase();
      } else if (ad['direction'] != null) {
        // Handle numeric direction: 1 = buy, 2 = sell
        final direction = ad['direction'];
        adType = (direction == 1 || direction == '1') ? 'buy' : 'sell';
      }
      
      String adCoin = '';
      if (ad['coin'] != null) {
        adCoin = ad['coin'].toString().toUpperCase();
      } else if (ad['coinSymbol'] != null) {
        adCoin = ad['coinSymbol'].toString().toUpperCase();
      } else if (ad['cryptocurrency'] != null) {
        adCoin = ad['cryptocurrency'].toString().toUpperCase();
      } else if (ad['coinId'] != null) {
        adCoin = ad['coinId'].toString().toUpperCase();
      }
      
      // Debug each ad
      debugPrint('Ad: type=$adType, coin=$adCoin, looking for type=$type, coin=$_selectedCrypto');
      
      final typeMatches = adType == type;
      final coinMatches = adCoin == _selectedCrypto.toUpperCase() || 
                         adCoin.contains(_selectedCrypto.toUpperCase()) ||
                         _selectedCrypto.toUpperCase().contains(adCoin);
      
      if (typeMatches && coinMatches) {
        filteredAds.add(ad);
      } else if (typeMatches) {
        sameTypeAds.add(ad);
      } else if (coinMatches) {
        sameCoinAds.add(ad);
      }
    }
    
    debugPrint('Filtered ads count: ${filteredAds.length}');
    debugPrint('Same type (different coin): ${sameTypeAds.length}');
    debugPrint('Same coin (different type): ${sameCoinAds.length}');
    
    // Fallback: if no exact match but we have same type ads, show those
    if (filteredAds.isEmpty && sameTypeAds.isNotEmpty && !_showAllAds) {
      debugPrint('Showing ads with matching type but different coin');
      filteredAds = sameTypeAds;
    }
    
    // If user wants to see all ads, bypass all filtering
    if (_showAllAds && _offers.isNotEmpty) {
      debugPrint('Showing all ads (filter bypassed)');
      filteredAds = List.from(_offers);
    }

    // Show loading state for advertisements
    if (_apiStates['advertisements']?.status == RefreshStatus.loading && _offers.isEmpty) {
      return RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _refreshData,
        color: const Color(0xFF84BD00),
        backgroundColor: const Color(0xFF1C1C1E),
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFF84BD00)),
                  SizedBox(height: 16),
                  Text('Loading advertisements...', style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (filteredAds.isEmpty) {
      String message = 'No active advertisements found';
      String subMessage = '';
      
      if (!_isLoggedIn) {
        message = 'Please log in to view advertisements';
      } else if (_offers.isEmpty) {
        if (_apiStates['advertisements']?.status == RefreshStatus.error) {
          message = 'Failed to load advertisements';
          subMessage = _apiStates['advertisements']?.errorMessage ?? 'Pull down to retry';
        } else {
          message = 'No advertisements available';
          subMessage = 'Be the first to create an ad!';
        }
      } else {
        message = 'No $type advertisements for $_selectedCrypto';
        subMessage = 'Try switching to ${_isBuySelected ? 'Sell' : 'Buy'} tab or select different coin';
      }
      
      return RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _refreshData,
        color: const Color(0xFF84BD00),
        backgroundColor: const Color(0xFF1C1C1E),
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.15),
            Center(
              child: Column(
                children: [
                  Icon(
                    _apiStates['advertisements']?.status == RefreshStatus.error
                        ? Icons.error_outline
                        : Icons.inbox_outlined,
                    color: Colors.white54,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  if (subMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 32, right: 32),
                      child: Text(
                        subMessage,
                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            if (!_isLoggedIn)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    ).then((_) => _checkAuthAndFetchData());
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF84BD00)),
                  child: const Text('Login to View Ads', style: TextStyle(color: Colors.black)),
                ),
              ),
            if (_apiStates['advertisements']?.status == RefreshStatus.error)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton.icon(
                  onPressed: _refreshData,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('Retry', style: TextStyle(color: Colors.white)),
                ),
              ),
            // Show All Ads button when we have offers but filtered is empty
            if (_offers.isNotEmpty && filteredAds.isEmpty && !_showAllAds)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Show all ads without filtering
                    setState(() {
                      _showAllAds = true;
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  icon: const Icon(Icons.visibility, color: Colors.white),
                  label: Text('Show All ${_offers.length} Ads', style: const TextStyle(color: Colors.white)),
                ),
              ),
            const SizedBox(height: 20),
            Center(
              child: TextButton.icon(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh, color: Color(0xFF84BD00), size: 18),
                label: const Text('Pull to refresh', style: TextStyle(color: Color(0xFF84BD00))),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      key: _refreshIndicatorKey,
      onRefresh: _refreshData,
      color: const Color(0xFF84BD00),
      backgroundColor: const Color(0xFF1C1C1E),
      displacement: 40,
      strokeWidth: 3,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredAds.length + 1, // +1 for last updated text
        itemBuilder: (context, index) {
          if (index == filteredAds.length) {
            // Last item - show last updated timestamp
            final lastUpdated = _apiStates['advertisements']?.lastUpdated;
            if (lastUpdated != null) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Last updated: ${_formatLastUpdated(lastUpdated)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }
          return _buildAdCard(filteredAds[index]);
        },
      ),
    );
  }

  String _formatLastUpdated(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildAdCard(dynamic ad) {
    final advertiser = ad['advertiser'] ?? {};
    final userName = ad['advertiserName'] ?? 
                     ad['userName'] ?? 
                     ad['name'] ?? 
                     ad['sellerName'] ?? 
                     ad['buyerName'] ??
                     advertiser['userName'] ?? 
                     advertiser['name'] ?? 
                     'Trader';
    
    final price = ad['price'] ?? ad['rate'] ?? ad['pricePerUnit'] ?? ad['unitPrice'] ?? 0;
    final minLimit = ad['min'] ?? ad['minAmount'] ?? ad['minimumLimit'] ?? ad['minLimit'] ?? 0;
    final maxLimit = ad['max'] ?? ad['maxAmount'] ?? ad['maximumLimit'] ?? ad['maxLimit'] ?? 0;
    final available = ad['amount'] ?? ad['availableAmount'] ?? ad['quantity'] ?? ad['available'] ?? 0;
    
    var paymentModes = ad['paymentMode'] ?? ad['paymentMethods'] ?? ad['paymentMethodsList'] ?? ad['paymentOptions'] ?? ['Bank Transfer'];
    if (paymentModes is! List) {
      paymentModes = [paymentModes.toString()];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 14, backgroundColor: const Color(0xFF5C4B2A), child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'T', style: const TextStyle(color: Colors.white, fontSize: 12))),
              const SizedBox(width: 8),
              Expanded(child: Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              const Text('98% completion', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Price', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text('₹$price', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Available: $available $_selectedCrypto', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  Text('Limit: ₹$minLimit - ₹$maxLimit', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: paymentModes.map<Widget>((mode) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                      child: Text(mode.toString(), style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    );
                  }).toList(),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => P2PPlaceOrderScreen(
                        adId: ad['_id'] ?? ad['id'] ?? ad['advertisementId'] ?? '',
                        orderType: _isBuySelected ? 'buy' : 'sell',
                        userName: userName,
                        price: price.toString(),
                        available: available.toString(),
                        paymentMethods: paymentModes.map<String>((e) => e.toString()).toList(),
                        minLimit: minLimit is double ? minLimit : (minLimit is int ? minLimit.toDouble() : double.tryParse(minLimit.toString()) ?? 0.0),
                        maxLimit: maxLimit is double ? maxLimit : (maxLimit is int ? maxLimit.toDouble() : double.tryParse(maxLimit.toString()) ?? 0.0),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isBuySelected ? const Color(0xFF84BD00) : Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                child: Text(_isBuySelected ? 'Buy' : 'Sell', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFF1C1C1E),
      selectedItemColor: const Color(0xFF84BD00),
      unselectedItemColor: Colors.white54,
      type: BottomNavigationBarType.fixed,
      currentIndex: 0,
      onTap: (index) {
        switch (index) {
          case 1:
            Navigator.push(context, MaterialPageRoute(builder: (context) => const OrderHistoryScreen()));
            break;
          case 2:
            Navigator.push(context, MaterialPageRoute(builder: (context) => const P2PChatListScreen()));
            break;
          case 3:
            Navigator.push(context, MaterialPageRoute(builder: (context) => const DisputeManagementScreen()));
            break;
          case 4:
            Navigator.push(context, MaterialPageRoute(builder: (context) => const UserProfileScreen()));
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'P2P'),
        BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Orders'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chats'),
        BottomNavigationBarItem(icon: Icon(Icons.gavel), label: 'Disputes'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
      ],
    );
  }

  void _showCreateAdDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Create Advertisement', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.arrow_downward, color: Color(0xFF84BD00)),
              title: const Text('Buy USDT', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                if (_validateUserRequirements()) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const P2PBuyScreen()));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward, color: Colors.redAccent),
              title: const Text('Sell USDT', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                if (_validateUserRequirements()) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const P2PSellScreen()));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.list, color: Colors.blue),
              title: const Text('My Advertisements', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const P2PTradingOrdersScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComingSoonScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text(
          'P2P Trading',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _bounceAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _bounceAnimation.value),
                  child: AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFF84BD00).withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF84BD00).withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.people_outline,
                            size: 60,
                            color: Color(0xFF84BD00),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            const Text(
              'Coming Soon',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'P2P trading is under development. Stay tuned for peer-to-peer trading features!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF84BD00).withOpacity(0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule,
                    color: Color(0xFF84BD00),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Launching Soon',
                    style: TextStyle(
                      color: Color(0xFF84BD00),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class KYCDocumentInstructionScreen {
  const KYCDocumentInstructionScreen();
}
