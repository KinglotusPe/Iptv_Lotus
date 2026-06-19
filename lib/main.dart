import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/storage_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profiles_screen.dart';
import 'models/data_models.dart';

import 'package:wakelock_plus/wakelock_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enable Wakelock
  try {
    await WakelockPlus.enable();
  } catch (e) {
    print("Failed to enable wakelock: $e");
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
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
        primaryColor: const Color(0xFFFFB703),
        scaffoldBackgroundColor: const Color(0xFF090D16),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFB703),
          secondary: Color(0xFFFB8500),
          surface: Color(0xFF151F32),
          background: Color(0xFF090D16),
          outline: Color(0xFF233554),
        ),
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFB703),
            foregroundColor: Colors.black,
            textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF151F32),
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white30),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF233554), width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFFFB703), width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AppStarter(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const HomeScreen(),
        '/profiles': (context) => const ProfilesScreen(),
      },
    );
  }
}

class AppStarter extends StatefulWidget {
  const AppStarter({super.key});

  @override
  State<AppStarter> createState() => _AppStarterState();
}

class _AppStarterState extends State<AppStarter> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
    _checkLogin();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkLogin() async {
    // Run checks in parallel with splash animation
    final results = await Future.wait([
      StorageService.getActiveAccount(),
      StorageService.getAccounts(),
      Future.delayed(const Duration(milliseconds: 2000)), // Minimum splash time
    ]);
    
    if (!mounted) return;

    final Account? activeAccount = results[0] as Account?;
    final List<Account> allAccounts = results[1] as List<Account>;

    if (activeAccount != null) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else if (allAccounts.isNotEmpty) {
      Navigator.of(context).pushReplacementNamed('/profiles');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF090D16),
              Color(0xFF0F172A),
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Glowing logo container
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB703).withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFB703).withOpacity(0.4),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB703).withOpacity(0.2),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_filled, 
                        size: 80, 
                        color: Color(0xFFFFB703),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    "LotusPlay",
                    style: GoogleFonts.outfit(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFFB703),
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(
                          color: const Color(0xFFFFB703).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tu Centro de Entretenimiento Digital",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white54,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Sleek micro progress indicator
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: Color(0xFFFFB703),
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Desarrollado por @Kinglotusp",
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: const Color(0xFFFFB703).withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
