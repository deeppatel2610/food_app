import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../utils/dialog_helper.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  bool _isAnalyzing = false;
  bool _showSlowNetworkWarning = false;
  int _selectedIndex = 0; // 0 = Tracker Tab, 1 = Community Tab
  bool _isInit = false;

  // Scroll controllers & state variables for scroll down loading
  final ScrollController _communityScrollController = ScrollController();
  bool _isCommunityLoadingMore = false;
  int _communityPage = 1;
  bool _hasMoreCommunityPosts = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      Provider.of<UserProvider>(context, listen: false).refreshUserDetails();
      _loadScanHistory();
      _isInit = true;
    }
  }

  Future<void> _loadScanHistory() async {
    if (mounted) {
      setState(() {
        _isLoadingHistory = true;
      });
    }

    try {
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final history = await ApiService.getFoodAnalysisHistory(
        isEat: 'true',
        date: todayStr,
      );

      double totalCalories = 0.0;
      for (var item in history) {
        totalCalories += (item['calories'] as num?)?.toDouble() ?? 0.0;
      }

      if (mounted) {
        setState(() {
          _scanHistory.clear();
          _scanHistory.addAll(history);
          _consumedCalories = totalCalories;
          _isLoadingHistory = false;
        });

        // Re-trigger progress count animation
        _dashboardAnimationController.reset();
        _dashboardAnimationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
        final isNetworkError = e.toString().contains('NetworkException') ||
            e.toString().contains('SocketException');
        if (isNetworkError) {
          DialogHelper.showNetworkErrorDialog(context);
        }
      }
      debugPrint('Failed to load scan history: $e');
    }
  }

  Future<void> _refreshTrackerData() async {
    await Provider.of<UserProvider>(context, listen: false)
        .refreshUserDetails();
    await _loadScanHistory();
  }

  bool _isCommunityLoading = false;

  Future<void> _loadCommunityFeed() async {
    if (mounted) {
      setState(() {
        _isCommunityLoading = true;
        _communityPage = 1;
        _hasMoreCommunityPosts = true;
      });
    }
    try {
      final feed = await ApiService.getCommunityFeed(page: 1, limit: 10);
      if (mounted) {
        setState(() {
          _posts = feed;
        });
      }
    } catch (e) {
      debugPrint('Failed to load community feed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCommunityLoading = false;
        });
      }
    }
  }

  Future<void> _refreshCommunityData() async {
    try {
      final feed = await ApiService.getCommunityFeed(page: 1, limit: 10);
      if (mounted) {
        setState(() {
          _posts = feed;
          _communityPage = 1;
          _hasMoreCommunityPosts = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Feed updated!', style: GoogleFonts.poppins()),
            backgroundColor: const Color(0xFF2ECC71),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to update feed: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red[800],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreCommunityPosts() async {
    if (!_hasMoreCommunityPosts || _isCommunityLoadingMore) return;

    if (mounted) {
      setState(() {
        _isCommunityLoadingMore = true;
      });
    }

    try {
      final nextPage = _communityPage + 1;
      final feed = await ApiService.getCommunityFeed(page: nextPage, limit: 10);
      if (mounted) {
        setState(() {
          if (feed.isEmpty) {
            _hasMoreCommunityPosts = false;
          } else {
            _posts.addAll(feed);
            _communityPage = nextPage;
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load more posts: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCommunityLoadingMore = false;
        });
      }
    }
  }

  // Starting mock posts database
  late List<Map<String, dynamic>> _posts;

  // Dashboard animation variables
  late AnimationController _dashboardAnimationController;
  late Animation<double> _calorieProgressAnimation;
  late Animation<double> _calorieCountAnimation;

  // Scanned food history state
  final List<Map<String, dynamic>> _scanHistory = [];
  double _consumedCalories = 0.0;
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _posts = [];
    _loadCommunityFeed();

    // Add listener for community feed infinite scrolling
    _communityScrollController.addListener(() {
      if (_communityScrollController.position.pixels >=
              _communityScrollController.position.maxScrollExtent - 200 &&
          !_isCommunityLoadingMore) {
        _loadMoreCommunityPosts();
      }
    });

    // Initial dashboard animations
    _dashboardAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _calorieProgressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _dashboardAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _calorieCountAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _dashboardAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _dashboardAnimationController.forward();
  }

  @override
  void dispose() {
    _communityScrollController.dispose();
    _dashboardAnimationController.dispose();
    super.dispose();
  }

  // Handle picking an image from camera or library
  Future<void> _pickAndAnalyzeImage(ImageSource source) async {
    Timer? slowNetworkTimer;
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return; // User cancelled

      setState(() {
        _isAnalyzing = true;
        _showSlowNetworkWarning = false;
      });

      slowNetworkTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && _isAnalyzing) {
          setState(() {
            _showSlowNetworkWarning = true;
          });
        }
      });

      // Send image to our backend ApiService
      final result = await ApiService.analyzeFoodImage(image.path);

      slowNetworkTimer.cancel();

      setState(() {
        _isAnalyzing = false;
      });

      // Navigate to Food Analysis Screen and await returned result
      if (mounted) {
        final addedResult = await Navigator.pushNamed(
          context,
          '/food_analysis',
          arguments: result,
        );

        if (addedResult != null && addedResult is Map<String, dynamic>) {
          setState(() {
            _scanHistory.insert(0, addedResult);
            _consumedCalories += addedResult['calories'] as int;

            // Re-trigger progress count animation
            _dashboardAnimationController.reset();
            _dashboardAnimationController.forward();
          });
        }
      }
    } on ValidationException catch (e) {
      slowNetworkTimer?.cancel();
      setState(() {
        _isAnalyzing = false;
      });
      if (mounted) {
        _showFormattedErrorDialog(
          'Scan Warning',
          e.message,
          Icons.no_food_rounded,
          const Color(0xFFE67E22),
        );
      }
    } on ApiException catch (e) {
      slowNetworkTimer?.cancel();
      setState(() {
        _isAnalyzing = false;
      });
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
      slowNetworkTimer?.cancel();
      setState(() {
        _isAnalyzing = false;
      });
      if (mounted) {
        final isNetworkError = e.toString().contains('NetworkException') ||
            e.toString().contains('SocketException');
        if (isNetworkError) {
          DialogHelper.showNetworkErrorDialog(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to analyze image. Please try again.',
                  style: GoogleFonts.poppins()),
              backgroundColor: Colors.red[800],
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showFormattedErrorDialog(
      String title, String message, IconData icon, Color color) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          icon: Icon(icon, color: color, size: 48),
          title: Text(
            title,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: const Color(0xFF1E272C),
            ),
          ),
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Dismiss',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Opens camera or library selection bottom sheet
  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 20.0, horizontal: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scan Meal Nutrition',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E272C),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Capture or pick an image of your food to identify calories, ingredients, and get health metrics.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPickerOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      color: const Color(0xFF2ECC71),
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndAnalyzeImage(ImageSource.camera);
                      },
                    ),
                    _buildPickerOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      color: const Color(0xFFE67E22),
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndAnalyzeImage(ImageSource.gallery);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Opens bottom sheet with full BMI recommendations directly from backend
  void _showBMIReportBottomSheet(double bmi, String category, String report) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.8,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your BMI Report',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E272C),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2ECC71).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          category,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF27AE60),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // BMI Value Circle Visual
                  Center(
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                            color: const Color(0xFF2ECC71), width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2ECC71).withOpacity(0.15),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              bmi.toStringAsFixed(1),
                              style: GoogleFonts.outfit(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E272C),
                              ),
                            ),
                            Text(
                              'BMI',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                  Text(
                    'NutriLife Clinical Advice',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    report,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Opens interactive bottom comments sheet for community posts
  void _showCommentsBottomSheet(Map<String, dynamic> post) {
    final TextEditingController commentController = TextEditingController();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final List<dynamic> comments = post['comments'] ?? [];
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Comments (${comments.length})',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const Divider(height: 24),

                  // Comments list
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.35,
                    ),
                    child: comments.isEmpty
                        ? Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 24.0),
                              child: Text(
                                'No comments yet. Start the conversation!',
                                style: GoogleFonts.poppins(
                                    color: Colors.grey[400], fontSize: 13),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            itemCount: comments.length,
                            itemBuilder: (context, idx) {
                              final comment = comments[idx];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: const Color(0xFF2ECC71)
                                          .withOpacity(0.1),
                                      child: Text(
                                        comment['author'][0],
                                        style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF27AE60)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                comment['author'],
                                                style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12),
                                              ),
                                              Text(
                                                comment['time'] ?? 'Just now',
                                                style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    color: Colors.grey[400]),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            comment['text'],
                                            style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: Colors.grey[700]),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  const Divider(height: 18),

                  // Comment input box
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: commentController,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle: GoogleFonts.poppins(
                                fontSize: 13, color: Colors.grey[400]),
                            isDense: true,
                            border: InputBorder.none,
                          ),
                          onFieldSubmitted: (text) async {
                            if (text.trim().isEmpty) return;
                            final trimmedText = text.trim();
                            commentController.clear();
                            try {
                              final newComment =
                                  await ApiService.addCommentToPost(
                                      post['id'], trimmedText);
                              setState(() {
                                comments.add(newComment);
                              });
                              setModalState(() {});
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to post comment: $e'),
                                  backgroundColor: Colors.red[800],
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final text = commentController.text.trim();
                          if (text.isEmpty) return;
                          commentController.clear();
                          try {
                            final newComment =
                                await ApiService.addCommentToPost(
                                    post['id'], text);
                            setState(() {
                              comments.add(newComment);
                            });
                            setModalState(() {});
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to post comment: $e'),
                                backgroundColor: Colors.red[800],
                              ),
                            );
                          }
                        },
                        child: Text(
                          'Post',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF27AE60)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    final String firstName = user?.firstName ?? 'Guest';

    // Dynamic Health Calculations (BMI, Category, Report & Calorie Budget supplied directly by backend)
    final double bmi = user?.bmi ?? 0.0;
    final String bmiCategory = user?.bmiCategory ?? 'Normal';
    final String bmiReport = user?.bmiReport ??
        'BMI report and recommendations are provided by the backend API.';
    final double dailyCalorieTarget = userProvider.calorieTarget;

    final caloriePercent =
        (_consumedCalories / dailyCalorieTarget).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      body: Stack(
        children: [
          SafeArea(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                // Tab 0: Dynamic Daily Calorie & BMI Tracker dashboard
                RefreshIndicator(
                  color: const Color(0xFF2ECC71),
                  backgroundColor: Colors.white,
                  onRefresh: _refreshTrackerData,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      // A. Top bar Profile Section
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hello, $firstName! 👋',
                                    style: GoogleFonts.outfit(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1E272C),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Let\'s reach your health goals today.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                              // Circular avatar wrapping ProfileScreen routing
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(context, '/profile');
                                },
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF2ECC71)
                                        .withOpacity(0.1),
                                    border: Border.all(
                                        color: const Color(0xFF2ECC71),
                                        width: 1.5),
                                  ),
                                  child: const Icon(Icons.person,
                                      color: Color(0xFF27AE60), size: 24),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // B. Calorie Budget & BMI Cards
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Card(
                                  elevation: 0,
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                        color: Colors.grey[150]
                                            .colorWithBorderDefault(),
                                        width: 1.5),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      children: [
                                        Text(
                                          'Daily Calories',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        AnimatedBuilder(
                                          animation:
                                              _dashboardAnimationController,
                                          builder: (context, child) {
                                            final currentPercent =
                                                caloriePercent *
                                                    _calorieProgressAnimation
                                                        .value;
                                            final animatedCalories =
                                                (_consumedCalories *
                                                        _calorieCountAnimation
                                                            .value)
                                                    .toInt();
                                            return Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 80,
                                                  height: 80,
                                                  child:
                                                      CircularProgressIndicator(
                                                    value: currentPercent,
                                                    strokeWidth: 7,
                                                    backgroundColor:
                                                        Colors.grey[100],
                                                    valueColor:
                                                        const AlwaysStoppedAnimation<
                                                                Color>(
                                                            Color(0xFF2ECC71)),
                                                  ),
                                                ),
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      animatedCalories
                                                          .toString(),
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: const Color(
                                                            0xFF1E272C),
                                                      ),
                                                    ),
                                                    Text(
                                                      '/${dailyCalorieTarget.toInt()}',
                                                      style:
                                                          GoogleFonts.poppins(
                                                        fontSize: 10,
                                                        color: Colors.grey[500],
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Budget Target',
                                          style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey[400]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _showBMIReportBottomSheet(
                                      bmi, bmiCategory, bmiReport),
                                  child: Card(
                                    elevation: 0,
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                          color: Colors.grey[150]
                                              .colorWithBorderDefault(),
                                          width: 1.5),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        children: [
                                          Text(
                                            'BMI Status',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Container(
                                            width: 70,
                                            height: 70,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: const Color(0xFF2ECC71)
                                                  .withOpacity(0.08),
                                            ),
                                            child: Center(
                                              child: Text(
                                                bmi.toStringAsFixed(1),
                                                style: GoogleFonts.outfit(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w800,
                                                  color:
                                                      const Color(0xFF27AE60),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          Text(
                                            bmiCategory,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF1E272C),
                                            ),
                                          ),
                                          Text(
                                            'Tap for Report',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              color: const Color(0xFF27AE60),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // C. Central Scan Action Bar
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24.0, vertical: 20.0),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF27AE60).withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Ready to Track?',
                                        style: GoogleFonts.outfit(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Take a photo of your food to instantly analyze calories & health impact.',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.85),
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton(
                                  onPressed: _showImageSourcePicker,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF27AE60),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.photo_camera_rounded,
                                          size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Scan',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // D. Scan History Header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24.0, vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Today\'s Food Track',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E272C),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/all_scans');
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'See All Scans',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF27AE60),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 10,
                                      color: Color(0xFF27AE60),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // E. History List Items
                      _isLoadingHistory
                          ? const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 40.0),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF2ECC71),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : _scanHistory.isEmpty
                              ? SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 40.0),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          const Icon(Icons.restaurant_rounded,
                                              size: 48, color: Colors.grey),
                                          const SizedBox(height: 12),
                                          Text(
                                            'No food items scanned today.',
                                            style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: Colors.grey[400]),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final item = _scanHistory[index];
                                      final status = item['status'] as String;

                                      final statusColor = status == 'Healthy'
                                          ? const Color(0xFF2ECC71)
                                          : status == 'Avoid'
                                              ? const Color(0xFFE74C3C)
                                              : const Color(0xFFE67E22);

                                      return TweenAnimationBuilder<double>(
                                        tween:
                                            Tween<double>(begin: 0.0, end: 1.0),
                                        duration: Duration(
                                            milliseconds: 350 +
                                                (index * 80).clamp(0, 300)),
                                        curve: Curves.easeOutQuad,
                                        builder: (context, value, child) {
                                          return Opacity(
                                            opacity: value,
                                            child: Transform.translate(
                                              offset:
                                                  Offset(0, 15 * (1.0 - value)),
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24.0, vertical: 8.0),
                                          child: Card(
                                            elevation: 0,
                                            color: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              side: BorderSide(
                                                  color: Colors.grey[100]!,
                                                  width: 1),
                                            ),
                                            child: ListTile(
                                              contentPadding:
                                                  const EdgeInsets.all(12),
                                              leading: Container(
                                                padding:
                                                    const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: statusColor
                                                      .withOpacity(0.08),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  status == 'Healthy'
                                                      ? Icons.spa_rounded
                                                      : status == 'Avoid'
                                                          ? Icons
                                                              .fastfood_rounded
                                                          : Icons
                                                              .cookie_rounded,
                                                  color: statusColor,
                                                  size: 24,
                                                ),
                                              ),
                                              title: Text(
                                                item['name'],
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      const Color(0xFF1E272C),
                                                ),
                                              ),
                                              subtitle: Text(
                                                '${item['calories']} kcal | ${status.toUpperCase()}',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: statusColor,
                                                ),
                                              ),
                                              trailing: const Icon(
                                                  Icons
                                                      .arrow_forward_ios_rounded,
                                                  size: 14,
                                                  color: Colors.grey),
                                              onTap: () {
                                                // Pass isFromHistory to hide bottom button in details
                                                final Map<String, dynamic>
                                                    argMap =
                                                    Map<String, dynamic>.from(
                                                        item);
                                                argMap['isFromHistory'] = true;
                                                Navigator.pushNamed(
                                                    context, '/food_analysis',
                                                    arguments: argMap);
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    childCount: _scanHistory.length,
                                  ),
                                ),

                      const SliverToBoxAdapter(
                        child: SizedBox(height: 80),
                      )
                    ],
                  ),
                ),

                // Tab 1: Community Feed tab showing Before/After transformations
                RefreshIndicator(
                  color: const Color(0xFF2ECC71),
                  backgroundColor: Colors.white,
                  onRefresh: _refreshCommunityData,
                  child: CustomScrollView(
                    controller: _communityScrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      // A. Feed Header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Community Progress',
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1E272C),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'See weight transformations and share clean diets.',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // B. Scrollable Feed Posts List
                      if (_isCommunityLoading)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(top: 100.0),
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF2ECC71)),
                              ),
                            ),
                          ),
                        )
                      else if (_posts.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 100.0),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.feed_outlined,
                                      size: 48, color: Colors.grey[300]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No transformations shared yet.',
                                    style: GoogleFonts.poppins(
                                        color: Colors.grey[500]),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Be the first to share your progress!',
                                    style: GoogleFonts.poppins(
                                        color: Colors.grey[400], fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final post = _posts[index];
                              final int avatarColor =
                                  post['author_avatar_color'] ?? 0xFF2ECC71;
                              final bool isLiked = post['is_liked'] ?? false;

                              return TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0.0, end: 1.0),
                                duration: Duration(
                                    milliseconds:
                                        350 + (index * 80).clamp(0, 300)),
                                curve: Curves.easeOutQuad,
                                builder: (context, value, child) {
                                  return Opacity(
                                    opacity: value,
                                    child: Transform.translate(
                                      offset: Offset(0, 15 * (1.0 - value)),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24.0, vertical: 10.0),
                                  child: Card(
                                    elevation: 0,
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                          color: Colors.grey[100]!, width: 1.5),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(18.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Post Author Row & DM Navigation link
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 18,
                                                    backgroundColor:
                                                        Color(avatarColor)
                                                            .withOpacity(0.15),
                                                    child: Text(
                                                      post['author_name'][0],
                                                      style: GoogleFonts.outfit(
                                                        color:
                                                            Color(avatarColor),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        post['author_name'],
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                          color: const Color(
                                                              0xFF1E272C),
                                                        ),
                                                      ),
                                                      Text(
                                                        '@${post['author_username']}',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 11,
                                                          color:
                                                              Colors.grey[400],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              // DM Icon (Chat with Author)
                                              IconButton(
                                                icon: const Icon(
                                                    Icons
                                                        .chat_bubble_outline_rounded,
                                                    color: Color(0xFF27AE60),
                                                    size: 20),
                                                onPressed: () {
                                                  Navigator.pushNamed(
                                                    context,
                                                    '/dm',
                                                    arguments: {
                                                      'recipientName':
                                                          post['author_name'],
                                                      'recipientUsername': post[
                                                          'author_username'],
                                                      'avatarColor':
                                                          avatarColor,
                                                    },
                                                  );
                                                },
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 12),

                                          // Caption
                                          Text(
                                            post['caption'],
                                            style: GoogleFonts.poppins(
                                              fontSize: 13.5,
                                              color: Colors.grey[750],
                                              height: 1.45,
                                            ),
                                          ),

                                          const SizedBox(height: 16),

                                          // Before / After comparison layout
                                          Row(
                                            children: [
                                              // Before Photo Box
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    _buildBeforeAfterBox(
                                                      label: 'BEFORE',
                                                      imagePath: post[
                                                          'before_image_path'],
                                                      fallbackColor: const Color(
                                                          0xFFE9F7EF), // soft red/light green
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Center(
                                                      child: Text(
                                                        post['before_metric'],
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              // After Photo Box
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    _buildBeforeAfterBox(
                                                      label: 'AFTER',
                                                      imagePath: post[
                                                          'after_image_path'],
                                                      fallbackColor: const Color(
                                                          0xFFD4F1E1), // deep green
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Center(
                                                      child: Text(
                                                        post['after_metric'],
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 12,
                                                          color: const Color(
                                                              0xFF27AE60),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),

                                          const Divider(
                                              height: 32, thickness: 1.2),

                                          // Interactions Bar (Like, Comment, Share)
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              // Like Button with pulse animation
                                              LikeButtonAnimated(
                                                isLiked: isLiked,
                                                likesCount:
                                                    post['likes'] as int,
                                                onTap: () async {
                                                  final originalIsLiked =
                                                      isLiked;
                                                  final originalLikes =
                                                      post['likes'] as int;
                                                  setState(() {
                                                    post['is_liked'] = !isLiked;
                                                    post['likes'] = isLiked
                                                        ? originalLikes - 1
                                                        : originalLikes + 1;
                                                  });
                                                  try {
                                                    await ApiService
                                                        .toggleLikePost(
                                                            post['id']);
                                                  } catch (e) {
                                                    // Revert status on failure
                                                    setState(() {
                                                      post['is_liked'] =
                                                          originalIsLiked;
                                                      post['likes'] =
                                                          originalLikes;
                                                    });
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                            'Failed to update like status: $e'),
                                                        backgroundColor:
                                                            Colors.red[800],
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                              // Comment Button
                                              InkWell(
                                                onTap: () =>
                                                    _showCommentsBottomSheet(
                                                        post),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                        Icons
                                                            .mode_comment_outlined,
                                                        color: Colors.grey[600],
                                                        size: 18),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      (post['comments']
                                                              as List<dynamic>)
                                                          .length
                                                          .toString(),
                                                      style:
                                                          GoogleFonts.poppins(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Share Button
                                              InkWell(
                                                onTap: () {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          'Transformation link copied to clipboard!',
                                                          style: GoogleFonts
                                                              .poppins()),
                                                      backgroundColor:
                                                          const Color(
                                                              0xFF2ECC71),
                                                      behavior: SnackBarBehavior
                                                          .floating,
                                                    ),
                                                  );
                                                },
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.share_outlined,
                                                        color: Colors.grey[600],
                                                        size: 18),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: _posts.length,
                          ),
                        ),

                      if (_isCommunityLoadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.0),
                            child: Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF2ECC71)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 100),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),

          // loader for API scan request
          if (_isAnalyzing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF2ECC71)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'NutriLife Image AI',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Analyzing ingredients & nutrition...',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (_showSlowNetworkWarning) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF9E7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFF39C12), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.wifi_off_rounded,
                                  color: Color(0xFFD35400),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Slow connection detected. Please wait...',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF7E5109),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),

      // Centered Floating Action Button notched in bottom navigation
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newPost = await Navigator.pushNamed(
            context,
            '/add_daily_post',
          );
          if (newPost != null && newPost is Map<String, dynamic>) {
            setState(() {
              _posts.insert(0, newPost);
            });
          }
        },
        backgroundColor: const Color(0xFF2ECC71),
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add_a_photo_rounded,
            color: Colors.white, size: 24),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Custom notched BottomAppBar with Left and Right tabs
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        elevation: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Tracker Tab
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedIndex = 0;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.track_changes_rounded,
                          color: _selectedIndex == 0
                              ? const Color(0xFF27AE60)
                              : Colors.grey[400],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tracker',
                          style: GoogleFonts.poppins(
                            fontWeight: _selectedIndex == 0
                                ? FontWeight.w600
                                : FontWeight.w500,
                            fontSize: 11,
                            color: _selectedIndex == 0
                                ? const Color(0xFF27AE60)
                                : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Spacing for FAB
              const SizedBox(width: 48),

              // Community Tab
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedIndex = 1;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.diversity_3_rounded,
                          color: _selectedIndex == 1
                              ? const Color(0xFF27AE60)
                              : Colors.grey[400],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Community',
                          style: GoogleFonts.poppins(
                            fontWeight: _selectedIndex == 1
                                ? FontWeight.w600
                                : FontWeight.w500,
                            fontSize: 11,
                            color: _selectedIndex == 1
                                ? const Color(0xFF27AE60)
                                : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBeforeAfterBox({
    required String label,
    required String? imagePath,
    required Color fallbackColor,
  }) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: imagePath == null ? fallbackColor : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: imagePath != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: imagePath.startsWith('http')
                  ? Image.network(
                      imagePath,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                        child: Icon(Icons.broken_image_rounded,
                            color: Colors.grey),
                      ),
                    )
                  : Image.file(
                      File(imagePath),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF27AE60).withOpacity(0.6),
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(Icons.photo_rounded,
                      color: const Color(0xFF27AE60).withOpacity(0.3),
                      size: 24),
                ],
              ),
            ),
    );
  }
}

extension GreyTextDefaultBorderExtension on Color? {
  Color colorWithBorderDefault() {
    return const Color(0xFFF2F2F2);
  }
}

// ----------------------------------------------------
// Animated Like Button (Pulse scale animation on tap)
// ----------------------------------------------------
class LikeButtonAnimated extends StatefulWidget {
  final bool isLiked;
  final int likesCount;
  final VoidCallback onTap;

  const LikeButtonAnimated({
    super.key,
    required this.isLiked,
    required this.likesCount,
    required this.onTap,
  });

  @override
  State<LikeButtonAnimated> createState() => _LikeButtonAnimatedState();
}

class _LikeButtonAnimatedState extends State<LikeButtonAnimated>
    with SingleTickerProviderStateMixin {
  late AnimationController _likeController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(
        CurvedAnimation(parent: _likeController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LikeButtonAnimated oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked != oldWidget.isLiked && widget.isLiked) {
      _likeController.reset();
      _likeController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        widget.onTap();
        if (!widget.isLiked) {
          _likeController.reset();
          _likeController.forward();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Row(
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Icon(
                widget.isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_outline_rounded,
                color: widget.isLiked ? Colors.red : Colors.grey[600],
                size: 20,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              widget.likesCount.toString(),
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
