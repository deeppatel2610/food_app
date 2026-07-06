import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/social_login_button.dart';
import '../services/api_service.dart';
import '../utils/dialog_helper.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final response = await ApiService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );

        if (mounted) {
          Provider.of<UserProvider>(context, listen: false)
              .setUser(UserModel.fromJson(response['user']));

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Welcome back, ${response['user']['first_name']}!',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: const Color(0xFF27AE60),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );

          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
            (route) => false,
          );
        }
      } on ApiException catch (e) {
        if (mounted) {
          if (e is NetworkException) {
            DialogHelper.showNetworkErrorDialog(context, message: e.message);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.message, style: GoogleFonts.poppins()),
                backgroundColor: Colors.red[800],
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          final isNetworkError = e.toString().contains('NetworkException') ||
              e.toString().contains('SocketException');
          if (isNetworkError) {
            DialogHelper.showNetworkErrorDialog(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Login failed. Please try again.',
                    style: GoogleFonts.poppins()),
                backgroundColor: Colors.red[800],
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1E272C)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1.0 - value)),
                child: child,
              ),
            );
          },
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  // 1. Organic motif icon and greeting
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: Color(0xFF2ECC71),
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Center(
                    child: Text(
                      'Welcome Back',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E272C),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Sign in to access your custom health plans',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 2. Email Field
                  CustomTextField(
                    controller: _emailController,
                    labelText: 'Email Address',
                    hintText: 'name@example.com',
                    prefixIcon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),

                  // 3. Password Field
                  CustomTextField(
                    controller: _passwordController,
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: Icons.lock_outline_rounded,
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters long';
                      }
                      return null;
                    },
                  ),

                  // 4. Forgot Password Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/forgot_password');
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF27AE60),
                      ),
                      child: Text(
                        'Forgot Password?',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 5. Sign In Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2ECC71),
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shadowColor: const Color(0xFF27AE60).withOpacity(0.2),
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                            )
                          : Text(
                              'Sign In',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 6. Divider "Or continue with"
                  Row(
                    children: [
                      Expanded(
                          child:
                              Divider(color: Colors.grey[200], thickness: 1.5)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'Or continue with',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[400],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                          child:
                              Divider(color: Colors.grey[200], thickness: 1.5)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 7. Social Buttons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Google
                      SocialIconButton(
                        icon: const FaIcon(
                          FontAwesomeIcons.google,
                          color: Color(0xFFDB4437), // Google Red
                          size: 24,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Logging in with Google...',
                                    style: GoogleFonts.poppins())),
                          );
                        },
                      ),
                      // Facebook
                      SocialIconButton(
                        icon: const FaIcon(
                          FontAwesomeIcons.facebook,
                          color: Color(0xFF1877F2), // Facebook Blue
                          size: 24,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Logging in with Facebook...',
                                    style: GoogleFonts.poppins())),
                          );
                        },
                      ),
                      // Apple
                      SocialIconButton(
                        icon: const FaIcon(
                          FontAwesomeIcons.apple,
                          color: Colors.black, // Apple Black
                          size: 24,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Logging in with Apple...',
                                    style: GoogleFonts.poppins())),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 36),

                  // 8. Sign Up redirection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/register');
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF27AE60),
                        ),
                        child: Text(
                          'Sign Up',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
