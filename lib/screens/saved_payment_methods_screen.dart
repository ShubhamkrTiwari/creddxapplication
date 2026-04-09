import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/p2p_service.dart';
import 'add_bank_account_screen.dart';
import 'add_upi_screen.dart';

class SavedPaymentMethodsScreen extends StatefulWidget {
  const SavedPaymentMethodsScreen({super.key});

  @override
  State<SavedPaymentMethodsScreen> createState() => _SavedPaymentMethodsScreenState();
}

class _SavedPaymentMethodsScreenState extends State<SavedPaymentMethodsScreen> {
  List<Map<String, dynamic>> _savedPaymentMethods = [];
  bool _isLoading = true;
  String _selectedCountry = 'India';
  List<String> _availablePaymentModes = [];
  
  final List<Map<String, String>> countries = [
    {'name': 'India', 'code': 'IN'},
    {'name': 'United States', 'code': 'US'},
    {'name': 'United Kingdom', 'code': 'UK'},
    {'name': 'Canada', 'code': 'CA'},
    {'name': 'Australia', 'code': 'AU'},
    {'name': 'Germany', 'code': 'DE'},
    {'name': 'France', 'code': 'FR'},
    {'name': 'United Arab Emirates', 'code': 'AE'},
    {'name': 'Singapore', 'code': 'SG'},
    {'name': 'Japan', 'code': 'JP'},
  ];

  @override
  void initState() {
    super.initState();
    // Add delay to allow API to sync newly saved data
    Future.delayed(const Duration(milliseconds: 500), () {
      _fetchSavedPaymentMethods();
      _fetchPaymentModes();
    });
  }

  Future<void> _fetchSavedPaymentMethods() async {
    try {
      debugPrint('Fetching saved payment methods...');
      
      // Try to get user details first
      final userDetails = await P2PService.getPaymentUserDetails();
      debugPrint('User details response: $userDetails');
      
      List<dynamic> methods = [];
      
      if (userDetails != null) {
        // Check multiple possible response formats
        if (userDetails['docs'] != null && userDetails['docs'] is List) {
          // API returns data in 'docs' field
          methods = userDetails['docs'];
          debugPrint('Payment methods from docs: $methods');
        } else if (userDetails['paymentMethods'] != null) {
          // Extract payment methods from user details
          methods = userDetails['paymentMethods'] is List 
              ? userDetails['paymentMethods'] 
              : (userDetails['data']?['paymentMethods'] ?? []);
          debugPrint('Payment methods from user details: $methods');
        } else if (userDetails['data'] != null && userDetails['data'] is List) {
          // Data might be directly in data field
          methods = userDetails['data'];
          debugPrint('Payment methods from data: $methods');
        }
      } else {
        // Fallback to regular payment methods endpoint
        methods = await P2PService.getPaymentMethods();
        debugPrint('Payment methods from fallback endpoint: $methods');
      }
      
      setState(() {
        _savedPaymentMethods = methods.map<Map<String, dynamic>>((method) {
          // Convert API response to expected format
          // API uses 'name' for payment type (UPI/Bank), 'UPI_ID' for UPI, 'upiUserName' for holder
          final paymentType = method['name']?.toString().toUpperCase() ?? 
                             method['type']?.toString().toUpperCase() ?? 
                             method['paymentType']?.toString().toUpperCase() ?? '';
          
          if (paymentType == 'UPI') {
            return {
              'type': 'UPI Payment',
              'details': method['UPI_ID'] ?? method['upiId'] ?? method['paymentId'] ?? 'Unknown UPI',
              'holderName': method['upiUserName'] ?? method['accountHolder'] ?? method['holderName'] ?? 'Unknown Holder',
              'isDefault': method['isDefault'] ?? method['default'] ?? false,
              'id': method['_id'] ?? method['id'], // Store ID for editing/deleting
            };
          } else if (paymentType == 'BANK' || paymentType.contains('BANK')) {
            final accountNumber = method['accountNumber'] ?? '';
            final maskedNumber = accountNumber.length > 4 
                ? '****${accountNumber.substring(accountNumber.length - 4)}'
                : '****1234';
            return {
              'type': 'Bank Transfer',
              'details': '${method['bankName'] ?? 'Unknown Bank'} $maskedNumber',
              'holderName': method['accountHolder'] ?? method['holderName'] ?? 'Unknown Holder',
              'isDefault': method['isDefault'] ?? method['default'] ?? false,
              'id': method['_id'] ?? method['id'], // Store ID for editing/deleting
            };
          }
          return {
            'type': '$paymentType Payment',
            'details': method['UPI_ID'] ?? method['accountNumber'] ?? 'Unknown',
            'holderName': method['upiUserName'] ?? method['accountHolder'] ?? method['holderName'] ?? 'Unknown Holder',
            'isDefault': method['isDefault'] ?? false,
            'id': method['_id'] ?? method['id'],
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching payment methods: $e');
      setState(() {
        _savedPaymentMethods = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchPaymentModes() async {
    try {
      debugPrint('Fetching payment modes for country: $_selectedCountry');
      
      // For India, show both UPI and Bank
      if (_selectedCountry == 'India') {
        setState(() {
          _availablePaymentModes = ['Bank Transfer', 'UPI Payment'];
        });
        debugPrint('Available payment modes for India: $_availablePaymentModes');
        return;
      }
      
      // For other countries, always show Bank Transfer as minimum
      setState(() {
        _availablePaymentModes = ['Bank Transfer'];
      });
      
      // Try to get additional payment modes from API
      try {
        final response = await P2PService.getPaymentModes(_selectedCountry);
        
        if (response != null && response['success'] == true) {
          final data = response['data'] ?? {};
          final modes = data['paymentModes'] ?? data['modes'] ?? [];
          
          if (modes.isNotEmpty) {
            setState(() {
              _availablePaymentModes = List<String>.from(modes);
              // Ensure Bank Transfer is always included
              if (!_availablePaymentModes.contains('Bank Transfer')) {
                _availablePaymentModes.add('Bank Transfer');
              }
            });
            debugPrint('Available payment modes from API: $_availablePaymentModes');
          } else {
            debugPrint('API returned empty modes, using Bank Transfer fallback');
          }
        } else {
          debugPrint('API call failed or returned no success, using Bank Transfer fallback');
        }
      } catch (apiError) {
        debugPrint('API call failed: $apiError, using Bank Transfer fallback');
      }
    } catch (e) {
      debugPrint('Error fetching payment modes: $e');
      // Always ensure Bank Transfer is available
      setState(() {
        _availablePaymentModes = ['Bank Transfer'];
      });
      debugPrint('Using Bank Transfer fallback due to error: $_availablePaymentModes');
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
          'Saved Payment Methods',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _fetchSavedPaymentMethods,
            icon: const Icon(Icons.refresh, color: Color(0xFF84BD00)),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF84BD00)),
            )
          : _savedPaymentMethods.isEmpty
              ? _buildEmptyState()
              : _buildPaymentMethodsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddPaymentOptions(context);
        },
        backgroundColor: const Color(0xFF84BD00),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.payment_outlined,
            size: 80,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No payment methods saved',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
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
          const SizedBox(height: 24),
          _buildCountrySelection(),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _showAddPaymentOptions(context);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Payment Method'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF84BD00),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsList() {
    return RefreshIndicator(
      onRefresh: _fetchSavedPaymentMethods,
      color: const Color(0xFF84BD00),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCountrySelection(),
          const SizedBox(height: 16),
          ..._savedPaymentMethods.asMap().entries.map((entry) {
            final index = entry.key;
            final method = entry.value;
            return _buildPaymentMethodCard(method);
          }).toList(),
        ],
      ),
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

  Widget _buildCountrySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Country', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12)),
          child: DropdownButton<String>(
            value: _selectedCountry,
            isExpanded: true,
            dropdownColor: const Color(0xFF1C1C1E),
            underline: const SizedBox(),
            icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF8E8E93)),
            items: countries.map((country) {
              return DropdownMenuItem<String>(
                value: country['name'],
                child: Row(
                  children: [
                    Text(
                      country['name']!,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${country['code']})',
                      style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedCountry = value;
                });
                _fetchPaymentModes(); // Fetch payment modes for new country
                _fetchSavedPaymentMethods(); // Refresh saved payment methods
              }
            },
          ),
        ),
        if (_availablePaymentModes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Available payment modes: ${_availablePaymentModes.join(", ")}',
            style: const TextStyle(color: Color(0xFF84BD00), fontSize: 12),
          ),
        ],
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
      builder: (context) => _buildAddPaymentBottomSheet(),
    );
  }

  Widget _buildAddPaymentBottomSheet() {
    return Container(
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
          // Dynamic payment options based on available modes
          ..._availablePaymentModes.map((mode) {
            if (mode == 'UPI Payment') {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildPaymentOption(
                  icon: Icons.phone_android,
                  title: 'UPI Payment',
                  subtitle: 'Add UPI ID for instant transfers',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddUpiScreen(country: _selectedCountry),
                      ),
                    ).then((_) => _fetchSavedPaymentMethods());
                  },
                ),
              );
            } else if (mode == 'Bank Transfer') {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildPaymentOption(
                  icon: Icons.account_balance,
                  title: 'Bank Transfer',
                  subtitle: 'Add bank account details',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddBankAccountScreen(country: _selectedCountry),
                      ),
                    ).then((_) => _fetchSavedPaymentMethods());
                  },
                ),
              );
            }
            return const SizedBox.shrink();
          }).toList(),
          // Add Advert option always available
          const SizedBox(height: 16),
          _buildPaymentOption(
            icon: Icons.campaign,
            title: 'Add Advert',
            subtitle: 'Create and manage advertisements',
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to add advert screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Add Advert feature coming soon!'),
                  backgroundColor: Color(0xFF84BD00),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
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

  void _deletePaymentMethod(Map<String, dynamic> method) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Delete Payment Method',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete this ${method['type']}?',
          style: const TextStyle(color: Color(0xFF8E8E93)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF84BD00)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const AlertDialog(
                  backgroundColor: Color(0xFF1C1C1E),
                  content: Row(
                    children: [
                      CircularProgressIndicator(color: Color(0xFF84BD00)),
                      SizedBox(width: 16),
                      Text('Deleting...', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              );
              
              try {
                final paymentMethodId = method['id']?.toString();
                if (paymentMethodId == null || paymentMethodId.isEmpty) {
                  throw Exception('Payment method ID not found');
                }
                
                final success = await P2PService.deletePaymentMethod(paymentMethodId);
                
                // Close loading dialog
                Navigator.pop(context);
                
                if (success) {
                  setState(() {
                    _savedPaymentMethods.remove(method);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payment method deleted successfully'),
                      backgroundColor: Color(0xFF84BD00),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete payment method'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                // Close loading dialog
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
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
