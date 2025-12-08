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
    final String? raw = prefs.getString(KEY_ACTIVE_ACCOUNT);
    if (raw != null) {
      return Account.fromJson(json.decode(raw));
    }
    return null;
  }
  
  static Future<void> clearActiveAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(KEY_ACTIVE_ACCOUNT);
  }
}
