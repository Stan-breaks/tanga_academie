import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/storage_service.dart';

/// Attempts to refresh the access token using the stored refresh token.
/// Returns the new access token, or null if refresh failed.
Future<String?> refreshAccessToken() async {
  final refreshToken = await getRefreshToken();
  if (refreshToken == null || refreshToken.isEmpty) return null;

  try {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'refreshToken': refreshToken}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final newToken = data['token']?.toString();
      if (newToken != null && newToken.isNotEmpty) {
        await saveToken(newToken);
        return newToken;
      }
    } else {
      // Refresh token itself is invalid/expired — clear everything
      debugPrint('Refresh failed (${response.statusCode}), clearing session');
      await logout();
    }
  } catch (e) {
    debugPrint('Token refresh error: $e');
  }
  return null;
}

/// Call on app startup. If the access token is missing or near expiry (< 3 days),
/// tries to get a new one silently from the refresh token.
Future<bool> ensureFreshToken() async {
  final token = await getToken();

  if (token == null || token.isEmpty) {
    // No access token — try refresh
    final newToken = await refreshAccessToken();
    return newToken != null;
  }

  // Decode JWT without verifying (just read expiry) to check if near expiry
  try {
    final parts = token.split('.');
    if (parts.length == 3) {
      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = payload['exp'] as int?;
      if (exp != null) {
        final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        final daysLeft = expiry.difference(DateTime.now()).inDays;
        if (daysLeft < 3) {
          // Near expiry — refresh proactively
          debugPrint('Token expires in $daysLeft days, refreshing...');
          await refreshAccessToken();
        }
      }
    }
  } catch (e) {
    debugPrint('Token decode error: $e');
  }

  return true;
}

/// Notify backend to revoke the refresh token on logout.
Future<void> serverLogout() async {
  final refreshToken = await getRefreshToken();
  try {
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/auth/logout'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 10));
    }
  } catch (_) {
    // Ignore — local logout still proceeds
  }
  await logout(); // Clear local storage
}
