import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/custom_text_field.dart';
import '../services/api_service.dart';
import '../utils/dialog_helper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  // Step 1: Account Controllers & Keys
  final _step1Key = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Step 2: Health/Body Controllers & Keys
  final _step2Key = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _problemsController = TextEditingController();
  bool _isLoading = false;
  
  String? _selectedBloodGroup;
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  
  final List<String> _commonConditions = [
    'Diabetes',
    'Hypertension',
    'Gluten Allergy',
    'Lactose Intolerant',
    'Asthma',
    'None',
  ];
  final Set<String> _selectedConditions = {};

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _problemsController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_step1Key.currentState!.validate()) {
      setState(() {
        _currentStep = 1;
      });
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    setState(() {
      _currentStep = 0;
    });
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _handleSubmit() async {
    if (_step2Key.currentState!.validate()) {
      if (_selectedBloodGroup == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select your blood group.', style: GoogleFonts.poppins()),
            backgroundColor: Colors.orange[800],
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      // Collect all data
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final username = _usernameController.text.trim();
      final email = _emailController.text.trim();
      final ageStr = _ageController.text.trim();
      final weightStr = _weightController.text.trim();
      final heightStr = _heightController.text.trim();
      final customProblems = _problemsController.text.trim();
      final bloodGroup = _selectedBloodGroup!;
      final tags = _selectedConditions.toList();

      try {
        final age = int.parse(ageStr);
        final weight = double.parse(weightStr);
        final height = double.parse(heightStr);

        final response = await ApiService.register(
          firstName: firstName,
          lastName: lastName,
          username: username,
          email: email,
          password: _passwordController.text,
          age: age,
          weight: weight,
          height: height,
          bloodGroup: bloodGroup,
          healthConditions: tags,
          additionalConcerns: customProblems,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Successfully registered!', style: GoogleFonts.poppins()),
              backgroundColor: const Color(0xFF27AE60),
              behavior: SnackBarBehavior.floating,
            ),
          );
          
          // Route to Login Screen
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
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
                content: Text('Registration failed. Please check inputs and try again.',
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E272C)),
          onPressed: () {
            if (_currentStep == 1) {
              _previousPage();
            } else {
              Navigator.pop(context);
            }
          },
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
          child: Column(
            children: [
              // 1. Progress Step Stepper UI
              _buildStepperHeader(),
              
              // 2. Form PageView Content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep1AccountInfo(),
                    _buildStep2HealthInfo(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Stepper Header showing the user progress (1. Account -> 2. Body Info)
  Widget _buildStepperHeader() {
    const activeColor = Color(0xFF2ECC71);
    final inactiveColor = Colors.grey[300]!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 10.0),
      child: Row(
        children: [
          // Step 1 circle
          _buildStepNode(1, 'Account', _currentStep >= 0),
          // Connecting Line
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 3,
              color: _currentStep >= 1 ? activeColor : inactiveColor,
            ),
          ),
          // Step 2 circle
          _buildStepNode(2, 'Health details', _currentStep >= 1),
        ],
      ),
    );
  }

  Widget _buildStepNode(int index, String label, bool isActive) {
    const activeColor = Color(0xFF2ECC71);
    final inactiveColor = Colors.grey[300]!;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? activeColor : Colors.white,
            border: Border.all(
              color: isActive ? activeColor : inactiveColor,
              width: 2,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              '$index',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isActive ? Colors.white : Colors.grey[500],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? const Color(0xFF1E272C) : Colors.grey[400],
          ),
        ),
      ],
    );
  }

  // Step 1 Form Layout
  Widget _buildStep1AccountInfo() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
      child: Form(
        key: _step1Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Let\'s create your account',
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E272C),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter your basic details to start your journey.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 28),

            // First Name & Last Name in one row
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _firstNameController,
                    labelText: 'First Name',
                    hintText: 'John',
                    prefixIcon: Icons.person_outline_rounded,
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    controller: _lastNameController,
                    labelText: 'Last Name',
                    hintText: 'Doe',
                    prefixIcon: Icons.person_outline_rounded,
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),

            // Username
            CustomTextField(
              controller: _usernameController,
              labelText: 'Username',
              hintText: 'johndoe123',
              prefixIcon: Icons.alternate_email_rounded,
              validator: (val) {
                if (val == null || val.isEmpty) return 'Please enter username';
                if (val.length < 3) return 'Username is too short';
                return null;
              },
            ),

            // Email
            CustomTextField(
              controller: _emailController,
              labelText: 'Email Address',
              hintText: 'john@example.com',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (val) {
                if (val == null || val.isEmpty) return 'Please enter your email';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),

            // Password
            CustomTextField(
              controller: _passwordController,
              labelText: 'Password',
              hintText: 'Create a password',
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: true,
              textInputAction: TextInputAction.done,
              validator: (val) {
                if (val == null || val.isEmpty) return 'Please create a password';
                if (val.length < 6) return 'Must be at least 6 characters';
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Next Step Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  foregroundColor: Colors.white,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Next Step',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Step 2 Form Layout
  Widget _buildStep2HealthInfo() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
      child: Form(
        key: _step2Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Body & Health details',
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E272C),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Helps us personalize your calories and nutrition goals.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 28),

            // Age, Weight & Height in one row
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _ageController,
                    labelText: 'Age (yrs)',
                    hintText: '25',
                    prefixIcon: Icons.calendar_today_rounded,
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Required';
                      final ageVal = int.tryParse(val);
                      if (ageVal == null || ageVal <= 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CustomTextField(
                    controller: _weightController,
                    labelText: 'Weight (kg)',
                    hintText: '70',
                    prefixIcon: Icons.scale_outlined,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Required';
                      if (double.tryParse(val) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CustomTextField(
                    controller: _heightController,
                    labelText: 'Height (cm)',
                    hintText: '175',
                    prefixIcon: Icons.height_rounded,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Required';
                      if (double.tryParse(val) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),

            // Blood Group label
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
              child: Text(
                'Blood Group',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ),

            // Blood Group Select Chips Grid
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _bloodGroups.map((bg) {
                final isSelected = _selectedBloodGroup == bg;
                return ChoiceChip(
                  label: Text(
                    bg,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF2ECC71),
                  backgroundColor: const Color(0xFFF9FBF9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF2ECC71) : Colors.grey[200]!,
                      width: 1.5,
                    ),
                  ),
                  showCheckmark: false,
                  elevation: isSelected ? 2 : 0,
                  onSelected: (selected) {
                    setState(() {
                      _selectedBloodGroup = selected ? bg : null;
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Health Conditions / Body Problems (Optional) Label
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
              child: Text(
                'Any Health Problems? (Optional)',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ),
            Text(
              'Select any conditions that apply, or type below.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 10),

            // Quick select conditions chips
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _commonConditions.map((condition) {
                final isSelected = _selectedConditions.contains(condition);
                return FilterChip(
                  label: Text(
                    condition,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.grey[700],
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFFE67E22), // Warm Orange for warning/health flags
                  backgroundColor: const Color(0xFFF9FBF9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFFE67E22) : Colors.grey[200]!,
                      width: 1.5,
                    ),
                  ),
                  showCheckmark: false,
                  onSelected: (selected) {
                    setState(() {
                      if (condition == 'None') {
                        _selectedConditions.clear();
                        if (selected) _selectedConditions.add('None');
                      } else {
                        _selectedConditions.remove('None');
                        if (selected) {
                          _selectedConditions.add(condition);
                        } else {
                          _selectedConditions.remove(condition);
                        }
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Optional description detail input
            CustomTextField(
              controller: _problemsController,
              labelText: 'Additional Health Concerns / Food Allergies',
              hintText: 'e.g. Peanut allergy, gluten intolerance, joint pain, etc.',
              prefixIcon: Icons.medical_services_outlined,
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),

            const SizedBox(height: 24),

            // Buttons: Back and Submit
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _previousPage,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Back',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: SizedBox(
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
                              'Complete Profile',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
