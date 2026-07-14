import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../widgets/custom_text_field.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
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
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _problemsController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedBloodGroup == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select your blood group.', style: GoogleFonts.poppins()),
            backgroundColor: Colors.orange[800],
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final ageStr = _ageController.text.trim();
      final weightStr = _weightController.text.trim();
      final heightStr = _heightController.text.trim();
      
      try {
        final age = int.parse(ageStr);
        final weight = double.parse(weightStr);
        final height = double.parse(heightStr);
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final currentUser = userProvider.user;

        if (currentUser == null) {
          throw ApiException('User session not found. Please try logging in again.');
        }

        // Combine selected condition chips and custom input
        final List<String> healthProblemList = [];
        if (_selectedConditions.isNotEmpty && !_selectedConditions.contains('None')) {
          healthProblemList.addAll(_selectedConditions);
        }
        if (_problemsController.text.trim().isNotEmpty) {
          healthProblemList.add(_problemsController.text.trim());
        }
        final String healthProblem = healthProblemList.isNotEmpty 
            ? healthProblemList.join(', ') 
            : 'None';

        // Call userProvider.updateProfile to update on server and locally
        await userProvider.updateProfile(
          firstName: currentUser.firstName,
          lastName: currentUser.lastName,
          username: currentUser.username,
          email: currentUser.email,
          age: age,
          weight: weight,
          height: height,
          bloodGroup: _selectedBloodGroup!,
          healthConditions: healthProblem,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Profile completed successfully! Welcome to NutriLife.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: const Color(0xFF27AE60),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );

          // Route to Home
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
            (route) => false,
          );
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
              content: Text(
                'Failed to complete profile. Please check inputs and try again.',
                style: GoogleFonts.poppins(),
              ),
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
    final userProvider = Provider.of<UserProvider>(context);
    final String welcomeName = userProvider.user?.firstName ?? 'there';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A decorative eco icon in circle
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2ECC71).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.spa_rounded,
                          color: Color(0xFF2ECC71),
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Center(
                      child: Text(
                        'Complete Your Profile',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E272C),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'Hi $welcomeName! We just need a few more details to customize your nutrition budget and health plans.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[500],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Age, Weight & Height
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                              final parsed = int.tryParse(val);
                              if (parsed == null || parsed <= 0 || parsed > 120) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomTextField(
                            controller: _weightController,
                            labelText: 'Weight (kg)',
                            hintText: '70',
                            prefixIcon: Icons.scale_outlined,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Required';
                              final parsed = double.tryParse(val);
                              if (parsed == null || parsed <= 10) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomTextField(
                            controller: _heightController,
                            labelText: 'Height (cm)',
                            hintText: '175',
                            prefixIcon: Icons.height_rounded,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Required';
                              final parsed = double.tryParse(val);
                              if (parsed == null || parsed <= 50) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    // Blood Group Label
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

                    // Blood Group Chip Wrap
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

                    // Health Problems Selector
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                      child: Text(
                        'Any Health Conditions? (Optional)',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    Text(
                      'This helps adjust warnings for food analyses.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 10),

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
                          selectedColor: const Color(0xFFE67E22), // warm orange for warning fields
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

                    const SizedBox(height: 20),

                    // Additional Health concerns
                    CustomTextField(
                      controller: _problemsController,
                      labelText: 'Additional Health Concerns / Food Allergies',
                      hintText: 'e.g. Peanut allergy, gluten intolerance, joint pain, etc.',
                      prefixIcon: Icons.medical_services_outlined,
                      maxLines: 3,
                      textInputAction: TextInputAction.done,
                    ),

                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
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
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                              )
                            : Text(
                                'Save & Enter App',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.1),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2ECC71)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
