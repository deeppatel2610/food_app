import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:food_app/main.dart';
import 'package:food_app/providers/user_provider.dart';

void main() {
  testWidgets('App landing and login navigation test', (WidgetTester tester) async {
    // Set screen size to simulate a realistic device resolution and avoid test overflows
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;

    // Reset screen size after test completion
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final userProvider = UserProvider();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider<UserProvider>.value(
        value: userProvider,
        child: const MyApp(isLoggedIn: false),
      ),
    );

    // Verify that we are on the Welcome screen
    expect(find.text('NutriLife'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    // Tap the 'Sign In' button and trigger a frame transition.
    final signInButton = find.text('Sign In');
    expect(signInButton, findsOneWidget);
    await tester.tap(signInButton);
    await tester.pumpAndSettle();

    // Verify that we are on the Login screen
    expect(find.text('Welcome Back'), findsOneWidget);
  });
}
