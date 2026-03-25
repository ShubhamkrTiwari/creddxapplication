import 'package:flutter/material.dart';
import 'bot_trade_screen.dart';
import 'bot_dashboard_screen.dart';
import 'package:creddx/screens/package_program_screen.dart';
import 'bot_history_screen.dart';
import 'bot_algorithm_screen.dart';
import 'bot_positions_screen.dart';
import 'subscription_screen.dart';
import '../main_navigation.dart';

class BotMainScreen extends StatefulWidget {
  const BotMainScreen({super.key});

  @override
  State<BotMainScreen> createState() => _BotMainScreenState();
}

class _BotMainScreenState extends State<BotMainScreen> {
  // Start with index 1 (Dashboard) as the default active tab
  int _selectedIndex = 1;

  final List<Widget> _screens = [
    const SizedBox.shrink(), // Home icon navigation trigger
    const BotTradeScreen(), // Dashboard tab shows the Trading/Algos interface
    const BotAlgorithmScreen(), // Algos tab shows the Algorithm selection screen
    const BotPositionsScreen(), // Positions tab shows Open Positions
    const SubscriptionScreen(), // Subscribe
    const BotHistoryScreen(showHeader: true), // Logs tab with header
  ];

  void _onItemTapped(int index) {
    if (index == 0) {
      // Home click karne par wapas App Home Screen par navigation
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainNavigation()),
        (route) => false,
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        height: 85,
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(
            top: BorderSide(color: Colors.white12, width: 0.5),
          ),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(Icons.home_outlined, Icons.home, 'Home', 0),
              _buildNavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', 1),
              _buildNavItem(Icons.psychology_outlined, Icons.psychology, 'Algos', 2),
              _buildNavItem(Icons.trending_up_outlined, Icons.trending_up, 'Positions', 3),
              _buildNavItem(Icons.subscriptions_outlined, Icons.subscriptions, 'Subscribe', 4),
              _buildNavItem(Icons.receipt_long_outlined, Icons.receipt_long, 'Logs', 5),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, IconData activeIcon, String label, int index) {
    final bool isActive = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            color: isActive ? const Color(0xFF84BD00) : Colors.white60,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFF84BD00) : Colors.white60,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
