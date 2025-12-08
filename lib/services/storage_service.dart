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
  }
}
