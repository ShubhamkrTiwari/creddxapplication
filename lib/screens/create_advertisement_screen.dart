import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/p2p_service.dart';

class CreateAdvertisementScreen extends StatefulWidget {
  final String? initialType;

  const CreateAdvertisementScreen({super.key, this.initialType});

  @override
  State<CreateAdvertisementScreen> createState() => _CreateAdvertisementScreenState();
}

class _CreateAdvertisementScreenState extends State<CreateAdvertisementScreen> {
  int _currentStep = 1;
  bool _isBuySelected = true;
  String _selectedCoin = 'USDT';
  String _selectedFiat = 'INR';
  String _selectedCountry = 'India';
  List<dynamic> _coinList = [];
  bool _isLoading = false;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _priceController = TextEditingController(text: '120');
  final TextEditingController _minLimitController = TextEditingController();
  final TextEditingController _maxLimitController = TextEditingController();
  late TextEditingController _yourPriceController;

  int _paymentTime = 15;
  double _floating = 0;
  double _highestOrderPrice = 120;
  double _yourPrice = 120;

  final List<String> _availablePaymentMethods = ['Bank Transfer', 'UPI', 'PayTM', 'Google Pay', 'PhonePe', 'IMPS', 'NEFT'];
  List<String> _selectedPaymentMethods = [];

  final Map<String, String> _countries = {
    'India': 'India (INR)',
    'USA': 'USA (USD)',
    'UK': 'UK (GBP)',
    'UAE': 'UAE (AED)',
    'Singapore': 'Singapore (SGD)',
  };

  @override
  void initState() {
    super.initState();
    _yourPriceController = TextEditingController(text: '120');
    _isBuySelected = widget.initialType != 'sell';
    _loadCoins();
    _calculatePrice();
  }

  Future<void> _loadCoins() async {
    final coins = await P2PService.getP2PCoins();
    setState(() {
      _coinList = coins;
      if (_coinList.isNotEmpty && _coinList[0]['coinSymbol'] != null) {
        _selectedCoin = _coinList[0]['coinSymbol'];
      }
    });
  }

  void _calculatePrice() {
    final basePrice = double.tryParse(_priceController.text) ?? 120;
    setState(() {
      _yourPrice = basePrice + _floating;
      _highestOrderPrice = basePrice;
      _yourPriceController.text = _yourPrice.toInt().toString();
    });
  }

  void _updateFloatingFromYourPrice(String value) {
    final newYourPrice = double.tryParse(value) ?? _highestOrderPrice;
    setState(() {
      _floating = newYourPrice - _highestOrderPrice;
      _yourPrice = newYourPrice;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _priceController.dispose();
    _minLimitController.dispose();
    _maxLimitController.dispose();
    _yourPriceController.dispose();
    super.dispose();
  }

  Future<void> _createAdvertisement() async {
    if (_amountController.text.isEmpty) {
      _showError('Please enter total amount');
      return;
    }
    if (_selectedPaymentMethods.isEmpty) {
      _showError('Please add at least one payment method');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final adData = {
        'coin': _selectedCoin,
        'coinSymbol': _selectedCoin,
        'type': _isBuySelected ? 'buy' : 'sell',
        'direction': _isBuySelected ? 1 : 2,
        'amount': double.tryParse(_amountController.text) ?? 0.0,
        'quantity': double.tryParse(_amountController.text) ?? 0.0,
        'price': _yourPrice,
        'min': _minLimitController.text.isNotEmpty ? double.tryParse(_minLimitController.text) : null,
        'minOrder': _minLimitController.text.isNotEmpty ? double.tryParse(_minLimitController.text) : null,
        'max': _maxLimitController.text.isNotEmpty ? double.tryParse(_maxLimitController.text) : null,
        'maxOrder': _maxLimitController.text.isNotEmpty ? double.tryParse(_maxLimitController.text) : null,
        'payModes': _selectedPaymentMethods,
        'payTime': _paymentTime,
        'fiat': _selectedFiat,
        'currency': _selectedFiat,
        'floating': _floating,
        'country': _selectedCountry,
      };

      debugPrint('Creating advertisement: ${json.encode(adData)}');

      final result = await P2PService.createAdvertisement(adData);

      if (mounted) {
        setState(() => _isLoading = false);
        if (result['success'] == true) {
          _showSuccess('Advertisement posted successfully!');
          Navigator.pop(context, true);
        } else {
          _showError(result['error'] ?? 'Failed to create advertisement');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Error: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF84BD00)),
    );
  }

  void _nextStep() {
    if (_currentStep == 1) {
      setState(() => _currentStep = 2);
    }
  }

  void _backStep() {
    if (_currentStep == 2) {
      setState(() => _currentStep = 1);
    } else {
      Navigator.pop(context);
    }
  }

  void _addPaymentMethod() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Select Payment Method', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ..._availablePaymentMethods.map((method) {
                final isSelected = _selectedPaymentMethods.contains(method);
                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? const Color(0xFF84BD00) : Colors.grey,
                  ),
                  title: Text(method, style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedPaymentMethods.remove(method);
                      } else {
                        _selectedPaymentMethods.add(method);
                      }
                    });
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _backStep,
        ),
        title: const Text('Add Advert', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF84BD00)))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildTypeToggle(),
                const SizedBox(height: 32),
                if (_currentStep == 1) ...[
                  _buildStep1(),
                ] else ...[
                  _buildStep2(),
                ],
              ],
            ),
          ),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isBuySelected = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              decoration: BoxDecoration(
                color: _isBuySelected ? const Color(0xFF84BD00) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Buy',
                style: TextStyle(
                  color: _isBuySelected ? Colors.black : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _isBuySelected = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              decoration: BoxDecoration(
                color: !_isBuySelected ? const Color(0xFF84BD00) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Sell',
                style: TextStyle(
                  color: !_isBuySelected ? Colors.black : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Asset'),
        _buildDropdown(_selectedCoin, ['USDT', 'BTC', 'ETH'], (val) => setState(() => _selectedCoin = val)),
        const SizedBox(height: 20),
        
        _buildLabel('FIAT'),
        _buildDropdown(_countries[_selectedCountry]!, _countries.values.toList(), (val) {
          setState(() {
            _selectedCountry = _countries.entries.firstWhere((e) => e.value == val).key;
            _selectedFiat = _selectedCountry == 'India' ? 'INR' : 
                           _selectedCountry == 'USA' ? 'USD' :
                           _selectedCountry == 'UK' ? 'GBP' :
                           _selectedCountry == 'UAE' ? 'AED' : 'SGD';
          });
        }),
        const SizedBox(height: 20),
        
        _buildLabel('Floating'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1419),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2C2C2E)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _floating = (_floating - 1).clamp(-50, 50);
                    _calculatePrice();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.remove, color: Colors.white, size: 20),
                ),
              ),
              SizedBox(
                width: 80,
                child: TextField(
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  controller: TextEditingController(text: _floating.toInt().toString()),
                  onSubmitted: (value) {
                    final newValue = int.tryParse(value) ?? 0;
                    setState(() {
                      _floating = newValue.clamp(-50, 50).toDouble();
                      _calculatePrice();
                    });
                  },
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _floating = (_floating + 1).clamp(-50, 50);
                    _calculatePrice();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Highest order price', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
                const SizedBox(height: 4),
                Text('${_highestOrderPrice.toInt()} $_selectedFiat', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Your Price', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_floating != 0)
                      Text(
                        '${_highestOrderPrice.toInt()} ${_floating > 0 ? '+' : ''}${_floating.toInt()} = ',
                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        textAlign: TextAlign.end,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        controller: _yourPriceController,
                        onSubmitted: _updateFloatingFromYourPrice,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(_selectedFiat, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 40),
        
        _buildNextStepButton(),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Total Amount'),
        Row(
          children: [
            Expanded(
              child: _buildTextField(_amountController, '0', TextInputType.number),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('=', style: TextStyle(color: Colors.white54, fontSize: 18)),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1419),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2C2C2E)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _amountController.text.isEmpty 
                        ? '0' 
                        : ((double.tryParse(_amountController.text) ?? 0) * _yourPrice).toInt().toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    Text(_selectedFiat, style: const TextStyle(color: Colors.white54, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        _buildLabel('Order Limit'),
        Row(
          children: [
            Expanded(
              child: _buildTextField(_minLimitController, 'Min', TextInputType.number),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('=', style: TextStyle(color: Colors.white54, fontSize: 18)),
            ),
            Expanded(
              child: _buildTextField(_maxLimitController, 'Max', TextInputType.number),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLabel('Payment method'),
            GestureDetector(
              onTap: _addPaymentMethod,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF84BD00),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.black, size: 16),
                    SizedBox(width: 4),
                    Text('Add', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_selectedPaymentMethods.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedPaymentMethods.map((method) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C2E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF84BD00)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF84BD00),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(method, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _selectedPaymentMethods.remove(method)),
                      child: const Icon(Icons.close, color: Colors.white54, size: 16),
                    ),
                  ],
                ),
              );
            }).toList(),
          )
        else
          const Text('No payment methods selected', style: TextStyle(color: Colors.white38, fontSize: 14)),
        const SizedBox(height: 24),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLabel('Payment Time Limit'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<int>(
                value: _paymentTime,
                dropdownColor: const Color(0xFF1C1C1E),
                underline: const SizedBox(),
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
                style: const TextStyle(color: Colors.white),
                items: [15, 30, 45, 60].map((time) {
                  return DropdownMenuItem(
                    value: time,
                    child: Text('$time Minutes'),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _paymentTime = value ?? 15),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        _buildLabel('Select Country'),
        _buildDropdown(_countries[_selectedCountry]!, _countries.values.toList(), (val) {
          setState(() {
            _selectedCountry = _countries.entries.firstWhere((e) => e.value == val).key;
          });
        }),
        const SizedBox(height: 40),
        
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _backStep,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF84BD00), Color(0xFF5A8F00)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Text(
                    'Back',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: _createAdvertisement,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF84BD00), Color(0xFF5A8F00)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF84BD00).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Text(
                    'Post now',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13)),
    );
  }

  Widget _buildDropdown(String value, List<String> items, Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1419),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF1C1C1E),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          items: items.map((item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, TextInputType type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1419),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
          border: InputBorder.none,
          suffixText: hint == '0' ? _selectedCoin : (hint == 'Min' || hint == 'Max' ? _selectedFiat : ''),
          suffixStyle: const TextStyle(color: Colors.white54),
        ),
      ),
    );
  }

  Widget _buildNextStepButton() {
    return GestureDetector(
      onTap: _nextStep,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF84BD00), Color(0xFF5A8F00)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF84BD00).withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Text(
          'Next Step',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
