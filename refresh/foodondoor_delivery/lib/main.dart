import 'package:flutter/material.dart';
import '../splashScreen/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'global/global.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts

// Define the new color palette
const Color primaryCyan = Colors.cyan; // Using standard Cyan
const Color secondaryAmber = Colors.amber; // Using standard Amber
const Color darkText = Color(0xFF333333);
const Color white = Color(0xFFFFFFFF);
const Color lightBackground = Color(0xFFFAFAFA);
const Color lightGrey = Color(0xFFD3D3D3);

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
      title: 'Food on Door - Delivery', // Updated App Title
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Define the default brightness and colors.
        brightness: Brightness.light,
        primaryColor: primaryCyan,
        scaffoldBackgroundColor: lightBackground,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.cyan) // Use cyan as base
            .copyWith(
              primary: primaryCyan,
              secondary: secondaryAmber, // Use Amber as accent
              background: lightBackground,
              brightness: Brightness.light,
              onPrimary: white, // Text on primary color buttons
              onSecondary: darkText, // Text on secondary color buttons (Amber is light)
              surface: white, // Card backgrounds, dialogs etc.
              onSurface: darkText, // Text on surface
            ),

        // Define the default font family using GoogleFonts
        fontFamily: GoogleFonts.poppins().fontFamily,

        // Define the default TextTheme. Use this to specify the default
        // text styling for headlines, titles, bodies of text, and more.
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme).copyWith(
          // Override specific text styles if needed, using GoogleFonts
          displayLarge: GoogleFonts.poppins(fontSize: 48.0, fontWeight: FontWeight.bold, color: darkText),
          headlineMedium: GoogleFonts.poppins(fontSize: 24.0, fontWeight: FontWeight.w600, color: darkText),
          // Example: Use Lobster for titles globally if desired, or apply specifically
          // titleLarge: GoogleFonts.lobster(fontSize: 22.0, color: darkText),
          titleLarge: GoogleFonts.poppins(fontSize: 20.0, fontWeight: FontWeight.w600, color: darkText),
          bodyLarge: GoogleFonts.poppins(fontSize: 16.0, color: darkText),
          bodyMedium: GoogleFonts.poppins(fontSize: 14.0, color: darkText),
          labelLarge: GoogleFonts.poppins(fontSize: 16.0, fontWeight: FontWeight.bold, color: white), // For button text
        ),

        appBarTheme: AppBarTheme(
          backgroundColor: primaryCyan, // Use Cyan for AppBar Background
          foregroundColor: white, // Color for icons and back button
          elevation: 1, // Slight elevation
          centerTitle: true,
          // Use Lobster font specifically for AppBar titles
          titleTextStyle: GoogleFonts.lobster(fontSize: 24, color: white, fontWeight: FontWeight.normal),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryCyan, // Use Cyan for buttons
            foregroundColor: white, // Text color on buttons
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: lightGrey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: lightGrey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primaryCyan), // Use Cyan for focus
          ),
          labelStyle: GoogleFonts.poppins(color: darkText),
        ),

        // Theme for Floating Action Button if needed
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: secondaryAmber, // Use Amber for FAB
          foregroundColor: darkText,
        ),

        // Add other theme properties as needed
      ),
      home: const MySplashScreen(),
    );
  }
}
