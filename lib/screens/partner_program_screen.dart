import 'package:flutter/material.dart';
import '../services/user_service.dart';

class AffiliateProgramScreen extends StatefulWidget {
  const AffiliateProgramScreen({super.key});

  @override
  State<AffiliateProgramScreen> createState() => _AffiliateProgramScreenState();
}

class _AffiliateProgramScreenState extends State<AffiliateProgramScreen> {
  int? _selectedLevel;
  bool _isLoading = false;
  Map<String, dynamic>? _levelWiseData;
  Map<String, dynamic>? _detailedLevelData;

  @override
  void initState() {
    super.initState();
    _loadLevelWiseData();
  }

  Future<void> _loadLevelWiseData() async {
    setState(() => _isLoading = true);
    try {
      final result = await UserService.getLevelWiseSummary();
      if (mounted) {
        setState(() {
          _levelWiseData = result['success'] == true ? result : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadDetailedLevelData(int level) async {
    setState(() {
      _selectedLevel = level;
      _isLoading = true;
    });
    try {
      final result = await UserService.getLevelIncomeSummary(level);
      if (mounted) {
        setState(() {
          _detailedLevelData = result['success'] == true ? result : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _goBack() {
    setState(() {
      _selectedLevel = null;
      _detailedLevelData = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161618),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          _selectedLevel == null ? 'Affiliate Program' : 'Level $_selectedLevel Details',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_selectedLevel != null) {
              _goBack();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
          : _selectedLevel == null
              ? _buildLevelWiseView()
              : _buildDetailedLevelView(),
    );
  }

  Widget _buildLevelWiseView() {
    if (_levelWiseData == null) {
      return _buildErrorWidget();
    }

    final levels = _levelWiseData?['levels'] as List? ?? [];
    
    double totalSubscriptionIncome = 0;
    double totalBotIncome = 0;
    int totalBotUsers = 0;
    int totalSubscriptionUsers = 0;

    for (var level in levels) {
      totalSubscriptionIncome += (level['subscriptionIncome'] as num?)?.toDouble() ?? 0.0;
      totalBotIncome += (level['botProfitIncome'] as num?)?.toDouble() ?? 0.0;
      totalBotUsers += (level['botUserCount'] as int?) ?? 0;
      totalSubscriptionUsers += (level['subscriptionUserCount'] as int?) ?? 0;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTotalSummaryCard(
            totalSubscriptionIncome,
            totalBotIncome,
            totalBotUsers,
            totalSubscriptionUsers,
          ),
          const SizedBox(height: 24),
          const Text(
            'Income by Level',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (levels.isEmpty)
            _buildEmptyState()
          else
            ...levels.map((level) => _buildLevelCard(level)).toList(),
        ],
      ),
    );
  }

  Widget _buildTotalSummaryCard(
    double subscriptionIncome,
    double botIncome,
    int botUsers,
    int subscriptionUsers,
  ) {
    final totalIncome = subscriptionIncome + botIncome;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF84BD00), Color(0xFF6A9600)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Earnings',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${totalIncome.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric(
                  'Subscription',
                  '\$${subscriptionIncome.toStringAsFixed(2)}',
                  '$subscriptionUsers users',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryMetric(
                  'Bot Profit',
                  '\$${botIncome.toStringAsFixed(2)}',
                  '$botUsers users',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(String label, String value, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildLevelCard(Map<String, dynamic> level) {
    final levelNum = level['level'] ?? 0;
    final botUserCount = level['botUserCount'] ?? 0;
    final subscriptionUserCount = level['subscriptionUserCount'] ?? 0;
    final subscriptionIncome = (level['subscriptionIncome'] as num?)?.toDouble() ?? 0.0;
    final botUserIncomeCount = level['botUserIncomeCount'] ?? 0;
    final botProfitIncome = (level['botProfitIncome'] as num?)?.toDouble() ?? 0.0;
    final totalIncome = subscriptionIncome + botProfitIncome;

    return GestureDetector(
      onTap: () => _loadDetailedLevelData(levelNum),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF84BD00),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Level $levelNum',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '\$${totalIncome.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF84BD00),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white54,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildLevelMetric(
                    'Subscription',
                    subscriptionUserCount.toString(),
                    '\$${subscriptionIncome.toStringAsFixed(2)}',
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildLevelMetric(
                    'Bot Users',
                    botUserCount.toString(),
                    '$botUserIncomeCount earning',
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildLevelMetric(
                    'Bot Profit',
                    '\$${botProfitIncome.toStringAsFixed(2)}',
                    '',
                    const Color(0xFF84BD00),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelMetric(String label, String value, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailedLevelView() {
    if (_detailedLevelData == null) {
      return _buildErrorWidget();
    }

    final totalUsers = _detailedLevelData?['totalUsers'] ?? 0;
    final users = _detailedLevelData?['users'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailedSummaryCard(totalUsers),
          const SizedBox(height: 16),
          Text(
            'Users ($totalUsers)',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (users.isEmpty)
            _buildEmptyState()
          else
            ...users.map((user) => _buildUserCard(user)).toList(),
        ],
      ),
    );
  }

  Widget _buildDetailedSummaryCard(int totalUsers) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Level', _selectedLevel.toString(), const Color(0xFF84BD00)),
          _buildSummaryItem('Total Users', totalUsers.toString(), Colors.blue),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final name = user['name'] ?? 'Unknown';
    final email = user['email'] ?? '';
    final amount = (user['amount'] as num?)?.toDouble() ?? 0.0;
    final source = user['source'] ?? 'no-income';

    Color sourceColor;
    String sourceText;
    
    if (source.contains('subscription') && source.contains('bot')) {
      sourceColor = const Color(0xFF84BD00);
      sourceText = 'Subscription + Bot';
    } else if (source.contains('subscription')) {
      sourceColor = Colors.blue;
      sourceText = 'Subscription';
    } else if (source.contains('bot')) {
      sourceColor = Colors.orange;
      sourceText = 'Bot';
    } else {
      sourceColor = Colors.grey;
      sourceText = 'No Income';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF84BD00),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: sourceColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sourceText,
                  style: TextStyle(
                    color: sourceColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '\$${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF84BD00),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No users at this level yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Failed to load data',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (_selectedLevel == null) {
                _loadLevelWiseData();
              } else {
                _loadDetailedLevelData(_selectedLevel!);
              }
            },
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
}
