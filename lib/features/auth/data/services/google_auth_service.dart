import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/auth_session.dart';

class GoogleAuthService {
  GoogleAuthService({
    GoogleSignIn? googleSignIn,
    http.Client? httpClient,
    FlutterSecureStorage? secureStorage,
  })  : _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: const ['email', 'profile']),
        _httpClient = httpClient ?? http.Client(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _sessionStorageKey = 'auth_session';
  static const String _backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
  static const List<String> _googleAuthPaths = [
    '/auth/google/mobile',
    '/auth/google/login',
    '/auth/google',
  ];

  final GoogleSignIn _googleSignIn;
  final http.Client _httpClient;
  final FlutterSecureStorage _secureStorage;

  Future<AuthSession?> readSession() async {
    final jsonString = await _secureStorage.read(key: _sessionStorageKey);
    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        await clearSession();
        return null;
      }
      return AuthSession.fromJson(decoded);
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(key: _sessionStorageKey);
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {}
    await _googleSignIn.signOut();
    await clearSession();
  }

  Future<AuthSession> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw const AuthException('Login com Google cancelado.');
    }

    final authentication = await googleUser.authentication;
    final idToken = authentication.idToken;
    final accessToken = authentication.accessToken;
    final serverAuthCode = googleUser.serverAuthCode;

    if (idToken == null && accessToken == null && serverAuthCode == null) {
      throw const AuthException('Não foi possível obter credenciais do Google.');
    }

    final payload = <String, dynamic>{
      'idToken': idToken,
      'accessToken': accessToken,
      'serverAuthCode': serverAuthCode,
      'email': googleUser.email,
      'displayName': googleUser.displayName,
    }..removeWhere((_, value) => value == null);

    final responseData = await _authenticateAgainstBackend(payload);

    final session = AuthSession(
      isAuthenticated: true,
      token: _extractString(responseData, const ['accessToken', 'token', 'jwt']),
      refreshToken: _extractString(responseData, const ['refreshToken']),
      userName: _extractString(responseData, const ['name', 'displayName']) ?? googleUser.displayName,
      userEmail: _extractString(responseData, const ['email']) ?? googleUser.email,
    );

    await _secureStorage.write(
      key: _sessionStorageKey,
      value: jsonEncode(session.toJson()),
    );
    return session;
  }

  Future<Map<String, dynamic>> _authenticateAgainstBackend(Map<String, dynamic> payload) async {
    for (final path in _googleAuthPaths) {
      final uri = Uri.parse('$_backendBaseUrl$path');
      final response = await _httpClient.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 404) {
        continue;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(_extractErrorMessage(response.body) ?? 'Falha ao autenticar no backend.');
      }

      if (response.body.isEmpty) {
        return <String, dynamic>{};
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return <String, dynamic>{};
    }

    throw const AuthException(
      'Nenhum endpoint de autenticação Google do backend foi encontrado.',
    );
  }

  String? _extractString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  String? _extractErrorMessage(String body) {
    if (body.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}
    return null;
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
