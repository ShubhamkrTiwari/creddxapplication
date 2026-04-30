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
    {'name': 'Andorra', 'code': '376'},
    {'name': 'Angola', 'code': '244'},
    {'name': 'Argentina', 'code': '54'},
    {'name': 'Armenia', 'code': '374'},
    {'name': 'Australia', 'code': '61'},
    {'name': 'Austria', 'code': '43'},
    {'name': 'Azerbaijan', 'code': '994'},
    {'name': 'Bahrain', 'code': '973'},
    {'name': 'Bangladesh', 'code': '880'},
    {'name': 'Belarus', 'code': '375'},
    {'name': 'Belgium', 'code': '32'},
    {'name': 'Belize', 'code': '501'},
    {'name': 'Benin', 'code': '229'},
    {'name': 'Bhutan', 'code': '975'},
    {'name': 'Bolivia', 'code': '591'},
    {'name': 'Bosnia and Herzegovina', 'code': '387'},
    {'name': 'Botswana', 'code': '267'},
    {'name': 'Brazil', 'code': '55'},
    {'name': 'Brunei', 'code': '673'},
    {'name': 'Bulgaria', 'code': '359'},
    {'name': 'Burkina Faso', 'code': '226'},
    {'name': 'Burundi', 'code': '257'},
    {'name': 'Cambodia', 'code': '855'},
    {'name': 'Cameroon', 'code': '237'},
    {'name': 'Canada', 'code': '1'},
    {'name': 'Cape Verde', 'code': '238'},
    {'name': 'Central African Republic', 'code': '236'},
    {'name': 'Chad', 'code': '235'},
    {'name': 'Chile', 'code': '56'},
    {'name': 'China', 'code': '86'},
    {'name': 'Colombia', 'code': '57'},
    {'name': 'Comoros', 'code': '269'},
    {'name': 'Congo', 'code': '243'},
    {'name': 'Congo (Republic)', 'code': '242'},
    {'name': 'Costa Rica', 'code': '506'},
    {'name': 'Croatia', 'code': '385'},
    {'name': 'Cuba', 'code': '53'},
    {'name': 'Cyprus', 'code': '357'},
    {'name': 'Czech Republic', 'code': '420'},
    {'name': 'Denmark', 'code': '45'},
    {'name': 'Djibouti', 'code': '253'},
    {'name': 'Ecuador', 'code': '593'},
    {'name': 'Egypt', 'code': '20'},
    {'name': 'El Salvador', 'code': '503'},
    {'name': 'Equatorial Guinea', 'code': '240'},
    {'name': 'Eritrea', 'code': '291'},
    {'name': 'Estonia', 'code': '372'},
    {'name': 'Ethiopia', 'code': '251'},
    {'name': 'Fiji', 'code': '679'},
    {'name': 'Finland', 'code': '358'},
    {'name': 'France', 'code': '33'},
    {'name': 'Gabon', 'code': '241'},
    {'name': 'Gambia', 'code': '220'},
    {'name': 'Georgia', 'code': '995'},
    {'name': 'Germany', 'code': '49'},
    {'name': 'Ghana', 'code': '233'},
    {'name': 'Greece', 'code': '30'},
    {'name': 'Guatemala', 'code': '502'},
    {'name': 'Guinea', 'code': '224'},
    {'name': 'Guinea-Bissau', 'code': '245'},
    {'name': 'Guyana', 'code': '592'},
    {'name': 'Haiti', 'code': '509'},
    {'name': 'Honduras', 'code': '504'},
    {'name': 'Hong Kong', 'code': '852'},
    {'name': 'Hungary', 'code': '36'},
    {'name': 'Iceland', 'code': '354'},
    {'name': 'India', 'code': '91'},
    {'name': 'Indonesia', 'code': '62'},
    {'name': 'Iran', 'code': '98'},
    {'name': 'Iraq', 'code': '964'},
    {'name': 'Ireland', 'code': '353'},
    {'name': 'Israel', 'code': '972'},
    {'name': 'Italy', 'code': '39'},
    {'name': 'Ivory Coast', 'code': '225'},
    {'name': 'Japan', 'code': '81'},
    {'name': 'Jordan', 'code': '962'},
    {'name': 'Kazakhstan', 'code': '7'},
    {'name': 'Kenya', 'code': '254'},
    {'name': 'Kiribati', 'code': '686'},
    {'name': 'Kuwait', 'code': '965'},
    {'name': 'Kyrgyzstan', 'code': '996'},
    {'name': 'Laos', 'code': '856'},
    {'name': 'Latvia', 'code': '371'},
    {'name': 'Lebanon', 'code': '961'},
    {'name': 'Lesotho', 'code': '266'},
    {'name': 'Liberia', 'code': '231'},
    {'name': 'Libya', 'code': '218'},
    {'name': 'Liechtenstein', 'code': '423'},
    {'name': 'Lithuania', 'code': '370'},
    {'name': 'Luxembourg', 'code': '352'},
    {'name': 'Macau', 'code': '853'},
    {'name': 'Macedonia', 'code': '389'},
    {'name': 'Madagascar', 'code': '261'},
    {'name': 'Malawi', 'code': '265'},
    {'name': 'Malaysia', 'code': '60'},
    {'name': 'Maldives', 'code': '960'},
    {'name': 'Mali', 'code': '223'},
    {'name': 'Malta', 'code': '356'},
    {'name': 'Marshall Islands', 'code': '692'},
    {'name': 'Mauritania', 'code': '222'},
    {'name': 'Mauritius', 'code': '230'},
    {'name': 'Mexico', 'code': '52'},
    {'name': 'Micronesia', 'code': '691'},
    {'name': 'Moldova', 'code': '373'},
    {'name': 'Monaco', 'code': '377'},
    {'name': 'Mongolia', 'code': '976'},
    {'name': 'Montenegro', 'code': '382'},
    {'name': 'Morocco', 'code': '212'},
    {'name': 'Mozambique', 'code': '258'},
    {'name': 'Myanmar', 'code': '95'},
    {'name': 'Namibia', 'code': '264'},
    {'name': 'Nauru', 'code': '674'},
    {'name': 'Nepal', 'code': '977'},
    {'name': 'Netherlands', 'code': '31'},
    {'name': 'New Zealand', 'code': '64'},
    {'name': 'Nicaragua', 'code': '505'},
    {'name': 'Niger', 'code': '227'},
    {'name': 'Nigeria', 'code': '234'},
    {'name': 'North Korea', 'code': '850'},
    {'name': 'Norway', 'code': '47'},
    {'name': 'Oman', 'code': '968'},
    {'name': 'Pakistan', 'code': '92'},
    {'name': 'Palau', 'code': '680'},
    {'name': 'Panama', 'code': '507'},
    {'name': 'Papua New Guinea', 'code': '675'},
    {'name': 'Paraguay', 'code': '595'},
    {'name': 'Peru', 'code': '51'},
    {'name': 'Philippines', 'code': '63'},
    {'name': 'Poland', 'code': '48'},
    {'name': 'Portugal', 'code': '351'},
    {'name': 'Qatar', 'code': '974'},
    {'name': 'Romania', 'code': '40'},
    {'name': 'Russia', 'code': '7'},
    {'name': 'Rwanda', 'code': '250'},
    {'name': 'San Marino', 'code': '378'},
    {'name': 'Sao Tome and Principe', 'code': '239'},
    {'name': 'Saudi Arabia', 'code': '966'},
    {'name': 'Senegal', 'code': '221'},
    {'name': 'Serbia', 'code': '381'},
    {'name': 'Seychelles', 'code': '248'},
    {'name': 'Sierra Leone', 'code': '232'},
    {'name': 'Singapore', 'code': '65'},
    {'name': 'Slovakia', 'code': '421'},
    {'name': 'Slovenia', 'code': '386'},
    {'name': 'Solomon Islands', 'code': '677'},
    {'name': 'Somalia', 'code': '252'},
    {'name': 'South Africa', 'code': '27'},
    {'name': 'South Korea', 'code': '82'},
    {'name': 'South Sudan', 'code': '211'},
    {'name': 'Spain', 'code': '34'},
    {'name': 'Sri Lanka', 'code': '94'},
    {'name': 'Sudan', 'code': '249'},
    {'name': 'Suriname', 'code': '597'},
    {'name': 'Swaziland', 'code': '268'},
    {'name': 'Sweden', 'code': '46'},
    {'name': 'Switzerland', 'code': '41'},
    {'name': 'Syria', 'code': '963'},
    {'name': 'Taiwan', 'code': '886'},
    {'name': 'Tajikistan', 'code': '992'},
    {'name': 'Tanzania', 'code': '255'},
    {'name': 'Thailand', 'code': '66'},
    {'name': 'Togo', 'code': '228'},
    {'name': 'Tonga', 'code': '676'},
    {'name': 'Tunisia', 'code': '216'},
    {'name': 'Turkey', 'code': '90'},
    {'name': 'Turkmenistan', 'code': '993'},
    {'name': 'Uganda', 'code': '256'},
    {'name': 'Ukraine', 'code': '380'},
    {'name': 'UAE', 'code': '971'},
    {'name': 'United Arab Emirates', 'code': '971'},
    {'name': 'UK', 'code': '44'},
    {'name': 'United Kingdom', 'code': '44'},
    {'name': 'Uruguay', 'code': '598'},
    {'name': 'USA', 'code': '1'},
    {'name': 'United States', 'code': '1'},
    {'name': 'Uzbekistan', 'code': '998'},
    {'name': 'Venezuela', 'code': '58'},
    {'name': 'Vietnam', 'code': '84'},
    {'name': 'Yemen', 'code': '967'},
    {'name': 'Zambia', 'code': '260'},
    {'name': 'Zimbabwe', 'code': '263'},
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
