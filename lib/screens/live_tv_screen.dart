import 'package:flutter/foundation.dart';
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
  List<String> _history = [];
  
  // State
  String _selectedCategory = "Todas";
  bool _isLoading = true;
  String? _errorMessage;
  Account? _account;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent({bool forceRefresh = false}) async {
    _account = await StorageService.getActiveAccount();
    if (_account == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // 1. Cargar favoritos e historial en paralelo
      final resultsFavHist = await Future.wait([
        StorageService.getFavorites(),
        StorageService.getHistory(_account!),
      ]);
      _favorites = (resultsFavHist[0] as List<String>).toSet();
      _history = resultsFavHist[1] as List<String>;

      List<Channel> channels = [];
      Map<String, String> catMap = {};

      // 2. Intentar cargar desde caché local
      bool loadedFromCache = false;
      if (!forceRefresh) {
        final cached = await StorageService.getCachedChannels(_account!, 'live');
        final cachedCats = await StorageService.getCachedCategories(_account!, 'live');
        if (cached != null && cached.isNotEmpty) {
          channels = cached;
          catMap = cachedCats ?? {};
          loadedFromCache = true;
        }
      }

      // 3. Si no hay caché o es refresco forzado, descargar
      if (!loadedFromCache) {
        if (_account!.type == 'xtream') {
          final results = await Future.wait([
            ApiService.getXtreamLive(_account!.url, _account!.username, _account!.password),
            ApiService.getXtreamCategories(_account!.url, _account!.username, _account!.password)
          ]).timeout(const Duration(seconds: 20));
          
          channels = results[0] as List<Channel>;
          catMap = results[1] as Map<String, String>;
        } else {
          final response = await http.get(Uri.parse(_account!.url)).timeout(const Duration(seconds: 25));
          if (response.statusCode == 200) {
            channels = await compute(ApiService.parseM3u, response.body);
          } else {
            throw Exception("El servidor retornó código de error: ${response.statusCode}");
          }
        }

        // Guardar en almacenamiento local para acceso instantáneo posterior
        await StorageService.cacheChannels(_account!, 'live', channels);
        if (catMap.isNotEmpty) {
          await StorageService.cacheCategories(_account!, 'live', catMap);
        }
      }
      
      // 4. Extraer categorías
      final Set<String> cats = {"Todas", "Favoritos", "Recientes"};
      for (var c in channels) {
        cats.add(c.group);
      }
      
      setState(() {
        _allChannels = channels;
        _categoryMap = catMap;
        _categories = cats.toList()..sort((a, b) {
             if (a == "Todas" || a == "Favoritos" || a == "Recientes") return -1;
             if (b == "Todas" || b == "Favoritos" || b == "Recientes") return 1;
             final nameA = _categoryMap[a] ?? a;
             final nameB = _categoryMap[b] ?? b;
             return nameA.compareTo(nameB);
        });
        
        _categories.remove("Todas");
        _categories.remove("Favoritos");
        _categories.remove("Recientes");
        _categories.insert(0, "Recientes");
        _categories.insert(0, "Favoritos");
        _categories.insert(0, "Todas");
      });

    } catch (e) {
      setState(() => _errorMessage = "Error cargando canales: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reloadFavoritesAndHistory() async {
    if (_account == null) return;
    final favList = await StorageService.getFavorites();
    final histList = await StorageService.getHistory(_account!);
    setState(() {
      _favorites = favList.toSet();
      _history = histList;
    });
  }

  String _getCategoryName(String id) {
     if (id == "Todas") return "Todas las Categorías";
     if (id == "Favoritos") return "★ Favoritos";
     if (id == "Recientes") return "🕒 Recientes";
     return _categoryMap[id] ?? id;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF090D16),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFFFB703)),
              SizedBox(height: 16),
              Text("Cargando lista de canales...", style: TextStyle(color: Colors.white70, fontSize: 15)),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF090D16),
        appBar: AppBar(
          backgroundColor: const Color(0xFF151F32),
          title: Text("TV EN VIVO", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _loadContent(forceRefresh: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Reintentar"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Filter Logic
    List<Channel> displayedChannels = [];
    if (_selectedCategory == "Todas") {
      displayedChannels = _allChannels;
    } else if (_selectedCategory == "Favoritos") {
      displayedChannels = _allChannels.where((c) => _favorites.contains(c.url)).toList();
    } else if (_selectedCategory == "Recientes") {
      // Filtrar y ordenar según el orden del historial
      displayedChannels = _allChannels.where((c) => _history.contains(c.url)).toList();
      displayedChannels.sort((a, b) => _history.indexOf(a.url).compareTo(_history.indexOf(b.url)));
    } else {
      displayedChannels = _allChannels.where((c) => c.group == _selectedCategory).toList();
    }

    // Search Logic
    if (_searchQuery.isNotEmpty) {
      displayedChannels = displayedChannels.where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("TV EN VIVO", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            Text("@Kinglotusp", style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFFFB703), fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF151F32),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Color(0xFFFFB703)),
            tooltip: "Sincronizar Canales",
            onPressed: () => _loadContent(forceRefresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar Area
          Container(
            color: const Color(0xFF151F32),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
               style: const TextStyle(color: Colors.white),
               decoration: InputDecoration(
                 hintText: "Buscar canal por nombre...",
                 hintStyle: const TextStyle(color: Colors.white30),
                 prefixIcon: const Icon(Icons.search, color: Color(0xFFFFB703)),
                 filled: true,
                 fillColor: const Color(0xFF090D16),
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                 contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
               ),
               onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          
          Expanded(
            child: Row(
              children: [
                // Left Column: Categories
                SizedBox(
                  width: 180,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF0C1322),
                      border: Border(right: BorderSide(color: Color(0xFF1E293B), width: 1.5)),
                    ),
                    child: ListView.builder(
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final catId = _categories[index];
                        final catName = _getCategoryName(catId);
                        final isSelected = catId == _selectedCategory;
                        
                        return _buildCategoryItem(catId, catName, isSelected);
                      },
                    ),
                  ),
                ),
                
                // Right Column: Channels
                Expanded(
                  child: Container(
                    color: const Color(0xFF090D16),
                    child: displayedChannels.isEmpty
                        ? Center(
                            child: Text(
                              "No se encontraron canales",
                              style: GoogleFonts.inter(color: Colors.white30, fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: displayedChannels.length,
                            itemBuilder: (context, index) {
                              final channel = displayedChannels[index];
                              final isFav = _favorites.contains(channel.url);
                              
                              return _buildChannelTile(channel, isFav);
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

  Widget _buildCategoryItem(String catId, String catName, bool isSelected) {
    return Focus(
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return InkWell(
            onTap: () => setState(() => _selectedCategory = catId),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFFFFB703).withOpacity(0.18) 
                    : (hasFocus ? Colors.white10 : Colors.transparent),
                border: Border(
                  left: BorderSide(
                    color: isSelected 
                        ? const Color(0xFFFFB703) 
                        : (hasFocus ? Colors.white30 : Colors.transparent),
                    width: 4,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Text(
                catName, 
                style: GoogleFonts.inter(
                  color: isSelected || hasFocus ? Colors.white : Colors.white54, 
                  fontSize: 13,
                  fontWeight: isSelected || hasFocus ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildChannelTile(Channel channel, bool isFav) {
    return Focus(
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: hasFocus ? const Color(0xFFFFB703).withOpacity(0.15) : const Color(0xFF151F32),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasFocus ? const Color(0xFFFFB703) : const Color(0xFF233554),
                width: hasFocus ? 2 : 1,
              ),
              boxShadow: hasFocus
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFB703).withOpacity(0.25),
                        blurRadius: 10,
                      )
                    ]
                  : [],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black26, 
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: channel.logo.isNotEmpty 
                    ? Image.network(
                        channel.logo, 
                        fit: BoxFit.contain, 
                        errorBuilder: (_,__,___) => const Icon(Icons.tv, color: Colors.white24, size: 22),
                      )
                    : const Icon(Icons.tv, color: Colors.white24, size: 22),
                ),
              ),
              title: Text(
                channel.name, 
                style: GoogleFonts.inter(
                  color: Colors.white, 
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              trailing: Focus(
                descendantsAreFocusable: false,
                child: IconButton(
                  icon: Icon(isFav ? Icons.star : Icons.star_border, color: const Color(0xFFFFB703)),
                  onPressed: () async {
                    await StorageService.toggleFavorite(channel.url);
                    _reloadFavoritesAndHistory();
                  },
                ),
              ),
              onTap: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => PlayerScreen(url: channel.url, title: channel.name)),
                ).then((_) => _reloadFavoritesAndHistory());
              },
            ),
          );
        }
      ),
    );
  }
}
