import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:device_preview/device_preview.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    DevicePreview(
      enabled: kIsWeb,
      builder: (context) => const CreddXApp(),
    ),
  );
}

class CreddXApp extends StatelessWidget {
  const CreddXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CreddX',
      debugShowCheckedModeBanner: false,
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF161618),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF90C128),
          brightness: Brightness.dark,
          primary: const Color(0xFF90C128),
        ),
        useMaterial3: true,
        fontFamily: 'Inter', // Assuming standard Inter font as in many designs
      ),
      home: const SplashScreen(),
    );
  }
}
