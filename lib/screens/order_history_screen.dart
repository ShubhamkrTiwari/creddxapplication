import 'package:flutter/material.dart';
import '../services/p2p_service.dart';
import 'p2p_chat_detail_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _orders = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    final orders = await P2PService.getMyOrders();
    if (mounted) {
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text('Order History', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF84BD00),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Completed'),
            Tab(text: 'Canceled'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOrderList(filterType: 'all'),
                _buildOrderList(filterType: 'completed'),
                _buildOrderList(filterType: 'canceled'),
              ],
            ),
    );
  }

  Widget _buildOrderList({required String filterType}) {
    final filteredOrders = _orders.where((order) {
      final status = (order['status'] ?? '').toString().toLowerCase();
      switch (filterType) {
        case 'all':
          return true;
        case 'completed':
          return status == 'completed';
        case 'canceled':
          return status == 'cancelled' || status == 'canceled';
        default:
          return true;
      }
    }).toList();

    if (filteredOrders.isEmpty) {
      return Center(child: Text('No orders found', style: const TextStyle(color: Colors.white54)));
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) => _buildOrderCard(filteredOrders[index]),
      ),
    );
  }

  Widget _buildOrderCard(dynamic order) {
    final isBuy = order['type'] == 'buy';
    final status = (order['status'] ?? 'pending').toString().toLowerCase();
    final orderId = order['_id'] ?? '';
    
    Color statusColor;
    String statusText;
    List<Widget> actions = [];

    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'Pending';
        actions.add(_buildCancelButton(orderId));
        break;
      case 'unpaid':
        statusColor = Colors.red;
        statusText = 'Unpaid';
        actions.add(_buildCancelButton(orderId));
        if (isBuy) {
          actions.add(_buildPayButton(orderId));
        }
        break;
      case 'paid':
        statusColor = Colors.blue;
        statusText = 'Paid';
        if (!isBuy) {
          actions.add(_buildReleaseButton(orderId));
        }
        actions.add(_buildChatButton(order));
        actions.add(_buildDisputeButton(orderId));
        break;
      case 'completed':
        statusColor = const Color(0xFF84BD00);
        statusText = 'Completed';
        actions.add(_buildFeedbackButton(orderId));
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusText = 'Cancelled';
        break;
      case 'disputed':
        statusColor = Colors.purple;
        statusText = 'Disputed';
        actions.add(_buildChatButton(order));
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Unknown';
    }

    if (actions.isEmpty && status != 'completed' && status != 'cancelled') {
      actions.add(_buildChatButton(order));
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${isBuy ? "Buy" : "Sell"} ${order['coin'] ?? "USDT"}',
                style: TextStyle(color: isBuy ? const Color(0xFF84BD00) : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Order ID', orderId.substring(0, 8) + '...'),
          _buildInfoRow('Amount', '${order['amount']} ${order['coin']}'),
          _buildInfoRow('Price', '₹${order['price']}'),
          _buildInfoRow('Total', '₹${(double.tryParse(order['amount'].toString()) ?? 0) * (double.tryParse(order['price'].toString()) ?? 0)}'),
          if (order['paymentMode'] != null)
            _buildInfoRow('Payment Method', order['paymentMode']),
          if (order['createdAt'] != null)
            _buildInfoRow('Created', _formatDate(order['createdAt'])),
          const Divider(color: Colors.white10, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: actions,
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton(String orderId) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton(
        onPressed: () => _cancelOrder(orderId),
        style: TextButton.styleFrom(
          backgroundColor: Colors.red.withOpacity(0.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
      ),
    );
  }

  Widget _buildPayButton(String orderId) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ElevatedButton(
        onPressed: () => _showPaymentDialog(orderId),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF84BD00),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: const Text('Pay Now', style: TextStyle(color: Colors.black)),
      ),
    );
  }

  Widget _buildReleaseButton(String orderId) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ElevatedButton(
        onPressed: () => _releaseCrypto(orderId),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF84BD00),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: const Text('Release', style: TextStyle(color: Colors.black)),
      ),
    );
  }

  Widget _buildChatButton(dynamic order) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => P2PChatDetailScreen(
                userId: order['advertiserId'] ?? order['userId'] ?? '',
                userName: order['advertiserName'] ?? 'Partner',
                appealId: order['_id'],
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: const Text('Chat', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildDisputeButton(String orderId) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton(
        onPressed: () => _showDisputeDialog(orderId),
        style: TextButton.styleFrom(
          backgroundColor: Colors.purple.withOpacity(0.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: const Text('Dispute', style: TextStyle(color: Colors.purple)),
      ),
    );
  }

  Widget _buildFeedbackButton(String orderId) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton(
        onPressed: () => _showFeedbackDialog(orderId),
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFF84BD00).withOpacity(0.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: const Text('Feedback', style: TextStyle(color: Color(0xFF84BD00))),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  void _showPaymentDialog(String orderId) {
    final TextEditingController utrController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Confirm Payment', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: utrController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'UTR / Transaction ID',
            labelStyle: TextStyle(color: Color(0xFF8E8E93)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await P2PService.confirmPayment(orderId, utrController.text, "");
              if (mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment confirmed!'), backgroundColor: Color(0xFF84BD00)),
                  );
                  _fetchOrders();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to confirm payment'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _releaseCrypto(String orderId) async {
    final success = await P2PService.releaseCrypto(orderId);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crypto released successfully!'), backgroundColor: Color(0xFF84BD00)),
      );
      _fetchOrders();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to release crypto'), backgroundColor: Colors.red),
      );
    }
  }

  void _showDisputeDialog(String orderId) {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Create Dispute', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: reasonController,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Dispute Reason',
            labelStyle: TextStyle(color: Color(0xFF8E8E93)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await P2PService.createDispute({
                'orderId': orderId,
                'reason': reasonController.text,
              });
              if (mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dispute created!'), backgroundColor: Color(0xFF84BD00)),
                  );
                  _fetchOrders();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to create dispute'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog(String orderId) {
    final TextEditingController feedbackController = TextEditingController();
    int rating = 5;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Submit Feedback', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: Colors.yellow,
                  ),
                  onPressed: () {
                    // Update rating in state
                  },
                );
              }),
            ),
            TextField(
              controller: feedbackController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Your Feedback',
                labelStyle: TextStyle(color: Color(0xFF8E8E93)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await P2PService.submitFeedback({
                'orderId': orderId,
                'rating': rating,
                'comment': feedbackController.text,
              });
              if (mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Feedback submitted!'), backgroundColor: Color(0xFF84BD00)),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to submit feedback'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _cancelOrder(String orderId) async {
    final success = await P2PService.cancelOrder(orderId, 'User cancelled');
    if (success) _fetchOrders();
  }
}
