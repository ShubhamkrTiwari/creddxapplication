import 'package:flutter/material.dart';
import '../services/p2p_service.dart';
import 'p2p_chat_detail_screen.dart';

class DisputeManagementScreen extends StatefulWidget {
  const DisputeManagementScreen({super.key});

  @override
  State<DisputeManagementScreen> createState() => _DisputeManagementScreenState();
}

class _DisputeManagementScreenState extends State<DisputeManagementScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _disputes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchDisputes();
  }

  Future<void> _fetchDisputes() async {
    setState(() => _isLoading = true);
    final disputes = await P2PService.getMyDisputes();
    if (mounted) {
      setState(() {
        _disputes = disputes;
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
        title: const Text('Dispute Management', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF84BD00),
          labelColor: const Color(0xFF84BD00),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Resolved'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDisputeList(isActive: true),
                _buildDisputeList(isActive: false),
              ],
            ),
    );
  }

  Widget _buildDisputeList({required bool isActive}) {
    final filteredDisputes = _disputes.where((dispute) {
      final status = (dispute['status'] ?? '').toString().toLowerCase();
      return isActive ? status != 'resolved' && status != 'closed' : status == 'resolved' || status == 'closed';
    }).toList();

    if (filteredDisputes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.pending_actions : Icons.check_circle_outline,
              color: Colors.white54,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              isActive ? 'No active disputes' : 'No resolved disputes',
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchDisputes,
      color: const Color(0xFF84BD00),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredDisputes.length,
        itemBuilder: (context, index) => _buildDisputeCard(filteredDisputes[index]),
      ),
    );
  }

  Widget _buildDisputeCard(dynamic dispute) {
    final status = (dispute['status'] ?? 'pending').toString().toLowerCase();
    final orderId = dispute['orderId'] ?? '';
    final reason = dispute['reason'] ?? 'No reason provided';
    final createdAt = dispute['createdAt'] ?? '';
    
    Color statusColor;
    String statusText;
    
    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'Pending';
        break;
      case 'investigating':
        statusColor = Colors.blue;
        statusText = 'Investigating';
        break;
      case 'resolved':
        statusColor = const Color(0xFF84BD00);
        statusText = 'Resolved';
        break;
      case 'closed':
        statusColor = Colors.grey;
        statusText = 'Closed';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Unknown';
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
              Expanded(
                child: Text(
                  'Dispute #${orderId.substring(0, 8)}...',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
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
          Text(
            reason,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Order ID', orderId.substring(0, 16) + '...'),
          _buildInfoRow('Created', _formatDate(createdAt)),
          if (dispute['response'] != null)
            _buildInfoRow('Response', dispute['response'], maxLines: 2),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (status == 'pending' || status == 'investigating')
                TextButton(
                  onPressed: () => _showResponseDialog(dispute),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.blue.withOpacity(0.2),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Respond', style: TextStyle(color: Colors.blue)),
                ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _viewDisputeDetails(dispute),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF84BD00),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('View Details', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          const Text(': ', style: TextStyle(color: Colors.white54, fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  void _showResponseDialog(dynamic dispute) {
    final TextEditingController responseController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Respond to Dispute', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dispute: ${dispute['reason'] ?? 'No reason'}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: responseController,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Your Response',
                labelStyle: TextStyle(color: Color(0xFF8E8E93)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF84BD00))),
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
              final success = await P2PService.respondToDispute(
                dispute['_id'],
                responseController.text,
              );
              if (mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Response submitted!'), backgroundColor: Color(0xFF84BD00)),
                  );
                  _fetchDisputes();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to submit response'), backgroundColor: Colors.red),
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

  void _viewDisputeDetails(dynamic dispute) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Dispute Details', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Dispute ID', dispute['_id'] ?? ''),
              _buildDetailRow('Order ID', dispute['orderId'] ?? ''),
              _buildDetailRow('Status', dispute['status'] ?? ''),
              _buildDetailRow('Reason', dispute['reason'] ?? ''),
              if (dispute['response'] != null)
                _buildDetailRow('Response', dispute['response']),
              _buildDetailRow('Created', _formatDate(dispute['createdAt'] ?? '')),
              if (dispute['updatedAt'] != null)
                _buildDetailRow('Updated', _formatDate(dispute['updatedAt'])),
              if (dispute['resolvedAt'] != null)
                _buildDetailRow('Resolved', _formatDate(dispute['resolvedAt'])),
            ],
          ),
        ),
        actions: [
          if (dispute['orderId'] != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => P2PChatDetailScreen(
                      userId: dispute['otherUserId'] ?? '',
                      userName: dispute['otherUserName'] ?? 'Support',
                      appealId: dispute['orderId'],
                    ),
                  ),
                );
              },
              child: const Text('Chat'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF84BD00), fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
