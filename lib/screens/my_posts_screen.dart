import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  List<Map<String, dynamic>> _myPosts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMyPosts();
  }

  Future<void> _loadMyPosts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      final posts = await ApiService.getMyPosts();
      if (mounted) {
        setState(() {
          _myPosts = posts;
        });
      }
    } catch (e) {
      debugPrint('Failed to load my posts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load your posts: $e', style: GoogleFonts.poppins()),
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

  Future<void> _refreshMyPosts() async {
    try {
      final posts = await ApiService.getMyPosts();
      if (mounted) {
        setState(() {
          _myPosts = posts;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh posts: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red[800],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showCommentsBottomSheet(Map<String, dynamic> post) {
    final commentController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
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
                              padding: const EdgeInsets.symmetric(vertical: 24.0),
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
                                        comment['author'].isNotEmpty ? comment['author'][0] : 'U',
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
                              final newComment = await ApiService.addCommentToPost(post['id'], trimmedText);
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
                            final newComment = await ApiService.addCommentToPost(post['id'], text);
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
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.broken_image_rounded, color: Colors.grey),
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
                  Icon(Icons.photo_library_rounded, size: 28, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.grey[500],
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: Text(
          'My Transformations',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: const Color(0xFF1E272C)),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E272C), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF2ECC71),
        backgroundColor: Colors.white,
        onRefresh: _refreshMyPosts,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2ECC71)),
                ),
              )
            : _myPosts.isEmpty
                ? CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_album_outlined, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                "No progress posts yet.",
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1E272C),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                                child: Text(
                                  "Share your personal diet transitions or weight changes with the community!",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final newPost = await Navigator.pushNamed(
                                    context,
                                    '/add_daily_post',
                                  );
                                  if (newPost != null) {
                                    _loadMyPosts();
                                  }
                                },
                                icon: const Icon(Icons.add_rounded, color: Colors.white),
                                label: Text(
                                  'Share Transformation',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2ECC71),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    ],
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _myPosts.length,
                    itemBuilder: (context, index) {
                      final post = _myPosts[index];
                      final bool isLiked = post['is_liked'] ?? false;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
                        child: Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.grey[100]!, width: 1.5),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(18.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: const Color(0xFF2ECC71).withOpacity(0.15),
                                      child: Text(
                                        post['author_name'].isNotEmpty ? post['author_name'][0] : 'U',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF27AE60),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          post['author_name'],
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: const Color(0xFF1E272C),
                                          ),
                                        ),
                                        Text(
                                          '@${post['author_username']}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  post['caption'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.5,
                                    color: Colors.grey[750],
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildBeforeAfterBox(
                                            label: 'BEFORE',
                                            imagePath: post['before_image_path'],
                                            fallbackColor: const Color(0xFFE9F7EF),
                                          ),
                                          const SizedBox(height: 6),
                                          Center(
                                            child: Text(
                                              post['before_metric'],
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildBeforeAfterBox(
                                            label: 'AFTER',
                                            imagePath: post['after_image_path'],
                                            fallbackColor: const Color(0xFFD4F1E1),
                                          ),
                                          const SizedBox(height: 6),
                                          Center(
                                            child: Text(
                                              post['after_metric'],
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: const Color(0xFF27AE60),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 32, thickness: 1.2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Likes count summary
                                    Row(
                                      children: [
                                        Icon(
                                          isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                          color: isLiked ? const Color(0xFFE74C3C) : Colors.grey[400],
                                          size: 20,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${post['likes']} likes',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Comments trigger button
                                    InkWell(
                                      onTap: () => _showCommentsBottomSheet(post),
                                      child: Row(
                                        children: [
                                          Icon(Icons.mode_comment_outlined, color: Colors.grey[600], size: 18),
                                          const SizedBox(width: 6),
                                          Text(
                                            (post['comments'] as List<dynamic>).length.toString(),
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Share Icon
                                    IconButton(
                                      icon: Icon(Icons.share_outlined, color: Colors.grey[600], size: 18),
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Transformation link copied to clipboard!', style: GoogleFonts.poppins()),
                                            backgroundColor: const Color(0xFF2ECC71),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
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
    );
  }
}
