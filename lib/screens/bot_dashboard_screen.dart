import 'package:flutter/material.dart';

class BotDashboardScreen extends StatefulWidget {
  const BotDashboardScreen({super.key});

  @override
  State<BotDashboardScreen> createState() => _BotDashboardScreenState();
}

class _BotDashboardScreenState extends State<BotDashboardScreen> {
  String _selectedSort = 'Top';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text(
          'Trading Bot Dashboard',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            _buildWelcomeSection(),
            const SizedBox(height: 24),
            
            // Currency Market Section
            _buildCurrencyMarket(),
            const SizedBox(height: 24),
            
            // Top Strategies Section
            _buildTopStrategies(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyMarket() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Currency Market',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Bitcoin
          _buildCurrencyItem(
            'BTC',
            'Bitcoin',
            '\$67,432.50',
            '+2.45%',
            const Color(0xFF84BD00),
            '₹5.67L Cr',
          ),
          const SizedBox(height: 8),
          
          // Ethereum
          _buildCurrencyItem(
            'ETH',
            'Ethereum',
            '\$3,456.78',
            '+1.23%',
            const Color(0xFF84BD00),
            '₹2.91L Cr',
          ),
          const SizedBox(height: 8),
          
          // Solana
          _buildCurrencyItem(
            'SOL',
            'Solana',
            '\$178.92',
            '-0.87%',
            const Color(0xFFFF3B30),
            '₹15.08K Cr',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyItem(
    String symbol,
    String name,
    String price,
    String change,
    Color changeColor,
    String marketCap,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                symbol,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: changeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  change,
                  style: TextStyle(
                    color: changeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            price,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'MCap $marketCap',
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to CreddX',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your Ultimate Crypto Trading AI Bot',
            style: TextStyle(
              color: Color(0xFF84BD00),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Automate your trading strategies with our advanced AI-powered bots. '
            'Choose from proven strategies or create your own custom trading algorithms.',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Active Bots', '12', Icons.autorenew),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Total Profit', '+24.5%', Icons.trending_up),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Win Rate', '78%', Icons.track_changes),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF84BD00), size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTopStrategies() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Top Strategies',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                _buildSortButton('Top'),
                const SizedBox(width: 8),
                _buildSortButton('Latest'),
                const SizedBox(width: 8),
                _buildSortButton('View all'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Strategy Cards Slider
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            itemBuilder: (context, index) {
              final strategies = [
                {'name': 'Omega', 'multiplier': '3x', 'available': true},
                {'name': 'Alpha', 'multiplier': '2x', 'available': false},
                {'name': 'Ranger', 'multiplier': '5x', 'available': false},
              ];
              final strategy = strategies[index];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 200,
                  child: _buildStrategyCard(
                    strategy['name'] as String,
                    strategy['multiplier'] as String,
                    strategy['available'] as bool,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSortButton(String label) {
    final isSelected = _selectedSort == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedSort = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF84BD00) : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStrategyCard(String name, String multiplier, bool isAvailable) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF84BD00).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${multiplier}x',
                  style: const TextStyle(
                    color: Color(0xFF84BD00),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Mini Chart
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(
                Icons.show_chart,
                color: Color(0xFF84BD00),
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Returns
          const Text(
            'Returns',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildReturnItem('3M', '+12.5%'),
              _buildReturnItem('6M', '+28.3%'),
              _buildReturnItem('1Y', '+45.7%'),
            ],
          ),
          const SizedBox(height: 16),
          
          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isAvailable ? () {} : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isAvailable ? const Color(0xFF84BD00) : const Color(0xFF333333),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                isAvailable ? 'Subscribe' : 'Coming Soon',
                style: TextStyle(
                  color: isAvailable ? Colors.black : const Color(0xFF8E8E93),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnItem(String period, String value) {
    return Column(
      children: [
        Text(
          period,
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF84BD00),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
