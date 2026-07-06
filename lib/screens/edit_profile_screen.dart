import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../widgets/custom_text_field.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _ageController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _conditionsController;
  
  String _selectedBloodGroup = 'O+';
  bool _isLoading = false;
  bool _isInit = false;

  final List<String> _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final user = Provider.of<UserProvider>(context).user;
      
      _firstNameController = TextEditingController(text: user?.firstName ?? '');
      _lastNameController = TextEditingController(text: user?.lastName ?? '');
      _usernameController = TextEditingController(text: user?.username ?? '');
      _emailController = TextEditingController(text: user?.email ?? '');
      _ageController = TextEditingController(text: user?.age.toString() ?? '');
      _weightController = TextEditingController(text: user?.weight.toStringAsFixed(1) ?? '');
      _heightController = TextEditingController(text: user?.height.toStringAsFixed(0) ?? '');
      
      final conditions = user?.healthConditions ?? [];
      _conditionsController = TextEditingController(
        text: (conditions.isEmpty || conditions.first == 'None') 
            ? '' 
            : conditions.join(', ')
      );

      final String bg = user?['blood_group']?.toString() ?? 'O+';
      if (_bloodGroups.contains(bg)) {
        _selectedBloodGroup = bg;
      }
      
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _conditionsController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        
        final String healthProblem = _conditionsController.text.trim().isEmpty 
            ? 'None' 
            : _conditionsController.text.trim();

        await userProvider.updateProfile(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          age: int.parse(_ageController.text.trim()),
          weight: double.parse(_weightController.text.trim()),
          height: double.parse(_heightController.text.trim()),
          bloodGroup: _selectedBloodGroup,
          healthConditions: healthProblem,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Profile updated successfully!',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: const Color(0xFF27AE60),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          Navigator.pop(context);
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
              content: Text('Failed to update profile. Please check your inputs.', style: GoogleFonts.poppins()),
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
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700, 
            color: const Color(0xFF1E272C)
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E272C)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personal Details',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E272C),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // First Name
                  CustomTextField(
                    controller: _firstNameController,
                    labelText: 'First Name',
                    hintText: 'Enter your first name',
                    prefixIcon: Icons.person_outline_rounded,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'First name is required';
                      }
                      return null;
                    },
                  ),

                  // Last Name
                  CustomTextField(
                    controller: _lastNameController,
                    labelText: 'Last Name',
                    hintText: 'Enter your last name',
                    prefixIcon: Icons.person_outline_rounded,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Last name is required';
                      }
                      return null;
                    },
                  ),

                  // Username
                  CustomTextField(
                    controller: _usernameController,
                    labelText: 'Username',
                    hintText: 'Enter username',
                    prefixIcon: Icons.alternate_email_rounded,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Username is required';
                      }
                      if (value.trim().length < 3) {
                        return 'Username must be at least 3 characters';
                      }
                      return null;
                    },
                  ),

                  // Email
                  CustomTextField(
                    controller: _emailController,
                    labelText: 'Email Address',
                    hintText: 'name@example.com',
                    prefixIcon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 12),
                  Text(
                    'Health & Body Metrics',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E272C),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Age, Weight, Height in a Row or Grid
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CustomTextField(
                          controller: _ageController,
                          labelText: 'Age',
                          hintText: '25',
                          prefixIcon: Icons.calendar_today_rounded,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Req';
                            }
                            final parsed = int.tryParse(value);
                            if (parsed == null || parsed <= 0 || parsed > 120) {
                              return 'Invalid';
                            }
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
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Req';
                            }
                            final parsed = double.tryParse(value);
                            if (parsed == null || parsed <= 50 || parsed > 250) {
                              return 'Invalid';
                            }
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
                          prefixIcon: Icons.scale_rounded,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Req';
                            }
                            final parsed = double.tryParse(value);
                            if (parsed == null || parsed <= 10 || parsed > 300) {
                              return 'Invalid';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  // Blood Group Dropdown
                  const SizedBox(height: 12),
                  Text(
                    'Blood Group',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E272C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!, width: 1.5),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedBloodGroup,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1E272C),
                        ),
                        items: _bloodGroups.map((group) {
                          return DropdownMenuItem(
                            value: group,
                            child: Text(group),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedBloodGroup = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  
                  // Health conditions
                  CustomTextField(
                    controller: _conditionsController,
                    labelText: 'Health Concerns',
                    hintText: 'e.g. Diabetes, High Blood Pressure (comma separated)',
                    prefixIcon: Icons.medical_services_outlined,
                    textInputAction: TextInputAction.done,
                  ),

                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSave,
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
                              'Save Changes',
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
    );
  }
}
