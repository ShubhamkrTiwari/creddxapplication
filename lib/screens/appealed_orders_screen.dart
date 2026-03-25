import 'package:flutter/material.dart';

class AppealedOrdersScreen extends StatelessWidget {
  const AppealedOrdersScreen({super.key});

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
        title: const Text('Appealed Orders', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: const Center(
        child: Text('Appealed Orders Screen', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
