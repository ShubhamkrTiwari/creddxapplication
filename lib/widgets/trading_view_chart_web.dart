import 'package:flutter/material.dart';
import 'trading_view_chart_stub.dart';

class TradingViewChart extends TradingViewChartBase {
  const TradingViewChart({
    super.key,
    required super.symbol,
    super.theme,
    super.interval,
    super.allowFullscreen,
    super.allowSymbolChange,
    super.autosize,
    super.hideTopToolbar,
    super.hideLegend,
    super.hideSideToolbar,
    super.timezone,
  });

  @override
  State<TradingViewChart> createState() => _TradingViewChartState();
}

typedef TradingViewChartBase = TradingViewChart;

class _TradingViewChartState extends State<TradingViewChart> {
  @override
  Widget build(BuildContext context) {
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
    // No-op on web
  }
}
