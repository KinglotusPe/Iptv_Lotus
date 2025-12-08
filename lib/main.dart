import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const LotusPlayApp());
}

class LotusPlayApp extends StatelessWidget {
  const LotusPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LotusPlay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        colorScheme: const ColorScheme.dark(
          primary: Colors.amber,
          secondary: Colors.amberAccent,
          surface: Color(0xFF2D2D2D),
          background: Color(0xFF1A1A1A),
        ),
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AppStarter(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}

class AppStarter extends StatefulWidget {
  const AppStarter({super.key});

  @override
  State<AppStarter> createState() => _AppStarterState();
}

class _AppStarterState extends State<AppStarter> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    // Simple splash delay or check auth
    // For now, redirect to Login. 
    // TODO: implement checking shared_preferences for auto-login
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
       Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_circle_filled, size: 80, color: Colors.amber),
            const SizedBox(height: 20),
            Text("LotusPlay", style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.amber)),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Colors.amber),
          ],
        ),
      ),
    );
  }
}
