import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/custom_text_field.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _EditTextWithClearButton extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final IconData prefixIcon;
  final FormFieldValidator<String>? validator;

  const _EditTextWithClearButton({
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.prefixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E272C),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: 3,
          minLines: 1,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1E272C),
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
            prefixIcon: Icon(prefixIcon, color: Colors.grey[400], size: 20),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 20),
              onPressed: () => controller.clear(),
            ),
            fillColor: Colors.white,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF2ECC71), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      // Extract passed token argument if present
      final tokenArg = ModalRoute.of(context)?.settings.arguments as String?;
      if (tokenArg != null && tokenArg.isNotEmpty) {
        _tokenController.text = tokenArg;
      }
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final token = _tokenController.text.trim();
        final password = _passwordController.text;

        await ApiService.resetPassword(token: token, password: password);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Password reset successfully! Please login with your new password.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: const Color(0xFF27AE60),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message, style: GoogleFonts.poppins()),
              backgroundColor: Colors.red[800],
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reset password. Check if the token is valid or expired.', style: GoogleFonts.poppins()),
              backgroundColor: Colors.red[800],
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E272C)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ECC71).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.vpn_key_outlined,
                      color: Color(0xFF2ECC71),
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'Reset Password',
                    style: GoogleFonts.outfit(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E272C),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Enter your reset token and your new secure password below.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[500],
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                
                // Token Field with clearance support
                _EditTextWithClearButton(
                  controller: _tokenController,
                  labelText: 'Reset Token',
                  hintText: 'Enter or paste simulated reset token',
                  prefixIcon: Icons.api_rounded,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the reset token';
                    }
                    return null;
                  },
                ),

                // New Password
                CustomTextField(
                  controller: _passwordController,
                  labelText: 'New Password',
                  hintText: 'Min 6 characters',
                  prefixIcon: Icons.lock_outline_rounded,
                  isPassword: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a new password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                // Confirm Password
                CustomTextField(
                  controller: _confirmPasswordController,
                  labelText: 'Confirm New Password',
                  hintText: 'Confirm new password',
                  prefixIcon: Icons.lock_outline_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your new password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          )
                        : Text(
                            'Reset Password',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
