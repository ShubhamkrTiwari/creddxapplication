import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> 
    with TickerProviderStateMixin {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;
  
  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Start Your Crypto Journey Here ✨',
      subtitle: 'Easily manage and protect your cryptocurrencies with our state-of-the-art mobile wallet.',
      type: OnboardingType.chart,
    ),
    OnboardingData(
      title: 'Your Gateway to the Crypto World 🌎',
      subtitle: 'Experience seamless transactions and instant access to your digital assets, all from your hand.',
      type: OnboardingType.exchangeImage,
    ),
    OnboardingData(
      title: 'Empower Finances with Crypto 🪙',
      subtitle: 'Take control of your financial future with secure and innovative crypto solutions.',
      type: OnboardingType.btcImage,
    ),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemCount: _pages.length,
        itemBuilder: (context, index) {
          return OnboardingPage(
            data: _pages[index],
            currentPage: _currentPage,
            totalPages: _pages.length,
            pageController: _pageController,
          );
        },
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String subtitle;
  final OnboardingType type;

  OnboardingData({
    required this.title, 
    required this.subtitle, 
    required this.type,
  });
}

enum OnboardingType { chart, exchangeImage, btcImage }

class OnboardingPage extends StatelessWidget {
  final OnboardingData data;
  final int currentPage;
  final int totalPages;
  final PageController pageController;

  const OnboardingPage({
    super.key, 
    required this.data,
    required this.currentPage,
    required this.totalPages,
    required this.pageController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/Creddxlogo.png'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Row(
                children: List.generate(3, (index) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: index == currentPage 
                          ? Colors.white
                          : Colors.grey[600],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _buildContent(),
                const SizedBox(height: 30),
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                if (data.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    data.subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF6C7278),
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        
        // Bottom Navigation
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF616161)),
                        backgroundColor: const Color(0xFF424242),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Skip', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () {
                        if (currentPage < totalPages - 1) {
                          pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF84BD00),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: Text(
                        currentPage < totalPages - 1 ? 'Next' : 'Get Started',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (data.type) {
      case OnboardingType.chart:
        return _buildImageContent('assets/images/graph.png', height: 200);
      case OnboardingType.exchangeImage:
        return _buildImageContent('assets/images/exchange.png', height: 260);
      case OnboardingType.btcImage:
        return _buildImageContent('assets/images/btc.png', height: 260);
    }
  }

  Widget _buildImageContent(String assetPath, {double height = 260}) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Colors.white54, size: 50),
          ),
        ),
      ),
    );
  }
}
