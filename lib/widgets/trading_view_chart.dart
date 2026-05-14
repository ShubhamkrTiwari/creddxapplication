import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class TradingViewChart extends StatefulWidget {
  final String symbol;
  final String? theme;
  final String? interval;
  final bool allowFullscreen;
  final bool allowSymbolChange;
  final bool autosize;
  final bool hideTopToolbar;
  final bool hideLegend;
  final bool hideSideToolbar;
  final String timezone;

  const TradingViewChart({
    super.key,
    required this.symbol,
    this.theme = 'dark',
    this.interval = '15',
    this.allowFullscreen = true,
    this.allowSymbolChange = false,
    this.autosize = true,
    this.hideTopToolbar = false,
    this.hideLegend = false,
    this.hideSideToolbar = false,
    this.timezone = 'Etc/UTC',
  });

  @override
  State<TradingViewChart> createState() => _TradingViewChartState();
}

class _TradingViewChartState extends State<TradingViewChart> {
  bool _isLoading = true;
  late WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (error) {
            setState(() {
              _isLoading = false;
            });
            debugPrint('TradingView WebView error: $error');
          },
        ),
      );
    _loadChart();
  }

  @override
  void didUpdateWidget(covariant TradingViewChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol ||
        oldWidget.interval != widget.interval ||
        oldWidget.theme != widget.theme) {
      _loadChart();
    }
  }

  void _loadChart() {
    final url = _buildTradingViewUrl();
    _webViewController.loadRequest(Uri.parse(url));
  }

  String _buildTradingViewUrl() {
    final symbol = widget.symbol.contains(':') 
        ? widget.symbol 
        : 'BINANCE:${widget.symbol}';
    
    final params = {
      'frameElementId': 'tradingview_chart',
      'symbol': symbol,
      'interval': widget.interval ?? '15',
      'theme': widget.theme ?? 'dark',
      'style': '1',
      'locale': 'en',
      'toolbar_bg': '#f1f3f6',
      'enable_publishing': 'false',
      'allow_symbol_change': widget.allowSymbolChange ? 'true' : 'false',
      'save_image': 'true',
      'container_id': 'tradingview_chart',
      'hide_top_toolbar': widget.hideTopToolbar ? 'true' : 'false',
      'hide_legend': widget.hideLegend ? 'true' : 'false',
      'hide_side_toolbar': widget.hideSideToolbar ? 'true' : 'false',
      'timezone': widget.timezone,
      'withdateranges': 'true',
      'range': 'YTD',
      'show_popup_button': 'true',
      'popup_width': '1000',
      'popup_height': '650',
    };

    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return 'https://s.tradingview.com/widgetembed/?$queryString';
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _buildWebFallback();
    }

    final url = _buildTradingViewUrl();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          WebViewWidget(
            controller: _webViewController,
          ),
          if (_isLoading)
            Container(
              color: const Color(0xFF0D0D0D),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF84BD00),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Loading TradingView Chart...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
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
            'TradingView Chart',
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
              'Available on Mobile App',
              style: TextStyle(
                color: Color(0xFF84BD00),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void refreshChart() {
    if (!kIsWeb) {
      _loadChart();
    }
  }
}
