import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math' as math;

class TradingViewChart extends StatefulWidget {
  final String symbol;
  final String? theme;
  final String? interval;
  final bool allowFullscreen;
  final bool allowSymbolChange;
  final bool allowTimeframeChange;
  final bool allowChartTypeChange;
  final bool allowCompare;
  final bool allowSideToolbar;
  final bool allowTopToolbar;
  final bool allowBottomToolbar;
  final bool allowStudy;
  final bool allowDrawing;
  final bool allowCrosshair;
  final bool allowHotkeys;
  final bool allowSave;
  final bool allowScreenshot;
  final bool allowDataExport;
  final bool allowMeasure;

  const TradingViewChart({
    super.key,
    required this.symbol,
    this.theme = 'dark',
    this.interval = '15',
    this.allowFullscreen = true,
    this.allowSymbolChange = false,
    this.allowTimeframeChange = true,
    this.allowChartTypeChange = true,
    this.allowCompare = true,
    this.allowSideToolbar = true,
    this.allowTopToolbar = true,
    this.allowBottomToolbar = false,
    this.allowStudy = true,
    this.allowDrawing = true,
    this.allowCrosshair = true,
    this.allowHotkeys = true,
    this.allowSave = true,
    this.allowScreenshot = true,
    this.allowDataExport = true,
    this.allowMeasure = true,
  });

  @override
  State<TradingViewChart> createState() => _TradingViewChartState();
}

class _TradingViewChartState extends State<TradingViewChart> {
  late WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            // Inject JavaScript to set symbol after page loads
            _setSymbolAndTheme();
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
            });
            print('WebView error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow all navigation within the TradingView widget
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(
        Uri.parse('https://www.tradingview.com/chart'),
      );
  }

  void _setSymbolAndTheme() async {
    try {
      // Wait a bit for the page to fully load
      await Future.delayed(const Duration(seconds: 2));
      
      // JavaScript to set symbol and theme
      final jsCode = '''
        // Try to find and set the symbol input
        const symbolInput = document.querySelector('[data-name="symbol-search-input"]');
        if (symbolInput) {
          symbolInput.value = '${widget.symbol}';
          symbolInput.dispatchEvent(new Event('input', { bubbles: true }));
          symbolInput.dispatchEvent(new Event('change', { bubbles: true }));
        }
        
        // Try to click on the symbol and set it
        const symbolElement = document.querySelector('[data-symbol="${widget.symbol}"]');
        if (symbolElement) {
          symbolElement.click();
        }
        
        // Set theme to dark if possible
        const themeButton = document.querySelector('[data-name="theme-switcher"]');
        if (themeButton && themeButton.textContent.includes('Light')) {
          themeButton.click();
        }
      ''';
      
      await _controller.runJavaScript(jsCode);
    } catch (e) {
      print('JavaScript injection error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if we're on web platform
    if (kIsWeb) {
      return _buildWebFallback();
    }
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: const Color(0xFF0D0D0D),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF84BD00),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWebFallback() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.show_chart,
            color: Color(0xFF84BD00),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            '${widget.symbol} Chart',
            style: const TextStyle(
              color: Color(0xFF84BD00),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Professional TradingView Chart',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF84BD00).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF84BD00)),
            ),
            child: const Text(
              'Available on Mobile/Desktop',
              style: TextStyle(
                color: Color(0xFF84BD00),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Simple chart visualization
          Container(
            height: 200,
            margin: const EdgeInsets.symmetric(horizontal: 32),
            child: CustomPaint(
              painter: SimpleChartPainter(),
              child: Container(),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Real-time price data • Technical indicators',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
          const Text(
            'Drawing tools • Multiple timeframes',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void refreshChart() {
    if (!kIsWeb) {
      _initializeWebView();
    }
  }

  void changeSymbol(String newSymbol) {
    setState(() {
      // This would require rebuilding the widget with new symbol
    });
  }

  void changeInterval(String newInterval) {
    setState(() {
      // This would require rebuilding the widget with new interval
    });
  }

  void changeTheme(String newTheme) {
    setState(() {
      // This would require rebuilding the widget with new theme
    });
  }
}

class SimpleChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF84BD00)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    
    // Create a simple sine wave-like chart
    final width = size.width;
    final height = size.height;
    final amplitude = height * 0.3;
    final centerY = height / 2;
    
    path.moveTo(0, centerY);
    
    for (double x = 0; x <= width; x += 5) {
      final y = centerY + amplitude * math.sin((x / width) * 4 * math.pi);
      path.lineTo(x, y);
    }
    
    canvas.drawPath(path, paint);
    
    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;
    
    // Horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      final y = (height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }
    
    // Vertical grid lines
    for (int i = 0; i <= 6; i++) {
      final x = (width / 6) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, height), gridPaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
