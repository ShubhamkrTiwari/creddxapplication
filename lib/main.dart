import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const SplashScreen(),
    );
  }
}
