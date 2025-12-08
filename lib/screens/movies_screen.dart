import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/data_models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'player_screen.dart';

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  bool _isLoading = true;
  List<Channel> _movies = [];
  List<Channel> _displayedMovies = [];
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadMovies();
  }

  Future<void> _loadMovies() async {
    final account = await StorageService.getActiveAccount();
    if (account != null && account.type == 'xtream') {
      try {
        final movies = await ApiService.getXtreamVod(account.url, account.username, account.password);
        if (mounted) {
          setState(() {
            _movies = movies;
            _displayedMovies = movies;
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

  void _filterMovies(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _displayedMovies = _movies;
      } else {
        _displayedMovies = _movies.where((m) => m.name.toLowerCase().contains(query.toLowerCase())).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B263B),
        title: Text("PELÍCULAS", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
               style: const TextStyle(color: Colors.white),
               decoration: InputDecoration(
                 hintText: "Buscar película...",
                 hintStyle: const TextStyle(color: Colors.white54),
                 prefixIcon: const Icon(Icons.search, color: Colors.redAccent),
                 filled: true,
                 fillColor: Colors.black26,
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
               ),
               onChanged: _filterMovies,
            ),
          ),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
        : _displayedMovies.isEmpty 
           ? const Center(child: Text("No se encontraron películas", style: TextStyle(color: Colors.white)))
           : GridView.builder(
               padding: const EdgeInsets.all(10),
               gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                 maxCrossAxisExtent: 150, // Poster width
                 childAspectRatio: 0.7, // Poster aspect ratio
                 crossAxisSpacing: 10,
                 mainAxisSpacing: 10,
               ),
               itemCount: _displayedMovies.length,
               itemBuilder: (context, index) {
                 final movie = _displayedMovies[index];
                 return GestureDetector(
                   onTap: () {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(url: movie.url, title: movie.name)));
                   },
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.stretch,
                     children: [
                       Expanded(
                         child: ClipRRect(
                           borderRadius: BorderRadius.circular(8),
                           child: Container(
                             color: Colors.black26,
                             child: movie.logo.isNotEmpty
                               ? Image.network(movie.logo, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.movie, size: 40, color: Colors.white24))
                               : const Icon(Icons.movie, size: 40, color: Colors.white24),
                           ),
                         ),
                       ),
                       const SizedBox(height: 5),
                       Text(movie.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                     ],
                   ),
                 );
               },
             ),
    );
  }
}
