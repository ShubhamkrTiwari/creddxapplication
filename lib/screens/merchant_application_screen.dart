import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/p2p_service.dart';
import 'p2p_trading_screen.dart';
import 'order_history_screen.dart';
import 'user_profile_screen.dart';
import 'add_upi_screen.dart';
import 'add_bank_account_screen.dart';
import 'confirm_advert_screen.dart';
import 'create_advertisement_screen.dart';

class MerchantApplicationScreen extends StatefulWidget {
  const MerchantApplicationScreen({super.key});

  @override
  State<MerchantApplicationScreen> createState() => _MerchantApplicationScreenState();
}

class _MerchantApplicationScreenState extends State<MerchantApplicationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isBuySelected = true;
  bool _isAddAdvertBuySelected = true;
  int _floatingValue = 0;
  String _selectedPaymentMethod = 'Bank Transfer (India)';
  String _selectedCountry = 'India (+91)';
  bool _isPaymentMethodAdded = false;
  List<String> _availablePaymentModes = [];
  bool _isPaymentModesLoading = true;
  
  // Add adverts form variables
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _minLimitController = TextEditingController();
  final TextEditingController _maxLimitController = TextEditingController();
  bool _isLoading = false;
  String _selectedCoin = 'USDT_0';
  String _selectedFiat = 'INR';
  
  // API fetched data
  List<dynamic> _coins = [];
  List<dynamic> _fiatCurrencies = [];
  bool _isDataLoading = false;

  // Reset screen to initial state
  void _resetScreenToInitialState() {
    setState(() {
      // Reset form fields
      _amountController.clear();
      _priceController.clear();
      _minLimitController.clear();
      _maxLimitController.clear();
      
      // Reset selections to defaults
      _selectedCoin = 'USDT';
      _selectedFiat = 'INR';
      _floatingValue = 0;
      _isAddAdvertBuySelected = true; // Reset to Buy
      
      // Clear any error messages
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
  }

  // Calculate price based on floating value
  double _calculatePrice() {
    double basePrice = double.tryParse(_priceController.text) ?? 92.0; // Default base price
    return basePrice - (_floatingValue * 0.01 * basePrice); // Decrease price by floating percentage
  }

  // Show amount input dialog
  void _showAmountInputDialog() {
    final TextEditingController tempController = TextEditingController(text: _amountController.text);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text('Enter Amount', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: tempController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Enter amount',
              hintStyle: TextStyle(color: Color(0xFF8E8E93)),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF84BD00)),
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _amountController.text = tempController.text;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Done', style: TextStyle(color: Color(0xFF84BD00))),
            ),
          ],
        );
      },
    );
  }

  Future<void> _refreshCoinsAndFiat() async {
    await _fetchCoinsAndFiat();
  }

  final List<Map<String, String>> _countries = [
    {'name': 'Afghanistan', 'code': '+93'},
    {'name': 'Albania', 'code': '+355'},
    {'name': 'Algeria', 'code': '+213'},
    {'name': 'American Samoa', 'code': '+1-684'},
    {'name': 'Andorra', 'code': '+376'},
    {'name': 'Angola', 'code': '+244'},
    {'name': 'Anguilla', 'code': '+1-264'},
    {'name': 'Antarctica', 'code': '+672'},
    {'name': 'Antigua and Barbuda', 'code': '+1-268'},
    {'name': 'Argentina', 'code': '+54'},
    {'name': 'Armenia', 'code': '+374'},
    {'name': 'Aruba', 'code': '+297'},
    {'name': 'Australia', 'code': '+61'},
    {'name': 'Austria', 'code': '+43'},
    {'name': 'Azerbaijan', 'code': '+994'},
    {'name': 'Bahamas', 'code': '+1-242'},
    {'name': 'Bahrain', 'code': '+973'},
    {'name': 'Bangladesh', 'code': '+880'},
    {'name': 'Barbados', 'code': '+1-246'},
    {'name': 'Belarus', 'code': '+375'},
    {'name': 'Belgium', 'code': '+32'},
    {'name': 'Belize', 'code': '+501'},
    {'name': 'Benin', 'code': '+229'},
    {'name': 'Bermuda', 'code': '+1-441'},
    {'name': 'Bhutan', 'code': '+975'},
    {'name': 'Bolivia', 'code': '+591'},
    {'name': 'Bosnia and Herzegovina', 'code': '+387'},
    {'name': 'Botswana', 'code': '+267'},
    {'name': 'Brazil', 'code': '+55'},
    {'name': 'British Indian Ocean Territory', 'code': '+246'},
    {'name': 'British Virgin Islands', 'code': '+1-284'},
    {'name': 'Brunei', 'code': '+673'},
    {'name': 'Bulgaria', 'code': '+359'},
    {'name': 'Burkina Faso', 'code': '+226'},
    {'name': 'Burundi', 'code': '+257'},
    {'name': 'Cambodia', 'code': '+855'},
    {'name': 'Cameroon', 'code': '+237'},
    {'name': 'Canada', 'code': '+1'},
    {'name': 'Cape Verde', 'code': '+238'},
    {'name': 'Cayman Islands', 'code': '+1-345'},
    {'name': 'Central African Republic', 'code': '+236'},
    {'name': 'Chad', 'code': '+235'},
    {'name': 'Chile', 'code': '+56'},
    {'name': 'China', 'code': '+86'},
    {'name': 'Christmas Island', 'code': '+61'},
    {'name': 'Cocos Islands', 'code': '+61'},
    {'name': 'Colombia', 'code': '+57'},
    {'name': 'Comoros', 'code': '+269'},
    {'name': 'Cook Islands', 'code': '+682'},
    {'name': 'Costa Rica', 'code': '+506'},
    {'name': 'Croatia', 'code': '+385'},
    {'name': 'Cuba', 'code': '+53'},
    {'name': 'Curacao', 'code': '+599'},
    {'name': 'Cyprus', 'code': '+357'},
    {'name': 'Czech Republic', 'code': '+420'},
    {'name': 'Democratic Republic of the Congo', 'code': '+243'},
    {'name': 'Denmark', 'code': '+45'},
    {'name': 'Djibouti', 'code': '+253'},
    {'name': 'Dominica', 'code': '+1-767'},
    {'name': 'Dominican Republic', 'code': '+1-809'},
    {'name': 'East Timor', 'code': '+670'},
    {'name': 'Ecuador', 'code': '+593'},
    {'name': 'Egypt', 'code': '+20'},
    {'name': 'El Salvador', 'code': '+503'},
    {'name': 'Equatorial Guinea', 'code': '+240'},
    {'name': 'Eritrea', 'code': '+291'},
    {'name': 'Estonia', 'code': '+372'},
    {'name': 'Ethiopia', 'code': '+251'},
    {'name': 'Falkland Islands', 'code': '+500'},
    {'name': 'Faroe Islands', 'code': '+298'},
    {'name': 'Fiji', 'code': '+679'},
    {'name': 'Finland', 'code': '+358'},
    {'name': 'France', 'code': '+33'},
    {'name': 'French Polynesia', 'code': '+689'},
    {'name': 'Gabon', 'code': '+241'},
    {'name': 'Gambia', 'code': '+220'},
    {'name': 'Georgia', 'code': '+995'},
    {'name': 'Germany', 'code': '+49'},
    {'name': 'Ghana', 'code': '+233'},
    {'name': 'Gibraltar', 'code': '+350'},
    {'name': 'Greece', 'code': '+30'},
    {'name': 'Greenland', 'code': '+299'},
    {'name': 'Grenada', 'code': '+1-473'},
    {'name': 'Guam', 'code': '+1-671'},
    {'name': 'Guatemala', 'code': '+502'},
    {'name': 'Guernsey', 'code': '+44-1481'},
    {'name': 'Guinea', 'code': '+224'},
    {'name': 'Guinea-Bissau', 'code': '+245'},
    {'name': 'Guyana', 'code': '+592'},
    {'name': 'Haiti', 'code': '+509'},
    {'name': 'Honduras', 'code': '+504'},
    {'name': 'Hong Kong', 'code': '+852'},
    {'name': 'Hungary', 'code': '+36'},
    {'name': 'Iceland', 'code': '+354'},
    {'name': 'India', 'code': '+91'},
    {'name': 'Indonesia', 'code': '+62'},
    {'name': 'Iran', 'code': '+98'},
    {'name': 'Iraq', 'code': '+964'},
    {'name': 'Ireland', 'code': '+353'},
    {'name': 'Isle of Man', 'code': '+44-1624'},
    {'name': 'Israel', 'code': '+972'},
    {'name': 'Italy', 'code': '+39'},
    {'name': 'Ivory Coast', 'code': '+225'},
    {'name': 'Jamaica', 'code': '+1-876'},
    {'name': 'Japan', 'code': '+81'},
    {'name': 'Jersey', 'code': '+44-1534'},
    {'name': 'Jordan', 'code': '+962'},
    {'name': 'Kazakhstan', 'code': '+7'},
    {'name': 'Kenya', 'code': '+254'},
    {'name': 'Kiribati', 'code': '+686'},
    {'name': 'Kosovo', 'code': '+383'},
    {'name': 'Kuwait', 'code': '+965'},
    {'name': 'Kyrgyzstan', 'code': '+996'},
    {'name': 'Laos', 'code': '+856'},
    {'name': 'Latvia', 'code': '+371'},
    {'name': 'Lebanon', 'code': '+961'},
    {'name': 'Lesotho', 'code': '+266'},
    {'name': 'Liberia', 'code': '+231'},
    {'name': 'Libya', 'code': '+218'},
    {'name': 'Liechtenstein', 'code': '+423'},
    {'name': 'Lithuania', 'code': '+370'},
    {'name': 'Luxembourg', 'code': '+352'},
    {'name': 'Macao', 'code': '+853'},
    {'name': 'Macedonia', 'code': '+389'},
    {'name': 'Madagascar', 'code': '+261'},
    {'name': 'Malawi', 'code': '+265'},
    {'name': 'Malaysia', 'code': '+60'},
    {'name': 'Maldives', 'code': '+960'},
    {'name': 'Mali', 'code': '+223'},
    {'name': 'Malta', 'code': '+356'},
    {'name': 'Marshall Islands', 'code': '+692'},
    {'name': 'Mauritania', 'code': '+222'},
    {'name': 'Mauritius', 'code': '+230'},
    {'name': 'Mayotte', 'code': '+262'},
    {'name': 'Mexico', 'code': '+52'},
    {'name': 'Micronesia', 'code': '+691'},
    {'name': 'Moldova', 'code': '+373'},
    {'name': 'Monaco', 'code': '+377'},
    {'name': 'Mongolia', 'code': '+976'},
    {'name': 'Montenegro', 'code': '+382'},
    {'name': 'Montserrat', 'code': '+1-664'},
    {'name': 'Morocco', 'code': '+212'},
    {'name': 'Mozambique', 'code': '+258'},
    {'name': 'Myanmar', 'code': '+95'},
    {'name': 'Namibia', 'code': '+264'},
    {'name': 'Nauru', 'code': '+674'},
    {'name': 'Nepal', 'code': '+977'},
    {'name': 'Netherlands', 'code': '+31'},
    {'name': 'Netherlands Antilles', 'code': '+599'},
    {'name': 'New Caledonia', 'code': '+687'},
    {'name': 'New Zealand', 'code': '+64'},
    {'name': 'Nicaragua', 'code': '+505'},
    {'name': 'Niger', 'code': '+227'},
    {'name': 'Nigeria', 'code': '+234'},
    {'name': 'Niue', 'code': '+683'},
    {'name': 'North Korea', 'code': '+850'},
    {'name': 'Northern Mariana Islands', 'code': '+1-670'},
    {'name': 'Norway', 'code': '+47'},
    {'name': 'Oman', 'code': '+968'},
    {'name': 'Pakistan', 'code': '+92'},
    {'name': 'Palau', 'code': '+680'},
    {'name': 'Palestine', 'code': '+970'},
    {'name': 'Panama', 'code': '+507'},
    {'name': 'Papua New Guinea', 'code': '+675'},
    {'name': 'Paraguay', 'code': '+595'},
    {'name': 'Peru', 'code': '+51'},
    {'name': 'Philippines', 'code': '+63'},
    {'name': 'Pitcairn', 'code': '+64'},
    {'name': 'Poland', 'code': '+48'},
    {'name': 'Portugal', 'code': '+351'},
    {'name': 'Puerto Rico', 'code': '+1-787'},
    {'name': 'Qatar', 'code': '+974'},
    {'name': 'Republic of the Congo', 'code': '+242'},
    {'name': 'Reunion', 'code': '+262'},
    {'name': 'Romania', 'code': '+40'},
    {'name': 'Russia', 'code': '+7'},
    {'name': 'Rwanda', 'code': '+250'},
    {'name': 'Saint Barthelemy', 'code': '+590'},
    {'name': 'Saint Helena', 'code': '+290'},
    {'name': 'Saint Kitts and Nevis', 'code': '+1-869'},
    {'name': 'Saint Lucia', 'code': '+1-758'},
    {'name': 'Saint Martin', 'code': '+590'},
    {'name': 'Saint Pierre and Miquelon', 'code': '+508'},
    {'name': 'Saint Vincent and the Grenadines', 'code': '+1-784'},
    {'name': 'Samoa', 'code': '+685'},
    {'name': 'San Marino', 'code': '+378'},
    {'name': 'Sao Tome and Principe', 'code': '+239'},
    {'name': 'Saudi Arabia', 'code': '+966'},
    {'name': 'Senegal', 'code': '+221'},
    {'name': 'Serbia', 'code': '+381'},
    {'name': 'Seychelles', 'code': '+248'},
    {'name': 'Sierra Leone', 'code': '+232'},
    {'name': 'Singapore', 'code': '+65'},
    {'name': 'Sint Maarten', 'code': '+1-721'},
    {'name': 'Slovakia', 'code': '+421'},
    {'name': 'Slovenia', 'code': '+386'},
    {'name': 'Solomon Islands', 'code': '+677'},
    {'name': 'Somalia', 'code': '+252'},
    {'name': 'South Africa', 'code': '+27'},
    {'name': 'South Korea', 'code': '+82'},
    {'name': 'South Sudan', 'code': '+211'},
    {'name': 'Spain', 'code': '+34'},
    {'name': 'Sri Lanka', 'code': '+94'},
    {'name': 'Sudan', 'code': '+249'},
    {'name': 'Suriname', 'code': '+597'},
    {'name': 'Svalbard and Jan Mayen', 'code': '+47'},
    {'name': 'Swaziland', 'code': '+268'},
    {'name': 'Sweden', 'code': '+46'},
    {'name': 'Switzerland', 'code': '+41'},
    {'name': 'Syria', 'code': '+963'},
    {'name': 'Taiwan', 'code': '+886'},
    {'name': 'Tajikistan', 'code': '+992'},
    {'name': 'Tanzania', 'code': '+255'},
    {'name': 'Thailand', 'code': '+66'},
    {'name': 'Togo', 'code': '+228'},
    {'name': 'Tokelau', 'code': '+690'},
    {'name': 'Tonga', 'code': '+676'},
    {'name': 'Trinidad and Tobago', 'code': '+1-868'},
    {'name': 'Tunisia', 'code': '+216'},
    {'name': 'Turkey', 'code': '+90'},
    {'name': 'Turkmenistan', 'code': '+993'},
    {'name': 'Turks and Caicos Islands', 'code': '+1-649'},
    {'name': 'Tuvalu', 'code': '+688'},
    {'name': 'U.S. Virgin Islands', 'code': '+1-340'},
    {'name': 'UAE', 'code': '+971'},
    {'name': 'Uganda', 'code': '+256'},
    {'name': 'UK', 'code': '+44'},
    {'name': 'Ukraine', 'code': '+380'},
    {'name': 'Uruguay', 'code': '+598'},
    {'name': 'USA', 'code': '+1'},
    {'name': 'Uzbekistan', 'code': '+998'},
    {'name': 'Vanuatu', 'code': '+678'},
    {'name': 'Vatican', 'code': '+379'},
    {'name': 'Venezuela', 'code': '+58'},
    {'name': 'Vietnam', 'code': '+84'},
    {'name': 'Wallis and Futuna', 'code': '+681'},
    {'name': 'Western Sahara', 'code': '+212'},
    {'name': 'Yemen', 'code': '+967'},
    {'name': 'Zambia', 'code': '+260'},
    {'name': 'Zimbabwe', 'code': '+263'},
  ];

  // API fetched data for My Adverts
  List<dynamic> _myAdverts = [];
  bool _isMyAdvertsLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchCoinsAndFiat();
    _fetchPaymentModes();
    _fetchMyAdverts();

    // Listen to tab changes to refresh my adverts when tab is selected
    _tabController.addListener(() {
      if (_tabController.index == 0) {
        _fetchMyAdverts();
      }
    });
  }

  Future<void> _fetchMyAdverts() async {
    setState(() => _isMyAdvertsLoading = true);
    try {
      final adverts = await P2PService.getMyAdvertisements();
      if (mounted) {
        setState(() {
          _myAdverts = adverts;
          _isMyAdvertsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching my adverts: $e');
      if (mounted) {
        setState(() => _isMyAdvertsLoading = false);
      }
    }
  }

  List<dynamic> get _filteredAdverts {
    final type = _isBuySelected ? 'buy' : 'sell';
    return _myAdverts.where((ad) {
      final adType = ad['type']?.toString().toLowerCase() ?? '';
      return adType == type;
    }).toList();
  }

  Future<void> _fetchCoinsAndFiat() async {
    setState(() => _isDataLoading = true);
    
    try {
      final coins = await P2PService.getP2PCoins();
      final fiatCurrencies = await P2PService.getFiatCurrencies();
      
      setState(() {
        _coins = coins.isNotEmpty ? coins : [
          {'symbol': 'USDT', 'name': 'Tether'},
          {'symbol': 'BTC', 'name': 'Bitcoin'},
          {'symbol': 'ETH', 'name': 'Ethereum'},
        ];
        
        // Ensure unique symbols to avoid dropdown error
        final uniqueCoins = <String, Map<String, dynamic>>{};
        for (var coin in _coins) {
          final symbol = coin['symbol']?.toString() ?? coin['name']?.toString() ?? 'Unknown';
          if (!uniqueCoins.containsKey(symbol)) {
            uniqueCoins[symbol] = coin;
          }
        }
        _coins = uniqueCoins.values.toList();
        
        _fiatCurrencies = fiatCurrencies.isNotEmpty ? fiatCurrencies : [
          {'code': 'INR', 'name': 'Indian Rupee'},
          {'code': 'USD', 'name': 'US Dollar'},
          {'code': 'EUR', 'name': 'Euro'},
        ];
        _isDataLoading = false;
        
        // Set defaults if API returns data and current selection is not in the list
        if (_coins.isNotEmpty && !_coins.any((coin) => coin['symbol'] == _selectedCoin || coin['name'] == _selectedCoin)) {
          final firstCoin = _coins.first;
          final coinSymbol = firstCoin['symbol']?.toString() ?? firstCoin['name']?.toString() ?? 'USDT';
          _selectedCoin = '${coinSymbol}_0'; // Use unique format
        }
        
        if (_fiatCurrencies.isNotEmpty && !_fiatCurrencies.any((fiat) => fiat['code'] == _selectedFiat || fiat['symbol'] == _selectedFiat)) {
          _selectedFiat = _fiatCurrencies.first['code'] ?? _fiatCurrencies.first['symbol'] ?? 'INR';
        }
      });
    } catch (e) {
      debugPrint('Error fetching coins and fiat: $e');
      setState(() {
        // Fallback to default data
        _coins = [
          {'symbol': 'USDT', 'name': 'Tether'},
          {'symbol': 'BTC', 'name': 'Bitcoin'},
          {'symbol': 'ETH', 'name': 'Ethereum'},
        ];
        
        // Ensure unique symbols in fallback data too
        final uniqueCoins = <String, Map<String, dynamic>>{};
        for (var coin in _coins) {
          final symbol = coin['symbol']?.toString() ?? coin['name']?.toString() ?? 'Unknown';
          if (!uniqueCoins.containsKey(symbol)) {
            uniqueCoins[symbol] = coin;
          }
        }
        _coins = uniqueCoins.values.toList();
        
        // Set default selection in unique format
        if (_coins.isNotEmpty) {
          final firstCoin = _coins.first;
          final coinSymbol = firstCoin['symbol']?.toString() ?? firstCoin['name']?.toString() ?? 'USDT';
          _selectedCoin = '${coinSymbol}_0'; // Use unique format
        }
        
        _fiatCurrencies = [
          {'code': 'INR', 'name': 'Indian Rupee'},
          {'code': 'USD', 'name': 'US Dollar'},
          {'code': 'EUR', 'name': 'Euro'},
        ];
        _isDataLoading = false;
      });
    }
  }

  Future<void> _fetchPaymentModes() async {
    try {
      debugPrint('Fetching payment modes for country: ${_selectedCountry.split(' ')[0]}');
      
      // Extract country name without code
      final countryName = _selectedCountry.split(' ')[0];
      
      // For India, show both UPI and Bank
      if (countryName == 'India') {
        setState(() {
          _availablePaymentModes = ['Bank Transfer', 'UPI Payment'];
          _isPaymentModesLoading = false;
        });
        debugPrint('Available payment modes for India: $_availablePaymentModes');
        return;
      }
      
      // For other countries, always show Bank Transfer as minimum
      setState(() {
        _availablePaymentModes = ['Bank Transfer'];
        _isPaymentModesLoading = false;
      });
      
      // Try to get additional payment modes from API
      try {
        final response = await P2PService.getPaymentModes(country: countryName);
        
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
      debugPrint('Error in _fetchPaymentModes: $e');
      // Always ensure Bank Transfer is available
      setState(() {
        _availablePaymentModes = ['Bank Transfer'];
        _isPaymentModesLoading = false;
      });
      debugPrint('Using Bank Transfer fallback due to error: $_availablePaymentModes');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _priceController.dispose();
    _minLimitController.dispose();
    _maxLimitController.dispose();
    super.dispose();
  }

  Future<void> _createMerchantAdvertisement() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill amount field')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final adData = {
        "coin": _selectedCoin,
        "coinSymbol": _selectedCoin,
        "price": _calculatePrice(),
        "amount": double.tryParse(_amountController.text) ?? 0.0,
        "quantity": double.tryParse(_amountController.text) ?? 0.0,
        "payModes": [_selectedPaymentMethod],
        "type": _isAddAdvertBuySelected ? "buy" : "sell",
        "direction": _isAddAdvertBuySelected ? 1 : 2,
        "payTime": 15,
        "status": "active",
        // Add min/max limits for sell orders
        if (!_isAddAdvertBuySelected) ...{
          "min": double.tryParse(_minLimitController.text) ?? 0.0,
          "minOrder": double.tryParse(_minLimitController.text) ?? 0.0,
          "max": double.tryParse(_maxLimitController.text) ?? 0.0,
          "maxOrder": double.tryParse(_maxLimitController.text) ?? 0.0,
        },
        "floating": _floatingValue,
        "fiat": _selectedFiat,
        "currency": _selectedFiat,
      };

      debugPrint('Creating merchant advertisement with data: ${json.encode(adData)}');
      
      final success = await P2PService.createAdvertisement(adData);

      if (mounted) {
        setState(() => _isLoading = false);
        if (success['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_isAddAdvertBuySelected ? "Buy" : "Sell"} advertisement created successfully!'),
              backgroundColor: const Color(0xFF84BD00),
            ),
          );
          
          // Navigate to confirmation screen
          if (mounted) {
            debugPrint('Navigating to confirmation screen with data: ${json.encode(adData)}');
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ConfirmAdvertScreen(advertData: adData),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create advertisement'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Select Country',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: _countries.length,
                    itemBuilder: (context, index) {
                      final country = _countries[index];
                      final display = '${country['name']} (${country['code']})';
                      return ListTile(
                        title: Text(display, style: const TextStyle(color: Colors.white)),
                        onTap: () {
                          setState(() {
                            String oldCountry = _selectedCountry;
                            _selectedCountry = display;
                            
                            // Update payment method based on country
                            final countryName = display.split(' ')[0];
                            if (oldCountry.startsWith('India') != display.startsWith('India')) {
                              if (_selectedPaymentMethod == 'Bank Transfer (India)') {
                                _selectedPaymentMethod = 'Bank Transfer';
                              } else if (_selectedPaymentMethod == 'Bank Transfer') {
                                _selectedPaymentMethod = 'Bank Transfer (India)';
                              }
                            }
                            
                            // Reset payment method if it's not available for new country
                            if (!_availablePaymentModes.contains('UPI Payment') && _selectedPaymentMethod == 'UPI Payment') {
                              _selectedPaymentMethod = countryName == 'India' ? 'Bank Transfer (India)' : 'Bank Transfer';
                            }
                          });
                          
                          // Fetch payment modes for new country
                          _fetchPaymentModes();
                          
                          Navigator.pop(context);
                        },
                        trailing: _selectedCountry == display 
                          ? const Icon(Icons.check, color: Color(0xFF84BD00)) 
                          : null,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
        ),
        title: const Text('Merchant', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF84BD00),
            indicatorWeight: 2,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'My Adverts'),
              Tab(text: 'Add Adverts'),
              Tab(text: 'Add Payment Method'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyAdvertsTab(),
          _buildAddAdvertsTab(),
          _buildAddPaymentMethodTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildMyAdvertsTab() {
    final filteredAdverts = _filteredAdverts;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _buildToggleItem('Buy', _isBuySelected, () {
                        setState(() {
                          _isBuySelected = true;
                        });
                      }),
                      _buildToggleItem('Sell', !_isBuySelected, () {
                        setState(() {
                          _isBuySelected = false;
                        });
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _fetchMyAdverts,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isMyAdvertsLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Color(0xFF84BD00), strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isMyAdvertsLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF84BD00)),
              )
            : filteredAdverts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox, color: Colors.white38, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _isBuySelected ? 'No Buy adverts found' : 'No Sell adverts found',
                        style: const TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchMyAdverts,
                  color: const Color(0xFF84BD00),
                  backgroundColor: const Color(0xFF1C1C1E),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredAdverts.length,
                    itemBuilder: (context, index) {
                      final ad = filteredAdverts[index];
                      return _buildAdvertCardFromData(ad);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAddAdvertsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _openCreateAdScreen('buy'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF84BD00),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.black, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Buy Ad',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _openCreateAdScreen('sell'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.black, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Sell Ad',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Create New Advertisement',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _openCreateAdScreen(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateAdvertisementScreen(initialType: type),
      ),
    ).then((result) {
      // Refresh data when returning if ad was created
      if (result == true) {
        _fetchMyAdverts();
      }
    });
  }

  Widget _buildAddPaymentMethodTab() {
    if (_isPaymentMethodAdded) {
      return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Current Payment Mode', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 12),
                  // Show dynamic payment methods that were added
                  ..._availablePaymentModes.map((mode) {
                    if (mode == 'UPI Payment') {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildPaymentSummaryItem('UPI Payment', Colors.purple),
                      );
                    } else if (mode == 'Bank Transfer') {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildPaymentSummaryItem(
                          _selectedCountry.startsWith('India') ? 'Bank Transfer (India)' : 'Bank Transfer',
                          Colors.orange,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }).toList(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => setState(() => _isPaymentMethodAdded = false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF84BD00),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Edit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose your country', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 10),
                _buildCountryInput(_selectedCountry),
                const SizedBox(height: 12),
                if (_availablePaymentModes.isNotEmpty) ...[
                  Text(
                    'Available payment modes: ${_availablePaymentModes.join(", ")}',
                    style: const TextStyle(color: Color(0xFF84BD00), fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('Choose a payment method', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 12),
                if (_isPaymentModesLoading)
                  const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
                else
                  ..._availablePaymentModes.map((mode) {
                    if (mode == 'UPI Payment') {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildPaymentMethodItem('UPI Payment', Colors.purple, _selectedPaymentMethod == 'UPI Payment'),
                      );
                    } else if (mode == 'Bank Transfer') {
                      final bankLabel = _selectedCountry.startsWith('India') ? 'Bank Transfer (India)' : 'Bank Transfer';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildPaymentMethodItem(bankLabel, Colors.orange, _selectedPaymentMethod == bankLabel),
                      );
                    }
                    return const SizedBox.shrink();
                  }).toList(),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () async {
                bool? success;
                if (_selectedPaymentMethod == 'UPI Payment') {
                  success = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddUpiScreen(country: _selectedCountry)));
                } else if (_selectedPaymentMethod.startsWith('Bank Transfer')) {
                  success = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddBankAccountScreen(country: _selectedCountry)));
                }
                if (success == true) {
                  setState(() => _isPaymentMethodAdded = true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF84BD00),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Next', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSummaryItem(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 20,
            color: color,
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildCountryInput(String value) {
    return GestureDetector(
      onTap: _showCountryPicker,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16)),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodItem(String title, Color color, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 20,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? Colors.white : Colors.white54,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddAdvertToggleItem(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1C1C1E) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFormDropdown(String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(hint, style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 24),
        ],
      ),
    );
  }

  Widget _buildFloatingCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => setState(() { if(_floatingValue > 0) _floatingValue--; }),
            icon: const Icon(Icons.remove, color: Colors.white70, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          Text('$_floatingValue', style: const TextStyle(color: Colors.white, fontSize: 16)),
          IconButton(
            onPressed: () => setState(() => _floatingValue++),
            icon: const Icon(Icons.add, color: Colors.white70, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceColumn(String label, String value, {CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start}) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildToggleItem(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          height: 32,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2C2C2E) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white54,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdvertCardFromData(Map<String, dynamic> ad) {
    // Parse data from API response
    final date = ad['createdAt'] != null
      ? _formatDate(ad['createdAt'].toString())
      : 'N/A';
    final posted = ad['createdAt'] != null
      ? _timeAgo(ad['createdAt'].toString())
      : '';

    final status = ad['status']?.toString() ?? 'active';
    final isLive = status.toLowerCase() == 'active' || status.toLowerCase() == 'live';

    final coin = ad['coin']?.toString() ?? 'USDT';
    final amount = ad['amount']?.toString() ?? ad['quantity']?.toString() ?? '0';
    final fiat = ad['fiat']?.toString() ?? 'INR';

    final min = ad['min']?.toString() ?? '0';
    final max = ad['max']?.toString() ?? '0';
    final limit = '$fiat $min - $fiat $max';

    final tradeQty = '$amount $coin';

    // Parse payment modes
    final paymentModes = ad['paymentMode'] ?? ad['paymentMethods'] ?? [];
    final payments = <Map<String, dynamic>>[];
    if (paymentModes is List) {
      for (var mode in paymentModes) {
        final name = mode.toString();
        Color color = Colors.blue;
        if (name.toLowerCase().contains('upi')) color = Colors.purple;
        else if (name.toLowerCase().contains('bank')) color = Colors.orange;
        else if (name.toLowerCase().contains('paytm')) color = Colors.blue;
        else if (name.toLowerCase().contains('gpay')) color = Colors.green;
        payments.add({'name': name, 'color': color});
      }
    }
    if (payments.isEmpty) {
      payments.add({'name': 'Bank Transfer', 'color': Colors.orange});
    }

    return _buildAdvertCard(
      date: date,
      posted: posted,
      status: isLive ? 'Live' : 'Completed',
      amount: '$amount $coin',
      currency: fiat,
      limit: limit,
      tradeQty: tradeQty,
      payments: payments,
      isLive: isLive,
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day} ${_getMonthName(date.month)} ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _timeAgo(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 365) {
        return '${diff.inDays ~/ 365} year${diff.inDays ~/ 365 > 1 ? 's' : ''} ago';
      } else if (diff.inDays > 30) {
        return '${diff.inDays ~/ 30} month${diff.inDays ~/ 30 > 1 ? 's' : ''} ago';
      } else if (diff.inDays > 0) {
        return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes} min${diff.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildAdvertCard({
    required String date,
    required String posted,
    required String status,
    required String amount,
    required String currency,
    required String limit,
    required String tradeQty,
    required List<Map<String, dynamic>> payments,
    required bool isLive,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10, width: 1.0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  Text('Posted: $posted', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
              Row(
                children: [
                  Text('Status: $status', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(width: 6),
                  Icon(Icons.radio_button_checked, color: isLive ? const Color(0xFF84BD00) : Colors.white24, size: 16),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(amount, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Text('/$currency', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: payments.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 2,
                        height: 12,
                        color: p['color'] as Color,
                      ),
                      const SizedBox(width: 6),
                      Text(p['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ],
                  ),
                )).toList(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Limit: $limit', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  Text('Trade Qty: $tradeQty', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
              if (isLive)
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Deactivate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                )
              else
                SizedBox(
                  height: 32,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('View Stats', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: const Color(0xFF1C1C1E),
      ),
      child: BottomNavigationBar(
        backgroundColor: const Color(0xFF1C1C1E),
        selectedItemColor: const Color(0xFF84BD00),
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        currentIndex: 2,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const P2PTradingScreen()));
              break;
            case 1:
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const OrderHistoryScreen()));
              break;
            case 2:
              // Already on Merchant
              break;
            case 3:
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const UserProfileScreen()));
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.swap_horiz, size: 22), label: 'P2P'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt, size: 22), label: 'Order'),
          BottomNavigationBarItem(icon: Icon(Icons.storefront, size: 22), label: 'Merchant'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline, size: 22), label: 'Profile'),
        ],
      ),
    );
  }
}
