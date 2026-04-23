import 'package:flutter/material.dart';
import 'package:gif/gif.dart';

class PartnerProgramScreen extends StatefulWidget {
  const PartnerProgramScreen({super.key});

  @override
  State<PartnerProgramScreen> createState() => _PartnerProgramScreenState();
}

class _PartnerProgramScreenState extends State<PartnerProgramScreen>
    with TickerProviderStateMixin {
  late GifController _gifController;

  @override
  void initState() {
    super.initState();
    _gifController = GifController(vsync: this);
  }

  @override
  void dispose() {
    _gifController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Partner Program',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Gif(
          controller: _gifController,
          image: const AssetImage('assets/images/comingsoon.gif'),
          autostart: Autostart.loop,
          placeholder: (context) => const Text(
            'Coming Soon',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
