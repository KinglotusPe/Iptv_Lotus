import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/data_models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'player_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Channel> _channels = [];
  Set<String> _favorites = {};
  bool _isLoading = true;
  bool _showFavoritesOnly = false;
  Account? _account;
  String _filter = "";

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    _account = await StorageService.getActiveAccount();
    if (_account == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Load Favs
      final favList = await StorageService.getFavorites();
      _favorites = favList.toSet();

      if (_account!.type == 'xtream') {
        _channels = await ApiService.getXtreamLive(_account!.url, _account!.username, _account!.password);
      } else {
        final response = await http.get(Uri.parse(_account!.url));
        if (response.statusCode == 200) {
          _channels = ApiService.parseM3u(response.body);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al cargar: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFav(String url) async {
    await StorageService.toggleFavorite(url);
    setState(() {
      if (_favorites.contains(url)) {
        _favorites.remove(url);
      } else {
        _favorites.add(url);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_account == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final filtered = _channels.where((c) {
      final matchesFilter = c.name.toLowerCase().contains(_filter.toLowerCase());
      final matchesFav = !_showFavoritesOnly || _favorites.contains(c.url);
      return matchesFilter && matchesFav;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_account!.name),
        actions: [
          IconButton(
            icon: Icon(_showFavoritesOnly ? Icons.star : Icons.star_border, color: Colors.amber),
            tooltip: "Ver Favoritos",
            onPressed: () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await StorageService.clearActiveAccount();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Buscar canal...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _filter = val),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : filtered.isEmpty 
              ? Center(child: Text(_showFavoritesOnly ? "No hay favoritos" : "No hay canales"))
              : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final channel = filtered[index];
                final isFav = _favorites.contains(channel.url);
                return ListTile(
                  leading: channel.logo.isNotEmpty
                      ? Image.network(channel.logo, width: 50, errorBuilder: (_,__,___) => const Icon(Icons.tv))
                      : const Icon(Icons.tv),
                  title: Text(channel.name),
                  subtitle: Text(channel.group),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(isFav ? Icons.star : Icons.star_border, color: Colors.amber),
                        onPressed: () => _toggleFav(channel.url),
                      ),
                      const Icon(Icons.play_arrow, color: Colors.white54),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PlayerScreen(url: channel.url, title: channel.name)),
                    );
                  },
                );
              },
            ),
    );
  }
}
