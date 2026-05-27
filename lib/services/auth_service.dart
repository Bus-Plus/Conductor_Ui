import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class AuthService {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> login({
    required String userId,
    required String password,
  }) async {
    final url = Uri.parse('${ApiConfig.authBaseUrl}/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': userId, 'password': password}),
    );

    final body = response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};

    if (response.statusCode != 200) {
      final message = body['message'] ?? body['error'] ?? 'Login failed';
      throw Exception(message);
    }

    final accessToken = body['access_token'] ?? body['accessToken'] ?? body['token'];
    final refreshToken = body['refresh_token'] ?? body['refreshToken'];

    if (accessToken == null || refreshToken == null) {
      throw Exception('Missing access or refresh token in login response.');
    }

    await saveTokens(accessToken.toString(), refreshToken.toString(), userId: userId);
    return {
      'access_token': accessToken.toString(),
      'refresh_token': refreshToken.toString(),
      'user_id': userId,
      'response': body,
    };
  }

  Future<void> saveTokens(
    String accessToken,
    String refreshToken, {
    String? userId,
  }) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    if (userId != null) {
      await _secureStorage.write(key: _userIdKey, value: userId);
    }
  }

  Future<Map<String, String?>> getTokens() async {
    final accessToken = await _secureStorage.read(key: _accessTokenKey);
    final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    final userId = await _secureStorage.read(key: _userIdKey);
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'user_id': userId,
    };
  }

  Future<void> validateConductor({
    required String accessToken,
  }) async {
    final url = Uri.parse('${ApiConfig.conductorBaseUrl}/conductor/validate');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
      final message = body['message'] ?? body['error'] ?? 'Validation failed';
      throw Exception(message);
    }
  }

  Future<List<String>> fetchAvailableRouteIds() async {
    final url = Uri.parse('${ApiConfig.busBaseUrl}/connectivity/bus-numbers');
    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json'},
    );

    final body = response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    if (response.statusCode != 200) {
      final message = body['message'] ?? body['error'] ?? 'Could not fetch route ids';
      throw Exception(message);
    }

    final ids = body['ids'];
    if (ids is! List) {
      throw Exception('Unexpected route ids response format.');
    }

    return ids.map((item) => item.toString()).toList();
  }

  Future<void> initializeConductorBus({
    required String routeId,
    required String accessToken,
    required String username,
  }) async {
    final url = Uri.parse('${ApiConfig.conductorBaseUrl}/conductor/bus/$routeId/$username/initialize');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
      final message = body['message'] ?? body['error'] ?? 'Could not initialize conductor bus';
      throw Exception(message);
    }
  }

  Future<void> resetConductorBus({
    required String routeId,
    required String busNumber,
    required String accessToken,
  }) async {
    final url = Uri.parse('${ApiConfig.conductorBaseUrl}/conductor/bus/$routeId/$busNumber/reset');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
      final message = body['message'] ?? body['error'] ?? 'Could not reset conductor bus';
      throw Exception(message);
    }
  }

  Future<void> clearTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _userIdKey);
  }
}
