import 'package:flutter/material.dart';
import '../services/wallet_service.dart';

class AddInrBankScreen extends StatefulWidget {
  final bool isEditMode;
  final Map<String, dynamic>? editData;
  
  const AddInrBankScreen({
    super.key,
    this.isEditMode = false,
    this.editData,
  });

  @override
  State<AddInrBankScreen> createState() => _AddInrBankScreenState();
}

class _AddInrBankScreenState extends State<AddInrBankScreen> {
  final _formKey = GlobalKey<FormState>();
  final _holderNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _confirmAccountNumberController = TextEditingController();
  final _ifscCodeController = TextEditingController();
  final _bankNameController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode && widget.editData != null) {
      _holderNameController.text = widget.editData!['accountHolderName'] ?? widget.editData!['holderName'] ?? '';
      _bankNameController.text = widget.editData!['bankName'] ?? widget.editData!['Name'] ?? '';
      _accountNumberController.text = widget.editData!['accountNumber'] ?? '';
      _confirmAccountNumberController.text = widget.editData!['accountNumber'] ?? '';
      _ifscCodeController.text = widget.editData!['ifscCode'] ?? '';
    }
  }

  @override
  void dispose() {
    _holderNameController.dispose();
    _accountNumberController.dispose();
    _confirmAccountNumberController.dispose();
    _ifscCodeController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  Future<void> _handleInitialSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_accountNumberController.text != _confirmAccountNumberController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account numbers do not match'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      Map<String, dynamic> response;
      
      if (widget.isEditMode && widget.editData != null) {
        final id = widget.editData!['_id']?.toString() ?? widget.editData!['id']?.toString() ?? '';
        response = await WalletService.editINRBankAccount(
          id: id,
          accountHolderName: _holderNameController.text,
          accountNumber: _accountNumberController.text,
          ifscCode: _ifscCodeController.text,
          bankName: _bankNameController.text,
        );
      } else {
        response = await WalletService.addINRBankAccount(
          accountHolderName: _holderNameController.text,
          accountNumber: _accountNumberController.text,
          ifscCode: _ifscCodeController.text,
          bankName: _bankNameController.text,
        );
      }
      
      setState(() => _isLoading = false);
      
      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.isEditMode ? 'Bank account updated successfully' : 'Bank account added successfully'),
              backgroundColor: const Color(0xFF84BD00),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? response['message'] ?? 'Failed to save bank details'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        ),
        title: Text(
          widget.isEditMode ? 'Edit Bank Account' : 'Add Bank Account',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Account Holder Name'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _holderNameController,
                  hint: 'Enter account holder name',
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _buildLabel('Bank Name'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _bankNameController,
                  hint: 'Enter bank name',
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _buildLabel('Account Number'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _accountNumberController,
                  hint: 'Enter account number',
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _buildLabel('Confirm Account Number'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _confirmAccountNumberController,
                  hint: 'Re-enter account number',
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                _buildLabel('IFSC Code'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _ifscCodeController,
                  hint: 'Enter IFSC code',
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleInitialSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF84BD00),
                      disabledBackgroundColor: Colors.white10,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                          )
                        : Text(
                            widget.isEditMode ? 'Update' : 'Submit',
                            style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 16),
        filled: true,
        fillColor: const Color(0xFF1C1C1E),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF84BD00), width: 1),
        ),
      ),
    );
  }
}
