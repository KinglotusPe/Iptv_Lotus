import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/data_models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'player_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Channel> _channels = [];
  bool _isLoading = true;
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
      if (_account!.type == 'xtream') {
        _channels = await ApiService.getXtreamLive(_account!.url, _account!.username, _account!.password);
      } else {
        // M3U
        final response = await http.get(Uri.parse(_account!.url));
        if (response.statusCode == 200) {
          _channels = ApiService.parseM3u(response.body);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al cargar: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_account == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final filtered = _channels.where((c) => c.name.toLowerCase().contains(_filter.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_account!.name),
        actions: [
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
          : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final channel = filtered[index];
                return ListTile(
                  leading: channel.logo.isNotEmpty
                      ? Image.network(channel.logo, width: 50, errorBuilder: (_,__,___) => const Icon(Icons.tv))
                      : const Icon(Icons.tv),
                  title: Text(channel.name),
                  subtitle: Text(channel.group),
                  trailing: const Icon(Icons.play_arrow, color: Colors.amber),
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
