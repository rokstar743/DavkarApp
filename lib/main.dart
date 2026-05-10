import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const EtoroEdavkiApp());
}

class EtoroEdavkiApp extends StatelessWidget {
  const EtoroEdavkiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eToro → eDavki',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006837), // zelena (SI zastava)
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: const HomeScreen(),  // ignore: prefer_const_constructors
    );
  }
}