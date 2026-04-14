import 'package:flutter/material.dart';
import '../services/bot_service.dart';
import 'bot_balance_history_screen.dart';
import 'dart:math' as math;

class BotPositionsScreen extends StatefulWidget {
  const BotPositionsScreen({super.key});

  @override
  State<BotPositionsScreen> createState() => _BotPositionsScreenState();
}

class _BotPositionsScreenState extends State<BotPositionsScreen> {
  String _selectedPair = 'BTC-USDT';
  String _selectedTimeframe = '1h';
  bool _isLoading = false;
  List<BotPosition> _positions = [];
  String? _errorMessage;
  Map<String, dynamic>? _positionData;

  final List<String> _timeframes = ['1m', '30m', '1h', '3m', '15m', '4h', '1d'];

  @override
  void initState() {
    super.initState();
    _loadPositions();
  }

  Future<void> _loadPositions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String strategy;
      String symbol;
      
      switch (_selectedPair) {
        case 'BTC-USDT':
          strategy = 'Omega';
          symbol = 'BTCUSDT';
          break;
        case 'ETH-USDT':
          strategy = 'Alpha';
          symbol = 'ETHUSDT';
          break;
        case 'SOL-USDT':
          strategy = 'Ranger';
          symbol = 'SOLUSDT';
          break;
        default:
          strategy = 'Omega';
          symbol = 'BTCUSDT';
      }

      final result = await BotService.getUserBotPositions(
        strategy: strategy,
        symbol: symbol,
      );

      if (mounted) {
        if (result['success'] == true) {
          final data = result['data'];
          final List<dynamic> positionsList = data['adjustedPositions'] ?? [];
          setState(() {
            _positions = positionsList.map((pos) => BotPosition.fromJson(pos)).toList();
            _positionData = data;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = result['error'] ?? 'Failed to load positions';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading positions: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Open Positions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildStrategyHeader(),
            _buildTimeframeSelector(),
            _buildTradingChart(),
            _buildPositionDetails(),
            const SizedBox(height: 20),
            _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
              : _errorMessage != null
                ? _buildErrorWidget()
                : _positions.isEmpty
                  ? _buildEmptyWidget()
                  : _buildPositionsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategyHeader() {
    if (_positionData == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Strategy: ${_positionData!['strategy'] ?? 'Unknown'}',
            style: const TextStyle(
              color: Color(0xFF84BD00),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final strategy = _positionData?['strategy']?.toString() ?? 'Omega';
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => BotBalanceHistoryScreen(
                    strategy: strategy,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF84BD00),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Balance Growth'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _timeframes.length,
        itemBuilder: (context, index) {
          final timeframe = _timeframes[index];
          final isSelected = _selectedTimeframe == timeframe;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedTimeframe = timeframe;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF84BD00) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? const Color(0xFF84BD00) : Colors.white.withOpacity(0.3),
                ),
              ),
              child: Text(
                timeframe,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTradingChart() {
    return Container(
      height: 350,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF84BD00).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF84BD00).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedPair.replaceAll('-', '/'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Live Price',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(_positions.isNotEmpty ? _positions.first.markPrice : 0.0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF84BD00),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          _positions.isNotEmpty && _positions.first.userUnrealizedProfit >= 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                          color: _positions.isNotEmpty && _positions.first.userUnrealizedProfit >= 0
                              ? const Color(0xFF84BD00)
                              : const Color(0xFFFF3B30),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _positions.isNotEmpty
                              ? '${(_positions.first.userUnrealizedProfit >= 0 ? '+' : '')}${_positions.first.userUnrealizedProfit.toStringAsFixed(2)}'
                              : '+0.00',
                          style: TextStyle(
                            color: _positions.isNotEmpty && _positions.first.userUnrealizedProfit >= 0
                                ? const Color(0xFF84BD00)
                                : const Color(0xFFFF3B30),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.1),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: CustomPaint(
                painter: EnhancedTradingChartPainter(
                  positions: _positions,
                  selectedTimeframe: _selectedTimeframe,
                ),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionDetails() {
    if (_positions.isEmpty) return const SizedBox();
    
    final position = _positions.first;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${position.symbol} - ${position.positionSide}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Size: ${position.size}',
                style: const TextStyle(color: Color(0xFF8E8E93)),
              ),
              Text(
                'Entry: ${position.avgPrice}',
                style: const TextStyle(color: Color(0xFF8E8E93)),
              ),
              Text(
                'Mark: ${position.markPrice}',
                style: const TextStyle(color: Color(0xFF8E8E93)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPositionsList() {
    return ListView.builder(
      itemCount: _positions.length,
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final position = _positions[index];
        return _buildPositionCard(position);
      },
    );
  }

  Widget _buildPositionCard(BotPosition position) {
    final isProfit = position.userUnrealizedProfit >= 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isProfit ? const Color(0xFF84BD00) : const Color(0xFFFF3B30),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: position.positionSide == 'LONG' 
                          ? const Color(0xFF84BD00).withOpacity(0.2)
                          : const Color(0xFFFF3B30).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      position.positionSide,
                      style: TextStyle(
                        color: position.positionSide == 'LONG' 
                            ? const Color(0xFF84BD00)
                            : const Color(0xFFFF3B30),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    position.symbol,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '${isProfit ? '+' : ''}\$${position.userUnrealizedProfit.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isProfit ? const Color(0xFF84BD00) : const Color(0xFFFF3B30),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetric('Entry Price', '\$${position.avgPrice.toStringAsFixed(2)}'),
              ),
              Expanded(
                child: _buildMetric('Mark Price', '\$${position.markPrice.toStringAsFixed(2)}'),
              ),
              Expanded(
                child: _buildMetric('Liq Price', '\$${position.liqPrice.toStringAsFixed(2)}'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetric('Margin', '\$${position.userMargin.toStringAsFixed(2)}'),
              ),
              Expanded(
                child: _buildMetric('Leverage', '${position.leverage}x'),
              ),
              Expanded(
                child: _buildMetric('Updated', _formatTime(position.updateTime)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 50,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An error occurred',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPositions,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF84BD00),
              foregroundColor: Colors.black,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.trending_up,
            color: Color(0xFF8E8E93),
            size: 50,
          ),
          SizedBox(height: 16),
          Text(
            'No Open Positions',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You don\'t have any open positions',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class EnhancedTradingChartPainter extends CustomPainter {
  final List<BotPosition> positions;
  final String selectedTimeframe;
  
  EnhancedTradingChartPainter({
    required this.positions,
    required this.selectedTimeframe,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background gradient
    final bgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF1C1C1E),
        const Color(0xFF2C2C2E).withOpacity(0.3),
      ],
    );
    
    final bgPaint = Paint()
      ..shader = bgGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Grid paint with improved styling
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Price level paints
    final supportPaint = Paint()
      ..color = const Color(0xFF84BD00).withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
      
    final resistancePaint = Paint()
      ..color = const Color(0xFFFF3B30).withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw improved grid
    _drawGrid(canvas, size, gridPaint);
    
    // Draw price levels if we have position data
    if (positions.isNotEmpty) {
      _drawPriceLevels(canvas, size, positions.first, supportPaint, resistancePaint);
    }
    
    // Draw enhanced candlesticks or line chart
    if (positions.isNotEmpty) {
      _drawPositionChart(canvas, size);
    } else {
      _drawNoDataMessage(canvas, size);
    }
    
    // Draw axis labels
    _drawAxisLabels(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size, Paint gridPaint) {
    // Horizontal grid lines with price levels
    for (int i = 0; i <= 8; i++) {
      final y = (size.height / 8) * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Vertical grid lines for time
    for (int i = 0; i <= 6; i++) {
      final x = (size.width / 6) * i;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }
  }

  void _drawPriceLevels(Canvas canvas, Size size, BotPosition position, Paint supportPaint, Paint resistancePaint) {
    // Draw entry price line
    final entryPriceY = _priceToY(position.avgPrice, size);
    canvas.drawLine(
      Offset(0, entryPriceY),
      Offset(size.width, entryPriceY),
      supportPaint,
    );
    
    // Draw current price line
    final currentPriceY = _priceToY(position.markPrice, size);
    canvas.drawLine(
      Offset(0, currentPriceY),
      Offset(size.width, currentPriceY),
      resistancePaint,
    );
    
    // Draw liquidation price if available
    if (position.liqPrice > 0) {
      final liqPriceY = _priceToY(position.liqPrice, size);
      final liqPaint = Paint()
        ..color = const Color(0xFFFF9500).withOpacity(0.4)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(0, liqPriceY),
        Offset(size.width, liqPriceY),
        liqPaint,
      );
    }
  }

  void _drawPositionChart(Canvas canvas, Size size) {
    if (positions.isEmpty) return;
    
    final linePaint = Paint()
      ..color = positions.first.userUnrealizedProfit >= 0 
          ? const Color(0xFF84BD00)
          : const Color(0xFFFF3B30)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Generate realistic price data based on position
    final points = _generatePricePoints(size);
    
    if (points.length > 1) {
      // Draw gradient fill under the line
      final gradientPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (positions.first.userUnrealizedProfit >= 0 
                ? const Color(0xFF84BD00)
                : const Color(0xFFFF3B30)).withOpacity(0.3),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      
      final path = Path()
        ..addPolygon(points, false)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      
      canvas.drawPath(path, gradientPaint);
      
      // Draw the main line
      for (int i = 0; i < points.length - 1; i++) {
        canvas.drawLine(points[i], points[i + 1], linePaint);
      }
      
      // Draw points at each data point
      final pointPaint = Paint()
        ..color = positions.first.userUnrealizedProfit >= 0 
            ? const Color(0xFF84BD00)
            : const Color(0xFFFF3B30)
        ..style = PaintingStyle.fill;
        
      for (final point in points) {
        canvas.drawCircle(point, 3, pointPaint);
      }
    }
  }

  void _drawNoDataMessage(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'No position data available',
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 14,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  void _drawAxisLabels(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    // Price labels on the right
    for (int i = 0; i <= 4; i++) {
      final price = _yToPrice((size.height / 4) * i, size);
      textPainter.text = TextSpan(
        text: '\$${price.toStringAsFixed(2)}',
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 10,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(size.width - textPainter.width - 8, (size.height / 4) * i - 6),
      );
    }
    
    // Time labels at the bottom
    final timeLabels = ['12:00', '14:00', '16:00', '18:00', '20:00', '22:00'];
    for (int i = 0; i < timeLabels.length && i < 6; i++) {
      textPainter.text = TextSpan(
        text: timeLabels[i],
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 10,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset((size.width / 6) * i + 8, size.height - 20),
      );
    }
  }

  List<Offset> _generatePricePoints(Size size) {
    final points = <Offset>[];
    final pointCount = 20;
    
    if (positions.isNotEmpty) {
      final basePrice = positions.first.avgPrice;
      final currentPrice = positions.first.markPrice;
      
      for (int i = 0; i < pointCount; i++) {
        final x = (size.width / (pointCount - 1)) * i;
        // Create realistic price movement
        final progress = i / (pointCount - 1);
        final variation = math.sin(progress * math.pi * 2) * 5 + 
                         math.sin(progress * math.pi * 4) * 2;
        final price = basePrice + (currentPrice - basePrice) * progress + variation;
        final y = _priceToY(price, size);
        points.add(Offset(x, y));
      }
    }
    
    return points;
  }

  double _priceToY(double price, Size size) {
    // Map price range to Y coordinate (inverted because canvas Y starts at top)
    final minPrice = 0.0;
    final maxPrice = 200.0; // Adjust based on your price range
    final normalizedPrice = (price - minPrice) / (maxPrice - minPrice);
    return size.height * (1 - normalizedPrice.clamp(0.0, 1.0));
  }

  double _yToPrice(double y, Size size) {
    // Map Y coordinate back to price
    final minPrice = 0.0;
    final maxPrice = 200.0;
    final normalizedY = 1 - (y / size.height);
    return minPrice + normalizedY * (maxPrice - minPrice);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CandleData {
  final double open;
  final double close;
  final double high;
  final double low;
  final bool isGreen;

  CandleData({
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.isGreen,
  });
}
