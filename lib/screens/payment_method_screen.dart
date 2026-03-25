import 'package:flutter/material.dart';
import 'add_bank_account_screen.dart';
import 'add_upi_screen.dart';

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
    // Simulate fetching saved payment methods
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _savedPaymentMethods = [
        {
          'type': 'Bank Transfer',
          'details': 'HDFC Bank ****1234',
          'holderName': 'John Doe',
          'isDefault': true,
        },
        {
          'type': 'UPI Payment',
          'details': 'john@paytm',
          'holderName': 'John Doe',
          'isDefault': false,
        },
      ];
      _isLoading = false;
    });
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF84BD00)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_savedPaymentMethods.isNotEmpty) ...[
                    _buildSectionTitle('Saved Payment Methods'),
                    const SizedBox(height: 16),
                    _buildSavedPaymentMethods(),
                    const SizedBox(height: 32),
                  ],
                  _buildSectionTitle('Add New Payment Method'),
                  const SizedBox(height: 16),
                  _buildCountryDropdown(),
                  const SizedBox(height: 32),
                  _buildPaymentMethodDropdown(),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: selectedCountry != null && selectedPaymentMethod != null
                          ? () {
                              if (selectedPaymentMethod == 'Bank Transfer') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddBankAccountScreen(
                                      country: selectedCountry!,
                                    ),
                                  ),
                                ).then((_) => _fetchSavedPaymentMethods());
                              } else if (selectedPaymentMethod == 'UPI Payment') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddUpiScreen(
                                      country: selectedCountry!,
                                    ),
                                  ),
                                ).then((_) => _fetchSavedPaymentMethods());
                              } else {
                                // Handle other payment methods
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF84BD00),
                        disabledBackgroundColor: const Color(0xFF84BD00).withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Next Step',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        // Handle FAQS
                      },
                      child: const Text(
                        'FAQS',
                        style: TextStyle(
                          color: Color(0xFF84BD00),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
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
              }
            },
            itemBuilder: (context) => [
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
