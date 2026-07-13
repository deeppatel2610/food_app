class ApiEndpoints {
  static const String authPrefix = 'auth/';
  static const String login = 'auth/login';
  static const String register = 'auth/register';
  static const String refresh = 'auth/refresh';
  static const String forgotPassword = 'auth/forgot-password';
  static const String resetPassword = 'auth/reset-password';
  static const String user = 'user';
  static const String foodAnalyze = 'food/analyze';
  static const String foodHistory = 'food/history';
  static const String community = 'community';
  static const String myPosts = 'community/my-posts';

  static String foodHistoryItem(dynamic id) => 'food/history/$id';
  static String likePost(dynamic postId) => 'community/$postId/like';
  static String commentPost(dynamic postId) => 'community/$postId/comment';
}
