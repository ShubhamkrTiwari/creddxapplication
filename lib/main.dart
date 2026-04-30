import 'package:flutter/material.dart';
import 'package:upgrader/upgrader.dart';
import 'screens/splash_screen.dart';
import 'widgets/maintenance_wrapper.dart';
import 'services/connectivity_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize connectivity monitoring
  ConnectivityService.instance.initialize();
  runApp(const CreddXApp());
}

class CreddXApp extends StatelessWidget {
  const CreddXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CreddX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF161618),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF90C128),
          brightness: Brightness.dark,
          primary: const Color(0xFF90C128),
        ),
        useMaterial3: true,
      ),
      builder: (context, child) => MaintenanceWrapper(
        apiBaseUrl: 'https://api11.hathmetech.com/api',
        checkInterval: const Duration(minutes: 1), // Check every minute
        child: UpgradeAlert(
          upgrader: Upgrader(
            durationUntilAlertAgain: const Duration(hours: 1),
          ),
          showIgnore: false,
          showLater: false,
          barrierDismissible: false,
          child: child!,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
