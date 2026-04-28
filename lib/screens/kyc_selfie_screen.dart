import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../main_navigation.dart';
import 'user_profile_screen.dart';
import '../services/user_service.dart';
import '../services/kyc_service.dart';

class KYCSelfieScreen extends StatefulWidget {
  final XFile? frontImage;
  final XFile? backImage;
  final String? documentType;
  final String? documentId;
  final bool fromDigiLocker;
  
  const KYCSelfieScreen({
    super.key,
    this.frontImage,
    this.backImage,
    this.documentType,
    this.documentId,
    this.fromDigiLocker = true,
  });

  @override
  State<KYCSelfieScreen> createState() => _KYCSelfieScreenState();
}

class _KYCSelfieScreenState extends State<KYCSelfieScreen> {
  XFile? _selfieImage;
  bool _isLoading = false;
  String _kycStatus = 'pending'; // pending, completed, rejected
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _checkKYCStatus();
  }

  Future<void> _checkKYCStatus() async {
    try {
      final result = await KYCService.getKYCStatus();
      if (result['success'] == true) {
        final responseData = result['data'];
        final status = responseData?['status']?.toString().toLowerCase() ?? '';
        
        if (status == 'completed' || status == 'already_completed') {
          setState(() => _kycStatus = 'completed');
          
          // Show message and navigate to home after delay
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Selfie upload already completed!'),
                backgroundColor: Color(0xFF84BD00),
                duration: Duration(seconds: 2),
              ),
            );
            
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const UserProfileScreen()),
                  (route) => false,
                );
              }
            });
          });
        } else if (status == 'rejected') {
          setState(() => _kycStatus = 'rejected');
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('KYC verification rejected. Please upload selfie again.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking KYC status: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    
    if (pickedFile != null) {
      setState(() {
        _selfieImage = pickedFile;
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
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
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
              'Selfie Verification (2/2)',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _kycStatus == 'completed'
          ? _buildAlreadyCompletedView()
          : _kycStatus == 'rejected'
              ? _buildRejectedView()
              : SingleChildScrollView(
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
                      _buildImageUploadSection(),
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

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload Selfie',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Take a clear selfie or upload from gallery',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 16),
        
        // Show selected image preview
        if (_selfieImage != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF84BD00), width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    child: kIsWeb 
                      ? Image.network(
                          _selfieImage!.path,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFF2C2C2E),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, color: Colors.white54, size: 50),
                                  SizedBox(height: 8),
                                  Text('Image not available', style: TextStyle(color: Colors.white38)),
                                ],
                              ),
                            ),
                          ),
                        )
                      : Image.file(
                          File(_selfieImage!.path),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFF2C2C2E),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, color: Colors.white54, size: 50),
                                  SizedBox(height: 8),
                                  Text('Image not available', style: TextStyle(color: Colors.white38)),
                                ],
                              ),
                            ),
                          ),
                        ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF84BD00).withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF84BD00), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Selfie selected',
                            style: TextStyle(
                              color: Color(0xFF84BD00),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selfieImage = null;
                          });
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        label: const Text(
                          'Remove',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        
        // Media selection buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt, color: Colors.black),
                label: const Text(
                  'Camera',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF84BD00),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library, color: Colors.black),
                label: const Text(
                  'Gallery',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C1C1E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Supported formats: JPG/JPEG/PNG/BMP (Max 1MB)',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
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
    setState(() => _isLoading = true);

    try {
      if (widget.fromDigiLocker) {
        // For DigiLocker flow
        if (_selfieImage != null) {
          // Upload selfie
          final result = await _userService.verifySelfieFromDigiLocker(
            selfieImage: _selfieImage!,
          );

          if (mounted) {
            setState(() => _isLoading = false);
            
            if (result['success'] == true) {
              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Selfie upload successful!'),
                  backgroundColor: Color(0xFF84BD00),
                ),
              );
              
              // Navigate back to profile screen
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const UserProfileScreen()),
                (route) => false,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result['error'] ?? 'Failed to verify selfie'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          // Proceed without selfie
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Proceeding to profile...'),
                backgroundColor: Color(0xFF84BD00),
              ),
            );
            
            // Navigate to profile directly
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const UserProfileScreen()),
              (route) => false,
            );
          }
        }
      } else {
        // Legacy flow with document images
        if (_selfieImage != null) {
          final result = await _userService.verifySelfie(
            selfieImage: _selfieImage!,
            documentType: widget.documentType,
            documentId: widget.documentId,
          );

          if (mounted) {
            setState(() => _isLoading = false);
            
            if (result['success'] == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('KYC submitted successfully!'),
                  backgroundColor: Color(0xFF84BD00),
                ),
              );
              
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const UserProfileScreen()),
                (route) => false,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result['error'] ?? 'Failed to submit KYC'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          // Proceed without selfie in legacy flow
          if (mounted) {
            setState(() => _isLoading = false);
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const UserProfileScreen()),
              (route) => false,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAlreadyCompletedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF84BD00).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified,
              color: Color(0xFF84BD00),
              size: 50,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Selfie Upload Already Completed!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Your KYC verification is complete.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const UserProfileScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF84BD00),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            ),
            child: const Text(
              'Back to Profile',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline,
              color: Color(0xFFFF3B30),
              size: 50,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'KYC Verification Rejected',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Please upload a clear selfie and try again.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              setState(() => _kycStatus = 'pending');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF84BD00),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            ),
            child: const Text(
              'Upload Again',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
