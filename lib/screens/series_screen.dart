import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/data_models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'player_screen.dart';

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
                       _showEpisodes(serie);
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

  Future<void> _showEpisodes(Channel serie) async {
    final account = await StorageService.getActiveAccount();
    if (account == null || account.type != 'xtream' || serie.streamId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B263B),
      isScrollControlled: true,
      builder: (context) => const SizedBox(
        height: 200, 
        child: Center(child: CircularProgressIndicator(color: Colors.amber)),
      ),
    );

    try {
      final episodes = await ApiService.getXtreamSeriesEpisodes(account.url, account.username, account.password, serie.streamId!);
      
      if (!mounted) return;
      Navigator.pop(context); // Pop loading

      if (episodes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se encontraron episodios")));
        return;
      }

      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1B263B),
        isScrollControlled: true,
        builder: (context) {
           return DraggableScrollableSheet(
             initialChildSize: 0.6,
             minChildSize: 0.4,
             maxChildSize: 0.9,
             expand: false,
             builder: (_, controller) {
               return Column(
                 children: [
                   Padding(
                     padding: const EdgeInsets.all(16),
                     child: Text(serie.name, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                   ),
                   Expanded(
                     child: ListView.builder(
                       controller: controller,
                       itemCount: episodes.length,
                       itemBuilder: (context, index) {
                         final ep = episodes[index];
                         return ListTile(
                           leading: const Icon(Icons.play_circle_outline, color: Colors.amber),
                           title: Text(ep.name, style: const TextStyle(color: Colors.white)),
                           subtitle: Text(ep.group, style: const TextStyle(color: Colors.white54)), // Season
                           onTap: () {
                              Navigator.pop(context); // Close sheet
                              Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(url: ep.url, title: ep.name)));
                           },
                         );
                       },
                     ),
                   ),
                 ],
               );
             }
           );
        },
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }
