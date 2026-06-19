import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/data_models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'player_screen.dart';
import '../widgets/skeleton_loader.dart';

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Account? _account;
  
  List<Channel> _movies = [];
  Map<String, String> _categoryMap = {};
  List<String> _categories = [];
  Set<String> _favorites = {};
  
  String _selectedCategory = "Todas";
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  Future<void> _loadMovies({bool forceRefresh = false}) async {
    final account = await StorageService.getActiveAccount();
    if (account == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final favList = await StorageService.getFavorites();

    setState(() {
      _account = account;
      _favorites = favList.toSet();
      _isLoading = true;
      _errorMessage = null;
    });

    if (account.type != 'xtream') {
      setState(() {
        _isLoading = false;
        _errorMessage = "Esta sección requiere una cuenta Xtream Codes. Las listas M3U muestran todo su contenido en la sección de TV en Vivo.";
      });
      return;
    }

    try {
      List<Channel> movies = [];
      Map<String, String> catMap = {};

      bool loadedFromCache = false;
      if (!forceRefresh) {
        final cached = await StorageService.getCachedChannels(account, 'vod');
        final cachedCats = await StorageService.getCachedCategories(account, 'vod');
        if (cached != null && cached.isNotEmpty) {
          movies = cached;
          catMap = cachedCats ?? {};
          loadedFromCache = true;
        }
      }

      if (!loadedFromCache) {
        final results = await Future.wait([
          ApiService.getXtreamVod(account.url, account.username, account.password),
          ApiService.getXtreamVodCategories(account.url, account.username, account.password),
        ]).timeout(const Duration(seconds: 25));

        movies = results[0] as List<Channel>;
        catMap = results[1] as Map<String, String>;

        await StorageService.cacheChannels(account, 'vod', movies);
        if (catMap.isNotEmpty) {
          await StorageService.cacheCategories(account, 'vod', catMap);
        }
      }

      final Set<String> cats = {"Todas", "Favoritos"};
      for (var m in movies) {
        cats.add(m.group);
      }

      setState(() {
        _movies = movies;
        _categoryMap = catMap;
        _categories = cats.toList()..sort((a, b) {
             if (a == "Todas" || a == "Favoritos") return -1;
             if (b == "Todas" || b == "Favoritos") return 1;
             final nameA = _categoryMap[a] ?? a;
             final nameB = _categoryMap[b] ?? b;
             return nameA.compareTo(nameB);
        });
        
        _categories.remove("Todas");
        _categories.remove("Favoritos");
        _categories.insert(0, "Favoritos");
        _categories.insert(0, "Todas");
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error cargando películas: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  Future<void> _reloadFavorites() async {
    final favList = await StorageService.getFavorites();
    if (mounted) {
      setState(() {
        _favorites = favList.toSet();
      });
    }
  }

  String _getCategoryName(String id) {
     if (id == "Todas") return "Todas las Categorías";
     if (id == "Favoritos") return "★ Favoritos";
     return _categoryMap[id] ?? id;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF090D16),
        appBar: AppBar(
          title: Text("PELÍCULAS", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF151F32),
          elevation: 0,
        ),
        body: Row(
          children: [
            // Left column categories skeleton
            Container(
              width: 180,
              decoration: const BoxDecoration(
                color: Color(0xFF0C1322),
                border: Border(right: BorderSide(color: Color(0xFF1E293B), width: 1.5)),
              ),
              child: ListView.builder(
                itemCount: 8,
                itemBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  child: ShimmerLoading(width: 120, height: 14),
                ),
              ),
            ),
            // Right column movies grid skeleton
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 140, 
                  childAspectRatio: 0.7, 
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: 12,
                itemBuilder: (_, __) => const CardSkeleton(),
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF090D16),
        appBar: AppBar(
          backgroundColor: const Color(0xFF151F32),
          title: Text("PELÍCULAS", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _account?.type == 'xtream' ? Icons.error_outline : Icons.info_outline,
                  size: 64,
                  color: _account?.type == 'xtream' ? Colors.redAccent : Colors.blueAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (_account?.type == 'xtream')
                  ElevatedButton.icon(
                    onPressed: () => _loadMovies(forceRefresh: true),
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
    List<Channel> displayedMovies = [];
    if (_selectedCategory == "Todas") {
      displayedMovies = _movies;
    } else if (_selectedCategory == "Favoritos") {
      displayedMovies = _movies.where((m) => _favorites.contains(m.url)).toList();
    } else {
      displayedMovies = _movies.where((m) => m.group == _selectedCategory).toList();
    }

    // Search Logic
    if (_searchQuery.isNotEmpty) {
      displayedMovies = displayedMovies.where((m) => m.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("PELÍCULAS (VOD)", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            Text("@Kinglotusp", style: GoogleFonts.inter(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF151F32),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.redAccent),
            tooltip: "Sincronizar Películas",
            onPressed: () => _loadMovies(forceRefresh: true),
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
                 hintText: "Buscar película...",
                 hintStyle: const TextStyle(color: Colors.white30),
                 prefixIcon: const Icon(Icons.search, color: Colors.redAccent),
                 filled: true,
                 fillColor: const Color(0xFF090D16),
                 enabledBorder: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(30),
                   borderSide: const BorderSide(color: Color(0xFF233554), width: 1.5),
                 ),
                 focusedBorder: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(30),
                   borderSide: const BorderSide(color: Colors.redAccent, width: 2.0),
                 ),
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
                
                // Right Column: Grid of Movies
                Expanded(
                  child: Container(
                    color: const Color(0xFF090D16),
                    child: displayedMovies.isEmpty
                        ? Center(
                            child: Text(
                              "No se encontraron películas",
                              style: GoogleFonts.inter(color: Colors.white30, fontSize: 16),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 140, 
                              childAspectRatio: 0.7, 
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: displayedMovies.length,
                            itemBuilder: (context, index) {
                              final movie = displayedMovies[index];
                              return _buildMovieCard(movie);
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
                    ? Colors.redAccent.withOpacity(0.18) 
                    : (hasFocus ? Colors.white10 : Colors.transparent),
                border: Border(
                  left: BorderSide(
                    color: isSelected 
                        ? Colors.redAccent 
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

  Widget _buildMovieCard(Channel movie) {
    final isFav = _favorites.contains(movie.url);
    return Focus(
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(channel: movie)))
                  .then((_) => _reloadFavorites());
            },
            onLongPress: () async {
              await StorageService.toggleFavorite(movie.url);
              await _reloadFavorites();
              if (context.mounted) {
                final nextFav = _favorites.contains(movie.url);
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      nextFav 
                          ? "Añadida '${movie.name}' a Favoritos" 
                          : "Eliminada '${movie.name}' de Favoritos",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    duration: const Duration(seconds: 2),
                    backgroundColor: nextFav ? Colors.green : Colors.redAccent,
                  ),
                );
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOut,
              transform: hasFocus ? (Matrix4.identity()..scale(1.06)) : Matrix4.identity(),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasFocus ? Colors.redAccent : const Color(0xFF233554),
                  width: hasFocus ? 2.5 : 1.0,
                ),
                boxShadow: hasFocus
                    ? [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: const Color(0xFF151F32)),
                    if (isFav)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.star,
                            color: Color(0xFFFFB703),
                            size: 16,
                          ),
                        ),
                      ),
                    movie.logo.isNotEmpty
                        ? Image.network(
                            movie.logo,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.movie, size: 40, color: Colors.white24),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.movie, size: 40, color: Colors.white24),
                          ),
                    // Shadow overlay for title readability
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        child: Text(
                          movie.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }
}
