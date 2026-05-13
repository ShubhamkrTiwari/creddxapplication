import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    // Major countries
    {'code': '+93', 'country': 'Afghanistan'},
    {'code': '+355', 'country': 'Albania'},
    {'code': '+213', 'country': 'Algeria'},
    {'code': '+376', 'country': 'Andorra'},
    {'code': '+244', 'country': 'Angola'},
    {'code': '+54', 'country': 'Argentina'},
    {'code': '+374', 'country': 'Armenia'},
    {'code': '+61', 'country': 'Australia'},
    {'code': '+43', 'country': 'Austria'},
    {'code': '+994', 'country': 'Azerbaijan'},
    {'code': '+973', 'country': 'Bahrain'},
    {'code': '+880', 'country': 'Bangladesh'},
    {'code': '+375', 'country': 'Belarus'},
    {'code': '+32', 'country': 'Belgium'},
    {'code': '+501', 'country': 'Belize'},
    {'code': '+229', 'country': 'Benin'},
    {'code': '+975', 'country': 'Bhutan'},
    {'code': '+591', 'country': 'Bolivia'},
    {'code': '+387', 'country': 'Bosnia and Herzegovina'},
    {'code': '+267', 'country': 'Botswana'},
    {'code': '+55', 'country': 'Brazil'},
    {'code': '+673', 'country': 'Brunei'},
    {'code': '+359', 'country': 'Bulgaria'},
    {'code': '+226', 'country': 'Burkina Faso'},
    {'code': '+95', 'country': 'Burma (Myanmar)'},
    {'code': '+257', 'country': 'Burundi'},
    {'code': '+855', 'country': 'Cambodia'},
    {'code': '+237', 'country': 'Cameroon'},
    {'code': '+1', 'country': 'Canada'},
    {'code': '+238', 'country': 'Cape Verde'},
    {'code': '+236', 'country': 'Central African Republic'},
    {'code': '+235', 'country': 'Chad'},
    {'code': '+56', 'country': 'Chile'},
    {'code': '+86', 'country': 'China'},
    {'code': '+57', 'country': 'Colombia'},
    {'code': '+269', 'country': 'Comoros'},
    {'code': '+243', 'country': 'Congo'},
    {'code': '+242', 'country': 'Congo (Republic)'},
    {'code': '+506', 'country': 'Costa Rica'},
    {'code': '+385', 'country': 'Croatia'},
    {'code': '+53', 'country': 'Cuba'},
    {'code': '+357', 'country': 'Cyprus'},
    {'code': '+420', 'country': 'Czech Republic'},
    {'code': '+45', 'country': 'Denmark'},
    {'code': '+253', 'country': 'Djibouti'},
    {'code': '+593', 'country': 'Ecuador'},
    {'code': '+20', 'country': 'Egypt'},
    {'code': '+503', 'country': 'El Salvador'},
    {'code': '+240', 'country': 'Equatorial Guinea'},
    {'code': '+291', 'country': 'Eritrea'},
    {'code': '+372', 'country': 'Estonia'},
    {'code': '+251', 'country': 'Ethiopia'},
    {'code': '+679', 'country': 'Fiji'},
    {'code': '+358', 'country': 'Finland'},
    {'code': '+33', 'country': 'France'},
    {'code': '+241', 'country': 'Gabon'},
    {'code': '+220', 'country': 'Gambia'},
    {'code': '+995', 'country': 'Georgia'},
    {'code': '+49', 'country': 'Germany'},
    {'code': '+233', 'country': 'Ghana'},
    {'code': '+30', 'country': 'Greece'},
    {'code': '+502', 'country': 'Guatemala'},
    {'code': '+224', 'country': 'Guinea'},
    {'code': '+245', 'country': 'Guinea-Bissau'},
    {'code': '+592', 'country': 'Guyana'},
    {'code': '+509', 'country': 'Haiti'},
    {'code': '+504', 'country': 'Honduras'},
    {'code': '+852', 'country': 'Hong Kong'},
    {'code': '+36', 'country': 'Hungary'},
    {'code': '+354', 'country': 'Iceland'},
    {'code': '+91', 'country': 'India'},
    {'code': '+62', 'country': 'Indonesia'},
    {'code': '+98', 'country': 'Iran'},
    {'code': '+964', 'country': 'Iraq'},
    {'code': '+353', 'country': 'Ireland'},
    {'code': '+972', 'country': 'Israel'},
    {'code': '+39', 'country': 'Italy'},
    {'code': '+225', 'country': 'Ivory Coast'},
    {'code': '+81', 'country': 'Japan'},
    {'code': '+962', 'country': 'Jordan'},
    {'code': '+7', 'country': 'Kazakhstan'},
    {'code': '+254', 'country': 'Kenya'},
    {'code': '+686', 'country': 'Kiribati'},
    {'code': '+965', 'country': 'Kuwait'},
    {'code': '+996', 'country': 'Kyrgyzstan'},
    {'code': '+856', 'country': 'Laos'},
    {'code': '+371', 'country': 'Latvia'},
    {'code': '+961', 'country': 'Lebanon'},
    {'code': '+266', 'country': 'Lesotho'},
    {'code': '+231', 'country': 'Liberia'},
    {'code': '+218', 'country': 'Libya'},
    {'code': '+423', 'country': 'Liechtenstein'},
    {'code': '+370', 'country': 'Lithuania'},
    {'code': '+352', 'country': 'Luxembourg'},
    {'code': '+853', 'country': 'Macau'},
    {'code': '+389', 'country': 'Macedonia'},
    {'code': '+261', 'country': 'Madagascar'},
    {'code': '+265', 'country': 'Malawi'},
    {'code': '+60', 'country': 'Malaysia'},
    {'code': '+960', 'country': 'Maldives'},
    {'code': '+223', 'country': 'Mali'},
    {'code': '+356', 'country': 'Malta'},
    {'code': '+692', 'country': 'Marshall Islands'},
    {'code': '+222', 'country': 'Mauritania'},
    {'code': '+230', 'country': 'Mauritius'},
    {'code': '+52', 'country': 'Mexico'},
    {'code': '+691', 'country': 'Micronesia'},
    {'code': '+373', 'country': 'Moldova'},
    {'code': '+377', 'country': 'Monaco'},
    {'code': '+976', 'country': 'Mongolia'},
    {'code': '+382', 'country': 'Montenegro'},
    {'code': '+212', 'country': 'Morocco'},
    {'code': '+258', 'country': 'Mozambique'},
    {'code': '+95', 'country': 'Myanmar'},
    {'code': '+264', 'country': 'Namibia'},
    {'code': '+674', 'country': 'Nauru'},
    {'code': '+977', 'country': 'Nepal'},
    {'code': '+31', 'country': 'Netherlands'},
    {'code': '+64', 'country': 'New Zealand'},
    {'code': '+505', 'country': 'Nicaragua'},
    {'code': '+227', 'country': 'Niger'},
    {'code': '+234', 'country': 'Nigeria'},
    {'code': '+850', 'country': 'North Korea'},
    {'code': '+47', 'country': 'Norway'},
    {'code': '+968', 'country': 'Oman'},
    {'code': '+92', 'country': 'Pakistan'},
    {'code': '+680', 'country': 'Palau'},
    {'code': '+507', 'country': 'Panama'},
    {'code': '+675', 'country': 'Papua New Guinea'},
    {'code': '+595', 'country': 'Paraguay'},
    {'code': '+51', 'country': 'Peru'},
    {'code': '+63', 'country': 'Philippines'},
    {'code': '+48', 'country': 'Poland'},
    {'code': '+351', 'country': 'Portugal'},
    {'code': '+974', 'country': 'Qatar'},
    {'code': '+40', 'country': 'Romania'},
    {'code': '+7', 'country': 'Russia'},
    {'code': '+250', 'country': 'Rwanda'},
    {'code': '+378', 'country': 'San Marino'},
    {'code': '+239', 'country': 'Sao Tome and Principe'},
    {'code': '+966', 'country': 'Saudi Arabia'},
    {'code': '+221', 'country': 'Senegal'},
    {'code': '+381', 'country': 'Serbia'},
    {'code': '+248', 'country': 'Seychelles'},
    {'code': '+232', 'country': 'Sierra Leone'},
    {'code': '+65', 'country': 'Singapore'},
    {'code': '+421', 'country': 'Slovakia'},
    {'code': '+386', 'country': 'Slovenia'},
    {'code': '+677', 'country': 'Solomon Islands'},
    {'code': '+252', 'country': 'Somalia'},
    {'code': '+27', 'country': 'South Africa'},
    {'code': '+82', 'country': 'South Korea'},
    {'code': '+211', 'country': 'South Sudan'},
    {'code': '+34', 'country': 'Spain'},
    {'code': '+94', 'country': 'Sri Lanka'},
    {'code': '+249', 'country': 'Sudan'},
    {'code': '+597', 'country': 'Suriname'},
    {'code': '+268', 'country': 'Swaziland'},
    {'code': '+46', 'country': 'Sweden'},
    {'code': '+41', 'country': 'Switzerland'},
    {'code': '+963', 'country': 'Syria'},
    {'code': '+886', 'country': 'Taiwan'},
    {'code': '+992', 'country': 'Tajikistan'},
    {'code': '+255', 'country': 'Tanzania'},
    {'code': '+66', 'country': 'Thailand'},
    {'code': '+228', 'country': 'Togo'},
    {'code': '+676', 'country': 'Tonga'},
    {'code': '+216', 'country': 'Tunisia'},
    {'code': '+90', 'country': 'Turkey'},
    {'code': '+993', 'country': 'Turkmenistan'},
    {'code': '+256', 'country': 'Uganda'},
    {'code': '+380', 'country': 'Ukraine'},
    {'code': '+971', 'country': 'UAE'},
    {'code': '+44', 'country': 'UK'},
    {'code': '+598', 'country': 'Uruguay'},
    {'code': '+1', 'country': 'USA'},
    {'code': '+998', 'country': 'Uzbekistan'},
    {'code': '+58', 'country': 'Venezuela'},
    {'code': '+84', 'country': 'Vietnam'},
    {'code': '+967', 'country': 'Yemen'},
    {'code': '+260', 'country': 'Zambia'},
    {'code': '+263', 'country': 'Zimbabwe'},
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
          _countries = []; // Keep empty when API fails
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
          _states = []; // Keep empty when API fails
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
        } else {
          debugPrint('Failed to load cities: ${result['error']}');
          _cities = []; // Keep empty when API fails
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
        countryName: _selectedCountryName,
        state: _selectedStateId,
        stateName: _selectedStateName,
        city: _selectedCityId,
        cityName: _selectedCityName,
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
            _buildTextField(
              _nameController,
              'Enter Name',
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
              ],
            ),
            const SizedBox(height: 20),
            
            _buildFieldLabel('Email'),
            _buildTextField(_emailController, 'Enter Email ID', readOnly: true, suffixIcon: Icons.copy),
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
                Expanded(
                  child: _buildTextField(
                    _mobileController,
                    'Enter Mobile Number',
                    suffixIcon: Icons.copy,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
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

  Widget _buildTextField(TextEditingController controller, String hint, {bool readOnly = false, IconData? suffixIcon, List<TextInputFormatter>? inputFormatters}) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: const Color(0xFF1C1C1E),
        suffixIcon: suffixIcon != null
            ? GestureDetector(
                onTap: suffixIcon == Icons.copy
                    ? () async {
                        if (controller.text.isNotEmpty) {
                          await Clipboard.setData(ClipboardData(text: controller.text));
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied to clipboard!'),
                                backgroundColor: Color(0xFF84BD00),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      }
                    : null,
                child: Icon(suffixIcon, color: Colors.white54, size: 18),
              )
            : null,
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
    
    List<Map<String, dynamic>> filteredCountries = List.from(_countries);
    final TextEditingController searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
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
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search country...',
                        hintStyle: TextStyle(color: Colors.white24),
                        prefixIcon: Icon(Icons.search, color: Colors.white54),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          filteredCountries = _countries
                              .where((country) => country['name']
                                  .toString()
                                  .toLowerCase()
                                  .contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredCountries.isEmpty
                        ? const Center(
                            child: Text(
                              'No countries found',
                              style: TextStyle(color: Colors.white54, fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredCountries.length,
                            itemBuilder: (context, index) {
                              final country = filteredCountries[index];
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
                              final isSelected = countryId == _selectedCountryId;
                              return ListTile(
                                onTap: () {
                                  if (countryId.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Invalid country data')),
                                    );
                                    return;
                                  }
                                  setState(() {
                                    _selectedCountryId = countryId;
                                    _selectedCountryName = countryName;
                                    _syncCountryCodeWithCountry(countryName);
                                  });
                                  Navigator.pop(context);
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
          }
        );
      },
    );
  }

  void _showStatePicker() {
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).requestFocus(FocusNode());
    
    List<Map<String, dynamic>> filteredStates = List.from(_states);
    final TextEditingController searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
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
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search state...',
                        hintStyle: TextStyle(color: Colors.white24),
                        prefixIcon: Icon(Icons.search, color: Colors.white54),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          filteredStates = _states
                              .where((state) => state['name']
                                  .toString()
                                  .toLowerCase()
                                  .contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isLoadingStates
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF84BD00),
                          ),
                        )
                      : filteredStates.isEmpty
                        ? const Center(
                            child: Text(
                              'No states found',
                              style: TextStyle(color: Colors.white54, fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredStates.length,
                            itemBuilder: (context, index) {
                              final state = filteredStates[index];
                              final stateId = state['_id']?.toString() ?? state['id']?.toString() ?? '';
                              final stateName = state['name']?.toString() ?? '';
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
          }
        );
      },
    );
  }

  void _showCityPicker() {
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).requestFocus(FocusNode());
    
    List<Map<String, dynamic>> filteredCities = List.from(_cities);
    final TextEditingController searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
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
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search city...',
                        hintStyle: TextStyle(color: Colors.white24),
                        prefixIcon: Icon(Icons.search, color: Colors.white54),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          filteredCities = _cities
                              .where((city) => city['name']
                                  .toString()
                                  .toLowerCase()
                                  .contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredCities.isEmpty
                        ? const Center(
                            child: Text(
                              'No cities found',
                              style: TextStyle(color: Colors.white54, fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredCities.length,
                            itemBuilder: (context, index) {
                              final city = filteredCities[index];
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
          }
        );
      },
    );
  }

  void _syncCountryCodeWithCountry(String countryName) {
    // Comprehensive country code mapping - must match _countryCodes list
    final countryMapping = {
      // A
      'Afghanistan': '+93',
      'Albania': '+355',
      'Algeria': '+213',
      'Andorra': '+376',
      'Angola': '+244',
      'Argentina': '+54',
      'Armenia': '+374',
      'Australia': '+61',
      'Austria': '+43',
      'Azerbaijan': '+994',
      // B
      'Bahrain': '+973',
      'Bangladesh': '+880',
      'Belarus': '+375',
      'Belgium': '+32',
      'Belize': '+501',
      'Benin': '+229',
      'Bhutan': '+975',
      'Bolivia': '+591',
      'Bosnia and Herzegovina': '+387',
      'Botswana': '+267',
      'Brazil': '+55',
      'Brunei': '+673',
      'Bulgaria': '+359',
      'Burkina Faso': '+226',
      'Burundi': '+257',
      // C
      'Cambodia': '+855',
      'Cameroon': '+237',
      'Canada': '+1',
      'Cape Verde': '+238',
      'Central African Republic': '+236',
      'Chad': '+235',
      'Chile': '+56',
      'China': '+86',
      'Colombia': '+57',
      'Comoros': '+269',
      'Congo': '+243',
      'Congo (Republic)': '+242',
      'Costa Rica': '+506',
      'Croatia': '+385',
      'Cuba': '+53',
      'Cyprus': '+357',
      'Czech Republic': '+420',
      // D
      'Denmark': '+45',
      'Djibouti': '+253',
      // E
      'Ecuador': '+593',
      'Egypt': '+20',
      'El Salvador': '+503',
      'Equatorial Guinea': '+240',
      'Eritrea': '+291',
      'Estonia': '+372',
      'Ethiopia': '+251',
      // F
      'Fiji': '+679',
      'Finland': '+358',
      'France': '+33',
      // G
      'Gabon': '+241',
      'Gambia': '+220',
      'Georgia': '+995',
      'Germany': '+49',
      'Ghana': '+233',
      'Greece': '+30',
      'Guatemala': '+502',
      'Guinea': '+224',
      'Guinea-Bissau': '+245',
      'Guyana': '+592',
      // H
      'Haiti': '+509',
      'Honduras': '+504',
      'Hong Kong': '+852',
      'Hungary': '+36',
      // I
      'Iceland': '+354',
      'India': '+91',
      'Indonesia': '+62',
      'Iran': '+98',
      'Iraq': '+964',
      'Ireland': '+353',
      'Israel': '+972',
      'Italy': '+39',
      'Ivory Coast': '+225',
      // J
      'Japan': '+81',
      'Jordan': '+962',
      // K
      'Kazakhstan': '+7',
      'Kenya': '+254',
      'Kiribati': '+686',
      'Kuwait': '+965',
      'Kyrgyzstan': '+996',
      // L
      'Laos': '+856',
      'Latvia': '+371',
      'Lebanon': '+961',
      'Lesotho': '+266',
      'Liberia': '+231',
      'Libya': '+218',
      'Liechtenstein': '+423',
      'Lithuania': '+370',
      'Luxembourg': '+352',
      // M
      'Macau': '+853',
      'Macedonia': '+389',
      'Madagascar': '+261',
      'Malawi': '+265',
      'Malaysia': '+60',
      'Maldives': '+960',
      'Mali': '+223',
      'Malta': '+356',
      'Marshall Islands': '+692',
      'Mauritania': '+222',
      'Mauritius': '+230',
      'Mexico': '+52',
      'Micronesia': '+691',
      'Moldova': '+373',
      'Monaco': '+377',
      'Mongolia': '+976',
      'Montenegro': '+382',
      'Morocco': '+212',
      'Mozambique': '+258',
      'Myanmar': '+95',
      // N
      'Namibia': '+264',
      'Nauru': '+674',
      'Nepal': '+977',
      'Netherlands': '+31',
      'New Zealand': '+64',
      'Nicaragua': '+505',
      'Niger': '+227',
      'Nigeria': '+234',
      'North Korea': '+850',
      'Norway': '+47',
      // O
      'Oman': '+968',
      // P
      'Pakistan': '+92',
      'Palau': '+680',
      'Panama': '+507',
      'Papua New Guinea': '+675',
      'Paraguay': '+595',
      'Peru': '+51',
      'Philippines': '+63',
      'Poland': '+48',
      'Portugal': '+351',
      // Q
      'Qatar': '+974',
      // R
      'Romania': '+40',
      'Russia': '+7',
      'Rwanda': '+250',
      // S
      'San Marino': '+378',
      'Sao Tome and Principe': '+239',
      'Saudi Arabia': '+966',
      'Senegal': '+221',
      'Serbia': '+381',
      'Seychelles': '+248',
      'Sierra Leone': '+232',
      'Singapore': '+65',
      'Slovakia': '+421',
      'Slovenia': '+386',
      'Solomon Islands': '+677',
      'Somalia': '+252',
      'South Africa': '+27',
      'South Korea': '+82',
      'South Sudan': '+211',
      'Spain': '+34',
      'Sri Lanka': '+94',
      'Sudan': '+249',
      'Suriname': '+597',
      'Swaziland': '+268',
      'Sweden': '+46',
      'Switzerland': '+41',
      'Syria': '+963',
      // T
      'Taiwan': '+886',
      'Tajikistan': '+992',
      'Tanzania': '+255',
      'Thailand': '+66',
      'Togo': '+228',
      'Tonga': '+676',
      'Tunisia': '+216',
      'Turkey': '+90',
      'Turkmenistan': '+993',
      // U
      'Uganda': '+256',
      'Ukraine': '+380',
      'UAE': '+971',
      'United Arab Emirates': '+971',
      'UK': '+44',
      'United Kingdom': '+44',
      'Uruguay': '+598',
      'USA': '+1',
      'United States': '+1',
      'United States of America': '+1',
      'Uzbekistan': '+998',
      // V
      'Venezuela': '+58',
      'Vietnam': '+84',
      // Y
      'Yemen': '+967',
      // Z
      'Zambia': '+260',
      'Zimbabwe': '+263',
      // Burma/Myanmar alias
      'Burma (Myanmar)': '+95',
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

  void _syncCountryWithCountryCode(String countryCode, String countryName) {
    // Find the country in the loaded countries list
    if (_countries.isEmpty) {
      debugPrint('Countries list is empty, cannot sync country');
      return;
    }

    // Try to find country by exact name match
    Map<String, dynamic>? matchedCountry;
    for (final country in _countries) {
      final name = country['name']?.toString() ?? '';
      if (name.toLowerCase() == countryName.toLowerCase()) {
        matchedCountry = country;
        break;
      }
    }

    // If no exact match, try partial match for special cases
    if (matchedCountry == null) {
      final lowerCountryName = countryName.toLowerCase();
      for (final country in _countries) {
        final name = country['name']?.toString() ?? '';
        final lowerName = name.toLowerCase();
        if (lowerName.contains(lowerCountryName) || lowerCountryName.contains(lowerName)) {
          matchedCountry = country;
          break;
        }
      }
    }

    if (matchedCountry != null) {
      final countryId = matchedCountry['id']?.toString() ??
                        matchedCountry['_id']?.toString() ??
                        matchedCountry['code']?.toString() ?? '';
      final matchedCountryName = matchedCountry['name']?.toString() ?? countryName;

      if (countryId.isNotEmpty && countryId != _selectedCountryId) {
        setState(() {
          _selectedCountryId = countryId;
          _selectedCountryName = matchedCountryName;
          // Reset state and city when country changes
          _selectedStateId = null;
          _selectedStateName = null;
          _selectedCityId = null;
          _selectedCityName = null;
          _states = [];
          _cities = [];
        });
        debugPrint('Auto-synced country: $matchedCountryName (ID: $countryId) for code: $countryCode');

        // Show user feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Country updated to $matchedCountryName'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF84BD00),
          ),
        );

        // Load states for the selected country
        _loadStates(countryId);
      }
    } else {
      debugPrint('No matching country found for: $countryName (code: $countryCode)');
    }
  }

  void _showCountryCodePicker() {
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).requestFocus(FocusNode());
    
    List<Map<String, String>> filteredCountryCodes = List.from(_countryCodes);
    final TextEditingController searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
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
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search country or code...',
                        hintStyle: TextStyle(color: Colors.white24),
                        prefixIcon: Icon(Icons.search, color: Colors.white54),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          filteredCountryCodes = _countryCodes
                              .where((country) => 
                                  country['country']!.toLowerCase().contains(value.toLowerCase()) ||
                                  country['code']!.toLowerCase().contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredCountryCodes.isEmpty
                        ? const Center(
                            child: Text(
                              'No codes found',
                              style: TextStyle(color: Colors.white54, fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredCountryCodes.length,
                            itemBuilder: (context, index) {
                              final country = filteredCountryCodes[index];
                              final isSelected = country['code'] == _selectedCountryCode;
                              return ListTile(
                                onTap: () {
                                  final selectedCode = country['code']!;
                                  final selectedCountryName = country['country']!;
                                  setState(() {
                                    _selectedCountryCode = selectedCode;
                                  });
                                  // Sync country when country code is selected
                                  _syncCountryWithCountryCode(selectedCode, selectedCountryName);
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
          }
        );
      },
    );
  }
}
