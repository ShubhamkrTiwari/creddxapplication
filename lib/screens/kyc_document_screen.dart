import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'kyc_selfie_screen.dart';
import 'kyc_pending_screen.dart';
import 'user_profile_screen.dart';
import 'update_profile_screen.dart';
import '../services/user_service.dart';

class KYCDocumentScreen extends StatefulWidget {
  const KYCDocumentScreen({super.key});

  @override
  State<KYCDocumentScreen> createState() => _KYCDocumentScreenState();
}

class _KYCDocumentScreenState extends State<KYCDocumentScreen> {
  String _selectedDocumentType = '';
  final _documentIdController = TextEditingController();
  XFile? _frontImage;
  XFile? _backImage;
  List<String> _documentTypes = ['Passport', 'National ID', 'Driver License', 'Aadhaar Card', 'Voter ID'];
  bool _isLoading = false;
  final UserService _userService = UserService();
  
  @override
  void initState() {
    super.initState();
    _loadDocumentTypes();
    // Check profile completeness when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProfileAndShowDialog();
    });
  }

  // Check if profile is complete
  bool _isProfileComplete() {
    return _userService.hasEmail() &&
           _userService.userPhone != null &&
           _userService.userPhone!.isNotEmpty;
  }

  // Check profile and show dialog if incomplete
  void _checkProfileAndShowDialog() {
    if (!_isProfileComplete()) {
      _showProfileRequiredDialog();
    }
  }

  // Show profile completion required dialog
  void _showProfileRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Profile Incomplete',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Please complete your profile (email and phone number) before starting KYC verification.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to previous screen
              },
              child: const Text('Go Back', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(context, MaterialPageRoute(builder: (context) => const UpdateProfileScreen()));
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF84BD00)),
              child: const Text('Complete Profile', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadDocumentTypes() async {
    final types = await _userService.getDocumentTypes();
    if (mounted) {
      setState(() {
        _documentTypes = types;
      });
    }
  }

  @override
  void dispose() {
    _documentIdController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, String imageType) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    
    if (pickedFile != null) {
      setState(() {
        if (imageType == 'front') {
          _frontImage = pickedFile;
        } else {
          _backImage = pickedFile;
        }
      });
    }
  }

  void _showImagePicker(String imageType) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Image Source',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera, color: Color(0xFF84BD00)),
              title: const Text('Camera', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, imageType);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF84BD00)),
              title: const Text('Gallery', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, imageType);
              },
            ),
          ],
        ),
      ),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Know Your Customers (KYC)',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Document Verification (1/3)',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - 120, // Account for app bar and padding
          ),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Please select your document type',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _buildDocumentTypeDropdown(),
                const SizedBox(height: 24),
                
                const Text(
                  'Document ID',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _buildDocumentIdField(),
                const SizedBox(height: 32),
                
                _buildImageUploadSection('Upload Document Front Image', _frontImage, 'front'),
                const SizedBox(height: 24),
                _buildImageUploadSection('Upload Document Back Image', _backImage, 'back'),
                const SizedBox(height: 32),
                
                _buildNavigationButtons(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDocumentType.isEmpty ? null : _selectedDocumentType,
          dropdownColor: const Color(0xFF1C1C1E),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          isExpanded: true,
          hint: const Text('Choose Document Types', style: TextStyle(color: Colors.white54)),
          items: _documentTypes.map((String type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Text(type),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedDocumentType = newValue;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildDocumentIdField() {
    return TextField(
      controller: _documentIdController,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Enter Document ID',
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: const Color(0xFF1C1C1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF84BD00)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildImageUploadSection(String title, XFile? image, String imageType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showImagePicker(imageType),
          child: Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      image.path,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(Icons.broken_image, color: Colors.white54, size: 40),
                        );
                      },
                    ),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined, color: Color(0xFF84BD00), size: 32),
                      const SizedBox(height: 8),
                      const Text(
                        'UPLOAD HERE',
                        style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '(JPG/JPEG/PNG/BMP, less than 1MB)',
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C1C1E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Back',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _validateAndProceed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF84BD00),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Next',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  void _validateAndProceed() async {
    // Check profile completeness before proceeding
    if (!_isProfileComplete()) {
      _showProfileRequiredDialog();
      return;
    }

    if (_selectedDocumentType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a document type')),
      );
      return;
    }

    if (_documentIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter document ID')),
      );
      return;
    }

    if (_frontImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload front image')),
      );
      return;
    }

    if (_backImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload back image')),
      );
      return;
    }

    // Skip validation API call - proceed directly to submit
    setState(() => _isLoading = true);

    // Submit KYC to API
    final result = await _userService.submitKYC(
      documentType: _selectedDocumentType,
      documentId: '6969cb81e94cf19f6333b083', // Fixed ObjectId
      idNumber: _documentIdController.text,
      frontImage: _frontImage!,
      backImage: _backImage,
      selfieImage: null, // Will be set in next screen
    );

    if (mounted) {
      setState(() => _isLoading = false);
      
      if (result['success'] == true) {
        final message = result['message']?.toString().toLowerCase() ?? '';
        final nextStep = result['nextStep']?.toString().toLowerCase() ?? 
                        result['data']?['nextStep']?.toString().toLowerCase() ?? '';
        
        // Check API response for next step
        if (nextStep.contains('selfie') || 
            nextStep.contains('proceed to selfie') ||
            message.contains('proceed to selfie')) {
          // Selfie verification needed - go to selfie screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => KYCSelfieScreen(
                frontImage: _frontImage!,
                backImage: _backImage,
                documentType: _selectedDocumentType,
                documentId: _documentIdController.text,
              ),
            ),
          );
        } else if (message.contains('already submitted') || 
                   message.contains('under review') ||
                   nextStep.contains('completed')) {
          // KYC complete - go to pending screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const KYCPendingScreen()),
          );
        } else {
          // Default: go to selfie screen for fresh submission
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => KYCSelfieScreen(
                frontImage: _frontImage!,
                backImage: _backImage,
                documentType: _selectedDocumentType,
                documentId: _documentIdController.text,
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to submit KYC'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
