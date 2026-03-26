import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/p2p_service.dart';
import 'add_bank_account_screen.dart';
import 'add_upi_screen.dart';
import 'saved_payment_methods_screen.dart';

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  String? selectedCountry;
  String? selectedPaymentMethod;
  List<Map<String, dynamic>> _savedPaymentMethods = [];
  bool _isLoading = true;

  final List<Map<String, String>> countries = [
    {'name': 'Afghanistan', 'code': '93'},
    {'name': 'Albania', 'code': '355'},
    {'name': 'Algeria', 'code': '213'},
    {'name': 'India', 'code': '91'},
    {'name': 'United States', 'code': '1'},
    {'name': 'United Kingdom', 'code': '44'},
    {'name': 'Canada', 'code': '1'},
    {'name': 'Australia', 'code': '61'},
    {'name': 'Germany', 'code': '49'},
    {'name': 'France', 'code': '33'},
  ];

  final List<String> paymentMethods = [
    'Bank Transfer',
    'UPI Payment',
    'PayPal',
    'Credit Card',
    'Debit Card',
    'Net Banking',
  ];

  @override
  void initState() {
    super.initState();
    _fetchSavedPaymentMethods();
  }

  Future<void> _fetchSavedPaymentMethods() async {
    try {
      debugPrint('Fetching saved payment methods...'); // Debug log
      
      // Try to get user details first
      final userDetails = await P2PService.getPaymentUserDetails();
      debugPrint('User details response: $userDetails'); // Debug log
      
      List<dynamic> methods = [];
      
      if (userDetails != null && userDetails['paymentMethods'] != null) {
        // Extract payment methods from user details
        methods = userDetails['paymentMethods'] is List 
            ? userDetails['paymentMethods'] 
            : (userDetails['data']?['paymentMethods'] ?? []);
        debugPrint('Payment methods from user details: $methods'); // Debug log
      } else {
        // Fallback to regular payment methods endpoint
        methods = await P2PService.getPaymentMethods();
        debugPrint('Payment methods from fallback endpoint: $methods'); // Debug log
      }
      
      setState(() {
        _savedPaymentMethods = methods.map<Map<String, dynamic>>((method) {
          // Convert API response to expected format
          if (method['type'] == 'UPI' || method['paymentType'] == 'UPI') {
            return {
              'type': 'UPI Payment',
              'details': method['upiId'] ?? method['paymentId'] ?? 'Unknown UPI',
              'holderName': method['accountHolder'] ?? method['holderName'] ?? 'Unknown Holder',
              'isDefault': method['isDefault'] ?? method['default'] ?? false,
              'id': method['id'] ?? method['_id'],
            };
          } else if (method['type'] == 'Bank' || method['paymentType'] == 'Bank') {
            final accountNumber = method['accountNumber'] ?? '';
            final maskedNumber = accountNumber.length > 4 
                ? '****${accountNumber.substring(accountNumber.length - 4)}'
                : '****1234';
            return {
              'type': 'Bank Transfer',
              'details': '${method['bankName'] ?? method['bankName'] ?? 'Unknown Bank'} $maskedNumber',
              'holderName': method['accountHolder'] ?? method['holderName'] ?? 'Unknown Holder',
              'isDefault': method['isDefault'] ?? method['default'] ?? false,
              'id': method['id'] ?? method['_id'],
            };
          }
          return method as Map<String, dynamic>;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching payment methods: $e'); // Debug log
      setState(() {
        _savedPaymentMethods = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: const Text(
          'Payment Method',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF84BD00)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Methods',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your payment methods',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          
          // Add Payment Method Card
          _buildActionCard(
            icon: Icons.add_circle_outline,
            title: 'Add Payment Method',
            subtitle: 'Add UPI, Bank Account, or other payment methods',
            onTap: () => _showAddPaymentOptions(context),
            color: const Color(0xFF84BD00),
          ),
          
          const SizedBox(height: 24),
          
          // Saved Payment Methods Section
          if (_savedPaymentMethods.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Saved Payment Methods',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SavedPaymentMethodsScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: Color(0xFF84BD00),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Show first 2-3 saved payment methods
            ..._savedPaymentMethods.take(3).map((method) => _buildCompactPaymentCard(method)),
            
            if (_savedPaymentMethods.length > 3) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SavedPaymentMethodsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward, color: Color(0xFF84BD00)),
                label: Text(
                  'View all ${_savedPaymentMethods.length} payment methods',
                  style: const TextStyle(color: Color(0xFF84BD00)),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ] else ...[
            // Empty state
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2C2C2E)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.payment_outlined,
                    size: 48,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No saved payment methods',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first payment method to get started',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Quick Stats
          _buildQuickStats(),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2C2C2E)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactPaymentCard(Map<String, dynamic> method) {
    final isDefault = method['isDefault'] ?? false;
    final type = method['type'] ?? '';
    final details = method['details'] ?? '';
    final holderName = method['holderName'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDefault ? const Color(0xFF84BD00) : const Color(0xFF2C2C2E),
          width: isDefault ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: type == 'Bank Transfer' ? Colors.blue : Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              type == 'Bank Transfer' ? Icons.account_balance : Icons.phone_android,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      type,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF84BD00),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Default',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  holderName,
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF8E8E93)),
            color: const Color(0xFF1C1C1E),
            onSelected: (value) {
              if (value == 'edit') {
                _editPaymentMethod(method);
              } else if (value == 'setDefault') {
                _setDefaultPaymentMethod(method);
              } else if (value == 'delete') {
                _deletePaymentMethod(method);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Color(0xFF84BD00), size: 20),
                    SizedBox(width: 8),
                    Text('Edit', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              if (!isDefault)
                const PopupMenuItem(
                  value: 'setDefault',
                  child: Row(
                    children: [
                      Icon(Icons.star, color: Color(0xFF84BD00), size: 20),
                      SizedBox(width: 8),
                      Text('Set as Default', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final savedCount = _savedPaymentMethods.length;
    final defaultCount = _savedPaymentMethods.where((m) => m['isDefault'] == true).length;
    
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
          Text(
            'Quick Stats',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  label: 'Saved Methods',
                  value: '$savedCount',
                  icon: Icons.payment,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: const Color(0xFF2C2C2E),
              ),
              Expanded(
                child: _buildStatItem(
                  label: 'Default Method',
                  value: defaultCount > 0 ? 'Set' : 'None',
                  icon: Icons.star,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFF84BD00),
          size: 20,
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
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showAddPaymentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Add Payment Method',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildPaymentOption(
              icon: Icons.phone_android,
              title: 'UPI Payment',
              subtitle: 'Add UPI ID for instant transfers',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddUpiScreen(country: 'India'),
                  ),
                ).then((_) => _fetchSavedPaymentMethods());
              },
            ),
            const SizedBox(height: 16),
            _buildPaymentOption(
              icon: Icons.account_balance,
              title: 'Bank Transfer',
              subtitle: 'Add bank account details',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddBankAccountScreen(country: 'India'),
                  ),
                ).then((_) => _fetchSavedPaymentMethods());
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF84BD00).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF84BD00),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF8E8E93),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryDropdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: DropdownButton<String>(
        value: selectedCountry,
        hint: const Text(
          'Select country',
          style: TextStyle(color: Color(0xFF8E8E93)),
        ),
        dropdownColor: const Color(0xFF1C1C1E),
        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF8E8E93)),
        isExpanded: true,
        underline: const SizedBox(),
        items: countries.map((country) {
          return DropdownMenuItem<String>(
            value: '${country['name']} (${country['code']})',
            child: Text(
              '${country['name']} (${country['code']})',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedCountry = value;
          });
        },
      ),
    );
  }

  Widget _buildPaymentMethodDropdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: DropdownButton<String>(
        value: selectedPaymentMethod,
        hint: const Text(
          'Select payment method',
          style: TextStyle(color: Color(0xFF8E8E93)),
        ),
        dropdownColor: const Color(0xFF1C1C1E),
        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF8E8E93)),
        isExpanded: true,
        underline: const SizedBox(),
        items: paymentMethods.map((method) {
          return DropdownMenuItem<String>(
            value: method,
            child: Text(
              method,
              style: const TextStyle(color: Colors.white),
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedPaymentMethod = value;
          });
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSavedPaymentMethods() {
    return Column(
      children: _savedPaymentMethods.map((method) {
        return _buildPaymentMethodCard(method);
      }).toList(),
    );
  }

  Widget _buildPaymentMethodCard(Map<String, dynamic> method) {
    final isDefault = method['isDefault'] ?? false;
    final type = method['type'] ?? '';
    final details = method['details'] ?? '';
    final holderName = method['holderName'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDefault ? const Color(0xFF84BD00) : const Color(0xFF2C2C2E),
          width: isDefault ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: type == 'Bank Transfer' ? Colors.blue : Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              type == 'Bank Transfer' ? Icons.account_balance : Icons.phone_android,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      type,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF84BD00),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Default',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  holderName,
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF8E8E93)),
            color: const Color(0xFF1C1C1E),
            onSelected: (value) {
              if (value == 'delete') {
                _deletePaymentMethod(method);
              } else if (value == 'setDefault') {
                _setDefaultPaymentMethod(method);
              } else if (value == 'edit') {
                _editPaymentMethod(method);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Color(0xFF84BD00), size: 20),
                    SizedBox(width: 8),
                    Text('Edit', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'setDefault',
                child: Row(
                  children: [
                    Icon(Icons.star, color: Color(0xFF84BD00), size: 20),
                    SizedBox(width: 8),
                    Text('Set as Default', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _deletePaymentMethod(Map<String, dynamic> method) {
    setState(() {
      _savedPaymentMethods.remove(method);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment method deleted'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _editPaymentMethod(Map<String, dynamic> method) {
    final type = method['type'] ?? '';
    
    if (type == 'UPI Payment') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddUpiScreen(
            country: 'India',
            isEditMode: true,
            editData: method,
          ),
        ),
      ).then((_) => _fetchSavedPaymentMethods());
    } else if (type == 'Bank Transfer') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddBankAccountScreen(
            country: 'India',
            isEditMode: true,
            editData: method,
          ),
        ),
      ).then((_) => _fetchSavedPaymentMethods());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Edit functionality not available for this payment method'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _setDefaultPaymentMethod(Map<String, dynamic> method) {
    setState(() {
      for (var m in _savedPaymentMethods) {
        m['isDefault'] = false;
      }
      method['isDefault'] = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment method set as default'),
        backgroundColor: Color(0xFF84BD00),
      ),
    );
  }
}
