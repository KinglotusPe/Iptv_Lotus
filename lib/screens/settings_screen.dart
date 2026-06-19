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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("AJUSTES Y PREFERENCIAS", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            Text("@Kinglotusp", style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFFFB703), fontWeight: FontWeight.bold)),
          ],
        ),
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
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            _buildSettingsItem(
              context: context,
              icon: Icons.info_outline,
              iconColor: Colors.blueAccent,
              title: "Acerca de",
              subtitle: "LotusPlay v1.1.0 desarrollado por @Kinglotusp. Optimizado para TV Box y bajo consumo de recursos (512MB RAM).",
              onTap: null,
            ),
            _buildSettingsItem(
              context: context,
              icon: Icons.cached_outlined,
              iconColor: Colors.amberAccent,
              title: "Limpiar Caché Local",
              subtitle: "Elimina los listados temporales de canales y categorías locales para forzar una recarga limpia del servidor",
              onTap: () async {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF151F32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFF233554)),
                    ),
                    title: Text("Limpiar Caché", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                    content: Text(
                      "¿Seguro que deseas borrar toda la caché local? Esto obligará a la aplicación a descargar todos los canales nuevamente en su próximo inicio.",
                      style: GoogleFonts.inter(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        autofocus: true,
                        onPressed: () => Navigator.pop(ctx),
                        child: Text("Cancelar", style: TextStyle(color: Colors.grey[400])),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await StorageService.clearCache();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Caché local borrada con éxito"),
                                backgroundColor: Color(0xFFFFB703),
                                foregroundColor: Colors.black,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB703), foregroundColor: Colors.black),
                        child: const Text("Limpiar"),
                      ),
                    ],
                  ),
                );
              },
            ),
            _buildSettingsItem(
              context: context,
              icon: Icons.delete_outline,
              iconColor: Colors.redAccent,
              title: "Borrar Favoritos",
              subtitle: "Limpia la lista de todos tus canales, películas y series marcadas como preferidos",
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
                    content: Text("¿Seguro que quieres borrar todos los favoritos guardados?", style: GoogleFonts.inter(color: Colors.white70)),
                    actions: [
                      TextButton(
                        autofocus: true,
                        onPressed: () => Navigator.pop(ctx),
                        child: Text("Cancelar", style: TextStyle(color: Colors.grey[400])),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await StorageService.saveFavorites([]);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Favoritos borrados con éxito")),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                        child: const Text("Borrar"),
                      ),
                    ],
                  ),
                );
              },
            ),
            _buildSettingsItem(
              context: context,
              icon: Icons.switch_account_outlined,
              iconColor: Colors.purpleAccent,
              title: "Cambiar Perfil",
              subtitle: "Selecciona otra cuenta configurada en este dispositivo",
              onTap: () {
                 Navigator.pushNamed(context, '/profiles');
              },
            ),
            _buildSettingsItem(
              context: context,
              icon: Icons.logout_outlined,
              iconColor: Colors.orangeAccent,
              title: "Cerrar Sesión",
              subtitle: "Salir del perfil activo actual de forma segura",
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
    required BuildContext context,
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
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: hasFocus ? const Color(0xFFFFB703).withOpacity(0.12) : const Color(0xFF151F32),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasFocus ? const Color(0xFFFFB703) : const Color(0xFF233554),
                width: hasFocus ? 2.5 : 1.0,
              ),
              boxShadow: hasFocus
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFB703).withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasFocus ? const Color(0xFFFFB703).withOpacity(0.2) : iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: hasFocus ? const Color(0xFFFFB703) : iconColor, size: 24),
              ),
              title: Text(
                title, 
                style: GoogleFonts.inter(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                subtitle, 
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
              ),
              onTap: onTap,
            ),
          );
        }
      ),
    );
  }
}
