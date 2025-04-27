// import 'package:firebase_core/firebase_core.dart'; // Removed
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Added import back
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../assistant_methods/address_changer.dart';
import '../assistant_methods/cart_item_counter.dart';
import '../assistant_methods/total_ammount.dart'; // Corrected import path if needed
import '../splashScreen/splash_screen.dart';
import 'global/global.dart';
import 'providers/auth_provider.dart';
import 'providers/home_provider.dart';
import 'providers/cart_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sharedPreferences = await SharedPreferences.getInstance();
  // await Firebase.initializeApp(); // Removed Firebase init
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => CartItemCounter()),
        ChangeNotifierProvider(create: (context) => TotalAmount()),
        ChangeNotifierProvider(create: (context) => AddressChanger()),
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => HomeProvider()),
        ChangeNotifierProvider(create: (context) => CartProvider()),
      ],
      child: MaterialApp(
        title: 'Food On Door', // Updated title
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.light,
          primaryColor: const Color(0xFFFF6600), // Orange
          scaffoldBackgroundColor: Colors.white,
          colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.orange).copyWith(
            secondary: Colors.black,
            brightness: Brightness.light,
          ),
          textTheme: GoogleFonts.montserratTextTheme(Theme.of(context).textTheme).copyWith(
            displayLarge: GoogleFonts.montserrat(fontSize: 72.0, fontWeight: FontWeight.bold, color: Colors.black),
            titleLarge: GoogleFonts.montserrat(fontSize: 36.0, fontWeight: FontWeight.w600, color: Colors.black),
            bodyMedium: GoogleFonts.montserrat(fontSize: 14.0, color: Colors.black),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFFF6600), // Orange
            foregroundColor: Colors.white,
            iconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Colors.white,
            ),
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6600),
              foregroundColor: Colors.white,
              textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6600))),
            labelStyle: GoogleFonts.montserrat(color: Colors.black),
          ),
        ),
        home: const MySplashScreen(),
      ),
    );
  }
}
