import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/data_models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class SeriesScreen extends StatefulWidget {
  const SeriesScreen({super.key});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  bool _isLoading = true;
  List<Channel> _series = [];
  List<Channel> _displayedSeries = [];
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadSeries();
  }

  Future<void> _loadSeries() async {
    final account = await StorageService.getActiveAccount();
    if (account != null && account.type == 'xtream') {
      try {
        final series = await ApiService.getXtreamSeries(account.url, account.username, account.password);
        if (mounted) {
          setState(() {
            _series = series;
            _displayedSeries = series;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterSeries(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _displayedSeries = _series;
      } else {
        _displayedSeries = _series.where((s) => s.name.toLowerCase().contains(query.toLowerCase())).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B263B),
        title: Text("SERIES", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
               style: const TextStyle(color: Colors.white),
               decoration: InputDecoration(
                 hintText: "Buscar serie...",
                 hintStyle: const TextStyle(color: Colors.white54),
                 prefixIcon: const Icon(Icons.search, color: Colors.purpleAccent),
                 filled: true,
                 fillColor: Colors.black26,
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
               ),
               onChanged: _filterSeries,
            ),
          ),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
        : _displayedSeries.isEmpty 
           ? const Center(child: Text("No se encontraron series", style: TextStyle(color: Colors.white)))
           : GridView.builder(
               padding: const EdgeInsets.all(10),
               gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                 maxCrossAxisExtent: 150,
                 childAspectRatio: 0.7,
                 crossAxisSpacing: 10,
                 mainAxisSpacing: 10,
               ),
               itemCount: _displayedSeries.length,
               itemBuilder: (context, index) {
                 final serie = _displayedSeries[index];
                 return GestureDetector(
                   onTap: () {
                     // TODO: Implement Episodes view
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Serie: ${serie.name} (Episodios próximamente)")));
                   },
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.stretch,
                     children: [
                       Expanded(
                         child: ClipRRect(
                           borderRadius: BorderRadius.circular(8),
                           child: Container(
                             color: Colors.black26,
                             child: serie.logo.isNotEmpty
                               ? Image.network(serie.logo, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.tv, size: 40, color: Colors.white24))
                               : const Icon(Icons.tv, size: 40, color: Colors.white24),
                           ),
                         ),
                       ),
                       const SizedBox(height: 5),
                       Text(serie.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                     ],
                   ),
                 );
               },
             ),
    );
  }
}
