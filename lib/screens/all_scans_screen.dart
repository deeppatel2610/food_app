import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../utils/dialog_helper.dart';

class AllScansScreen extends StatefulWidget {
  const AllScansScreen({super.key});

  @override
  State<AllScansScreen> createState() => _AllScansScreenState();
}

class _AllScansScreenState extends State<AllScansScreen> {
  final List<Map<String, dynamic>> _scanHistory = [];
  bool _isLoading = false;
  DateTime? _selectedDate;
  String _selectedIsEat = 'all'; // 'all', 'true', 'false'

  @override
  void initState() {
    super.initState();
    _fetchFilteredHistory();
  }

  Future<void> _fetchFilteredHistory() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final String? dateParam = _selectedDate != null
          ? _selectedDate!.toIso8601String().split('T')[0]
          : null;
      final String? isEatParam = _selectedIsEat == 'all' ? null : _selectedIsEat;

      final history = await ApiService.getFoodAnalysisHistory(
        isEat: isEatParam,
        date: dateParam,
      );

      if (mounted) {
        setState(() {
          _scanHistory.clear();
          _scanHistory.addAll(history);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final isNetworkError = e.toString().contains('NetworkException') ||
            e.toString().contains('SocketException');
        if (isNetworkError) {
          DialogHelper.showNetworkErrorDialog(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load history. Please try again.',
                  style: GoogleFonts.poppins()),
              backgroundColor: Colors.red[800],
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedDate = null;
      _selectedIsEat = 'all';
    });
    _fetchFilteredHistory();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2ECC71), // green header
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E272C),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchFilteredHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasActiveFilters = _selectedDate != null || _selectedIsEat != 'all';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: Text(
          'All Scanned History',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E272C),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E272C)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_rounded, color: Color(0xFFE74C3C)),
              onPressed: _clearFilters,
              tooltip: 'Clear Filters',
            ),
        ],
      ),
      body: Column(
        children: [
          // Filters Panel
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
            child: Column(
              children: [
                // Date selector row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F6F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedDate != null
                                  ? const Color(0xFF2ECC71)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 16,
                                    color: _selectedDate != null
                                        ? const Color(0xFF27AE60)
                                        : Colors.grey[500],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _selectedDate != null
                                        ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                        : 'Filter by Date',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: _selectedDate != null
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: _selectedDate != null
                                          ? const Color(0xFF1E272C)
                                          : Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                              if (_selectedDate != null)
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedDate = null;
                                    });
                                    _fetchFilteredHistory();
                                  },
                                  child: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                                )
                              else
                                const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Status Filter Segment
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildFilterChip('All', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Eaten', 'true'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Not Eaten', 'false'),
                  ],
                ),
              ],
            ),
          ),
          
          // History items list
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF2ECC71),
              backgroundColor: Colors.white,
              onRefresh: _fetchFilteredHistory,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2ECC71)),
                      ),
                    )
                  : _scanHistory.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF2F4F2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.receipt_long_rounded,
                                      color: Colors.grey[400],
                                      size: 54,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'No Scanned Items',
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E272C),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    hasActiveFilters
                                        ? 'No history matches your filters.'
                                        : 'Scan meals using the AI tool to trace them here.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  if (hasActiveFilters) ...[
                                    const SizedBox(height: 20),
                                    ElevatedButton(
                                      onPressed: _clearFilters,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2ECC71),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      ),
                                      child: Text(
                                        'Clear Filters',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                          itemCount: _scanHistory.length,
                          itemBuilder: (context, index) {
                            final item = _scanHistory[index];
                            final String foodName = item['name'] ?? 'Scanned Meal';
                            final int calories = item['calories'] ?? 0;
                            final String rating = item['status'] ?? 'Healthy';
                            final String scannedAt = item['scanned_at'] ?? '';
                            final bool isEat = item['isEat'] ?? item['is_eat'] ?? false;

                            final ratingColor = rating == 'Healthy'
                                ? const Color(0xFF2ECC71)
                                : rating == 'Avoid'
                                    ? const Color(0xFFE74C3C)
                                    : const Color(0xFFE67E22);

                            // Format scanned date nicely
                            String dateDisplay = 'Unknown time';
                            try {
                              if (scannedAt.isNotEmpty) {
                                final dt = DateTime.parse(scannedAt).toLocal();
                                final hours = dt.hour.toString().padLeft(2, '0');
                                final minutes = dt.minute.toString().padLeft(2, '0');
                                dateDisplay = '${dt.day}/${dt.month}/${dt.year} at $hours:$minutes';
                              }
                            } catch (_) {}

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: InkWell(
                                onTap: () {
                                  final Map<String, dynamic> argMap =
                                      Map<String, dynamic>.from(item);
                                  argMap['isFromHistory'] = true;
                                  Navigator.pushNamed(
                                    context,
                                    '/food_analysis',
                                    arguments: argMap,
                                  );
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(16.0),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.grey[100]!, width: 1.5),
                                  ),
                                  child: Row(
                                    children: [
                                      // Status indicator color
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: ratingColor.withOpacity(0.08),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isEat ? Icons.done_all_rounded : Icons.history_toggle_off_rounded,
                                          color: isEat ? const Color(0xFF27AE60) : Colors.grey[400],
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      // Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              foodName,
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: const Color(0xFF1E272C),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              dateDisplay,
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: Colors.grey[400],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Calories and Tag
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '$calories kcal',
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: const Color(0xFF1E272C),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // Eaten / Not Eaten Badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isEat
                                                  ? const Color(0xFFD4F1E1)
                                                  : const Color(0xFFECECEC),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              isEat ? 'Eaten' : 'Scanned',
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isEat
                                                    ? const Color(0xFF27AE60)
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final bool isSelected = _selectedIsEat == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIsEat = value;
          });
          _fetchFilteredHistory();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2ECC71) : const Color(0xFFF5F6F5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF1E272C),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
