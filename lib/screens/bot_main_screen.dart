import 'package:flutter/material.dart';
import 'bot_trade_screen.dart';
import 'bot_dashboard_screen.dart';
import 'bot_algorithm_screen.dart';
import 'bot_positions_screen.dart';
import 'subscription_screen.dart';
import '../main_navigation.dart';
import '../services/user_service.dart';
import 'user_profile_screen.dart';
import 'update_profile_screen.dart';

class BotMainScreen extends StatefulWidget {
  const BotMainScreen({super.key});

  @override
  State<BotMainScreen> createState() => _BotMainScreenState();
}

class _BotMainScreenState extends State<BotMainScreen> {
  // Start with index 1 (Dashboard) as the default active tab
  int _selectedIndex = 1;
  final UserService _userService = UserService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if we have an initial index from route arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int && args >= 0 && args < _screens.length) {
      setState(() {
        _selectedIndex = args;
      });
    }
  }

  // Check if profile is complete
  bool _isProfileComplete() {
    return _userService.hasEmail() && 
           _userService.userPhone != null && 
           _userService.userPhone!.isNotEmpty;
  }

  // Show profile completion required dialog
  void _showProfileRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Profile Completion Required',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Please complete your profile information (email and phone number) to access algorithmic trading features.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(context, MaterialPageRoute(builder: (context) => const UpdateProfileScreen()));
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF84BD00)),
              child: const Text('Complete Profile', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  // Validate profile before proceeding (KYC not required for bot section)
  bool _validateUserRequirements() {
    if (!_isProfileComplete()) {
      _showProfileRequiredDialog();
      return false;
    }

    return true;
  }

  final List<Widget> _screens = [
    const SizedBox.shrink(), // Placeholder - not used
    const BotDashboardScreen(), // Dashboard tab shows the new dashboard design
    const BotAlgorithmScreen(), // Algos tab shows the Algorithm selection screen
    const BotPositionsScreen(), // Positions tab shows Open Positions
    const SubscriptionScreen(), // Subscribe
  ];

  void _onItemTapped(int index) {
    // Validate requirements for Algos (2), Positions (3), and Subscribe (4)
    if (index >= 2) {
      if (!_validateUserRequirements()) {
        return;
      }
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                // Back button
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const MainNavigation()),
                      (route) => false,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF84BD00).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF84BD00).withOpacity(0.3), width: 1),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_rounded,
                      color: Color(0xFF84BD00),
                      size: 14,
                    ),
                  ),
                ),
                // Navigation items
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTopNavItem(Icons.dashboard_outlined, 'Dashboard', 1),
                        _buildTopNavItem(Icons.psychology_outlined, 'Algos', 2),
                        _buildTopNavItem(Icons.trending_up_outlined, 'Positions', 3),
                        _buildTopNavItem(Icons.subscriptions_outlined, 'Subscribe', 4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _screens[_selectedIndex],
    );
  }

  Widget _buildTopNavItem(IconData icon, String label, int index) {
    final bool isActive = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF84BD00).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isActive
              ? Border.all(color: const Color(0xFF84BD00).withOpacity(0.3), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF84BD00) : Colors.white60,
              size: 18,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF84BD00) : Colors.white60,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            )
          ],
        ),
      ),
    );
  }
}
