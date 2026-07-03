import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  double? _customCalorieTarget;
  bool _isLoading = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;

  double get calorieTarget {
    if (_customCalorieTarget != null) return _customCalorieTarget!;
    return _user?.calorieBudget ?? 2000.0;
  }

  void setUser(UserModel? user) {
    _user = user;
    notifyListeners();
  }

  void setCalorieTarget(double target) {
    _customCalorieTarget = target;
    notifyListeners();
  }

  // Load user data from local storage/APIs at startup
  Future<void> initializeUser() async {
    _isLoading = true;
    notifyListeners();
    try {
      final loggedIn = await ApiService.isLoggedIn();
      if (loggedIn) {
        final savedData = await ApiService.getSavedUserData();
        if (savedData != null) {
          _user = UserModel.fromJson(savedData);
        }
      }
    } catch (e) {
      debugPrint('Failed to initialize user provider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Perform API login and store state
  Future<Map<String, dynamic>> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiService.login(email, password);
      final rawUser = response['user'] as Map<String, dynamic>;
      _user = UserModel.fromJson(rawUser);
      _isLoading = false;
      notifyListeners();
      return response;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Reload fresh user details from backend API
  Future<void> refreshUserDetails() async {
    if (_user?.id == null) return;
    try {
      final freshData = await ApiService.getUserDetails(_user!.id);
      _user = UserModel.fromJson(freshData);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh user details: $e');
    }
  }

  // Log out the user and clear state
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiService.logout();
      _user = null;
      _customCalorieTarget = null;
    } catch (e) {
      debugPrint('Failed during logout in provider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
