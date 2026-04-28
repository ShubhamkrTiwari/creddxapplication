import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'onboarding_screen.dart';
import '../main_navigation.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/socket_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> 
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // System chrome configuration
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _fadeController.forward();
    
    // Start background initialization immediately
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Start all heavy initialization tasks in parallel
    // These run while the splash screen is visible
    final initUserTask = UserService().initUserData();
    final authCheckTask = AuthService.isLoggedIn();
    
    // 2. Define the fixed splash duration (2.0 seconds)
    // This ensures the logo stays visible as requested
    final splashTimerTask = Future.delayed(const Duration(milliseconds: 2000));
    
    // 3. Wait for the auth check and the fixed timer
    // We don't necessarily wait for full profile/KYC API refresh here 
    // because UserService.initUserData() internally loads local data first
    // and refreshes in the background.
    final results = await Future.wait([
      authCheckTask,
      splashTimerTask,
    ]);
    
    final bool isLoggedIn = results[0] as bool;

    if (isLoggedIn) {
      debugPrint('SplashScreen: User is logged in, connecting to websocket...');
      debugPrint('Socket URL: ${SocketService.isConnected ? "Already connected" : "Connecting..."}');
      unawaited(SocketService.connect());
      debugPrint('SplashScreen: WebSocket connection initiated');
    } else {
      debugPrint('SplashScreen: User not logged in, skipping websocket connection');
    }

    if (mounted) {
      try {
        // Navigation with a smooth transition
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => 
                isLoggedIn ? const MainNavigation() : const OnboardingScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      } catch (e) {
        debugPrint('Navigation error: $e');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/Creddxlogo.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
