import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../services/api_service.dart';

const _tokenKey = 'auth_token';
const _usernameKey = 'auth_username';

class AuthState {
  final bool isLoggedIn;
  final String? username;
  final String? token;
  final String? error;

  const AuthState({
    this.isLoggedIn = false,
    this.username,
    this.token,
    this.error,
  });

  AuthState copyWith({bool? isLoggedIn, String? username, String? token, String? error}) =>
      AuthState(
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        username: username ?? this.username,
        token: token ?? this.token,
        error: error,
      );
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final username = prefs.getString(_usernameKey);
    if (token != null && username != null) {
      ApiService.setToken(token);
      return AuthState(isLoggedIn: true, username: username, token: token);
    }
    return const AuthState();
  }

  Future<void> login(String username, String password) async {
    state = AsyncData(state.valueOrNull?.copyWith(error: null) ?? const AuthState());
    await _doAuth('/api/auth/login', username, password, expectedStatus: 200);
  }

  Future<void> register(String username, String password) async {
    state = AsyncData(state.valueOrNull?.copyWith(error: null) ?? const AuthState());
    await _doAuth('/api/auth/register', username, password, expectedStatus: 201);
  }

  Future<void> _doAuth(String path, String username, String password,
      {required int expectedStatus}) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      if (response.statusCode == expectedStatus) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final token = json['token'] as String;
        final user = json['username'] as String;
        ApiService.setToken(token);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
        await prefs.setString(_usernameKey, user);
        state = AsyncData(AuthState(isLoggedIn: true, username: user, token: token));
      } else {
        state = AsyncData(AuthState(error: _errorMessage(response)));
      }
    } catch (_) {
      state = AsyncData(const AuthState(error: 'Kan de server niet bereiken'));
    }
  }

  Future<void> logout() async {
    ApiService.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_usernameKey);
    state = const AsyncData(AuthState());
  }

  String _errorMessage(http.Response response) {
    try {
      return jsonDecode(response.body)['message'] as String? ?? 'Onbekende fout';
    } catch (_) {
      return switch (response.statusCode) {
        401 => 'Ongeldige inloggegevens',
        409 => 'Gebruikersnaam al in gebruik',
        400 => 'Ongeldige invoer',
        _ => 'Fout ${response.statusCode}',
      };
    }
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
