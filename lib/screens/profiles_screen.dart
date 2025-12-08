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

  Future<void> _deleteAccount(Account account) async {
     // TODO: Implement delete in StorageService (currently not exposed conveniently, but we can overwrite list)
     // For now, simple implementation assuming we have a delete method or we read/write
     // Since StorageService.saveAccount appends, we need a remove logic.
     // Let's just implement a quick remove in StorageService if needed, or do it here manually for MVP.
     final prefs = await StorageService.getAccounts(); // Actually re-fetching
     final updated = prefs.where((a) => a.url != account.url || a.username != account.username).toList();
     
     // We need to expose a "saveAllAccounts" or similar. 
     // For now, let's keep it simple: Just show "Coming Soon" or implement properly if time permits.
     // Actually, let's just implement a delete method in StorageService quickly after this.
     await StorageService.deleteAccount(account);
     _loadAccounts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Text("PERFILES", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1B263B),
        centerTitle: true,
      ),
      body: _isLoading 
         ? const Center(child: CircularProgressIndicator())
         : Column(
           children: [
             Expanded(
               child: _accounts.isEmpty 
                 ? Center(child: Text("No hay cuentas guardadas", style: GoogleFonts.inter(color: Colors.white54)))
                 : ListView.builder(
                     padding: const EdgeInsets.all(20),
                     itemCount: _accounts.length,
                     itemBuilder: (ctx, index) {
                       final acc = _accounts[index];
                       return Card(
                         color: const Color(0xFF1B263B),
                         margin: const EdgeInsets.only(bottom: 15),
                         child: ListTile(
                           contentPadding: const EdgeInsets.all(15),
                           leading: CircleAvatar(
                             backgroundColor: Colors.amber,
                             child: Text(acc.name[0].toUpperCase(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                           ),
                           title: Text(acc.name, style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                           subtitle: Text(acc.url, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                           trailing: IconButton(
                             icon: const Icon(Icons.delete, color: Colors.redAccent),
                             onPressed: () => _deleteAccount(acc),
                           ),
                           onTap: () => _selectAccount(acc),
                         ),
                       );
                     },
                   ),
             ),
             Padding(
               padding: const EdgeInsets.all(20.0),
               child: SizedBox(
                 width: double.infinity,
                 height: 55,
                 child: ElevatedButton.icon(
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.blueAccent,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                   ),
                   icon: const Icon(Icons.add, color: Colors.white),
                   label: Text("AGREGAR CUENTA", style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                   onPressed: () {
                     Navigator.pushNamed(context, '/login');
                   },
                 ),
               ),
             ),
             // Banner
             Padding(
               padding: const EdgeInsets.only(bottom: 20),
               child: Text("LotusPlay Multi-Account", style: GoogleFonts.inter(color: Colors.white24)),
             )
           ],
         ),
    );
  }
}
