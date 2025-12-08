import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../models/data_models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'player_screen.dart';

class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key});

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  // Data
  List<Channel> _allChannels = [];
  List<String> _categories = [];
  Set<String> _favorites = {};
  
  // State
  String _selectedCategory = "Todas";
  bool _isLoading = true;
  Account? _account;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    _account = await StorageService.getActiveAccount();
    if (_account == null) return;

    setState(() => _isLoading = true);
    
    try {
      // 1. Load Favorites
      final favList = await StorageService.getFavorites();
      _favorites = favList.toSet();

      // 2. Load Channels
      List<Channel> channels = [];
      if (_account!.type == 'xtream') {
        channels = await ApiService.getXtreamLive(_account!.url, _account!.username, _account!.password);
      } else {
        final response = await http.get(Uri.parse(_account!.url));
        if (response.statusCode == 200) {
          channels = ApiService.parseM3u(response.body);
        }
      }
      
      // 3. Extract Categories
      final Set<String> cats = {"Todas", "Favoritos"};
      for (var c in channels) {
        cats.add(c.group);
      }
      
      setState(() {
        _allChannels = channels;
        _categories = cats.toList()..sort();
        // Move specal cats to top
        _categories.remove("Todas");
        _categories.remove("Favoritos");
        _categories.insert(0, "Favoritos");
        _categories.insert(0, "Todas");
      });

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1B2A),
        body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
      );
    }

    // Filter Logic
    List<Channel> displayedChannels = [];
    if (_selectedCategory == "Todas") {
      displayedChannels = _allChannels;
    } else if (_selectedCategory == "Favoritos") {
      displayedChannels = _allChannels.where((c) => _favorites.contains(c.url)).toList();
    } else {
      displayedChannels = _allChannels.where((c) => c.group == _selectedCategory).toList();
    }

    // Search Logic
    if (_searchQuery.isNotEmpty) {
      displayedChannels = displayedChannels.where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Text("TV EN VIVO", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1B263B),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
               style: const TextStyle(color: Colors.white),
               decoration: InputDecoration(
                 hintText: "Buscar canal...",
                 hintStyle: const TextStyle(color: Colors.white54),
                 prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                 filled: true,
                 fillColor: Colors.black26,
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
               ),
               onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
        ),
      ),
      body: Row(
        children: [
          // Left Column: Categories
          Expanded(
            flex: 2,
            child: Container(
              color: const Color(0xFF161B22),
              child: ListView.separated(
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = cat == _selectedCategory;
                  return ListTile(
                    title: Text(cat, style: GoogleFonts.inter(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    tileColor: isSelected ? Colors.blueAccent.withOpacity(0.2) : null,
                    selected: isSelected,
                    selectedTileColor: Colors.blueAccent.withOpacity(0.2), // Highlight
                    leading: isSelected ? const Icon(Icons.arrow_right, color: Colors.blueAccent) : null,
                    onTap: () => setState(() => _selectedCategory = cat),
                  );
                },
              ),
            ),
          ),
          
          // Right Column: Channels
          Expanded(
            flex: 5, // Wider area for channels
            child: Container(
              color: const Color(0xFF0D1B2A), // Darker bg
              child: ListView.builder(
                itemCount: displayedChannels.length,
                itemBuilder: (context, index) {
                   final channel = displayedChannels[index];
                   final isFav = _favorites.contains(channel.url);
                   
                   return Card(
                     color: const Color(0xFF1B263B),
                     margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                     child: ListTile(
                       leading: Container(
                         width: 50, height: 50,
                         decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(5)),
                         child: channel.logo.isNotEmpty 
                           ? Image.network(channel.logo, fit: BoxFit.contain, errorBuilder: (_,__,___) => const Icon(Icons.tv, color: Colors.white24))
                           : const Icon(Icons.tv, color: Colors.white24),
                       ),
                       title: Text(channel.name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
                       trailing: IconButton(
                         icon: Icon(isFav ? Icons.star : Icons.star_border, color: Colors.amber),
                         onPressed: () async {
                           await StorageService.toggleFavorite(channel.url);
                           final newFavs = await StorageService.getFavorites();
                           setState(() => _favorites = newFavs.toSet());
                         },
                       ),
                       onTap: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(url: channel.url, title: channel.name)));
                       },
                     ),
                   );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
