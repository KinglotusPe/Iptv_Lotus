import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        title: Text("AJUSTES", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF151F32),
        elevation: 0,
      ),
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
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            _buildSettingsItem(
              icon: Icons.info_outline,
              iconColor: Colors.blueAccent,
              title: "Acerca de",
              subtitle: "LotusPlay v1.0.0 desarrollado por @Kinglotusp",
              onTap: null,
            ),
            const Divider(color: Colors.white10, height: 1),
            _buildSettingsItem(
              icon: Icons.delete_outline,
              iconColor: Colors.redAccent,
              title: "Borrar Favoritos",
              subtitle: "Limpia la lista de todos tus canales marcados",
              onTap: () async {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF151F32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFF233554)),
                    ),
                    title: Text("Confirmar", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                    content: Text("¿Seguro que quieres borrar todos los favoritos?", style: GoogleFonts.inter(color: Colors.white70)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text("Cancelar", style: TextStyle(color: Colors.grey[400])),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await StorageService.saveFavorites([]);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Favoritos borrados")),
                            );
                          }
                        },
                        child: const Text("Borrar", style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(color: Colors.white10, height: 1),
            _buildSettingsItem(
              icon: Icons.switch_account_outlined,
              iconColor: Colors.purpleAccent,
              title: "Cambiar Perfil",
              subtitle: "Selecciona otra cuenta configurada",
              onTap: () {
                 Navigator.pushNamed(context, '/profiles');
              },
            ),
            const Divider(color: Colors.white10, height: 1),
            _buildSettingsItem(
              icon: Icons.logout_outlined,
              iconColor: Colors.orangeAccent,
              title: "Cerrar Sesión",
              subtitle: "Salir del perfil activo actual",
              onTap: () async {
                 await StorageService.clearActiveAccount();
                 if (context.mounted) {
                   final accounts = await StorageService.getAccounts();
                   if (accounts.isNotEmpty) {
                      Navigator.pushReplacementNamed(context, '/profiles');
                   } else {
                      Navigator.pushReplacementNamed(context, '/login');
                   }
                 }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Focus(
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return Container(
            color: hasFocus ? const Color(0xFFFFB703).withOpacity(0.08) : null,
            child: ListTile(
              leading: Icon(icon, color: hasFocus ? const Color(0xFFFFB703) : iconColor, size: 26),
              title: Text(
                title, 
                style: GoogleFonts.inter(
                  color: Colors.white, 
                  fontWeight: hasFocus ? FontWeight.bold : FontWeight.w600,
                ),
              ),
              subtitle: Text(subtitle, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
              onTap: onTap,
            ),
          );
        }
      ),
    );
  }
}
