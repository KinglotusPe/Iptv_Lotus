import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/data_models.dart';

class StorageService {
  static const String KEY_ACCOUNTS = 'iptv_accounts';
  static const String KEY_ACTIVE_ACCOUNT = 'active_account';

  static Future<void> saveAccount(Account account) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> accounts = prefs.getStringList(KEY_ACCOUNTS) ?? [];
    // Avoid duplicates by URL
    accounts.removeWhere((e) => Account.fromJson(json.decode(e)).url == account.url);
    
    accounts.add(json.encode(account.toJson()));
    await prefs.setStringList(KEY_ACCOUNTS, accounts);
    
    // Set as active
    await setActiveAccount(account);
  }
  
  static Future<List<Account>> getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList(KEY_ACCOUNTS) ?? [];
    return list.map((e) => Account.fromJson(json.decode(e))).toList();
  }

  static Future<void> setActiveAccount(Account account) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(KEY_ACTIVE_ACCOUNT, json.encode(account.toJson()));
  }

  static Future<Account?> getActiveAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Force reload from disk
    final String? raw = prefs.getString(KEY_ACTIVE_ACCOUNT);
    if (raw != null) {
      try {
        return Account.fromJson(json.decode(raw));
      } catch (e) {
        print("Error decoding account: $e");
        return null;
      }
    }
    return null;
  }
  
  static Future<void> clearActiveAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(KEY_ACTIVE_ACCOUNT);
  }

  // --- Favorites ---
  static const String KEY_FAVORITES = 'iptv_favorites';

  static Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(KEY_FAVORITES) ?? [];
  }

  static Future<void> toggleFavorite(String url) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favs = prefs.getStringList(KEY_FAVORITES) ?? [];
    if (favs.contains(url)) {
      favs.remove(url);
    } else {
      favs.add(url);
    }
    await prefs.setStringList(KEY_FAVORITES, favs);
  }

  static Future<void> saveFavorites(List<String> favs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(KEY_FAVORITES, favs);
  }

  static Future<void> deleteAccount(Account account) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> accounts = prefs.getStringList(KEY_ACCOUNTS) ?? [];
    accounts.removeWhere((e) {
      final acc = Account.fromJson(json.decode(e));
      return acc.url == account.url && acc.username == account.username;
    });
    await prefs.setStringList(KEY_ACCOUNTS, accounts);

    // Si la cuenta eliminada era la activa, limpiarla
    final String? activeRaw = prefs.getString(KEY_ACTIVE_ACCOUNT);
    if (activeRaw != null) {
      try {
        final activeAcc = Account.fromJson(json.decode(activeRaw));
        if (activeAcc.url == account.url && activeAcc.username == account.username) {
          await prefs.remove(KEY_ACTIVE_ACCOUNT);
        }
      } catch (e) {
        print("Error checking active account on delete: $e");
      }
    }
  }

  // --- Caching System per Account ---
  static String _getCacheKey(Account account, String type) {
    return 'cache_${type}_${account.url.hashCode}_${account.username.hashCode}';
  }

  static Future<void> cacheChannels(Account account, String type, List<Channel> channels) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getCacheKey(account, type);
      final String encoded = json.encode(channels.map((c) => {
        'name': c.name,
        'group': c.group,
        'logo': c.logo,
        'url': c.url,
        if (c.streamId != null) 'stream_id': c.streamId,
      }).toList());
      await prefs.setString(key, encoded);
    } catch (e) {
      print("Error caching channels: $e");
    }
  }

  static Future<List<Channel>?> getCachedChannels(Account account, String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getCacheKey(account, type);
      final String? raw = prefs.getString(key);
      if (raw != null) {
        final List<dynamic> decoded = json.decode(raw);
        return decoded.map((item) => Channel.fromJson(item)).toList();
      }
    } catch (e) {
      print("Error reading cached channels: $e");
    }
    return null;
  }

  static Future<void> cacheCategories(Account account, String type, Map<String, String> categories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getCacheKey(account, '${type}_categories');
      await prefs.setString(key, json.encode(categories));
    } catch (e) {
      print("Error caching categories: $e");
    }
  }

  static Future<Map<String, String>?> getCachedCategories(Account account, String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getCacheKey(account, '${type}_categories');
      final String? raw = prefs.getString(key);
      if (raw != null) {
        final Map<String, dynamic> decoded = json.decode(raw);
        return decoded.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (e) {
      print("Error reading cached categories: $e");
    }
    return null;
  }

  // --- History System per Account ---
  static String _getHistoryKey(Account account) {
    return 'history_${account.url.hashCode}_${account.username.hashCode}';
  }

  static Future<List<String>> getHistory(Account account) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getHistoryKey(account);
    return prefs.getStringList(key) ?? [];
  }

  static Future<void> addToHistory(Account account, String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getHistoryKey(account);
      List<String> history = prefs.getStringList(key) ?? [];
      
      // Mover al inicio si ya existe
      history.remove(url);
      history.insert(0, url);
      
      // Limitar a los últimos 15 elementos
      if (history.length > 15) {
        history = history.sublist(0, 15);
      }
      await prefs.setStringList(key, history);
    } catch (e) {
      print("Error adding to history: $e");
    }
  }
}
