import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class AddDailyPostScreen extends StatefulWidget {
  const AddDailyPostScreen({super.key});

  @override
  State<AddDailyPostScreen> createState() => _AddDailyPostScreenState();
}

class _AddDailyPostScreenState extends State<AddDailyPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _captionController = TextEditingController();
  final _beforeWeightController = TextEditingController();
  final _afterWeightController = TextEditingController();
  
  final ImagePicker _picker = ImagePicker();
  String? _beforeImagePath;
  String? _afterImagePath;

  @override
  void dispose() {
    _captionController.dispose();
    _beforeWeightController.dispose();
    _afterWeightController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isBefore) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 80,
      );
      
      if (image == null) return;

      setState(() {
        if (isBefore) {
          _beforeImagePath = image.path;
        } else {
          _afterImagePath = image.path;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select image: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    }
  }

  void _handlePublish(Map<String, dynamic> user) {
    if (_formKey.currentState!.validate()) {
      if (_beforeImagePath == null || _afterImagePath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select both Before and After images.', style: GoogleFonts.poppins()),
            backgroundColor: Colors.orange[800],
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Construct a new post map to return back to Feed
      final newPost = {
        'id': 'post-${DateTime.now().millisecondsSinceEpoch}',
        'author_name': '${user['first_name'] ?? 'Guest'} ${user['last_name'] ?? ''}'.trim(),
        'author_username': user['username'] ?? 'guest',
        'author_avatar_color': 0xFF2ECC71, // Green accent for the user
        'caption': _captionController.text.trim(),
        'before_metric': _beforeWeightController.text.trim(),
        'after_metric': _afterWeightController.text.trim(),
        'before_image_path': _beforeImagePath,
        'after_image_path': _afterImagePath,
        'likes': 0,
        'is_liked': false,
        'comments': [],
      };

      Navigator.pop(context, newPost);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get user details from UserProvider
    final userModel = Provider.of<UserProvider>(context).user;
    final user = userModel?.toJson() ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: Text(
          'Share Progress',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: const Color(0xFF1E272C)),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF1E272C)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Show Your Transformation',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E272C),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Upload side-by-side images of your progress, meals, or weight transformation.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 28),

              // Before & After Image Pickers
              Row(
                children: [
                  // Before Picker
                  Expanded(
                    child: _buildImageSelector(
                      label: 'Before',
                      imagePath: _beforeImagePath,
                      onTap: () => _pickImage(true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // After Picker
                  Expanded(
                    child: _buildImageSelector(
                      label: 'After',
                      imagePath: _afterImagePath,
                      onTap: () => _pickImage(false),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Before & After Metric labels input
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _beforeWeightController,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Before Weight/Label',
                        hintText: 'e.g. 85 kg',
                        labelStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                        fillColor: Colors.white,
                        filled: true,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[200]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2ECC71), width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.red[300]!, width: 1.5),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _afterWeightController,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'After Weight/Label',
                        hintText: 'e.g. 72 kg',
                        labelStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                        fillColor: Colors.white,
                        filled: true,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[200]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2ECC71), width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.red[300]!, width: 1.5),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Caption Field
              TextFormField(
                controller: _captionController,
                maxLines: 4,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Caption / Progress Details',
                  hintText: 'Share your routine, tips, and diet targets (e.g. cardio twice a week, clean calorie budget)...',
                  labelStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
                  fillColor: Colors.white,
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF2ECC71), width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.red[300]!, width: 1.5),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a description.' : null,
              ),

              const SizedBox(height: 36),

              // Publish Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _handlePublish(user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Publish Transformation',
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
    );
  }

  Widget _buildImageSelector({
    required String label,
    required String? imagePath,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
          child: Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[800]),
          ),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!, width: 1.5),
            ),
            child: imagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      File(imagePath),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: Colors.grey[400], size: 36),
                        const SizedBox(height: 8),
                        Text(
                          'Upload Photo',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400], fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
