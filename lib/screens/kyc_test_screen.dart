import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/kyc_service.dart';

class KYCTestScreen extends StatefulWidget {
  const KYCTestScreen({super.key});

  @override
  State<KYCTestScreen> createState() => _KYCTestScreenState();
}

class _KYCTestScreenState extends State<KYCTestScreen> {
  final _docIdController = TextEditingController(text: '6969cb81e94cf19f6333b083');
  final _idNumberController = TextEditingController(text: '390059292656');
  XFile? _frontImage;
  XFile? _backImage;
  bool _isLoading = false;
  String _result = '';

  @override
  void dispose() {
    _docIdController.dispose();
    _idNumberController.dispose();
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
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select Image Source'),
            ListTile(
              leading: const Icon(Icons.camera),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, imageType);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
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

  Future<void> _testKYCUpload() async {
    if (_frontImage == null || _backImage == null) {
      setState(() {
        _result = 'Please upload both front and back images';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _result = 'Processing...';
    });

    try {
      final result = await KYCService.submitKYC(
        documentType: 'Test Document',
        documentId: _docIdController.text,
        frontImage: _frontImage!,
        backImage: _backImage!,
        selfieImage: _frontImage!, // Using front image as selfie for test
      );

      setState(() {
        _isLoading = false;
        _result = 'Result: ${result['success'] ? 'SUCCESS' : 'FAILED'}\n';
        _result += 'Data: ${result['data']}\n';
        _result += 'Error: ${result['error']}';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _result = 'Exception: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KYC Test - Localhost:8085'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test KYC Upload to localhost:8085',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            TextField(
              controller: _docIdController,
              decoration: const InputDecoration(
                labelText: 'Doc ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            
            TextField(
              controller: _idNumberController,
              decoration: const InputDecoration(
                labelText: 'ID Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showImagePicker('front'),
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _frontImage != null
                          ? Image.network(_frontImage!.path, fit: BoxFit.cover)
                          : const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.upload),
                                  Text('Front Image'),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showImagePicker('back'),
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _backImage != null
                          ? Image.network(_backImage!.path, fit: BoxFit.cover)
                          : const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.upload),
                                  Text('Back Image'),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _testKYCUpload,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Test KYC Upload'),
            ),
            const SizedBox(height: 20),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _result,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
