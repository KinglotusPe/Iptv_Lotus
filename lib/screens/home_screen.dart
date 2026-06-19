import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/data_models.dart';
import '../services/storage_service.dart';
import 'live_tv_screen.dart';
import 'movies_screen.dart';
import 'series_screen.dart';
import 'settings_screen.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Account? _account;
  List<Channel> _history = [];

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
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    if (_account != null) {
      final hist = await StorageService.getHistory(_account!);
      setState(() => _history = hist);
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) => _loadHistory());
  }

  @override
  Widget build(BuildContext context) {
    if (_account == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF090D16),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFFB703))),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF090D16), // Deep Space Dark Blue
              Color(0xFF0F172A), // Slate Dark
              Color(0xFF1E293B), // Soft Navy
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "LotusPlay",
                              style: GoogleFonts.outfit(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFFB703),
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "${_account?.name} • ${_account?.type == 'xtream' ? 'Xtream Codes' : 'M3U'}",
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        // Logout focusable button
                        Focus(
                          child: Builder(
                            builder: (context) {
                              final hasFocus = Focus.of(context).hasFocus;
                              return Container(
                                decoration: BoxDecoration(
                                  color: hasFocus ? Colors.redAccent.withOpacity(0.2) : Colors.white10,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: hasFocus ? Colors.redAccent : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.logout, color: Colors.white),
                                  tooltip: "Cerrar Sesión",
                                  onPressed: () async {
                                    await StorageService.clearActiveAccount();
                                    if (mounted) {
                                      final accounts = await StorageService.getAccounts();
                                      if (accounts.isNotEmpty) {
                                        Navigator.pushReplacementNamed(context, '/profiles');
                                      } else {
                                        Navigator.pushReplacementNamed(context, '/login');
                                      }
                                    }
                                  },
                                ),
                              );
                            }
                          ),
                        )
                      ],
                    ),
                    
                    const SizedBox(height: 20),

                    // "SEGUIR VIENDO" Section (Only visible if history exists)
                    if (_history.isNotEmpty) ...[
                      Text(
                        "SEGUIR VIENDO",
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 106,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _history.length,
                          itemBuilder: (context, index) {
                            return _buildHistoryCard(_history[index]);
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Main Buttons Grid
                    Builder(
                      builder: (context) {
                        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
                        return GridView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isLandscape ? 4 : 2, 
                            childAspectRatio: isLandscape ? 1.6 : 1.35, 
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                          ),
                          children: [
                            _buildMenuCard(
                              context: context,
                              icon: Icons.live_tv,
                              title: "TV EN VIVO",
                              color: Colors.blueAccent,
                              onTap: () => _navigateTo(const LiveTvScreen()),
                            ),
                            _buildMenuCard(
                              context: context,
                              icon: Icons.movie_outlined,
                              title: "PELÍCULAS",
                              color: Colors.redAccent,
                              onTap: () => _navigateTo(const MoviesScreen()),
                            ),
                            _buildMenuCard(
                              context: context,
                              icon: Icons.video_library_outlined,
                              title: "SERIES",
                              color: Colors.purpleAccent,
                              onTap: () => _navigateTo(const SeriesScreen()),
                            ),
                            _buildMenuCard(
                              context: context,
                              icon: Icons.settings_outlined,
                              title: "AJUSTES",
                              color: Colors.tealAccent,
                              onTap: () => _navigateTo(const SettingsScreen()),
                            ),
                          ],
                        );
                      }
                    ),
                    
                    const SizedBox(height: 24),

                    // Footer info
                    Center(
                      child: Column(
                        children: [
                          Text(
                            "Soporte Premium Activo • Expiración: Ilimitada",
                            style: GoogleFonts.inter(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Desarrollado por @Kinglotusp",
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFFFB703),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Channel item) {
    return Focus(
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PlayerScreen(channel: item)),
              ).then((_) => _loadHistory());
            },
            borderRadius: BorderRadius.circular(12),
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 155,
              margin: const EdgeInsets.only(right: 14, top: 4, bottom: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF151F32),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasFocus ? const Color(0xFFFFB703) : const Color(0xFF233554),
                  width: hasFocus ? 2.5 : 1,
                ),
                boxShadow: hasFocus
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFB703).withOpacity(0.35),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    item.logo.isNotEmpty
                        ? Image.network(
                            item.logo,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.play_circle_outline, size: 36, color: Colors.white30),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.play_circle_outline, size: 36, color: Colors.white30),
                          ),
                    // Dark gradient overlay
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black90, Colors.transparent],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Text(
                        item.name,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Focus(
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            splashColor: color.withOpacity(0.3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              transform: hasFocus ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: hasFocus
                      ? [
                          color.withOpacity(0.35),
                          color.withOpacity(0.15),
                        ]
                      : [
                          color.withOpacity(0.18),
                          color.withOpacity(0.04),
                        ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasFocus ? const Color(0xFFFFB703) : color.withOpacity(0.4),
                  width: hasFocus ? 3 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: hasFocus 
                    ? const Color(0xFFFFB703).withOpacity(0.4)
                    : color.withOpacity(0.05),
                    blurRadius: hasFocus ? 16 : 8,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: hasFocus ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(icon, size: 55, color: hasFocus ? const Color(0xFFFFB703) : color),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: hasFocus ? const Color(0xFFFFB703) : Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }
}
