import 'package:flutter/material.dart';
import '../services/bot_service.dart';
import 'dart:math' as math;

class BotBalanceHistoryScreen extends StatefulWidget {
  final String strategy;

  const BotBalanceHistoryScreen({
    super.key,
    required this.strategy,
  });

  @override
  State<BotBalanceHistoryScreen> createState() => _BotBalanceHistoryScreenState();
}

class _BotBalanceHistoryScreenState extends State<BotBalanceHistoryScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _balanceData;
  List<Map<String, dynamic>> _history = [];
  String? _errorMessage;
  int _selectedDays = 30;

  final List<int> _timeframeOptions = [7, 14, 30, 60, 90];

  @override
  void initState() {
    super.initState();
    _loadBalanceHistory();
  }

  Future<void> _loadBalanceHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await BotService.getBotBalanceHistory(
        strategy: widget.strategy,
        days: _selectedDays,
      );

      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _balanceData = result['data'];
            _history = List<Map<String, dynamic>>.from(result['data']?['history'] ?? []);
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = result['error'] ?? 'Failed to load balance history';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading balance history: $e';
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${widget.strategy} Balance Growth',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildTimeframeSelector(),
            _buildSummaryCards(),
            _buildBalanceChart(),
            _buildHistoryList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _timeframeOptions.length,
        itemBuilder: (context, index) {
          final days = _timeframeOptions[index];
          final isSelected = _selectedDays == days;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDays = days;
              });
              _loadBalanceHistory();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF84BD00) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? const Color(0xFF84BD00) : Colors.white.withOpacity(0.3),
                ),
              ),
              child: Text(
                '${days}D',
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

  Widget _buildSummaryCards() {
    if (_balanceData == null) return const SizedBox();

    final initialBalance = double.tryParse(_balanceData!['initialBalance']?.toString() ?? '0') ?? 0.0;
    final currentBalance = double.tryParse(_balanceData!['currentBalance']?.toString() ?? '0') ?? 0.0;
    final totalProfit = double.tryParse(_balanceData!['totalProfit']?.toString() ?? '0') ?? 0.0;
    final roi = double.tryParse(_balanceData!['roi']?.toString() ?? '0') ?? 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Current Balance',
              '\$${currentBalance.toStringAsFixed(2)}',
              const Color(0xFF84BD00),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Total Profit',
              '${totalProfit >= 0 ? '+' : ''}\$${totalProfit.toStringAsFixed(2)}',
              totalProfit >= 0 ? const Color(0xFF84BD00) : const Color(0xFFFF3B30),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'ROI',
              '${roi >= 0 ? '+' : ''}${roi.toStringAsFixed(2)}%',
              roi >= 0 ? const Color(0xFF84BD00) : const Color(0xFFFF3B30),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceChart() {
    if (_history.isEmpty) {
      return Container(
        height: 250,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'No balance data available',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Container(
      height: 280,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF84BD00).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Balance Growth',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF84BD00).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Color(0xFF84BD00),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CustomPaint(
                painter: BalanceChartPainter(
                  history: _history,
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

  Widget _buildHistoryList() {
    if (_history.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily History',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _history.length > 7 ? 7 : _history.length,
            reverse: true,
            itemBuilder: (context, index) {
              final item = _history[_history.length - 1 - index];
              return _buildHistoryItem(item);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final date = item['date']?.toString() ?? '';
    final balance = double.tryParse(item['balance']?.toString() ?? '0') ?? 0.0;
    final profit = double.tryParse(item['profit']?.toString() ?? '0') ?? 0.0;
    final roi = double.tryParse(item['roi']?.toString() ?? '0') ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            date,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${balance.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${profit >= 0 ? '+' : ''}\$${profit.toStringAsFixed(2)} (${roi >= 0 ? '+' : ''}${roi.toStringAsFixed(2)}%)',
                style: TextStyle(
                  color: profit >= 0 ? const Color(0xFF84BD00) : const Color(0xFFFF3B30),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BalanceChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> history;

  BalanceChartPainter({
    required this.history,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final padding = const EdgeInsets.only(left: 8, right: 8, top: 16, bottom: 24);
    final chartWidth = size.width - padding.horizontal;
    final chartHeight = size.height - padding.vertical;

    // Parse data
    final balances = history.map((h) => double.tryParse(h['balance']?.toString() ?? '0') ?? 0.0).toList();
    final minBalance = balances.reduce(math.min);
    final maxBalance = balances.reduce(math.max);
    final balanceRange = maxBalance - minBalance > 0 ? maxBalance - minBalance : 1;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 4; i++) {
      final y = padding.top + (chartHeight / 4) * i;
      canvas.drawLine(
        Offset(padding.left, y),
        Offset(size.width - padding.right, y),
        gridPaint,
      );
    }

    // Draw gradient fill
    final gradientPath = Path();
    for (int i = 0; i < balances.length; i++) {
      final x = padding.left + (chartWidth / (balances.length - 1)) * i;
      final normalizedY = (balances[i] - minBalance) / balanceRange;
      final y = padding.top + chartHeight - (normalizedY * chartHeight);

      if (i == 0) {
        gradientPath.moveTo(x, y);
      } else {
        gradientPath.lineTo(x, y);
      }
    }

    gradientPath.lineTo(size.width - padding.right, size.height - padding.bottom);
    gradientPath.lineTo(padding.left, size.height - padding.bottom);
    gradientPath.close();

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF84BD00).withOpacity(0.3),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTRB(0, padding.top, size.width, size.height - padding.bottom));

    canvas.drawPath(gradientPath, gradientPaint);

    // Draw line
    final linePaint = Paint()
      ..color = const Color(0xFF84BD00)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePath = Path();
    for (int i = 0; i < balances.length; i++) {
      final x = padding.left + (chartWidth / (balances.length - 1)) * i;
      final normalizedY = (balances[i] - minBalance) / balanceRange;
      final y = padding.top + chartHeight - (normalizedY * chartHeight);

      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }

    canvas.drawPath(linePath, linePaint);

    // Draw points
    final pointPaint = Paint()
      ..color = const Color(0xFF84BD00)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < balances.length; i += math.max(1, balances.length ~/ 8)) {
      final x = padding.left + (chartWidth / (balances.length - 1)) * i;
      final normalizedY = (balances[i] - minBalance) / balanceRange;
      final y = padding.top + chartHeight - (normalizedY * chartHeight);
      canvas.drawCircle(Offset(x, y), 3, pointPaint);
    }

    // Draw Y-axis labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i <= 4; i++) {
      final price = minBalance + (balanceRange / 4) * (4 - i);
      textPainter.text = TextSpan(
        text: '\$${price.toStringAsFixed(0)}',
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 9,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(0, padding.top + (chartHeight / 4) * i - textPainter.height / 2),
      );
    }

    // Draw X-axis labels (first and last date)
    final firstDate = history.first['date']?.toString() ?? '';
    final lastDate = history.last['date']?.toString() ?? '';

    textPainter.text = TextSpan(
      text: firstDate,
      style: TextStyle(
        color: Colors.white.withOpacity(0.5),
        fontSize: 9,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(padding.left, size.height - 20));

    textPainter.text = TextSpan(
      text: lastDate,
      style: TextStyle(
        color: Colors.white.withOpacity(0.5),
        fontSize: 9,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(size.width - padding.right - textPainter.width, size.height - 20),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
