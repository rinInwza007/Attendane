import 'package:flutter/material.dart';
import 'package:myproject2/presentation/screens/profile/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://cykbwnxcvdszxlypzucy.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN5a2J3bnhjdmRzenhseXB6dWN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzIwMDEwMDMsImV4cCI6MjA0NzU3NzAwM30.t51vDsflnqzKVic9tZ_uFpiaS_6RO3J3gOeMJdm0lvo',
  );

  // Setup service locator
  setupServiceLocator();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance Plus',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
