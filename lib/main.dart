import 'dart:async';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:food_app/firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'services/api_service.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/my_posts_screen.dart';
import 'screens/food_analysis_screen.dart';
import 'screens/add_daily_post_screen.dart';
import 'screens/dm_screen.dart';
import 'screens/all_scans_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/complete_profile_screen.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'models/user_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Suppress unhandled Google Fonts network fetching exceptions when offline
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    final errorString = error.toString();
    if (errorString.contains('fonts.gstatic.com') ||
        errorString.contains('SocketException') ||
        errorString.contains('Failed host lookup')) {
      debugPrint('Suppressed Google Fonts fetch exception (offline): $error');
      return true; // Mark error as handled
    }
    return false; // Let other exceptions propagate
  };

  await dotenv.load();
  final bool loggedIn = await ApiService.isLoggedIn();
  final Map<String, dynamic>? savedUser =
      loggedIn ? await ApiService.getSavedUserData() : null;

  final userProvider = UserProvider();
  if (loggedIn && savedUser != null) {
    userProvider.setUser(UserModel.fromJson(savedUser));
  }

  runApp(
    ChangeNotifierProvider<UserProvider>.value(
      value: userProvider,
      child: MyApp(isLoggedIn: loggedIn, savedUser: savedUser),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final Map<String, dynamic>? savedUser;

  const MyApp({
    super.key,
    required this.isLoggedIn,
    this.savedUser,
  });

  @override
  Widget build(BuildContext context) {
    final themeData = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2ECC71),
        primary: const Color(0xFF2ECC71),
        secondary: const Color(0xFFE67E22),
        background: Colors.white,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(
        Theme.of(context).textTheme,
      ),
      scaffoldBackgroundColor: Colors.white,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: elevatedButtonThemeFromColor(
          primaryColor: const Color(0xFF2ECC71),
        ),
      ),
    );

    return MaterialApp(
      title: 'NutriLife',
      theme: themeData,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return ConnectivityWrapper(child: child ?? const SizedBox());
      },
      initialRoute: isLoggedIn ? '/home' : '/',
      onGenerateRoute: (settings) {
        Widget builder;
        RouteSettings effectiveSettings = settings;

        String routeName = settings.name ?? '/';
        if (routeName == '/' && isLoggedIn) {
          routeName = '/home';
        }

        switch (routeName) {
          case '/':
            builder = const WelcomeScreen();
            break;
          case '/login':
            builder = const LoginScreen();
            break;
          case '/register':
            builder = const RegisterScreen();
            break;
          case '/home':
            builder = const HomeScreen();
            if (settings.arguments == null && savedUser != null) {
              effectiveSettings =
                  RouteSettings(name: '/home', arguments: savedUser);
            }
            break;
          case '/profile':
            builder = const ProfileScreen();
            break;
          case '/my_posts':
            builder = const MyPostsScreen();
            break;
          case '/food_analysis':
            builder = const FoodAnalysisScreen();
            break;
          case '/add_daily_post':
            builder = const AddDailyPostScreen();
            break;
          case '/dm':
            builder = const DMScreen();
            break;
          case '/all_scans':
            builder = const AllScansScreen();
            break;
          case '/forgot_password':
            builder = const ForgotPasswordScreen();
            break;
          case '/reset_password':
            builder = const ResetPasswordScreen();
            break;
          case '/edit_profile':
            builder = const EditProfileScreen();
            break;
          case '/complete_profile':
            builder = const CompleteProfileScreen();
            break;
          default:
            builder = isLoggedIn ? const HomeScreen() : const WelcomeScreen();
        }
        return PageRouteBuilder(
          settings: effectiveSettings,
          pageBuilder: (context, animation, secondaryAnimation) => builder,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 0.05);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;
            final tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            final offsetAnimation = animation.drive(tween);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: offsetAnimation,
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
        );
      },
    );
  }
}

// Custom helper function to generate standard button styling in code
ButtonStyle elevatedButtonThemeFromColor({required Color primaryColor}) {
  return ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16.0),
    ),
    padding: const EdgeInsets.symmetric(vertical: 16.0),
  );
}

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  bool _isConnected = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      _updateConnectionStatus(results);
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final bool connected =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);
    if (_isConnected != connected) {
      setState(() {
        _isConnected = connected;
      });
    }
  }

  Future<void> _checkConnection() async {
    if (_isChecking) return;
    setState(() {
      _isChecking = true;
    });
    try {
      final results = await Connectivity().checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      debugPrint('Error checking connection: $e');
    } finally {
      setState(() {
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnected) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFFDEDEC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: Color(0xFFE74C3C),
                  size: 80,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'No Connection',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E272C),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please connect to the internet to continue using the NutriLife app.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isChecking
                      ? null
                      : () {
                          _checkConnection();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _isChecking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.refresh_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _isChecking ? 'Checking...' : 'Check Connection',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
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
    );
  }
}
