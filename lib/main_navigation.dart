import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'screens/dashboard_screen.dart';
import 'screens/futures_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/bot_main_screen.dart';
import 'screens/bot_trading_screen.dart';
import 'screens/home_screen.dart';
import 'screens/spot_screen.dart';
import 'screens/p2p_user_profile_screen.dart';
import '../services/wallet_service.dart';
import '../services/user_service.dart';
import '../services/unified_wallet_service.dart';
import '../services/socket_service.dart';

class MainNavigation extends StatefulWidget {
  final int initialIndex;
  const MainNavigation({super.key, this.initialIndex = 0});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with WidgetsBindingObserver {
  late int _selectedIndex;
  late final UserService _userService;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _userService = UserService();
    
    // Add app lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    
    // Step 1: Initialize Unified Wallet Service early
    debugPrint('MainNavigation: Initializing UnifiedWalletService...');
    UnifiedWalletService.initialize();
    
    // Step 2: Connect to websocket
    debugPrint('MainNavigation: Connecting to websocket...');
    _connectWebSocket();
    
    _screens = [
      const HomeScreen(),
      const FuturesScreen(),
      const BotMainScreen(),
      const SpotScreen(),
      const WalletScreen(),
    ];
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('MainNavigation: App lifecycle state changed to: $state');
    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('MainNavigation: App resumed, reconnecting websocket...');
        _connectWebSocket();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        debugPrint('MainNavigation: App paused/inactive/detached/hidden');
        break;
    }
  }
  
  Future<void> _connectWebSocket() async {
    try {
      if (!SocketService.isConnected) {
        debugPrint('MainNavigation: Socket not connected, connecting now...');
        await SocketService.connect();
        debugPrint('MainNavigation: Socket connection status: ${SocketService.isConnected}');
      } else {
        debugPrint('MainNavigation: Socket already connected');
      }
    } catch (e) {
      debugPrint('MainNavigation: Error connecting socket: $e');
    }
  }

  Widget _buildP2PProfileScreen() {
    return FutureBuilder<void>(
      future: _userService.initUserData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)));
        }

        final userId = _userService.userId ?? '';
        final userName = _userService.userName ?? 'User';

        if (userId.isEmpty) {
          return const Center(
            child: Text(
              'Please login to view profile',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        return P2PUserProfileScreen(userId: userId, userName: userName);
      },
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  
  @override
  void dispose() {
    debugPrint('MainNavigation: Disposing, removing observer');
    WidgetsBinding.instance.removeObserver(this);
    // Don't disconnect socket here as it should stay connected for the entire app session
    // Socket will be disconnected when app is fully terminated
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hide main bottom nav if BotMainScreen (index 2) is active
    bool showMainBottomNav = _selectedIndex != 2;

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: showMainBottomNav ? _buildBottomNavigationBar() : null,
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      padding: const EdgeInsets.only(top: 2, bottom: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D0D),
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5))
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem('assets/images/home.png', 'Home', 0),
          Container(
            margin: const EdgeInsets.only(top: 9),
            child: _navItem('assets/images/future.png', 'Futures', 1),
          ),
          _navItem('assets/images/bot.png', 'Bot Trade', 2),
          _navItem('assets/images/spot.png', 'Spot', 3),
          _navItem('assets/images/wallet.png', 'Wallet', 4),
        ],
      ),
    );
  }

  Widget _navItem(String iconPath, String label, int index) {
    final bool isActive = _selectedIndex == index;
    
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive) Container(
            width: 30, 
            height: 3, 
            decoration: const BoxDecoration(
              color: Color(0xFF84BD00), 
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(2))
            )
          ) else const SizedBox(height: 3),
          const SizedBox(height: 8),
          Image.asset(
            iconPath, 
            width: 48, 
            height: 48, 
            color: isActive ? const Color(0xFF84BD00) : const Color(0xFF6C7278), 
            errorBuilder: (c, e, s) => Icon(
              Icons.circle, 
              color: isActive ? const Color(0xFF84BD00) : const Color(0xFF6C7278), 
              size: 48
            )
          ),
        ],
      ),
    );
  }
}

class CandleChartData {
  final double open, high, low, close;
  final DateTime time;
  CandleChartData(this.open, this.high, this.low, this.close, this.time);
}
