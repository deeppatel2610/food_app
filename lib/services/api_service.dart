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
          validateStatus: (status) => status != null && status < 500,
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

  // Refresh Access Token API using POST /auth/refresh
  static Future<String> refreshToken() async {
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
        final message =
            responseData['message'] ?? 'Session expired. Please log in again.';
        throw AuthException(message);
      }
    } on DioException catch (e) {
      if (e.response != null &&
          (e.response?.statusCode == 403 || e.response?.statusCode == 401)) {
        await logout();
        throw AuthException(
            'Refresh token expired or invalid. Please log in again.');
      } else {
        throw NetworkException(
            'Network error occurred while refreshing token.');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw ApiException('Unexpected error while refreshing token: $e');
    }
  }

  // Get User Details using GET /user API endpoint (ID is read from JWT token)
  static Future<Map<String, dynamic>> getUserDetails(dynamic id,
      [String? token]) async {
    try {
      String? authToken = token;
      if (authToken == null || authToken.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        authToken = prefs.getString(accessTokenKey);
      }

      final response = await _dio.get(
        'user',
        options: Options(
          headers: {
            if (authToken != null && authToken.isNotEmpty)
              'Authorization': 'Bearer $authToken',
          },
        ),
      );

      final responseData = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {};

      if (response.statusCode == 200 && responseData['success'] == true) {
        final rawUser = responseData['data'] ?? {};
        final user = UserModel.fromJson(rawUser).toJson();

        // Save user data to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(userDataKey, jsonEncode(user));

        return user;
      } else if (response.statusCode == 401) {
        // Automatically attempt token refresh on 401 Unauthorized
        final newToken = await refreshToken();
        return getUserDetails(id, newToken);
      } else {
        final message =
            responseData['message'] ?? 'Failed to fetch user details.';
        throw ApiException(message, response.statusCode);
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.statusCode == 401) {
        try {
          final newToken = await refreshToken();
          return getUserDetails(id, newToken);
        } catch (_) {}
      }
      if (e.response != null && e.response?.data is Map) {
        final msg = e.response?.data['message'] ?? 'Server error occurred.';
        throw ApiException(msg, e.response?.statusCode);
      } else {
        throw ApiException(e.message ?? 'Network error occurred');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw ApiException(
          'An unexpected error occurred while fetching profile: $e');
    }
  }

  // 1. Real Login Method using Dio connecting to Backend API
  static Future<Map<String, dynamic>> login(
      String identifier, String password) async {
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

      if (response.statusCode == 200 && responseData['success'] == true) {
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
          user = await getUserDetails(userId, accessToken);
        }

        return {
          'status': 'success',
          'token': accessToken,
          'user': user,
        };
      } else {
        final message = responseData['message'] ??
            'Login failed. Please check your credentials.';
        if (response.statusCode == 401) {
          throw AuthException(message);
        } else if (response.statusCode == 400) {
          throw ValidationException(message);
        } else {
          throw ApiException(message, response.statusCode);
        }
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw NetworkException(
            'Unable to connect to backend server. Please check your network connection.');
      } else if (e.response != null && e.response?.data is Map) {
        final msg = e.response?.data['message'] ?? 'Server error occurred.';
        throw ApiException(msg, e.response?.statusCode);
      } else {
        throw ApiException(e.message ?? 'Network error occurred');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('An unexpected error occurred during login: $e');
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

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          responseData['success'] == true) {
        final user = UserModel.fromJson(responseData['data'] ?? {}).toJson();
        return {
          'status': 'success',
          'message':
              responseData['message'] ?? 'Account registered successfully!',
          'user': user,
        };
      } else {
        final message = responseData['message'] ??
            'Registration failed. Please check inputs.';
        if (response.statusCode == 400) {
          throw ValidationException(message);
        } else {
          throw ApiException(message, response.statusCode);
        }
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw NetworkException(
            'Unable to connect to backend server. Please check your network connection.');
      } else if (e.response != null && e.response?.data is Map) {
        final msg = e.response?.data['message'] ?? 'Server error occurred.';
        throw ApiException(msg, e.response?.statusCode);
      } else {
        throw ApiException(e.message ?? 'Network error occurred');
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
          'An unexpected error occurred during registration: $e');
    }
  }

  // 3. Real Image Scan Analysis Method connecting to Backend API
  static Future<Map<String, dynamic>> analyzeFoodImage(String imagePath,
      [String? token]) async {
    if (imagePath.isEmpty) {
      throw ValidationException('No image path provided for analysis.');
    }

    try {
      String? authToken = token;
      if (authToken == null || authToken.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        authToken = prefs.getString(accessTokenKey);
      }

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
        options: Options(
          headers: {
            if (authToken != null && authToken.isNotEmpty)
              'Authorization': 'Bearer $authToken',
          },
        ),
      );

      final responseData = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {};

      if (response.statusCode == 200 && responseData['success'] == true) {
        final responsePayload = responseData['data'] ?? {};
        final data = responsePayload['analysis'] ?? {};
        final isFood = data['isFood'] ?? data['is_food'] ?? false;
        if (!isFood) {
          final msg = data['message'] ??
              'The uploaded image does not appear to contain any food or food package.';
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
      } else if (response.statusCode == 401) {
        final newToken = await refreshToken();
        return analyzeFoodImage(imagePath, newToken);
      } else {
        final message = responseData['message'] ?? 'Failed to analyze image.';
        if (response.statusCode == 400) {
          throw ValidationException(message);
        } else {
          throw ApiException(message, response.statusCode);
        }
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.statusCode == 401) {
        try {
          final newToken = await refreshToken();
          return analyzeFoodImage(imagePath, newToken);
        } catch (_) {}
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw NetworkException(
            'Unable to connect to backend server. Please check your network connection.');
      } else if (e.response != null && e.response?.data is Map) {
        final msg = e.response?.data['message'] ??
            'Server error occurred during food analysis.';
        if (e.response?.statusCode == 400) {
          throw ValidationException(msg);
        } else {
          throw ApiException(msg, e.response?.statusCode);
        }
      } else {
        throw ApiException(
            e.message ?? 'Network error occurred during food analysis.');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
          'An unexpected error occurred during food analysis: $e');
    }
  }

  // 4. Retrieve Food Analysis History from Backend API
  static Future<List<Map<String, dynamic>>> getFoodAnalysisHistory({
    String? isEat,
    String? date,
    String? token,
  }) async {
    try {
      String? authToken = token;
      if (authToken == null || authToken.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        authToken = prefs.getString(accessTokenKey);
      }

      final response = await _dio.get(
        'food/history',
        queryParameters: {
          if (isEat != null) 'isEat': isEat,
          if (date != null) 'date': date,
        },
        options: Options(
          headers: {
            if (authToken != null && authToken.isNotEmpty)
              'Authorization': 'Bearer $authToken',
          },
        ),
      );

      final responseData = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {};

      if (response.statusCode == 200 && responseData['success'] == true) {
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
      } else if (response.statusCode == 401) {
        final newToken = await refreshToken();
        return getFoodAnalysisHistory(
            isEat: isEat, date: date, token: newToken);
      } else {
        final message = responseData['message'] ??
            'Failed to retrieve food analysis history.';
        throw ApiException(message, response.statusCode);
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.statusCode == 401) {
        try {
          final newToken = await refreshToken();
          return getFoodAnalysisHistory(
              isEat: isEat, date: date, token: newToken);
        } catch (_) {}
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw NetworkException(
            'Unable to connect to backend server. Please check your network connection.');
      } else if (e.response != null && e.response?.data is Map) {
        final msg = e.response?.data['message'] ??
            'Server error occurred during fetching history.';
        throw ApiException(msg, e.response?.statusCode);
      } else {
        throw ApiException(
            e.message ?? 'Network error occurred during fetching history.');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
          'An unexpected error occurred during fetching history: $e');
    }
  }

  // Update is_eat status of a food analysis record using PATCH /food/history/{id}
  static Future<Map<String, dynamic>> updateFoodIsEatStatus(
      dynamic id, bool isEat,
      [String? token]) async {
    try {
      String? authToken = token;
      if (authToken == null || authToken.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        authToken = prefs.getString(accessTokenKey);
      }

      final response = await _dio.patch(
        'food/history/$id',
        data: {
          'is_eat': isEat,
          'isEat': isEat,
        },
        options: Options(
          headers: {
            if (authToken != null && authToken.isNotEmpty)
              'Authorization': 'Bearer $authToken',
          },
        ),
      );

      final responseData = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {};

      if (response.statusCode == 200 && responseData['success'] == true) {
        final data = responseData['data'] ?? {};
        return data is Map<String, dynamic> ? data : {};
      } else if (response.statusCode == 401) {
        final newToken = await refreshToken();
        return updateFoodIsEatStatus(id, isEat, newToken);
      } else {
        final message =
            responseData['message'] ?? 'Failed to update track status.';
        throw ApiException(message, response.statusCode);
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.statusCode == 401) {
        try {
          final newToken = await refreshToken();
          return updateFoodIsEatStatus(id, isEat, newToken);
        } catch (_) {}
      }
      if (e.response != null && e.response?.data is Map) {
        final msg = e.response?.data['message'] ?? 'Server error occurred.';
        throw ApiException(msg, e.response?.statusCode);
      } else {
        throw ApiException(e.message ?? 'Network error occurred');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw ApiException(
          'An unexpected error occurred while updating status: $e');
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
      String? authToken = token;
      if (authToken == null || authToken.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        authToken = prefs.getString(accessTokenKey);
      }

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
        options: Options(
          headers: {
            if (authToken != null && authToken.isNotEmpty)
              'Authorization': 'Bearer $authToken',
          },
        ),
      );

      final responseData = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : {};

      if (response.statusCode == 200 && responseData['success'] == true) {
        final rawUser = responseData['data'] ?? {};
        final user = UserModel.fromJson(rawUser).toJson();

        // Save updated user data to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(userDataKey, jsonEncode(user));

        return user;
      } else if (response.statusCode == 401) {
        final newToken = await refreshToken();
        return editUserProfile(
          firstName: firstName,
          lastName: lastName,
          username: username,
          email: email,
          age: age,
          weight: weight,
          height: height,
          bloodGroup: bloodGroup,
          healthConditions: healthConditions,
          token: newToken,
        );
      } else {
        final message =
            responseData['message'] ?? 'Failed to update user profile.';
        throw ApiException(message, response.statusCode);
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.statusCode == 401) {
        try {
          final newToken = await refreshToken();
          return editUserProfile(
            firstName: firstName,
            lastName: lastName,
            username: username,
            email: email,
            age: age,
            weight: weight,
            height: height,
            bloodGroup: bloodGroup,
            healthConditions: healthConditions,
            token: newToken,
          );
        } catch (_) {}
      }
      if (e.response != null && e.response?.data is Map) {
        final msg = e.response?.data['message'] ?? 'Server error occurred.';
        throw ApiException(msg, e.response?.statusCode);
      } else {
        throw ApiException(e.message ?? 'Network error occurred');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw ApiException(
          'An unexpected error occurred while updating profile: $e');
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

      final Map<String, dynamic> responseData =
          response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : <String, dynamic>{};

      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData['data'] is Map<String, dynamic>
            ? responseData['data'] as Map<String, dynamic>
            : <String, dynamic>{};
      } else {
        final message =
            responseData['message'] ?? 'Failed to send password reset token.';
        throw ApiException(message, response.statusCode);
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map) {
        final msg = e.response?.data['message'] ?? 'Server error occurred.';
        throw ApiException(msg, e.response?.statusCode);
      } else {
        throw ApiException(e.message ?? 'Network error occurred');
      }
    } catch (e) {
      throw ApiException(
          'An unexpected error occurred during forgot password: $e');
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

      final Map<String, dynamic> responseData =
          response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : <String, dynamic>{};

      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData;
      } else {
        final message = responseData['message'] ?? 'Failed to reset password.';
        throw ApiException(message, response.statusCode);
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map) {
        final msg = e.response?.data['message'] ?? 'Server error occurred.';
        throw ApiException(msg, e.response?.statusCode);
      } else {
        throw ApiException(e.message ?? 'Network error occurred');
      }
    } catch (e) {
      throw ApiException(
          'An unexpected error occurred during reset password: $e');
    }
  }

  // Get Community Feed using GET /community API
  static Future<List<Map<String, dynamic>>> getCommunityFeed(
      {int page = 1, int limit = 10, String? token}) async {
    try {
      String? authToken = token;
      if (authToken == null || authToken.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        authToken = prefs.getString(accessTokenKey);
      }

      final response = await _dio.get(
        'community',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
        options: Options(
          headers: {
            if (authToken != null && authToken.isNotEmpty)
              'Authorization': 'Bearer $authToken',
          },
        ),
      );

      final Map<String, dynamic> responseData =
          response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : <String, dynamic>{};

      if (response.statusCode == 200 && responseData['success'] == true) {
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
      } else if (response.statusCode == 401) {
        final newToken = await refreshToken();
        return getCommunityFeed(page: page, limit: limit, token: newToken);
      } else {
        final message =
            responseData['message'] ?? 'Failed to retrieve community feed.';
        throw ApiException(message, response.statusCode);
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.statusCode == 401) {
        try {
          final newToken = await refreshToken();
          return getCommunityFeed(page: page, limit: limit, token: newToken);
        } catch (_) {}
      }
      if (e.response != null && e.response?.data is Map) {
        final msg = e.response?.data['message'] ?? 'Server error occurred.';
        throw ApiException(msg, e.response?.statusCode);
      } else {
        throw ApiException(e.message ?? 'Network error occurred');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw ApiException(
          'An unexpected error occurred while fetching community feed: $e');
    }
  }

  // Get User's Own Posts using GET /community/my-posts API
  static Future<List<Map<String, dynamic>>> getMyPosts([String? token]) async {
    try {
      String? authToken = token;
      if (authToken == null || authToken.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        authToken = prefs.getString(accessTokenKey);
      }

      final response = await _dio.get(
        'community/my-posts',
        options: Options(
          headers: {
            if (authToken != null && authToken.isNotEmpty)
              'Authorization': 'Bearer $authToken',
          },
        ),
      );

      final Map<String, dynamic> responseData =
          response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : <String, dynamic>{};

      if (response.statusCode == 200 && responseData['success'] == true) {
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
      } else if (response.statusCode == 401) {
        final newToken = await refreshToken();
        return getMyPosts(newToken);
      } else {
        final message =
            responseData['message'] ?? 'Failed to retrieve your posts.';
        throw ApiException(message, response.statusCode);
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.statusCode == 401) {
        try {
          final newToken = await refreshToken();
          return getMyPosts(newToken);
        } catch (_) {}
      }
      if (e.response != null && e.response?.data is Map) {
        final msg = e.response?.data['message'] ?? 'Server error occurred.';
        throw ApiException(msg, e.response?.statusCode);
      } else {
        throw ApiException(e.message ?? 'Network error occurred');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw ApiException(
          'An unexpected error occurred while fetching your posts: $e');
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
      String? authToken = token;
      if (authToken == null || authToken.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        authToken = prefs.getString(accessTokenKey);
      }

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
        options: Options(
          headers: {
            if (authToken != null && authToken.isNotEmpty)
              'Authorization': 'Bearer $authToken',
          },
        ),
      );

      final Map<String, dynamic> responseData =
          response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : <String, dynamic>{};

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          responseData['success'] == true) {
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
            name = '${user['first_name'] ?? 'You'} ${user['last_name'] ?? ''}'
                .trim();
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
      } else if (response.statusCode == 401) {
        final newToken = await refreshToken();
        return publishCommunityPost(
          caption: caption,
          beforeMetric: beforeMetric,
          afterMetric: afterMetric,
          beforeImagePath: beforeImagePath,
          afterImagePath: afterImagePath,
          token: newToken,
        );
      } else {
        final message = responseData['message'] ?? 'Failed to publish post.';
        throw ApiException(message, response.statusCode);
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.statusCode == 401) {
        try {
          final newToken = await refreshToken();
          return publishCommunityPost(
            caption: caption,
            beforeMetric: beforeMetric,
            afterMetric: afterMetric,
            beforeImagePath: beforeImagePath,
            afterImagePath: afterImagePath,
            token: newToken,
          );
        } catch (_) {}
      }
      if (e.response != null && e.response?.data is Map) {
        final msg = e.response?.data['message'] ?? 'Server error occurred.';
        throw ApiException(msg, e.response?.statusCode);
      } else {
        throw ApiException(e.message ?? 'Network error occurred');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw ApiException(
          'An unexpected error occurred while publishing post: $e');
    }
  }

  // Toggle Like Status of a Community Post using POST /community/:id/like API
  static Future<Map<String, dynamic>> toggleLikePost(dynamic postId,
      [String? token]) async {
    try {
      String? authToken = token;
      if (authToken == null || authToken.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        authToken = prefs.getString(accessTokenKey);
      }

      final response = await _dio.post(
        'community/$postId/like',
        options: Options(
          headers: {
            if (authToken != null && authToken.isNotEmpty)
              'Authorization': 'Bearer $authToken',
          },
        ),
      );

      final Map<String, dynamic> responseData =
          response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : <String, dynamic>{};

      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData['data'] ?? {};
      } else if (response.statusCode == 401) {
        final newToken = await refreshToken();
        return toggleLikePost(postId, newToken);
      } else {
        final message = responseData['message'] ?? 'Failed to update like.';
        throw ApiException(message, response.statusCode);
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.statusCode == 401) {
        try {
          final newToken = await refreshToken();
          return toggleLikePost(postId, newToken);
        } catch (_) {}
      }
      if (e.response != null && e.response?.data is Map) {
        final msg = e.response?.data['message'] ?? 'Server error occurred.';
        throw ApiException(msg, e.response?.statusCode);
      } else {
        throw ApiException(e.message ?? 'Network error occurred');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw ApiException('An unexpected error occurred while liking post: $e');
    }
  }

  // Add Comment to a Community Post using POST /community/:id/comment API
  static Future<Map<String, dynamic>> addCommentToPost(
      dynamic postId, String content,
      [String? token]) async {
    try {
      String? authToken = token;
      if (authToken == null || authToken.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        authToken = prefs.getString(accessTokenKey);
      }

      final response = await _dio.post(
        'community/$postId/comment',
        data: {
          'content': content,
        },
        options: Options(
          headers: {
            if (authToken != null && authToken.isNotEmpty)
              'Authorization': 'Bearer $authToken',
          },
        ),
      );

      final Map<String, dynamic> responseData =
          response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : <String, dynamic>{};

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          responseData['success'] == true) {
        return responseData['data'] ?? {};
      } else if (response.statusCode == 401) {
        final newToken = await refreshToken();
        return addCommentToPost(postId, content, newToken);
      } else {
        final message = responseData['message'] ?? 'Failed to post comment.';
        throw ApiException(message, response.statusCode);
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.statusCode == 401) {
        try {
          final newToken = await refreshToken();
          return addCommentToPost(postId, content, newToken);
        } catch (_) {}
      }
      if (e.response != null && e.response?.data is Map) {
        final msg = e.response?.data['message'] ?? 'Server error occurred.';
        throw ApiException(msg, e.response?.statusCode);
      } else {
        throw ApiException(e.message ?? 'Network error occurred');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw ApiException(
          'An unexpected error occurred while posting comment: $e');
    }
  }

  // Mock Community Feed database
  static final List<Map<String, dynamic>> mockCommunityPosts = [
    {
      'id': 'post-1',
      'author_name': 'Sophia Miller',
      'author_username': 'sophiam',
      'author_avatar_color': 0xFF9B59B6, // Amethyst purple
      'caption':
          'Consistency is key! Swapped high carb processed meals for green organic salads and protein salmon bowls. Down 12kg in 2 months. Feeling so much lighter!',
      'before_metric': '84 kg (April)',
      'after_metric': '72 kg (June)',
      'likes': 142,
      'is_liked': false,
      'comments': [
        {
          'author': 'Liam Green',
          'text': 'This is absolutely inspiring, Sophia! Keep it up.',
          'time': '2h ago',
        },
        {
          'author': 'Olivia Smith',
          'text': 'What was your daily average calorie target?',
          'time': '1h ago',
        }
      ]
    },
    {
      'id': 'post-2',
      'author_name': 'Marcus Carter',
      'author_username': 'marcus_fit',
      'author_avatar_color': 0xFF3498DB, // Blue
      'caption':
          'Sticking to whole foods, portion control, and oatmeal breakfasts. Kept my daily calorie target at 1800 kcal consistently. Visual proof of clean eating results!',
      'before_metric': 'Daily Pizza & Soda',
      'after_metric': 'Oats & Salmon Bowls',
      'likes': 87,
      'is_liked': true,
      'comments': [
        {
          'author': 'Emma Watson',
          'text': 'Meal prep Sunday pays off! Incredible determination.',
          'time': '3h ago',
        }
      ]
    },
    {
      'id': 'post-3',
      'author_name': 'Elena Rostova',
      'author_username': 'elena_runs',
      'author_avatar_color': 0xFFE74C3C, // Coral red
      'caption':
          'Hit my target weight! 🏃‍♀️ Focused on daily step goals (10k+) and high-fiber/low-GI snacks. Swapped milk chocolate for raw almonds and blueberries. The energy boost is unreal!',
      'before_metric': '76 kg (Jan)',
      'after_metric': '65 kg (May)',
      'likes': 215,
      'is_liked': false,
      'comments': [
        {
          'author': 'Marcus Carter',
          'text':
              'The step count really is a game-changer. Awesome work, Elena!',
          'time': '4h ago',
        }
      ]
    },
    {
      'id': 'post-4',
      'author_name': 'David Vance',
      'author_username': 'davidv_keto',
      'author_avatar_color': 0xFFF39C12, // Orange
      'caption':
          'Keto journey update! 🥑 Cut down carbs drastically, added healthy fats. My body fat percentage dropped from 26% to 18%. Avocados, eggs, and leafy greens are my absolute staples now.',
      'before_metric': '26% Body Fat',
      'after_metric': '18% Body Fat',
      'likes': 94,
      'is_liked': false,
      'comments': [
        {
          'author': 'Sophia Miller',
          'text': '26% to 18% is huge! Did you experience keto flu at first?',
          'time': '5h ago',
        },
        {
          'author': 'David Vance',
          'text':
              'Yes, the first 4 days were rough! Salt water and extra avocados helped.',
          'time': '3h ago',
        }
      ]
    },
    {
      'id': 'post-5',
      'author_name': 'Sarah Jenkins',
      'author_username': 'sarah_j_health',
      'author_avatar_color': 0xFF1ABC9C, // Turquoise
      'caption':
          'Meal prep is the secret weapon. Spent 2 hours on Sunday prepping grilled chicken, roasted sweet potatoes, and steamed broccoli for the week. Saved money and stayed on track!',
      'before_metric': 'Takeout 5x/wk',
      'after_metric': 'Homecooked 100%',
      'likes': 312,
      'is_liked': false,
      'comments': [
        {
          'author': 'Emma Watson',
          'text': 'What containers do you use? Do they freeze well?',
          'time': '1d ago',
        }
      ]
    }
  ];
}
