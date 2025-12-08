import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/data_models.dart';

class ApiService {
  
  // --- M3U Logic ---
  static List<Channel> parseM3u(String content) {
    List<Channel> channels = [];
    final lines = LineSplitter.split(content).toList();
    
    String? currentName;
    String? currentGroup;
    String? currentLogo;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith("#EXTINF:")) {
        // Simple parsing logic
        // Extract attributes
        final info = line.substring(8);
        final parts = info.split(',');
        
        currentName = parts.last.trim();
        
        // Groups
        if (line.contains('group-title="')) {
           currentGroup = line.split('group-title="')[1].split('"')[0];
        } else {
           currentGroup = "General";
        }

        // Logo
        if (line.contains('tvg-logo="')) {
           currentLogo = line.split('tvg-logo="')[1].split('"')[0];
        } else {
           currentLogo = "";
        }

      } else if (!line.startsWith("#")) {
        if (currentName != null) {
          channels.add(Channel(
            name: currentName,
            group: currentGroup ?? "General",
            logo: currentLogo ?? "",
            url: line,
          ));
          currentName = null; // Reset
        }
      }
    }
    return channels;
  }

  // --- Xtream Logic ---
  static Future<bool> validateXtream(String url, String username, String password) async {
    try {
      // Normalize URL
      String cleanUrl = url.trim();
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }
      if (!cleanUrl.startsWith('http')) {
        cleanUrl = 'http://$cleanUrl';
      }

      final uri = Uri.parse("$cleanUrl/player_api.php?username=$username&password=$password");
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['user_info']['auth'] == 1;
      }
      return false;
    } catch (e) {
      print("Xtream Auth Error: $e");
      return false;
    }
  }

  static Future<List<Channel>> getXtreamLive(String url, String username, String password) async {
    try {
      final uri = Uri.parse("$url/player_api.php?username=$username&password=$password&action=get_live_streams");
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Channel(
          name: json['name'] ?? "Unknown",
          group: json['category_id']?.toString() ?? "General", // Need to map category ID to name ideally, skipping for MVP
          logo: json['stream_icon'] ?? "",
          url: "$url/live/$username/$password/${json['stream_id']}.ts",
          streamId: json['stream_id'].toString(),
        )).toList();
      }
      return [];
    } catch (e) {
      print("Xtream Live Error: $e");
      return [];
    }
  }
  
  static Future<List<Channel>> getXtreamVod(String url, String username, String password) async {
    // Similar logic for VOD
    try {
      final uri = Uri.parse("$url/player_api.php?username=$username&password=$password&action=get_vod_streams");
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Channel(
          name: json['name'] ?? "Unknown",
          group: "Movies",
          logo: json['stream_icon'] ?? "",
          url: "$url/movie/$username/$password/${json['stream_id']}.${json['container_extension'] ?? 'mp4'}",
          streamId: json['stream_id'].toString(),
        )).toList();
      }
      return [];
    } catch (e) {
       return [];
    }
  }
}
