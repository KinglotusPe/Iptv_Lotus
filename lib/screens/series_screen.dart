import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/data_models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'player_screen.dart';
import '../widgets/skeleton_loader.dart';

class SeriesScreen extends StatefulWidget {
  const SeriesScreen({super.key});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Account? _account;
  
  List<Channel> _series = [];
  Map<String, String> _categoryMap = {};
  List<String> _categories = [];
  
  String _selectedCategory = "Todas";
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadSeries();
  }

  Future<void> _loadSeries({bool forceRefresh = false}) async {
    final account = await StorageService.getActiveAccount();
    if (account == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    setState(() {
      _account = account;
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
      List<Channel> series = [];
      Map<String, String> catMap = {};

      bool loadedFromCache = false;
      if (!forceRefresh) {
        final cached = await StorageService.getCachedChannels(account, 'series');
        final cachedCats = await StorageService.getCachedCategories(account, 'series');
        if (cached != null && cached.isNotEmpty) {
          series = cached;
          catMap = cachedCats ?? {};
          loadedFromCache = true;
        }
      }

      if (!loadedFromCache) {
        final results = await Future.wait([
          ApiService.getXtreamSeries(account.url, account.username, account.password),
          ApiService.getXtreamSeriesCategories(account.url, account.username, account.password),
        ]).timeout(const Duration(seconds: 25));

        series = results[0] as List<Channel>;
        catMap = results[1] as Map<String, String>;

        await StorageService.cacheChannels(account, 'series', series);
        if (catMap.isNotEmpty) {
          await StorageService.cacheCategories(account, 'series', catMap);
        }
      }

      final Set<String> cats = {"Todas"};
      for (var s in series) {
        cats.add(s.group);
      }

      setState(() {
        _series = series;
        _categoryMap = catMap;
        _categories = cats.toList()..sort((a, b) {
             if (a == "Todas") return -1;
             if (b == "Todas") return 1;
             final nameA = _categoryMap[a] ?? a;
             final nameB = _categoryMap[b] ?? b;
             return nameA.compareTo(nameB);
        });
        
        _categories.remove("Todas");
        _categories.insert(0, "Todas");
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error cargando series: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  String _getCategoryName(String id) {
     if (id == "Todas") return "Todas las Categorías";
     return _categoryMap[id] ?? id;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF090D16),
        appBar: AppBar(
          title: Text("SERIES", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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
            // Right column series grid skeleton
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
          title: Text("SERIES", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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
                    onPressed: () => _loadSeries(forceRefresh: true),
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
    List<Channel> displayedSeries = [];
    if (_selectedCategory == "Todas") {
      displayedSeries = _series;
    } else {
      displayedSeries = _series.where((s) => s.group == _selectedCategory).toList();
    }

    // Search Logic
    if (_searchQuery.isNotEmpty) {
      displayedSeries = displayedSeries.where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("SERIES DE TV", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            Text("@Kinglotusp", style: GoogleFonts.inter(fontSize: 10, color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF151F32),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.purpleAccent),
            tooltip: "Sincronizar Series",
            onPressed: () => _loadSeries(forceRefresh: true),
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
                 hintText: "Buscar serie...",
                 hintStyle: const TextStyle(color: Colors.white30),
                 prefixIcon: const Icon(Icons.search, color: Colors.purpleAccent),
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
                
                // Right Column: Grid of Series
                Expanded(
                  child: Container(
                    color: const Color(0xFF090D16),
                    child: displayedSeries.isEmpty
                        ? Center(
                            child: Text(
                              "No se encontraron series",
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
                            itemCount: displayedSeries.length,
                            itemBuilder: (context, index) {
                              final serie = displayedSeries[index];
                              return _buildSeriesCard(serie);
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
                    ? Colors.purpleAccent.withOpacity(0.18) 
                    : (hasFocus ? Colors.white10 : Colors.transparent),
                border: Border(
                  left: BorderSide(
                    color: isSelected 
                        ? Colors.purpleAccent 
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

  Widget _buildSeriesCard(Channel serie) {
    return Focus(
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: () => _showEpisodes(serie),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOut,
              transform: hasFocus ? (Matrix4.identity()..scale(1.06)) : Matrix4.identity(),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasFocus ? Colors.purpleAccent : const Color(0xFF233554),
                  width: hasFocus ? 2.5 : 1.0,
                ),
                boxShadow: hasFocus
                    ? [
                        BoxShadow(
                          color: Colors.purpleAccent.withOpacity(0.3),
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
                    serie.logo.isNotEmpty
                        ? Image.network(
                            serie.logo,
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
                          serie.name,
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

  Future<void> _showEpisodes(Channel serie) async {
    if (_account == null || serie.streamId == null) return;

    // Show Loading Bottom Sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151F32),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SizedBox(
        height: 250, 
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFFFFB703)),
              const SizedBox(height: 16),
              Text(
                "Cargando temporadas de ${serie.name}...",
                style: GoogleFonts.inter(color: Colors.white70),
              )
            ],
          ),
        ),
      ),
    );

    try {
      final episodes = await ApiService.getXtreamSeriesEpisodes(
        _account!.url, _account!.username, _account!.password, serie.streamId!,
      );
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading sheet

      if (episodes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se encontraron episodios para esta serie")),
        );
        return;
      }

      // Group episodes by Season
      final Map<String, List<Channel>> groupedEpisodes = {};
      for (var ep in episodes) {
        final String seasonName = ep.group; // e.g. "Temporada 1"
        groupedEpisodes.putIfAbsent(seasonName, () => []).add(ep);
      }

      final List<String> seasonKeys = groupedEpisodes.keys.toList()
        ..sort((a, b) => a.compareTo(b)); // Sort seasons

      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF151F32),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: Color(0xFF233554), width: 1.5),
        ),
        builder: (context) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, controller) {
              return Column(
                children: [
                  // Grab handle indicator
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(
                      serie.name, 
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 16),
                  
                  // Grouped Expansion Panel List
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      itemCount: seasonKeys.length,
                      itemBuilder: (context, idx) {
                        final String seasonName = seasonKeys[idx];
                        final List<Channel> seasonEpisodes = groupedEpisodes[seasonName]!;

                        return Card(
                          color: const Color(0xFF0C1322),
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFF1E293B), width: 1),
                          ),
                          child: ExpansionTile(
                            title: Text(
                              seasonName,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            iconColor: const Color(0xFFFFB703),
                            collapsedIconColor: Colors.white54,
                            children: seasonEpisodes.map((ep) {
                              return Focus(
                                child: Builder(
                                  builder: (context) {
                                    final hasFocus = Focus.of(context).hasFocus;
                                    return Container(
                                      color: hasFocus ? const Color(0xFFFFB703).withOpacity(0.1) : null,
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                                        leading: Icon(
                                          Icons.play_circle_outline, 
                                          color: hasFocus ? const Color(0xFFFFB703) : Colors.white38,
                                        ),
                                        title: Text(
                                          ep.name, 
                                          style: GoogleFonts.inter(
                                            color: hasFocus ? const Color(0xFFFFB703) : Colors.white,
                                            fontWeight: hasFocus ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                        onTap: () {
                                          Navigator.pop(context); // Close bottom sheet
                                          Navigator.push(
                                            context, 
                                            MaterialPageRoute(builder: (_) => PlayerScreen(channel: ep)),
                                          );
                                        },
                                      ),
                                    );
                                  }
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al cargar episodios: $e")),
        );
      }
    }
  }
}
