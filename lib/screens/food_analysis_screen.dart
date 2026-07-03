import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../utils/dialog_helper.dart';

class FoodAnalysisScreen extends StatefulWidget {
  const FoodAnalysisScreen({super.key});

  @override
  State<FoodAnalysisScreen> createState() => _FoodAnalysisScreenState();
}

class _FoodAnalysisScreenState extends State<FoodAnalysisScreen> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    // Extract food analysis data map passed as route arguments
    final foodData = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final bool isFromHistory = foodData['isFromHistory'] ?? false;

    final String name = foodData['name'] ?? 'Scanned Meal';
    final int calories = foodData['calories'] ?? 0;
    final String status = foodData['status'] ?? 'Healthy';
    final String advice = foodData['advice'] ?? '';
    final bool isOpenFood = foodData['isOpenFood'] ?? false;
    
    final List<dynamic> goodIngredients = foodData['goodIngredients'] ?? [];
    final List<dynamic> badIngredients = foodData['badIngredients'] ?? [];

    final statusColor = status == 'Healthy'
        ? const Color(0xFF2ECC71)
        : status == 'Avoid'
            ? const Color(0xFFE74C3C)
            : const Color(0xFFE67E22);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: Text(
          'Nutrition Analysis',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: const Color(0xFF1E272C)),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E272C)),
          onPressed: () => Navigator.pop(context), // Close without adding
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Food Name & Calorie Card
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.0),
                      side: BorderSide(color: Colors.grey[100]!, width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                status == 'Healthy'
                                    ? Icons.spa_rounded
                                    : status == 'Avoid'
                                        ? Icons.fastfood_rounded
                                        : Icons.cookie_rounded,
                                color: statusColor,
                                size: 36,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E272C),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$calories kcal',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF27AE60),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$status Selection',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. Open Food Warning Card (if applicable)
                  if (isOpenFood)
                    Card(
                      elevation: 0,
                      color: const Color(0xFFFEF9E7), // Light warm yellow/amber
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: Color(0xFFF39C12), width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFD35400),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Open / Unpackaged Food Warning',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: const Color(0xFF7E5109),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'This is loose/unpackaged food, so the exact ingredients cannot be fully determined. The nutritional values and ingredients shown are approximate estimates.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: const Color(0xFF9A7D0A),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // 3. Ingredients Section with Color Coding
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.0),
                      side: BorderSide(color: Colors.grey[100]!, width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.list_alt_rounded, color: Color(0xFF27AE60), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Ingredient Breakdown',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E272C),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24, thickness: 1.2),

                          // A. Healthy / Good Ingredients (Green)
                          if (goodIngredients.isNotEmpty) ...[
                            Text(
                              'Beneficial Ingredients (Good):',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF27AE60),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: goodIngredients.map((ing) {
                                return Chip(
                                  avatar: const Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 16),
                                  label: Text(
                                    ing.toString(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: const Color(0xFF27AE60),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  backgroundColor: const Color(0xFFD4F1E1).withOpacity(0.3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Color(0xFFD4F1E1), width: 1.5),
                                  ),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // B. Avoid / Bad Ingredients (Red)
                          if (badIngredients.isNotEmpty) ...[
                            Text(
                              'Ingredients to Limit (Avoid):',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFE74C3C),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: badIngredients.map((ing) {
                                return Chip(
                                  avatar: const Icon(Icons.cancel, color: Color(0xFFE74C3C), size: 16),
                                  label: Text(
                                    ing.toString(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: const Color(0xFFC0392B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  backgroundColor: const Color(0xFFFADBD8).withOpacity(0.3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Color(0xFFFADBD8), width: 1.5),
                                  ),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 4. Custom Dietary Advice Card
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
                              const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFE67E22), size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'Health Advisory',
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
                            advice,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Add to Daily Tracker Button
          if (!isFromHistory)
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFECECEC), width: 1)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          final dynamic recordId = foodData['id'];
                          if (recordId != null) {
                            setState(() {
                              _isSaving = true;
                            });
                            try {
                              await ApiService.updateFoodIsEatStatus(recordId, true);
                              if (context.mounted) {
                                Navigator.pop(context, foodData);
                              }
                            } on ApiException catch (e) {
                              if (context.mounted) {
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
                              if (context.mounted) {
                                final isNetworkError = e.toString().contains('NetworkException') ||
                                    e.toString().contains('SocketException');
                                if (isNetworkError) {
                                  DialogHelper.showNetworkErrorDialog(context);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to add to tracker. Please try again.',
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
                                  _isSaving = false;
                                });
                              }
                            }
                          } else {
                            Navigator.pop(context, foodData);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Add to Daily Tracker',
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
    );
  }
}
