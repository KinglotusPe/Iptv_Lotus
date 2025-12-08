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
  Map<String, String> _categoryMap = {}; // ID -> Name
  List<String> _categories = []; // list of IDs (or names if m3u)
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

      List<Channel> channels = [];
      Map<String, String> catMap = {};

      if (_account!.type == 'xtream') {
        // Parallel fetch for speed
        final results = await Future.wait([
          ApiService.getXtreamLive(_account!.url, _account!.username, _account!.password),
          ApiService.getXtreamCategories(_account!.url, _account!.username, _account!.password)
        ]);
        
        channels = results[0] as List<Channel>;
        catMap = results[1] as Map<String, String>;
      } else {
        final response = await http.get(Uri.parse(_account!.url));
        if (response.statusCode == 200) {
          channels = ApiService.parseM3u(response.body);
          // M3U categories are just strings in the channel object
        }
      }
      
      // 3. Extract Categories
      final Set<String> cats = {"Todas", "Favoritos"};
      
      // Populate IDs or Names
      for (var c in channels) {
        cats.add(c.group); // For Xtream, this is the ID. For M3U, it's the Name.
      }
      
      setState(() {
        _allChannels = channels;
        _categoryMap = catMap;
        _categories = cats.toList()..sort((a, b) {
             // Sort by mapped name if available, else by ID/Name
             final nameA = _categoryMap[a] ?? a;
             final nameB = _categoryMap[b] ?? b;
             return nameA.compareTo(nameB);
        });
        
        // Ensure special cats are at top
        _categories.remove("Todas");
        _categories.remove("Favoritos");
        _categories.insert(0, "Favoritos");
        _categories.insert(0, "Todas");
      });

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getCategoryName(String id) {
     if (id == "Todas") return "Todas";
     if (id == "Favoritos") return "Favoritos";
     return _categoryMap[id] ?? id; // Return Name if mapped, else ID
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("TV EN VIVO", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            Text("@Kinglotusp", style: GoogleFonts.inter(fontSize: 10, color: Colors.amber)),
          ],
        ),
        backgroundColor: const Color(0xFF1B263B),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar Area (Clean, no overlap)
          Container(
            color: const Color(0xFF1B263B),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
               style: const TextStyle(color: Colors.white),
               decoration: InputDecoration(
                 hintText: "Buscar canal...",
                 hintStyle: const TextStyle(color: Colors.white54),
                 prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                 filled: true,
                 fillColor: Colors.black26,
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                 isDense: true, // Compact
               ),
               onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          
          Expanded(
            child: Row(
              children: [
                // Left Column: Categories
                SizedBox(
                  width: 120, // Fixed width sidebar
                  child: Container(
                    color: const Color(0xFF161B22),
                    child: ListView.separated(
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                      itemBuilder: (context, index) {
                        final catId = _categories[index];
                        final catName = _getCategoryName(catId);
                        final isSelected = catId == _selectedCategory;
                        
                        return InkWell(
                          onTap: () => setState(() => _selectedCategory = catId),
                          child: Container(
                            color: isSelected ? Colors.blueAccent.withOpacity(0.2) : null,
                            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                            child: Row(
                              children: [
                                if (isSelected) Container(width: 3, height: 15, color: Colors.blueAccent, margin: const EdgeInsets.only(right: 5)),
                                Expanded(
                                  child: Text(
                                    catName, 
                                    style: GoogleFonts.inter(
                                      color: isSelected ? Colors.white : Colors.white70, 
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                
                // Right Column: Channels
                Expanded(
                  child: Container(
                    color: const Color(0xFF0D1B2A),
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
          ),
        ],
      ),
    );
  }
}
