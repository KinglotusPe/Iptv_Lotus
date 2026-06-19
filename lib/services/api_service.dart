import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/data_models.dart';

class ApiService {
  
  // --- M3U Logic ---
  static List<Channel> parseM3u(String content) {
    final List<Channel> channels = [];
    final lines = LineSplitter.split(content).toList();
    
    String? currentName;
    String? currentGroup;
    String? currentLogo;

    // Expresiones regulares más robustas para atributos M3U
    final groupRegex = RegExp(r'''group-title=["']([^"']+)["']''', caseSensitive: false);
    final logoRegex = RegExp(r'''tvg-logo=["']([^"']+)["']''', caseSensitive: false);

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith("#EXTINF:")) {
        // Extraer el nombre que se encuentra al final de la línea después de la coma
        final commaIndex = line.lastIndexOf(',');
        if (commaIndex != -1) {
          currentName = line.substring(commaIndex + 1).trim();
        } else {
          currentName = "Canal Sin Nombre";
        }
        
        // Extraer grupo
        final groupMatch = groupRegex.firstMatch(line);
        currentGroup = groupMatch != null ? groupMatch.group(1) : "General";

        // Extraer logo
        final logoMatch = logoRegex.firstMatch(line);
        currentLogo = logoMatch != null ? logoMatch.group(1) : "";

      } else if (!line.startsWith("#")) {
        if (currentName != null) {
          channels.add(Channel(
            name: currentName,
            group: currentGroup ?? "General",
            logo: currentLogo ?? "",
            url: line,
          ));
          currentName = null; // Reiniciar
          currentGroup = null;
          currentLogo = null;
        }
      }
    }
    return channels;
  }

  // --- Xtream Logic ---
  static Future<bool> validateXtream(String url, String username, String password) async {
    try {
      String cleanUrl = url.trim();
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }
      if (!cleanUrl.startsWith('http')) {
        cleanUrl = 'http://$cleanUrl';
      }

      final uri = Uri.parse("$cleanUrl/player_api.php?username=$username&password=$password");
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data['user_info'] != null) {
          return data['user_info']['auth'] == 1;
        }
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
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Channel(
          name: json['name'] ?? "Unknown",
          group: json['category_id']?.toString() ?? "General",
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
    try {
      final uri = Uri.parse("$url/player_api.php?username=$username&password=$password&action=get_vod_streams");
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Channel(
          name: json['name'] ?? "Unknown",
          group: json['category_id']?.toString() ?? "General",
          logo: json['stream_icon'] ?? "",
          url: "$url/movie/$username/$password/${json['stream_id']}.${json['container_extension'] ?? 'mp4'}",
          streamId: json['stream_id'].toString(),
        )).toList();
      }
      return [];
    } catch (e) {
      print("Xtream VOD Error: $e");
      return [];
    }
  }

  static Future<List<Channel>> getXtreamSeries(String url, String username, String password) async {
    try {
      final uri = Uri.parse("$url/player_api.php?username=$username&password=$password&action=get_series");
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Channel(
          name: json['name'] ?? "Unknown",
          group: json['category_id']?.toString() ?? "General",
          logo: json['cover'] ?? json['stream_icon'] ?? "", 
          url: "", 
          streamId: json['series_id'].toString(),
        )).toList();
      }
      return [];
    } catch (e) {
       print("Xtream Series Error: $e");
       return [];
    }
  }

  static Future<Map<String, String>> getXtreamCategories(String url, String username, String password) async {
    try {
      final uri = Uri.parse("$url/player_api.php?username=$username&password=$password&action=get_live_categories");
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final Map<String, String> categories = {};
        for (var item in data) {
          if (item is Map) {
            final id = item['category_id']?.toString() ?? "";
            final name = item['category_name']?.toString() ?? "Unknown";
            categories[id] = name;
          }
        }
        return categories;
      }
      return {};
    } catch (e) {
      print("Xtream Live Categories Error: $e");
      return {};
    }
  }

  static Future<Map<String, String>> getXtreamVodCategories(String url, String username, String password) async {
    try {
      final uri = Uri.parse("$url/player_api.php?username=$username&password=$password&action=get_vod_categories");
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final Map<String, String> categories = {};
        for (var item in data) {
          if (item is Map) {
            final id = item['category_id']?.toString() ?? "";
            final name = item['category_name']?.toString() ?? "Unknown";
            categories[id] = name;
          }
        }
        return categories;
      }
      return {};
    } catch (e) {
      print("Xtream VOD Categories Error: $e");
      return {};
    }
  }

  static Future<Map<String, String>> getXtreamSeriesCategories(String url, String username, String password) async {
    try {
      final uri = Uri.parse("$url/player_api.php?username=$username&password=$password&action=get_series_categories");
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final Map<String, String> categories = {};
        for (var item in data) {
          if (item is Map) {
            final id = item['category_id']?.toString() ?? "";
            final name = item['category_name']?.toString() ?? "Unknown";
            categories[id] = name;
          }
        }
        return categories;
      }
      return {};
    } catch (e) {
      print("Xtream Series Categories Error: $e");
      return {};
    }
  }

  static Future<List<Channel>> getXtreamSeriesEpisodes(String url, String username, String password, String seriesId) async {
    try {
      final uri = Uri.parse("$url/player_api.php?username=$username&password=$password&action=get_series_info&series_id=$seriesId");
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data['episodes'] != null) {
          final episodesMap = data['episodes']; 
          List<Channel> allEpisodes = [];
          
          if (episodesMap is Map) {
            episodesMap.forEach((seasonStr, episodesList) {
               if (episodesList is List) {
                 for (var ep in episodesList) {
                    final String ext = ep['container_extension'] ?? 'mp4';
                    final String id = ep['id'].toString();
                    final String title = ep['title']?.toString() ?? "Episode";
                    final String season = seasonStr.toString();
                    final String? cover = ep['info']?['movie_image'];
                    
                    allEpisodes.add(Channel(
                      name: title,
                      group: "Temporada $season", 
                      logo: cover ?? "", 
                      url: "$url/series/$username/$password/$id.$ext",
                      streamId: id,
                    ));
                 }
               }
            });
          }
          return allEpisodes;
        }
      }
      return [];
    } catch (e) {
      print("Xtream Series Info Error: $e");
      return [];
    }
  }

  static Future<List<EpgProgram>> getXtreamShortEpg(String url, String username, String password, String streamId) async {
    try {
      final uri = Uri.parse("$url/player_api.php?username=$username&password=$password&action=get_short_epg&stream_id=$streamId");
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data['epg_listings'] != null && data['epg_listings'] is List) {
          final List<dynamic> listings = data['epg_listings'];
          return listings.map((json) => EpgProgram.fromJson(json as Map<String, dynamic>)).toList();
        }
      }
      return [];
    } catch (e) {
      print("Xtream Short EPG Error: $e");
      return [];
    }
  }
}
