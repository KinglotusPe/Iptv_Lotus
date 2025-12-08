import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/data_models.dart';
import '../services/storage_service.dart';
import 'live_tv_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Account? _account;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    final acc = await StorageService.getActiveAccount();
    if (acc == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } else {
      setState(() => _account = acc);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_account == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D1B2A), // Dark Blue
              Color(0xFF1B263B),
              Color(0xFF000000), // Black
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("LotusPlay", style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(_account?.name ?? "Usuario", style: GoogleFonts.inter(fontSize: 14, color: Colors.grey)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: () async {
                         await StorageService.clearActiveAccount();
                         if (mounted) Navigator.pushReplacementNamed(context, '/login');
                      },
                    )
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Main Buttons Grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    crossAxisCount: 2, // 2 columns
                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15,
                    childAspectRatio: 2.2, // Flatter cards for landscape
                    children: [
                      _buildMenuCard(
                        icon: Icons.live_tv,
                        title: "TV EN VIVO",
                        color: Colors.blueAccent,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveTvScreen())),
                      ),
                      _buildMenuCard(
                        icon: Icons.movie,
                        title: "PELÍCULAS",
                        color: Colors.redAccent,
                        onTap: () {
                          // TODO: Implement VOD
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Próximamente")));
                        },
                      ),
                      _buildMenuCard(
                        icon: Icons.video_library,
                        title: "SERIES",
                        color: Colors.purpleAccent,
                        onTap: () {
                           // TODO: Implement Series
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Próximamente")));
                        },
                      ),
                      _buildMenuCard(
                        icon: Icons.settings,
                        title: "AJUSTES",
                        color: Colors.grey,
                        onTap: () {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ajustes")));
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              // Footer info
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Text("Expiration: Unlimited", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 5),
                    Text("Desarrollado por @Kinglotusp", style: GoogleFonts.outfit(color: Colors.amber, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.5), width: 1),
          boxShadow: [
             BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
          ]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(height: 10),
            Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
