import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Text("AJUSTES", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1B263B),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.info, color: Colors.blueAccent),
            title: const Text("Acerca de", style: TextStyle(color: Colors.white)),
            subtitle: const Text("LotusPlay v1.0.0 desarrollado por @Kinglotusp", style: TextStyle(color: Colors.white54)),
          ),
          const Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.redAccent),
            title: const Text("Borrar Favoritos", style: TextStyle(color: Colors.white)),
            onTap: () async {
              showDialog(context: context, builder: (ctx) => AlertDialog(
                title: const Text("Confirmar"),
                content: const Text("¿Seguro que quieres borrar todos los favoritos?"),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                  TextButton(onPressed: () async {
                    Navigator.pop(ctx);
                    await StorageService.saveFavorites([]);
                    if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Favoritos borrados")));
                  }, child: const Text("Borrar")),
                ],
              ));
            },
          ),
          const Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.orange),
            title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.white)),
            onTap: () async {
               await StorageService.clearActiveAccount();
               if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }
}
