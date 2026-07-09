import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late double _calorieTarget;
  late TextEditingController _calorieController;
  bool _isInit = false;

  @override
  void dispose() {
    _calorieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    if (!_isInit) {
      _calorieTarget = userProvider.calorieTarget;
      _calorieController =
          TextEditingController(text: _calorieTarget.toInt().toString());
      _isInit = true;
    }

    final String firstName = user?.firstName ?? 'John';
    final String lastName = user?.lastName ?? 'Doe';
    final String username = user?.username ?? 'johndoe';
    final String email = user?.email ?? 'john@example.com';
    final int age = user?.age ?? 25;
    final double weight = user?.weight ?? 70.0;
    final double height = user?.height ?? 175.0;
    final String bloodGroup = user?['blood_group']?.toString() ?? 'O+';
    final List<dynamic> conditions = user?.healthConditions ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700, color: const Color(0xFF1E272C)),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1E272C)),
          onPressed: () => Navigator.pop(context), // Go back without changes
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Color(0xFF27AE60)),
            tooltip: 'Edit Profile',
            onPressed: () {
              Navigator.pushNamed(context, '/edit_profile');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // 1. Profile Avatar Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2ECC71).withOpacity(0.1),
                      border:
                          Border.all(color: const Color(0xFF2ECC71), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2ECC71).withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Color(0xFF27AE60),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '$firstName $lastName',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E272C),
                    ),
                  ),
                  Text(
                    '@$username',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // 2. Health & Body Details Card
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey[100]!, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.fitness_center_rounded,
                            color: Color(0xFF27AE60), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Body & Health Metrics',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E272C),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, thickness: 1.2),

                    // Grid-like structure for health details
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetricItem('Age', '$age yrs'),
                        _buildMetricItem(
                            'Weight', '${weight.toStringAsFixed(1)} kg'),
                        _buildMetricItem(
                            'Height', '${height.toStringAsFixed(0)} cm'),
                        _buildMetricItem('Blood Type', bloodGroup),
                      ],
                    ),

                    const SizedBox(height: 18),
                    Text(
                      'Email Address:',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      email,
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500),
                    ),

                    if (conditions.isNotEmpty &&
                        conditions.first != 'None') ...[
                      const SizedBox(height: 14),
                      Text(
                        'Registered Health Concerns:',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: conditions.map((cond) {
                          return Chip(
                            label: Text(
                              cond.toString(),
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.orange[800],
                                  fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: Colors.orange[50],
                            side: BorderSide(color: Colors.orange[100]!),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 3. Calorie Goal Configuration Card
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey[100]!, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded,
                            color: Color(0xFFE67E22), size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Daily Calorie Budget',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E272C),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, thickness: 1.2),
                    Text(
                      'Customize your daily target calorie budget. Adjust it depending on your diet plans or workout frequency.',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey[500], height: 1.4),
                    ),

                    const SizedBox(height: 20),

                    // Slider + Text Field Row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: const Color(0xFF2ECC71),
                              inactiveTrackColor: Colors.grey[100],
                              thumbColor: const Color(0xFF27AE60),
                              overlayColor:
                                  const Color(0xFF2ECC71).withOpacity(0.12),
                              trackHeight: 6,
                            ),
                            child: Slider(
                              value: _calorieTarget,
                              min: 1200.0,
                              max: 4000.0,
                              divisions: 56, // divisions of 50 kcal
                              onChanged: (value) {
                                setState(() {
                                  _calorieTarget = value;
                                  _calorieController.text =
                                      value.toInt().toString();
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _calorieController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: const Color(0xFF1E272C),
                            ),
                            decoration: InputDecoration(
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              suffixText: 'kcal',
                              suffixStyle: GoogleFonts.poppins(
                                  fontSize: 10, color: Colors.grey),
                              fillColor: const Color(0xFFF9FBF9),
                              filled: true,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey[200]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF2ECC71), width: 1.5),
                              ),
                            ),
                            onChanged: (text) {
                              final parsed = double.tryParse(text);
                              if (parsed != null &&
                                  parsed >= 1200.0 &&
                                  parsed <= 4000.0) {
                                setState(() {
                                  _calorieTarget = parsed;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('1200 kcal',
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: Colors.grey[400])),
                        Text(
                          'Selected: ${_calorieTarget.toInt()} kcal',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF27AE60)),
                        ),
                        Text('4000 kcal',
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: Colors.grey[400])),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // My Progress Posts / Transformations navigation button card
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey[100]!, width: 1.5),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF27AE60)),
                ),
                title: Text(
                  'My Transformations',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E272C),
                  ),
                ),
                subtitle: Text(
                  'View and manage your progress posts',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                onTap: () {
                  Navigator.pushNamed(context, '/my_posts');
                },
              ),
            ),

            const SizedBox(height: 28),

            // 4. Save Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  userProvider.setCalorieTarget(_calorieTarget);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  foregroundColor: Colors.white,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Save Target Changes',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 5. Logout Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () async {
                  await userProvider.logout();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/login', (route) => false);
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red[300]!, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Logout',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.red[600],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey[400],
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
              fontSize: 14,
              color: const Color(0xFF1E272C),
              fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
