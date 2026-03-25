import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../main_navigation.dart';

class ChartScreen extends StatefulWidget {
  final String? symbol;
  const ChartScreen({super.key, this.symbol});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  late Timer _timer;
  double _currentPrice = 0.0;
  int _selectedTimeframeIndex = 1; // Default to 15m
  final List<String> _timeframes = ["Line", "15m", "1h", "4h", "1d", "1w"];
  
  List<CandleData> _candleData = [];
  bool _isLoading = true;
  late String _selectedSymbol;
  final NumberFormat _priceFormat = NumberFormat.currency(symbol: "\$", decimalDigits: 2);
  
  Offset? _crosshairPosition;
  CandleData? _selectedCandle;

  @override
  void initState() {
    super.initState();
    _selectedSymbol = widget.symbol ?? "BTCUSDT";
    _fetchInitialCandleData();
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _getInterval() {
    switch (_selectedTimeframeIndex) {
      case 0: return "1m";
      case 1: return "15m";
      case 2: return "1h";
      case 3: return "4h";
      case 4: return "1d";
      case 5: return "1w";
      default: return "15m";
    }
  }

  Future<void> _fetchInitialCandleData() async {
    setState(() => _isLoading = true);
    final interval = _getInterval();
    try {
      final response = await http.get(
        Uri.parse("https://api.binance.com/api/v3/klines?symbol=$_selectedSymbol&interval=$interval&limit=60")
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<CandleData> candles = [];
        
        for (var item in data) {
          candles.add(CandleData(
            DateTime.fromMillisecondsSinceEpoch(item[0]),
            double.parse(item[1]), // open
            double.parse(item[2]), // high
            double.parse(item[3]), // low
            double.parse(item[4]), // close
            double.parse(item[5]), // volume
          ));
        }
        
        if (mounted) {
          setState(() {
            _candleData = candles;
            _isLoading = false;
            if (candles.isNotEmpty) {
              _currentPrice = candles.last.close;
            }
          });
        }
      }
    } catch (e) {
      _generateSampleCandleData();
    }
  }

  void _generateSampleCandleData() {
    final List<CandleData> sampleData = [];
    final random = math.Random();
    double basePrice = 48000;
    
    for (int i = 0; i < 60; i++) {
      final time = DateTime.now().subtract(Duration(minutes: (60 - i) * 15));
      final open = basePrice + (random.nextDouble() - 0.5) * 200;
      final close = open + (random.nextDouble() - 0.5) * 100;
      final high = math.max(open, close) + random.nextDouble() * 50;
      final low = math.min(open, close) - random.nextDouble() * 50;
      final volume = random.nextDouble() * 1000 + 500;
      
      sampleData.add(CandleData(time, open, high, low, close, volume));
      basePrice = close;
    }
    
    if (mounted) {
      setState(() {
        _candleData = sampleData;
        _isLoading = false;
        _currentPrice = sampleData.last.close;
      });
    }
  }

  Future<void> _updateRealTimeData() async {
    try {
      final response = await http.get(
        Uri.parse("https://api.binance.com/api/v3/ticker/price?symbol=$_selectedSymbol")
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newPrice = double.parse(data["price"]);
        
        if (mounted) {
          setState(() {
            _currentPrice = newPrice;
            if (_candleData.isNotEmpty) {
              final lastCandle = _candleData.last;
              _candleData[_candleData.length - 1] = CandleData(
                lastCandle.time,
                lastCandle.open,
                math.max(lastCandle.high, newPrice),
                math.min(lastCandle.low, newPrice),
                newPrice,
                lastCandle.volume,
              );
            }
          });
        }
      }
    } catch (e) {
      if (mounted && _candleData.isNotEmpty) {
        setState(() {
          final random = math.Random();
          _currentPrice += (random.nextDouble() - 0.5) * 15;
          final last = _candleData.last;
          _candleData[_candleData.length - 1] = CandleData(
            last.time,
            last.open,
            math.max(last.high, _currentPrice),
            math.min(last.low, _currentPrice),
            _currentPrice,
            last.volume,
          );
        });
      }
    }
  }

  double _get24hHigh() {
    if (_candleData.isEmpty) return 0.0;
    return _candleData.map((candle) => candle.high).reduce((a, b) => a > b ? a : b);
  }

  double _get24hLow() {
    if (_candleData.isEmpty) return 0.0;
    return _candleData.map((candle) => candle.low).reduce((a, b) => a < b ? a : b);
  }

  double _get24hChange() {
    if (_candleData.length < 2) return 0.0;
    final firstPrice = _candleData.first.open;
    return ((_currentPrice - firstPrice) / firstPrice) * 100;
  }

  void _startRealTimeUpdates() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _updateRealTimeData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _selectedSymbol,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchInitialCandleData,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
        : Column(
            children: [
              _buildCompactHeader(),
              _buildTimeframeSelector(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildMainChartSection(),
                      _buildOrderBook(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
      bottomNavigationBar: _buildTradingInterface(),
    );
  }

  Widget _buildCompactHeader() {
    final change = _get24hChange();
    final isPositive = change >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _priceFormat.format(_currentPrice),
                style: TextStyle(
                  color: isPositive ? const Color(0xFF00FF88) : const Color(0xFFFF3366),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Text(
                    "${isPositive ? "+" : ""}${change.toStringAsFixed(2)}%",
                    style: TextStyle(
                      color: isPositive ? const Color(0xFF00FF88) : const Color(0xFFFF3366),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "≈ \$${_currentPrice.toStringAsFixed(2)}",
                    style: const TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              _buildCompactStatItem("High", _priceFormat.format(_get24hHigh())),
              const SizedBox(width: 16),
              _buildCompactStatItem("Low", _priceFormat.format(_get24hLow())),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
        Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildTimeframeSelector() {
    return Container(
      height: 45,
      color: const Color(0xFF000000),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _timeframes.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedTimeframeIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedTimeframeIndex = index;
                _selectedCandle = null;
                _crosshairPosition = null;
              });
              _fetchInitialCandleData();
            },
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF84BD00).withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _timeframes[index],
                style: TextStyle(
                  color: isSelected ? const Color(0xFF84BD00) : Colors.white60,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainChartSection() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF000000),
      child: Column(
        children: [
          if (_selectedCandle != null) _buildCandleInfoBar(),
          _buildChartWithGestures(),
        ],
      ),
    );
  }

  Widget _buildCandleInfoBar() {
    final candle = _selectedCandle!;
    final isUp = candle.close >= candle.open;
    final color = isUp ? const Color(0xFF00FF88) : const Color(0xFFFF3366);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _infoItem("O", candle.open.toStringAsFixed(2), color),
          _infoItem("H", candle.high.toStringAsFixed(2), color),
          _infoItem("L", candle.low.toStringAsFixed(2), color),
          _infoItem("C", candle.close.toStringAsFixed(2), color),
        ],
      ),
    );
  }

  Widget _infoItem(String label, String value, Color color) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildChartWithGestures() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onLongPressStart: (details) => _updateCrosshair(details.localPosition, constraints.maxWidth),
          onLongPressMoveUpdate: (details) => _updateCrosshair(details.localPosition, constraints.maxWidth),
          onPanUpdate: (details) => _updateCrosshair(details.localPosition, constraints.maxWidth),
          onTapDown: (details) => _updateCrosshair(details.localPosition, constraints.maxWidth),
          onDoubleTap: () {
            setState(() {
              _crosshairPosition = null;
              _selectedCandle = null;
            });
          },
          child: Container(
            height: 420,
            width: double.infinity,
            margin: const EdgeInsets.only(top: 10),
            child: CustomPaint(
              painter: AdvancedCandlestickPainter(
                _candleData, 
                isLine: _selectedTimeframeIndex == 0,
                crosshairPosition: _crosshairPosition,
              ),
            ),
          ),
        );
      },
    );
  }

  void _updateCrosshair(Offset localPosition, double width) {
    if (_candleData.isEmpty) return;
    const double labelWidth = 60.0;
    final double chartWidth = width - labelWidth;
    
    if (localPosition.dx < 0 || localPosition.dx > chartWidth) return;
    
    final int index = (localPosition.dx / (chartWidth / _candleData.length)).floor().clamp(0, _candleData.length - 1);
    setState(() {
      _crosshairPosition = localPosition;
      _selectedCandle = _candleData[index];
    });
  }

  Widget _buildOrderBook() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D), 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Order Book", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Bid Amount", style: TextStyle(color: Colors.white38, fontSize: 11)),
              Text("Price", style: TextStyle(color: Colors.white38, fontSize: 11)),
              Text("Ask Amount", style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(6, (index) {
             final random = math.Random();
             return Padding(
               padding: const EdgeInsets.symmetric(vertical: 5),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text(random.nextDouble().toStringAsFixed(4), style: const TextStyle(color: Color(0xFF00FF88), fontSize: 12)),
                   Text(_priceFormat.format(_currentPrice + (index - 3) * 5), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                   Text(random.nextDouble().toStringAsFixed(4), style: const TextStyle(color: Color(0xFFFF3366), fontSize: 12)),
                 ],
               ),
             );
          }),
        ],
      ),
    );
  }

  Widget _buildTradingInterface() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const MainNavigation(initialIndex: 3)),
                  (route) => false,
                );
              }, 
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0DAC15),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ), 
              child: const Text("BUY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
            )
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const MainNavigation(initialIndex: 3)),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE41616),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ), 
              child: const Text("SELL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
            )
          ),
        ],
      ),
    );
  }
}

class CandleData {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  CandleData(this.time, this.open, this.high, this.low, this.close, this.volume);
}

class AdvancedCandlestickPainter extends CustomPainter {
  final List<CandleData> data;
  final bool isLine;
  final Offset? crosshairPosition;
  
  AdvancedCandlestickPainter(this.data, {this.isLine = false, this.crosshairPosition});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    
    const double labelWidth = 60.0;
    final double chartWidth = size.width - labelWidth;
    final double chartHeight = size.height;
    
    final double mainChartHeight = chartHeight * 0.8;
    final double volumeChartHeight = chartHeight * 0.2;
    
    final double verticalPadding = mainChartHeight * 0.1;
    final double effectiveHeight = mainChartHeight - (verticalPadding * 2);
    
    final maxPrice = data.map((d) => d.high).reduce((a, b) => a > b ? a : b);
    final minPrice = data.map((d) => d.low).reduce((a, b) => a < b ? a : b);
    double priceRange = (maxPrice - minPrice).abs();
    if (priceRange == 0) priceRange = 1.0;

    final bufferedMax = maxPrice + (priceRange * 0.05);
    final bufferedMin = minPrice - (priceRange * 0.05);
    final bufferedRange = bufferedMax - bufferedMin;

    double priceToY(double price) {
      return mainChartHeight - verticalPadding - ((price - bufferedMin) / bufferedRange) * effectiveHeight;
    }

    final gridPaint = Paint()..color = Colors.white.withValues(alpha: 0.04)..strokeWidth = 1;
    for (int i = 0; i <= 5; i++) {
      double y = verticalPadding + (effectiveHeight / 5) * i;
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
      
      final price = bufferedMax - (bufferedRange / 5) * i;
      final textPainter = TextPainter(
        text: TextSpan(
          text: price.toStringAsFixed(1),
          style: const TextStyle(color: Colors.white30, fontSize: 10),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(chartWidth + 6, y - textPainter.height / 2));
    }

    final double candleWidth = (chartWidth / data.length) * 0.8;
    final double maxVolume = data.map((e) => e.volume).reduce((a, b) => a > b ? a : b);

    for (int i = 0; i < data.length; i++) {
      final candle = data[i];
      double x = (i + 0.5) * (chartWidth / data.length);
      final bool isUp = candle.close >= candle.open;
      final color = isUp ? const Color(0xFF00FF88) : const Color(0xFFFF3366);

      final volHeight = (candle.volume / (maxVolume == 0 ? 1 : maxVolume)) * volumeChartHeight;
      final volPaint = Paint()..color = color.withValues(alpha: 0.2)..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(x - candleWidth / 2, chartHeight - volHeight, candleWidth, volHeight),
        volPaint
      );

      if (isLine) {
        if (i > 0) {
          final prevX = (i - 0.5) * (chartWidth / data.length);
          final prevY = priceToY(data[i-1].close);
          final currY = priceToY(candle.close);
          canvas.drawLine(Offset(prevX, prevY), Offset(x, currY), Paint()..color = const Color(0xFF84BD00)..strokeWidth = 2);
        }
      } else {
        double highY = priceToY(candle.high);
        double lowY = priceToY(candle.low);
        double openY = priceToY(candle.open);
        double closeY = priceToY(candle.close);
        
        canvas.drawLine(Offset(x, highY), Offset(x, lowY), Paint()..color = color..strokeWidth = 1.0);
        
        double bodyTop = math.min(openY, closeY);
        double bodyBottom = math.max(openY, closeY);
        double bodyHeight = math.max(1.5, (bodyBottom - bodyTop));
        
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, bodyTop + bodyHeight/2), width: candleWidth, height: bodyHeight),
            const Radius.circular(0.5),
          ),
          Paint()..color = color..style = PaintingStyle.fill
        );
      }
    }

    if (crosshairPosition != null) {
      final cp = Paint()..color = Colors.white38..strokeWidth = 0.8;
      canvas.drawLine(Offset(crosshairPosition!.dx, 0), Offset(crosshairPosition!.dx, mainChartHeight), cp);
      canvas.drawLine(Offset(0, crosshairPosition!.dy), Offset(chartWidth, crosshairPosition!.dy), cp);
      
      if (crosshairPosition!.dy <= mainChartHeight) {
        final currentYPrice = bufferedMax - ((crosshairPosition!.dy - verticalPadding) / effectiveHeight) * bufferedRange;
        final textPainter = TextPainter(
          text: TextSpan(
            text: currentYPrice.toStringAsFixed(1),
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        
        canvas.drawRect(Rect.fromLTWH(chartWidth, crosshairPosition!.dy - 9, labelWidth, 18), Paint()..color = const Color(0xFF222222));
        textPainter.paint(canvas, Offset(chartWidth + 4, crosshairPosition!.dy - textPainter.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
