import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/data_models.dart';
import '../services/storage_service.dart';

class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  List<Account> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accs = await StorageService.getAccounts();
    setState(() {
      _accounts = accs;
      _isLoading = false;
    });
  }

  Future<void> _selectAccount(Account account) async {
    await StorageService.setActiveAccount(account);
    if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
  }

  Future<void> _confirmDelete(Account account) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151F32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF233554), width: 1),
        ),
        title: Text("Eliminar Cuenta", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        content: Text(
          "¿Estás seguro de que deseas eliminar la cuenta '${account.name}'? Esto borrará tus datos locales de esta cuenta.",
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancelar", style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await StorageService.deleteAccount(account);
              _loadAccounts();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF090D16),
              Color(0xFF0F172A),
              Color(0xFF111827),
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFB703)))
              : Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Text(
                            "¿Quién está viendo hoy?",
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Selecciona tu perfil de LotusPlay",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Grid of Profiles
                    Expanded(
                      child: _accounts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.people_outline, size: 70, color: Colors.white24),
                                  const SizedBox(height: 16),
                                  Text(
                                    "No hay perfiles configurados",
                                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
                                  ),
                                ],
                              ),
                            )
                          : Center(
                              child: SingleChildScrollView(
                                child: Wrap(
                                  spacing: 24,
                                  runSpacing: 24,
                                  alignment: WrapAlignment.center,
                                  children: _accounts.map((acc) => _buildProfileCard(acc)).toList(),
                                ),
                              ),
                            ),
                    ),

                    // Actions Footer
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
                      child: Column(
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 350),
                            child: SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFB703),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  elevation: 4,
                                ),
                                icon: const Icon(Icons.add, color: Colors.black),
                                label: Text(
                                  "AGREGAR CUENTA",
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pushNamed(context, '/login');
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "LotusPlay Multi-Profile System • @Kinglotusp",
                            style: GoogleFonts.inter(color: Colors.white24, fontSize: 11),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(Account acc) {
    // Generate a simple gradient color based on account name
    final int hash = acc.name.hashCode;
    final List<Color> gradientColors = [
      Color(0xFF00B4D8).withOpacity(0.9), // Cyan
      Color(0xFF0077B6).withOpacity(0.9), // Darker Blue
    ];
    if (hash % 3 == 1) {
      gradientColors[0] = const Color(0xFFFF7096).withOpacity(0.9); // Pink
      gradientColors[1] = const Color(0xFFFF0A54).withOpacity(0.9); // Red
    } else if (hash % 3 == 2) {
      gradientColors[0] = const Color(0xFF70E000).withOpacity(0.9); // Lime Green
      gradientColors[1] = const Color(0xFF38B000).withOpacity(0.9); // Green
    }

    return Focus(
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: () => _selectAccount(acc),
            onLongPress: () => _confirmDelete(acc),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              transform: hasFocus ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
              width: 130,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Profile Avatar Box
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: gradientColors,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: hasFocus ? const Color(0xFFFFB703) : const Color(0xFF233554),
                            width: hasFocus ? 3 : 1.5,
                          ),
                          boxShadow: hasFocus
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFFFB703).withOpacity(0.4),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  )
                                ]
                              : [],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          acc.name.substring(0, 1).toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              const Shadow(color: Colors.black38, offset: Offset(2, 2), blurRadius: 4)
                            ],
                          ),
                        ),
                      ),
                      
                      // Delete action absolute positioning
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Focus(
                          child: Builder(
                            builder: (context) {
                              final deleteHasFocus = Focus.of(context).hasFocus;
                              return GestureDetector(
                                onTap: () => _confirmDelete(acc),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: deleteHasFocus ? Colors.redAccent : Colors.black87,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: deleteHasFocus ? Colors.white : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: deleteHasFocus ? Colors.white : Colors.redAccent,
                                    size: 16,
                                  ),
                                ),
                              );
                            }
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    acc.name,
                    style: GoogleFonts.outfit(
                      color: hasFocus ? const Color(0xFFFFB703) : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    acc.type == 'xtream' ? 'Xtream Codes' : 'M3U',
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 11,
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
