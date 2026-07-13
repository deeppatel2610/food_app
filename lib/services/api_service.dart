import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/env_variables.dart';
import '../utils/shared_preferences_key.dart';
import 'api_exceptions.dart';
import '../models/user_model.dart';
import '../models/food_analysis_model.dart';

export 'api_exceptions.dart';

class ApiService {
  static Dio? _dioInstance;

  static Dio get _dio {
    if (_dioInstance == null) {
      String baseUrl = '';
      if (kReleaseMode) {
        baseUrl = prodApiUrl.isNotEmpty ? prodApiUrl : devApiUrl;
      } else {
        baseUrl = devApiUrl.isNotEmpty ? devApiUrl : prodApiUrl;
      }
      if (baseUrl.isEmpty) {
        baseUrl = 'http://127.0.0.1:3000/api/';
      }
      if (!baseUrl.endsWith('/')) {
        baseUrl = '$baseUrl/';
      }
      _dioInstance = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        ),
      );

      _dioInstance!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (!options.path.startsWith('auth/')) {
              final prefs = await SharedPreferences.getInstance();
              final token = prefs.getString(accessTokenKey);
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
            }
            return handler.next(options);
          },
          onError: (DioException e, handler) async {
            if (e.response?.statusCode == 401) {
              if (e.requestOptions.path != 'auth/refresh') {
                try {
                  final newToken = await refreshToken();
                  e.requestOptions.headers['Authorization'] = 'Bearer $newToken';
                  final response = await _dioInstance!.fetch(e.requestOptions);
                  return handler.resolve(response);
                } catch (refreshError) {
                  return handler.next(DioException(
                    requestOptions: e.requestOptions,
                    error: refreshError,
                    response: e.response,
                    type: e.type,
                  ));
                }
              }
            }
            return handler.next(e);
          },
        ),
      );
    }
    return _dioInstance!;
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(accessTokenKey);
    return token != null && token.isNotEmpty;
  }

  // Retrieve saved user data
  static Future<Map<String, dynamic>?> getSavedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(userDataKey);
    if (userStr != null && userStr.isNotEmpty) {
      try {
        final rawUser = jsonDecode(userStr) as Map<String, dynamic>;
        return UserModel.fromJson(rawUser).toJson();
      } catch (_) {}
    }
    return null;
  }

  // Logout and clear tokens
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(accessTokenKey);
    await prefs.remove(refreshTokenKey);
    await prefs.remove(userDataKey);
  }

  static Future<String>? _refreshFuture;

  // Refresh Access Token API using POST /auth/refresh
  static Future<String> refreshToken() async {
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }

    final future = () async {
      final prefs = await SharedPreferences.getInstance();
      final savedRefreshToken = prefs.getString(refreshTokenKey);

      if (savedRefreshToken == null || savedRefreshToken.isEmpty) {
        await logout();
        throw AuthException('No refresh token found. Please log in again.');
      }

      try {
        final response = await _dio.post(
          'auth/refresh',
          data: {
            'refreshToken': savedRefreshToken,
          },
        );

        final responseData = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : {};

        if (response.statusCode == 200 && responseData['success'] == true) {
          final data = responseData['data'] ?? {};
          final newAccessToken = data['accessToken']?.toString() ?? '';

          if (newAccessToken.isNotEmpty) {
            await prefs.setString(accessTokenKey, newAccessToken);
            return newAccessToken;
          } else {
            throw AuthException('Invalid access token returned from server.');
          }
        } else {
          await logout();
          final message = responseData['message'] ?? 'Session expired. Please log in again.';
          throw AuthException(message);
        }
      } on DioException catch (e) {
        if (e.response != null &&
            (e.response?.statusCode == 403 || e.response?.statusCode == 401)) {
          await logout();
          throw AuthException('Refresh token expired or invalid. Please log in again.');
        } else {
          throw NetworkException('Network error occurred while refreshing token.');
        }
      } catch (e) {
        if (e is AuthException) rethrow;
        throw ApiException('Unexpected error while refreshing token: $e');
      }
    }();

    _refreshFuture = future;
    try {
      return await future;
    } finally {
      _refreshFuture = null;
    }
  }

  // Get User Details using GET /user API endpoint (ID is read from JWT token)
  static Future<Map<String, dynamic>> getUserDetails(dynamic id, [String? token]) async {
    try {
      final response = await _dio.get('user');
      final responseData = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {};

      if (responseData['success'] == true) {
        final rawUser = responseData['data'] ?? {};
        final user = UserModel.fromJson(rawUser).toJson();

        // Save user data to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(userDataKey, jsonEncode(user));

        return user;
      } else {
        final message = responseData['message'] ?? 'Failed to fetch user details.';
        throw ApiException(message, response.statusCode);
      }
    } catch (e, stack) {
      _handleError(e, stack);
    }
  }

  // 1. Real Login Method using Dio connecting to Backend API
  static Future<Map<String, dynamic>> login(String identifier, String password) async {
    try {
      final response = await _dio.post(
        'auth/login',
        data: {
          'identifier': identifier,
          'password': password,
        },
      );

      final responseData = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {};

      if (responseData['success'] == true) {
        final data = responseData['data'] ?? {};
        final accessToken = data['accessToken'] ?? '';
        final refreshToken = data['refreshToken'] ?? '';
        final userId = data['userId'] ??
            (data['user'] != null ? data['user']['id'] : null);

        // Save tokens to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(accessTokenKey, accessToken);
        await prefs.setString(refreshTokenKey, refreshToken);

        Map<String, dynamic> user = {};
        if (data['user'] != null && data['user'] is Map) {
          user = UserModel.fromJson(data['user']).toJson();
          await prefs.setString(userDataKey, jsonEncode(user));
        } else if (userId != null) {
          user = await getUserDetails(userId);
        }

        return {
          'status': 'success',
          'token': accessToken,
          'user': user,
        };
      } else {
        final message = responseData['message'] ?? 'Login failed. Please check your credentials.';
        throw ApiException(message, response.statusCode);
      }
    } catch (e, stack) {
      _handleError(e, stack);
    }
  }

  // 2. Real Registration Method using Dio connecting to Backend API
  static Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
    required int age,
    required double weight,
    required double height,
    required String bloodGroup,
    List<String>? healthConditions,
    String? additionalConcerns,
  }) async {
    try {
      final healthProblemList = <String>[];
      if (healthConditions != null && healthConditions.isNotEmpty) {
        healthProblemList.addAll(healthConditions);
      }
      if (additionalConcerns != null && additionalConcerns.isNotEmpty) {
        healthProblemList.add(additionalConcerns);
      }
      final healthProblem =
          healthProblemList.isNotEmpty ? healthProblemList.join(', ') : 'None';

      final response = await _dio.post(
        'auth/register',
        data: {
          'first_name': firstName,
          'firstName': firstName,
          'last_name': lastName,
          'lastName': lastName,
          'username': username,
          'email': email,
          'password': password,
          'age': age,
          'weight': weight,
          'height': height,
          'blood_group': bloodGroup,
          'bloodGroup': bloodGroup,
          'health_problem': healthProblem,
          'healthProblem': healthProblem,
        },
      );

      final responseData = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {};

      if (responseData['success'] == true) {
        final user = UserModel.fromJson(responseData['data'] ?? {}).toJson();
        return {
          'status': 'success',
          'message': responseData['message'] ?? 'Account registered successfully!',
          'user': user,
        };
      } else {
        final message = responseData['message'] ?? 'Registration failed. Please check inputs.';
        throw ApiException(message, response.statusCode);
      }
    } catch (e, stack) {
      _handleError(e, stack);
    }
  }

  // 3. Real Image Scan Analysis Method connecting to Backend API
  static Future<Map<String, dynamic>> analyzeFoodImage(String imagePath, [String? token]) async {
    if (imagePath.isEmpty) {
      throw ValidationException('No image path provided for analysis.');
    }

    try {
      final fileName = imagePath.split(RegExp(r'[/\\]')).last;
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imagePath,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        'food/analyze',
        data: formData,
      );

      final responseData = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {};

      if (responseData['success'] == true) {
        final responsePayload = responseData['data'] ?? {};
        final data = responsePayload['analysis'] ?? {};
        final isFood = data['isFood'] ?? data['is_food'] ?? false;
        if (!isFood) {
          final msg = data['message'] ?? 'The uploaded image does not appear to contain any food or food package.';
          throw ValidationException(msg);
        }

        final model = FoodAnalysisModel.fromJson(responsePayload);
        final foodData = model.toJson();
        final ingredients = data['ingredients'] ?? {};
        final List<dynamic> goodIngredients = ingredients['healthy'] ?? [];
        foodData['goodIngredients'] = goodIngredients;
        foodData['local_image_path'] = imagePath;
        foodData['scanned_at'] = DateTime.now().toIso8601String();

        return foodData;
      } else {
        final message = responseData['message'] ?? 'Failed to analyze image.';
        throw ApiException(message, response.statusCode);
      }
    } catch (e, stack) {
      _handleError(e, stack);
    }
  }

  // 4. Retrieve Food Analysis History from Backend API
  static Future<List<Map<String, dynamic>>> getFoodAnalysisHistory({
    String? isEat,
    String? date,
    String? token,
  }) async {
    try {
      final response = await _dio.get(
        'food/history',
        queryParameters: {
          if (isEat != null) 'isEat': isEat,
          if (date != null) 'date': date,
        },
      );

      final responseData = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {};

      if (responseData['success'] == true) {
        final rawData = responseData['data'];
        final List<dynamic> list;
        if (rawData is List) {
          list = rawData;
        } else if (rawData is Map) {
          list = rawData.values.toList();
        } else {
          list = [];
        }
        final List<Map<String, dynamic>> history = [];

        for (var item in list) {
          final data = item as Map<String, dynamic>;
          final model = FoodAnalysisModel.fromJson(data);
          final foodData = model.toJson();
          final ingredients = data['ingredients'] ?? {};
          final List<dynamic> goodIngredients = ingredients['healthy'] ?? [];
          foodData['goodIngredients'] = goodIngredients;
          history.add(foodData);
        }

        return history;
      } else {
        final message = responseData['message'] ?? 'Failed to retrieve food analysis history.';
        throw ApiException(message, response.statusCode);
      }
    } catch (e, stack) {
      _handleError(e, stack);
    }
  }

  // Update is_eat status of a food analysis record using PATCH /food/history/{id}
  static Future<Map<String, dynamic>> updateFoodIsEatStatus(dynamic id, bool isEat, [String? token]) async {
    try {
      final response = await _dio.patch(
        'food/history/$id',
        data: {
          'is_eat': isEat,
          'isEat': isEat,
        },
      );

      final responseData = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {};

      if (responseData['success'] == true) {
        final data = responseData['data'] ?? {};
        return data is Map<String, dynamic> ? data : {};
      } else {
        final message = responseData['message'] ?? 'Failed to update track status.';
        throw ApiException(message, response.statusCode);
      }
    } catch (e, stack) {
      _handleError(e, stack);
    }
  }

  // Edit User Profile using PUT /user API endpoint
  static Future<Map<String, dynamic>> editUserProfile({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required int age,
    required double weight,
    required double height,
    required String bloodGroup,
    required String healthConditions,
    String? token,
  }) async {
    try {
      final response = await _dio.put(
        'user',
        data: {
          'first_name': firstName,
          'firstName': firstName,
          'last_name': lastName,
          'lastName': lastName,
          'username': username,
          'email': email,
          'age': age,
          'weight': weight,
          'height': height,
          'blood_group': bloodGroup,
          'bloodGroup': bloodGroup,
          'health_problem': healthConditions,
          'healthProblem': healthConditions,
        },
      );

      final responseData = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {};

      if (responseData['success'] == true) {
        final rawUser = responseData['data'] ?? {};
        final user = UserModel.fromJson(rawUser).toJson();

        // Save updated user data to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(userDataKey, jsonEncode(user));

        return user;
      } else {
        final message = responseData['message'] ?? 'Failed to update user profile.';
        throw ApiException(message, response.statusCode);
      }
    } catch (e, stack) {
      _handleError(e, stack);
    }
  }

  // Forgot Password API using POST /auth/forgot-password
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await _dio.post(
        'auth/forgot-password',
        data: {
          'email': email,
        },
      );

      final Map<String, dynamic> responseData = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};

      if (responseData['success'] == true) {
        return responseData['data'] is Map<String, dynamic>
            ? responseData['data'] as Map<String, dynamic>
            : <String, dynamic>{};
      } else {
        final message = responseData['message'] ?? 'Failed to send password reset token.';
        throw ApiException(message, response.statusCode);
      }
    } catch (e, stack) {
      _handleError(e, stack);
    }
  }

  // Reset Password API using POST /auth/reset-password
  static Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        'auth/reset-password',
        data: {
          'token': token,
          'password': password,
        },
      );

      final Map<String, dynamic> responseData = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};

      if (responseData['success'] == true) {
        return responseData;
      } else {
        final message = responseData['message'] ?? 'Failed to reset password.';
        throw ApiException(message, response.statusCode);
      }
    } catch (e, stack) {
      _handleError(e, stack);
    }
  }

  // Get Community Feed using GET /community API
  static Future<List<Map<String, dynamic>>> getCommunityFeed({int page = 1, int limit = 10, String? token}) async {
    try {
      final response = await _dio.get(
        'community',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      final Map<String, dynamic> responseData = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};

      if (responseData['success'] == true) {
        final List<dynamic> list = responseData['data'] ?? [];
        final String originUrl = _dio.options.baseUrl.replaceAll('/api/', '');

        return list.map((item) {
          final map = item as Map<String, dynamic>;

          String beforeImg = map['beforeImagePath']?.toString() ?? '';
          String afterImg = map['afterImagePath']?.toString() ?? '';

          if (beforeImg.isNotEmpty && !beforeImg.startsWith('http')) {
            beforeImg = '$originUrl/$beforeImg';
          }
          if (afterImg.isNotEmpty && !afterImg.startsWith('http')) {
            afterImg = '$originUrl/$afterImg';
          }

          return {
            'id': map['id'],
            'caption': map['caption'] ?? '',
            'before_metric': map['beforeMetric'] ?? '',
            'after_metric': map['afterMetric'] ?? '',
            'before_image_path': beforeImg,
            'after_image_path': afterImg,
            'likes': map['likes'] ?? 0,
            'is_liked': map['isLiked'] ?? false,
            'author_name': map['authorName'] ?? '',
            'author_username': map['authorUsername'] ?? '',
            'author_avatar_color': map['authorAvatarColor'] ?? 0xFF2ECC71,
            'comments': (map['comments'] as List? ?? []).map((c) {
              final commentMap = c as Map<String, dynamic>;
              return {
                'id': commentMap['id'],
                'author': commentMap['author'] ?? '',
                'username': commentMap['username'] ?? '',
                'text': commentMap['content'] ?? commentMap['text'] ?? '',
                'time': commentMap['time'] ?? 'Just now',
              };
            }).toList(),
          };
        }).toList();
      } else {
        final message = responseData['message'] ?? 'Failed to retrieve community feed.';
        throw ApiException(message, response.statusCode);
      }
    } catch (e, stack) {
      _handleError(e, stack);
    }
  }

  // Get User's Own Posts using GET /community/my-posts API
  static Future<List<Map<String, dynamic>>> getMyPosts([String? token]) async {
    try {
      final response = await _dio.get('community/my-posts');

      final Map<String, dynamic> responseData = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};

      if (responseData['success'] == true) {
        final List<dynamic> list = responseData['data'] ?? [];
        final String originUrl = _dio.options.baseUrl.replaceAll('/api/', '');

        return list.map((item) {
          final map = item as Map<String, dynamic>;

          String beforeImg = map['beforeImagePath']?.toString() ?? '';
          String afterImg = map['afterImagePath']?.toString() ?? '';

          if (beforeImg.isNotEmpty && !beforeImg.startsWith('http')) {
            beforeImg = '$originUrl/$beforeImg';
          }
          if (afterImg.isNotEmpty && !afterImg.startsWith('http')) {
            afterImg = '$originUrl/$afterImg';
          }

          return {
            'id': map['id'],
            'caption': map['caption'] ?? '',
            'before_metric': map['beforeMetric'] ?? '',
            'after_metric': map['afterMetric'] ?? '',
            'before_image_path': beforeImg,
            'after_image_path': afterImg,
            'likes': map['likes'] ?? 0,
            'is_liked': map['isLiked'] ?? false,
            'author_name': map['authorName'] ?? '',
            'author_username': map['authorUsername'] ?? '',
            'author_avatar_color': map['authorAvatarColor'] ?? 0xFF2ECC71,
            'comments': (map['comments'] as List? ?? []).map((c) {
              final commentMap = c as Map<String, dynamic>;
              return {
                'id': commentMap['id'],
                'author': commentMap['author'] ?? '',
                'username': commentMap['username'] ?? '',
                'text': commentMap['content'] ?? commentMap['text'] ?? '',
                'time': commentMap['time'] ?? 'Just now',
              };
            }).toList(),
          };
        }).toList();
      } else {
        final message = responseData['message'] ?? 'Failed to retrieve your posts.';
        throw ApiException(message, response.statusCode);
      }
    } catch (e, stack) {
      _handleError(e, stack);
    }
  }

  // Publish Community Post using POST /community API
  static Future<Map<String, dynamic>> publishCommunityPost({
    required String caption,
    required String beforeMetric,
    required String afterMetric,
    required String beforeImagePath,
    required String afterImagePath,
    String? token,
  }) async {
    try {
      final beforeFileName = beforeImagePath.split(RegExp(r'[/\\]')).last;
      final afterFileName = afterImagePath.split(RegExp(r'[/\\]')).last;

      final formData = FormData.fromMap({
        'caption': caption,
        'before_metric': beforeMetric,
        'after_metric': afterMetric,
        'before_image': await MultipartFile.fromFile(
          beforeImagePath,
          filename: beforeFileName,
        ),
        'after_image': await MultipartFile.fromFile(
          afterImagePath,
          filename: afterFileName,
        ),
      });

      final response = await _dio.post(
        'community',
        data: formData,
      );

      final Map<String, dynamic> responseData = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};

      if (responseData['success'] == true) {
        final map = responseData['data'] ?? {};
        final String originUrl = _dio.options.baseUrl.replaceAll('/api/', '');

        String beforeImg = map['beforeImage']?.toString() ?? '';
        String afterImg = map['afterImage']?.toString() ?? '';

        if (beforeImg.isNotEmpty && !beforeImg.startsWith('http')) {
          beforeImg = '$originUrl/$beforeImg';
        }
        if (afterImg.isNotEmpty && !afterImg.startsWith('http')) {
          afterImg = '$originUrl/$afterImg';
        }

        // We fetch current user details to return the correct author properties
        final prefs = await SharedPreferences.getInstance();
        final userStr = prefs.getString(userDataKey);
        String name = 'You';
        String username = 'you';
        if (userStr != null && userStr.isNotEmpty) {
          try {
            final user = jsonDecode(userStr);
            name = '${user['first_name'] ?? 'You'} ${user['last_name'] ?? ''}'.trim();
            username = user['username'] ?? 'you';
          } catch (_) {}
        }

        return {
          'id': map['id'],
          'caption': map['caption'] ?? caption,
          'before_metric': map['beforeMetric'] ?? beforeMetric,
          'after_metric': map['afterMetric'] ?? afterMetric,
          'before_image_path': beforeImg,
          'after_image_path': afterImg,
          'likes': 0,
          'is_liked': false,
          'author_name': name,
          'author_username': username,
          'author_avatar_color': 0xFF2ECC71,
          'comments': [],
        };
      } else {
        final message = responseData['message'] ?? 'Failed to publish post.';
        throw ApiException(message, response.statusCode);
      }
    } catch (e, stack) {
      _handleError(e, stack);
    }
  }

  // Toggle Like Status of a Community Post using POST /community/:id/like API
  static Future<Map<String, dynamic>> toggleLikePost(dynamic postId, [String? token]) async {
    try {
      final response = await _dio.post('community/$postId/like');

      final Map<String, dynamic> responseData = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};

      if (responseData['success'] == true) {
        return responseData['data'] ?? {};
      } else {
        final message = responseData['message'] ?? 'Failed to update like.';
        throw ApiException(message, response.statusCode);
      }
    } catch (e, stack) {
      _handleError(e, stack);
    }
  }

  // Add Comment to a Community Post using POST /community/:id/comment API
  static Future<Map<String, dynamic>> addCommentToPost(dynamic postId, String content, [String? token]) async {
    try {
      final response = await _dio.post(
        'community/$postId/comment',
        data: {
          'content': content,
        },
      );

      final Map<String, dynamic> responseData = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};

      if (responseData['success'] == true) {
        return responseData['data'] ?? {};
      } else {
        final message = responseData['message'] ?? 'Failed to post comment.';
        throw ApiException(message, response.statusCode);
      }
    } catch (e, stack) {
      _handleError(e, stack);
    }
  }

  // Unified Error Handler Helper
  static Never _handleError(Object error, StackTrace stackTrace) {
    if (error is ApiException) {
      throw error;
    }
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        throw NetworkException(
            'Unable to connect to backend server. Please check your network connection.');
      }

      // If the error object contains a nested ApiException (e.g. from token refresh failure)
      if (error.error is ApiException) {
        throw error.error as ApiException;
      }

      final response = error.response;
      if (response != null) {
        final responseData = response.data;
        final message = responseData is Map ? responseData['message'] : null;
        final status = response.statusCode;
        if (status == 400) {
          throw ValidationException(message ?? 'Invalid input data.');
        } else if (status == 401 || status == 403) {
          throw AuthException(message ?? 'Unauthorized access.');
        } else {
          throw ApiException(message ?? 'Server error occurred.', status);
        }
      }
      throw ApiException(error.message ?? 'Network error occurred');
    }
    throw ApiException('An unexpected error occurred: $error');
  }
}
