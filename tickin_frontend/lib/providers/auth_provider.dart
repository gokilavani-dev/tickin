// ignore_for_file: avoid_print

import 'dart:convert';
import '../storage/token_store.dart';

class AuthProvider {
  final TokenStore tokenStore;
  AuthProvider(this.tokenStore);

  Future<void> setSession({
    required String token,
    required Map<String, dynamic> userMap,
  }) async {
    // ✅ MUST SAVE TOKEN
    await tokenStore.saveToken(token);

    // ✅ SAVE USER JSON
    await tokenStore.saveUserJson(jsonEncode(userMap));

    // ✅ DEBUG CHECK
    final check = await tokenStore.getToken();
    print("✅ TOKEN SAVED CHECK => ${check == null ? "NULL" : check.substring(0, 25)}");
  }

  Future<void> logout() async {
    await tokenStore.clear();
  }
}
