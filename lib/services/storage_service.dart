import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../models/data_models.dart';

class StorageService {
  static const String KEY_ACCOUNTS = 'iptv_accounts';
  static const String KEY_ACTIVE_ACCOUNT = 'active_account';
  static const _secureStorage = FlutterSecureStorage();

  static String _getPasswordKey(String url, String username) {
    return 'pass_${url.hashCode}_${username.hashCode}';
  }

  static Future<void> saveAccount(Account account) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> accounts = prefs.getStringList(KEY_ACCOUNTS) ?? [];
    
    // Save password securely
    if (account.password.isNotEmpty) {
      final pwdKey = _getPasswordKey(account.url, account.username);
      await _secureStorage.write(key: pwdKey, value: account.password);
    }
    
    final accountWithoutPassword = Account(
      name: account.name,
      url: account.url,
      username: account.username,
      password: '', // Do NOT store password in SharedPreferences
      type: account.type,
    );

    // Avoid duplicates by URL and Username
    accounts.removeWhere((e) {
      final acc = Account.fromJson(json.decode(e));
      return acc.url == account.url && acc.username == account.username;
    });
    
    accounts.add(json.encode(accountWithoutPassword.toJson()));
    await prefs.setStringList(KEY_ACCOUNTS, accounts);
    
    // Set as active
    await setActiveAccount(account);
  }
  
  static Future<List<Account>> getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList(KEY_ACCOUNTS) ?? [];
    
    List<Account> accounts = [];
    bool needsMigration = false;
    List<Account> migratedAccounts = [];

    for (var e in list) {
      try {
        final acc = Account.fromJson(json.decode(e));
        if (acc.password.isNotEmpty) {
          // Legacy account with password in SharedPreferences. Let's migrate it.
          final pwdKey = _getPasswordKey(acc.url, acc.username);
          await _secureStorage.write(key: pwdKey, value: acc.password);
          
          accounts.add(acc);
          
          // Add to migrated list (without password)
          migratedAccounts.add(Account(
            name: acc.name,
            url: acc.url,
            username: acc.username,
            password: '',
            type: acc.type,
          ));
          needsMigration = true;
        } else {
          // Already migrated account. Read password from secure storage.
          final pwdKey = _getPasswordKey(acc.url, acc.username);
          final securePassword = await _secureStorage.read(key: pwdKey) ?? '';
          
          accounts.add(Account(
            name: acc.name,
            url: acc.url,
            username: acc.username,
            password: securePassword,
            type: acc.type,
          ));
          migratedAccounts.add(acc);
        }
      } catch (err) {
        print("Error decoding account in getAccounts: $err");
      }
    }

    if (needsMigration) {
      final List<String> encoded = migratedAccounts.map((a) => json.encode(a.toJson())).toList();
      await prefs.setStringList(KEY_ACCOUNTS, encoded);
      print("IPTV accounts migrated to Secure Storage successfully.");
    }

    return accounts;
  }

  static Future<void> setActiveAccount(Account account) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Also save password securely (just in case)
    if (account.password.isNotEmpty) {
      final pwdKey = _getPasswordKey(account.url, account.username);
      await _secureStorage.write(key: pwdKey, value: account.password);
    }

    final accountWithoutPassword = Account(
      name: account.name,
      url: account.url,
      username: account.username,
      password: '', // Do NOT store password in SharedPreferences
      type: account.type,
    );

    await prefs.setString(KEY_ACTIVE_ACCOUNT, json.encode(accountWithoutPassword.toJson()));
  }

  static Future<Account?> getActiveAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Force reload from disk
    final String? raw = prefs.getString(KEY_ACTIVE_ACCOUNT);
    if (raw != null) {
      try {
        final acc = Account.fromJson(json.decode(raw));
        if (acc.password.isNotEmpty) {
          // Legacy active account with password in SharedPreferences. Let's migrate it.
          final pwdKey = _getPasswordKey(acc.url, acc.username);
          await _secureStorage.write(key: pwdKey, value: acc.password);
          
          // Re-save active account without password
          final migratedActive = Account(
            name: acc.name,
            url: acc.url,
            username: acc.username,
            password: '',
            type: acc.type,
          );
          await prefs.setString(KEY_ACTIVE_ACCOUNT, json.encode(migratedActive.toJson()));
          return acc; // Return with password still populated for immediate use
        } else {
          // Already migrated account. Read password from secure storage.
          final pwdKey = _getPasswordKey(acc.url, acc.username);
          final securePassword = await _secureStorage.read(key: pwdKey) ?? '';
          
          return Account(
            name: acc.name,
            url: acc.url,
            username: acc.username,
            password: securePassword,
            type: acc.type,
          );
        }
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

    // Delete password from secure storage
    final pwdKey = _getPasswordKey(account.url, account.username);
    await _secureStorage.delete(key: pwdKey);

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
        return decoded.map((item) => Channel.fromJson(item as Map<String, dynamic>)).toList();
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

  static Future<List<Channel>> getHistory(Account account) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getHistoryKey(account);
      final list = prefs.getStringList(key) ?? [];
      return list.map((e) {
        try {
          return Channel.fromJson(json.decode(e) as Map<String, dynamic>);
        } catch (err) {
          // Fallback en caso de que sea un historial antiguo con URLs planas
          return Channel(name: "Canal", group: "Historial", logo: "", url: e);
        }
      }).toList();
    } catch (e) {
      print("Error getting history: $e");
      return [];
    }
  }

  static Future<void> addToHistory(Account account, Channel channel) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getHistoryKey(account);
      final list = prefs.getStringList(key) ?? [];
      
      List<Channel> history = list.map((e) {
        try {
          return Channel.fromJson(json.decode(e) as Map<String, dynamic>);
        } catch (err) {
          return Channel(name: "Canal", group: "Historial", logo: "", url: e);
        }
      }).toList();

      // Evitar duplicados por URL de transmisión
      history.removeWhere((c) => c.url == channel.url);
      history.insert(0, channel);

      // Limitar a los últimos 15 elementos
      if (history.length > 15) {
        history = history.sublist(0, 15);
      }

      final List<String> encoded = history.map((c) => json.encode(c.toJson())).toList();
      await prefs.setStringList(key, encoded);
    } catch (e) {
      print("Error adding to history: $e");
    }
  }

  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (var key in keys) {
        if (key.startsWith('cache_')) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      print("Error clearing cache: $e");
    }
  }
}
