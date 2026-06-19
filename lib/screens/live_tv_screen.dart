import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../models/data_models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'player_screen.dart';
import '../widgets/skeleton_loader.dart';

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

  // EPG state variables
  Channel? _focusedChannel;
  List<EpgProgram> _focusedChannelEpg = [];
  bool _isEpgLoading = false;
  Timer? _epgDebounceTimer;

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

  @override
  void dispose() {
    _epgDebounceTimer?.cancel();
    super.dispose();
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
      return Scaffold(
        backgroundColor: const Color(0xFF090D16),
        appBar: AppBar(
          title: Text("TV EN VIVO", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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
            // Right column channel list skeleton
            Expanded(
              child: ListView.builder(
                itemCount: 6,
                itemBuilder: (_, __) => const ListTileSkeleton(),
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
                
                // Middle Column: Channels
                Expanded(
                  flex: 3,
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
                
                // Right Column: EPG Sidebar Panel
                Builder(
                  builder: (context) {
                    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
                    if (!isLandscape) return const SizedBox.shrink();
                    return Expanded(
                      flex: 2,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF0C1322),
                          border: Border(left: BorderSide(color: Color(0xFF1E293B), width: 1.5)),
                        ),
                        child: _buildEpgPanel(),
                      ),
                    );
                  }
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onChannelFocused(Channel channel) {
    if (_account == null || _account!.type != 'xtream' || channel.streamId == null) {
      setState(() {
        _focusedChannel = channel;
        _focusedChannelEpg = [];
        _isEpgLoading = false;
      });
      return;
    }

    setState(() {
      _focusedChannel = channel;
      _focusedChannelEpg = [];
      _isEpgLoading = true;
    });

    _epgDebounceTimer?.cancel();
    _epgDebounceTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final listings = await ApiService.getXtreamShortEpg(
          _account!.url,
          _account!.username,
          _account!.password,
          channel.streamId!,
        );
        if (mounted && _focusedChannel?.streamId == channel.streamId) {
          setState(() {
            _focusedChannelEpg = listings;
            _isEpgLoading = false;
          });
        }
      } catch (_) {
        if (mounted && _focusedChannel?.streamId == channel.streamId) {
          setState(() {
            _isEpgLoading = false;
          });
        }
      }
    });
  }

  String _formatEpgTime(String rawDateTime) {
    if (rawDateTime.length >= 16) {
      return rawDateTime.substring(11, 16);
    }
    return rawDateTime;
  }

  Widget _buildEpgPanel() {
    if (_focusedChannel == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.tv, size: 64, color: Colors.white12),
              const SizedBox(height: 16),
              Text(
                "Selecciona un canal para ver su guía de programación",
                style: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF233554), width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _focusedChannel!.logo.isNotEmpty
                      ? Image.network(
                          _focusedChannel!.logo,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.tv, color: Colors.white24, size: 28),
                        )
                      : const Icon(Icons.tv, color: Colors.white24, size: 28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _focusedChannel!.name,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getCategoryName(_focusedChannel!.group),
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFFB703),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const Divider(color: Color(0xFF1E293B), height: 30, thickness: 1.5),
          
          Text(
            "GUÍA DE PROGRAMACIÓN",
            style: GoogleFonts.outfit(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          
          if (_isEpgLoading)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerLoading(width: double.infinity, height: 16),
                SizedBox(height: 8),
                ShimmerLoading(width: 120, height: 12),
                SizedBox(height: 16),
                ShimmerLoading(width: double.infinity, height: 60),
                SizedBox(height: 24),
                ShimmerLoading(width: double.infinity, height: 16),
                SizedBox(height: 8),
                ShimmerLoading(width: 80, height: 12),
              ],
            )
          else if (_focusedChannelEpg.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Column(
                  children: [
                    const Icon(Icons.event_busy, size: 40, color: Colors.white24),
                    const SizedBox(height: 12),
                    Text(
                      "No hay programación disponible para este canal en este momento",
                      style: GoogleFonts.inter(color: Colors.white30, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _focusedChannelEpg.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 24),
              itemBuilder: (context, index) {
                final prog = _focusedChannelEpg[index];
                final isCurrent = index == 0;
                
                final timeStr = "${_formatEpgTime(prog.start)} - ${_formatEpgTime(prog.end)}";
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isCurrent 
                                ? const Color(0xFFFFB703).withOpacity(0.2) 
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isCurrent ? const Color(0xFFFFB703) : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            timeStr,
                            style: GoogleFonts.inter(
                              color: isCurrent ? const Color(0xFFFFB703) : Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "EN VIVO",
                            style: GoogleFonts.inter(
                              color: Colors.redAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      prog.title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (prog.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        prog.description,
                        style: GoogleFonts.inter(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                );
              },
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
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          _onChannelFocused(channel);
        }
      },
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
                  MaterialPageRoute(builder: (_) => PlayerScreen(channel: channel)),
                ).then((_) => _reloadFavoritesAndHistory());
              },
            ),
          );
        }
      ),
    );
  }
}
