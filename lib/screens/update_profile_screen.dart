import 'package:flutter/material.dart';
import '../services/user_service.dart';

class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({super.key});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _userIdController = TextEditingController();
  final _mobileController = TextEditingController();
  final UserService _userService = UserService();
  bool _isLoading = false;
  String _selectedCountryCode = '+91';

  // Country, State, City data
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _states = [];
  List<Map<String, dynamic>> _cities = [];
  String? _selectedCountryId;
  String? _selectedCountryName;
  String? _selectedStateId;
  String? _selectedStateName;
  String? _selectedCityId;
  String? _selectedCityName;
  bool _isLoadingCountries = false;
  bool _isLoadingStates = false;
  bool _isLoadingCities = false;

  final List<Map<String, String>> _countryCodes = [
    {'code': '+91', 'country': 'India'},
    {'code': '+1', 'country': 'USA'},
    {'code': '+44', 'country': 'UK'},
    {'code': '+61', 'country': 'Australia'},
    {'code': '+86', 'country': 'China'},
    {'code': '+81', 'country': 'Japan'},
    {'code': '+49', 'country': 'Germany'},
    {'code': '+33', 'country': 'France'},
    {'code': '+971', 'country': 'UAE'},
    {'code': '+65', 'country': 'Singapore'},
    {'code': '+82', 'country': 'South Korea'},
    {'code': '+7', 'country': 'Russia'},
    {'code': '+39', 'country': 'Italy'},
    {'code': '+34', 'country': 'Spain'},
    {'code': '+55', 'country': 'Brazil'},
  ];
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadCountries();
  }

  Future<void> _loadUserData() async {
    await _userService.initUserData();
    if (mounted) {
      setState(() {
        _nameController.text = _userService.userName ?? '';
        _emailController.text = _userService.userEmail ?? '';
        _userIdController.text = _userService.userId ?? '';
        _mobileController.text = _userService.userPhone ?? '';
        // Store saved location IDs if available
        if (_userService.userCountry != null && _userService.userCountry!.isNotEmpty) {
          _selectedCountryId = _userService.userCountry;
        }
        if (_userService.userState != null && _userService.userState!.isNotEmpty) {
          _selectedStateId = _userService.userState;
        }
        if (_userService.userCity != null && _userService.userCity!.isNotEmpty) {
          _selectedCityId = _userService.userCity;
        }
        if (_userService.userCountryCode != null && _userService.userCountryCode!.isNotEmpty) {
          _selectedCountryCode = _userService.userCountryCode!;
        }
      });
    }
  }

  Future<void> _loadCountries() async {
    setState(() => _isLoadingCountries = true);
    debugPrint('Loading countries...');
    final result = await _userService.getCountries();
    debugPrint('Countries result: $result');
    if (mounted) {
      setState(() {
        _isLoadingCountries = false;
        if (result['success'] == true && result['data'] is List) {
          _countries = List<Map<String, dynamic>>.from(result['data']);
          debugPrint('Loaded ${_countries.length} countries');
          debugPrint('Countries data: $_countries');
          // If we have a saved country ID, find its name
          if (_selectedCountryId != null) {
            final country = _countries.firstWhere(
              (c) => c['id']?.toString() == _selectedCountryId || c['_id']?.toString() == _selectedCountryId,
              orElse: () => {},
            );
            if (country.isNotEmpty) {
              _selectedCountryName = country['name']?.toString();
              // Auto-sync country code when country is loaded from saved data
              _syncCountryCodeWithCountry(_selectedCountryName!);
              // Load states for this country
              _loadStates(_selectedCountryId!);
            }
          }
        } else {
          debugPrint('Failed to load countries: ${result['error']}');
        }
      });
    }
  }

  Future<void> _loadStates(String countryId) async {
    setState(() {
      _isLoadingStates = true;
      _states = [];
      _cities = [];
      _selectedStateId = null;
      _selectedStateName = null;
      _selectedCityId = null;
      _selectedCityName = null;
    });
    
    // Check if countryId is valid
    if (countryId.isEmpty) {
      debugPrint('ERROR: countryId is empty!');
      setState(() => _isLoadingStates = false);
      return;
    }
    
    debugPrint('Loading states for countryId: "$countryId"');
    final result = await _userService.getStates(countryId);
    debugPrint('States load result: $result');
    if (mounted) {
      setState(() {
        _isLoadingStates = false;
        if (result['success'] == true && result['data'] is List) {
          _states = List<Map<String, dynamic>>.from(result['data']);
          debugPrint('Loaded ${_states.length} states');
          debugPrint('States data: $_states');
          // If we have a saved state ID, find its name
          if (_selectedStateId != null) {
            final state = _states.firstWhere(
              (s) => s['id']?.toString() == _selectedStateId || s['_id']?.toString() == _selectedStateId,
              orElse: () => {},
            );
            if (state.isNotEmpty) {
              _selectedStateName = state['name']?.toString();
              // Load cities for this state
              _loadCities(_selectedCountryId!, _selectedStateId!);
            }
          }
        } else {
          debugPrint('Failed to load states: ${result['error']}');
          _states = []; // Ensure empty list on failure
        }
      });
    }
  }

  Future<void> _loadCities(String countryId, String stateId) async {
    setState(() {
      _isLoadingCities = true;
      _cities = [];
      _selectedCityId = null;
      _selectedCityName = null;
    });
    final result = await _userService.getCities(countryId, stateId);
    if (mounted) {
      setState(() {
        _isLoadingCities = false;
        if (result['success'] == true && result['data'] is List) {
          _cities = List<Map<String, dynamic>>.from(result['data']);
          // If we have a saved city ID, find its name
          if (_selectedCityId != null) {
            final city = _cities.firstWhere(
              (c) => c['id']?.toString() == _selectedCityId || c['_id']?.toString() == _selectedCityId,
              orElse: () => {},
            );
            if (city.isNotEmpty) {
              _selectedCityName = city['name']?.toString();
            }
          }
        }
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty || _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name and email are required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Only send non-empty values to avoid server errors
      final result = await _userService.updateUserProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        mobile: _mobileController.text.trim().isNotEmpty ? _mobileController.text.trim() : null,
        countryCode: _selectedCountryCode.isNotEmpty ? _selectedCountryCode : null,
        countryId: _selectedCountryId,
        state: _selectedStateId,
        city: _selectedCityId,
      );

      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Profile updated successfully'),
            backgroundColor: const Color(0xFF84BD00),
          ),
        );
        Navigator.pop(context);
      } else {
        // Show detailed error message
        final errorMsg = result['error'] ?? 'Failed to update profile';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
        title: const Text('Update Profile', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldLabel('Name'),
            _buildTextField(_nameController, 'Enter Name'),
            const SizedBox(height: 20),
            
            _buildFieldLabel('Email'),
            _buildTextField(_emailController, 'Enter Email ID', readOnly: true),
            const SizedBox(height: 20),
            
            _buildFieldLabel('User ID'),
            _buildTextField(_userIdController, '', readOnly: true, suffixIcon: Icons.copy),
            const SizedBox(height: 20),
            
            _buildFieldLabel('Mobile Number'),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    // Force focus removal before opening picker
                    FocusManager.instance.primaryFocus?.unfocus();
                    FocusScope.of(context).requestFocus(FocusNode());
                    _showCountryCodePicker();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(_selectedCountryCode, style: const TextStyle(color: Colors.white)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _buildTextField(_mobileController, 'Enter Mobile Number')),
              ],
            ),
            const SizedBox(height: 20),

            _buildFieldLabel('Country'),
            _buildDropdownField(
              _selectedCountryName ?? 'Select Country',
              _isLoadingCountries ? null : _showCountryPicker,
              isLoading: _isLoadingCountries,
            ),
            const SizedBox(height: 20),

            _buildFieldLabel('State'),
            _buildDropdownField(
              _selectedStateName ?? (_selectedCountryId != null ? 'Select State' : 'Select Country First'),
              (_isLoadingStates || _selectedCountryId == null) ? null : _showStatePicker,
              isLoading: _isLoadingStates,
            ),
            const SizedBox(height: 20),

            _buildFieldLabel('City'),
            _buildDropdownField(
              _selectedCityName ?? (_selectedStateId != null ? 'Select City' : 'Select State First'),
              (_isLoadingCities || _selectedStateId == null) ? null : _showCityPicker,
              isLoading: _isLoadingCities,
            ),
            const SizedBox(height: 40),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF84BD00),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: const Color(0xFF84BD00),
                          ),
                        )
                      : const Text('Update Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool readOnly = false, IconData? suffixIcon}) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: const Color(0xFF1C1C1E),
        suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: Colors.white54, size: 18) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDropdownField(String value, VoidCallback? onTap, {bool isLoading = false}) {
    return GestureDetector(
      onTap: () {
        // Aggressively force focus removal and hide keyboard
        FocusManager.instance.primaryFocus?.unfocus();
        FocusScope.of(context).requestFocus(FocusNode());
        if (onTap != null) onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value, style: const TextStyle(color: Colors.white38, fontSize: 15)),
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF84BD00),
                ),
              )
            else
              const Icon(Icons.arrow_drop_down, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  void _showCountryPicker() {
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).requestFocus(FocusNode());
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Select Country',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _countries.length,
                  itemBuilder: (context, index) {
                    final country = _countries[index];
                    debugPrint('Country $index: $country');
                    // Try all possible ID fields
                    String countryId = '';
                    if (country['id'] != null) {
                      countryId = country['id'].toString();
                    } else if (country['_id'] != null) {
                      countryId = country['_id'].toString();
                    } else if (country['code'] != null) {
                      countryId = country['code'].toString();
                    } else if (country['iso'] != null) {
                      countryId = country['iso'].toString();
                    } else if (country['country_id'] != null) {
                      countryId = country['country_id'].toString();
                    }
                    
                    final countryName = country['name']?.toString() ?? '';
                    debugPrint('Extracted countryId: "$countryId", name: $countryName');
                    final isSelected = countryId == _selectedCountryId;
                    return ListTile(
                      onTap: () {
                        if (countryId.isEmpty) {
                          debugPrint('ERROR: Cannot select country with empty ID!');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invalid country data')),
                          );
                          return;
                        }
                        debugPrint('Selected country: $countryName with ID: $countryId');
                        setState(() {
                          _selectedCountryId = countryId;
                          _selectedCountryName = countryName;
                          // Auto-sync country code when country is selected
                          _syncCountryCodeWithCountry(countryName);
                        });
                        Navigator.pop(context);
                        // Load states for selected country
                        _loadStates(countryId);
                      },
                      title: Text(
                        countryName,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF84BD00) : Colors.white,
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Color(0xFF84BD00))
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showStatePicker() {
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).requestFocus(FocusNode());
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Select State',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoadingStates
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF84BD00),
                      ),
                    )
                  : _states.isEmpty
                    ? const Center(
                        child: Text(
                          'No states found',
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _states.length,
                        itemBuilder: (context, index) {
                          final state = _states[index];
                          debugPrint('State $index: $state');
                          final stateId = state['_id']?.toString() ?? state['id']?.toString() ?? '';
                          final stateName = state['name']?.toString() ?? '';
                          debugPrint('State extracted - id: $stateId, name: $stateName');
                          final isSelected = stateId == _selectedStateId;
                          return ListTile(
                            onTap: () {
                              setState(() {
                                _selectedStateId = stateId;
                                _selectedStateName = stateName;
                              });
                              Navigator.pop(context);
                              // Load cities for selected state
                              if (_selectedCountryId != null) {
                                _loadCities(_selectedCountryId!, stateId);
                              }
                            },
                            title: Text(
                              stateName.isNotEmpty ? stateName : 'Unknown',
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF84BD00) : Colors.white,
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check, color: Color(0xFF84BD00))
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCityPicker() {
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).requestFocus(FocusNode());
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Select City',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _cities.length,
                  itemBuilder: (context, index) {
                    final city = _cities[index];
                    final cityId = city['_id']?.toString() ?? city['id']?.toString() ?? '';
                    final cityName = city['name']?.toString() ?? '';
                    final isSelected = cityId == _selectedCityId;
                    return ListTile(
                      onTap: () {
                        setState(() {
                          _selectedCityId = cityId;
                          _selectedCityName = cityName;
                        });
                        Navigator.pop(context);
                      },
                      title: Text(
                        cityName,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF84BD00) : Colors.white,
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Color(0xFF84BD00))
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _syncCountryCodeWithCountry(String countryName) {
    // Enhanced country code mapping with more countries and API variations
    final countryMapping = {
      // Major countries with multiple name variations
      'India': '+91',
      'United States': '+1',
      'USA': '+1',
      'United States of America': '+1',
      'UK': '+44',
      'United Kingdom': '+44',
      'Australia': '+61',
      'China': '+86',
      'Japan': '+81',
      'Germany': '+49',
      'France': '+33',
      'UAE': '+971',
      'United Arab Emirates': '+971',
      'Singapore': '+65',
      'South Korea': '+82',
      'Korea': '+82',
      'Russia': '+7',
      'Italy': '+39',
      'Spain': '+34',
      'Brazil': '+55',
      
      // Additional countries
      'Canada': '+1',
      'Mexico': '+52',
      'Argentina': '+54',
      'Chile': '+56',
      'Peru': '+51',
      'Colombia': '+57',
      'Venezuela': '+58',
      
      // European countries
      'Netherlands': '+31',
      'Holland': '+31',
      'Belgium': '+32',
      'Switzerland': '+41',
      'Austria': '+43',
      'Sweden': '+46',
      'Norway': '+47',
      'Denmark': '+45',
      'Finland': '+358',
      'Poland': '+48',
      'Portugal': '+351',
      'Greece': '+30',
      'Ireland': '+353',
      'Iceland': '+354',
      
      // Asian countries
      'Pakistan': '+92',
      'Bangladesh': '+880',
      'Sri Lanka': '+94',
      'Nepal': '+977',
      'Malaysia': '+60',
      'Thailand': '+66',
      'Vietnam': '+84',
      'Philippines': '+63',
      'Indonesia': '+62',
      'Hong Kong': '+852',
      'Taiwan': '+886',
      
      // Middle East
      'Saudi Arabia': '+966',
      'Qatar': '+974',
      'Kuwait': '+965',
      'Bahrain': '+973',
      'Oman': '+968',
      'Israel': '+972',
      'Turkey': '+90',
      
      // African countries
      'South Africa': '+27',
      'Egypt': '+20',
      'Nigeria': '+234',
      'Kenya': '+254',
      'Morocco': '+212',
      'Tunisia': '+216',
      'Algeria': '+213',
      
      // Oceanic countries
      'New Zealand': '+64',
      
      // Misc
      'Iran': '+98',
      'Iraq': '+964',
      'Afghanistan': '+93',
    };
    
    // Try exact match first
    String? countryCode = countryMapping[countryName];
    
    // If no exact match, try case-insensitive search
    if (countryCode == null) {
      for (String key in countryMapping.keys) {
        if (key.toLowerCase() == countryName.toLowerCase()) {
          countryCode = countryMapping[key];
          break;
        }
      }
    }
    
    // If still no match, try partial matching (handle cases like "United States" vs "USA")
    if (countryCode == null) {
      final lowerCountryName = countryName.toLowerCase();
      if (lowerCountryName.contains('united states') || lowerCountryName.contains('usa')) {
        countryCode = '+1';
      } else if (lowerCountryName.contains('united kingdom') || lowerCountryName.contains('uk')) {
        countryCode = '+44';
      } else if (lowerCountryName.contains('united arab')) {
        countryCode = '+971';
      }
    }
    
    if (countryCode != null && countryCode != _selectedCountryCode) {
      setState(() {
        _selectedCountryCode = countryCode!;
      });
      debugPrint('Auto-synced country code: $countryCode for country: $countryName');
      
      // Show user feedback about country code change
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Country code updated to $countryCode'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF84BD00),
        ),
      );
    } else if (countryCode == null) {
      debugPrint('No country code found for: $countryName');
    }
  }

  void _showCountryCodePicker() {
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).requestFocus(FocusNode());
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Select Country Code',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _countryCodes.length,
                  itemBuilder: (context, index) {
                    final country = _countryCodes[index];
                    final isSelected = country['code'] == _selectedCountryCode;
                    return ListTile(
                      onTap: () {
                        setState(() {
                          _selectedCountryCode = country['code']!;
                        });
                        Navigator.pop(context);
                      },
                      leading: Text(
                        country['code']!,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF84BD00) : Colors.white,
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      title: Text(
                        country['country']!,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF84BD00) : Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Color(0xFF84BD00))
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
