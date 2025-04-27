import 'package:flutter/material.dart';
import 'package:foodondoor_vendor/global/global.dart';
import 'package:foodondoor_vendor/splashscreen/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Define the color palette
const Color primaryOrange = Color(0xFFFF7A00);
const Color darkText = Color(0xFF333333);
const Color white = Color(0xFFFFFFFF);
const Color lightBackground = Color(0xFFFFF9E6);
const Color mutedGreen = Color(0xFFE0EAE4);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sharedPreferences = await SharedPreferences.getInstance();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodOnDoor Vendor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: primaryOrange,
        scaffoldBackgroundColor: lightBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryOrange,
          primary: primaryOrange,
          secondary: primaryOrange,
          background: lightBackground,
          surface: white,
          onPrimary: white,
          onSecondary: white,
          onBackground: darkText,
          onSurface: darkText,
          brightness: Brightness.light,
        ),
        textTheme: TextTheme(
          displayLarge: TextStyle(fontSize: 72.0, fontWeight: FontWeight.bold, color: darkText),
          titleLarge: TextStyle(fontSize: 36.0, fontStyle: FontStyle.italic, color: darkText),
          bodyMedium: TextStyle(fontSize: 14.0, color: darkText),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: primaryOrange,
          foregroundColor: white,
          elevation: 4.0,
          centerTitle: true,
          titleTextStyle: const TextStyle(
            color: white,
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryOrange,
            foregroundColor: white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryOrange,
            side: const BorderSide(color: primaryOrange, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryOrange,
          ),
        ),
      ),
      home: const MySplashScreen(),
    );
  }
}
