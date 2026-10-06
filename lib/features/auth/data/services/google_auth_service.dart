import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/api_config.dart';
import '../../domain/entities/auth_session.dart';

class AuthService {
  AuthService({
    GoogleSignIn? googleSignIn,
    http.Client? httpClient,
    FlutterSecureStorage? secureStorage,
  })  : _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: const ['email', 'profile']),
        _httpClient = httpClient ?? http.Client(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _sessionStorageKey = 'auth_session';
  static const String _backendBaseUrl = ApiConfig.baseUrl;
  static const List<String> _googleAuthPaths = [
    '/auth/google/mobile',
    '/auth/google/login',
    ApiConfig.authGoogleEndpoint,
  ];
  static const List<String> _emailLoginPaths = [
    '/auth/login',
    '/auth/signin',
    '/login',
  ];
  static const List<String> _registerPaths = [
    '/auth/register',
    '/auth/signup',
    ApiConfig.usersEndpoint,
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

  Future<AuthSession> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final payload = <String, dynamic>{
      'email': email,
      'password': password,
    };
    final responseData = await _authenticateWithFallbackPaths(
      paths: _emailLoginPaths,
      payload: payload,
      notFoundMessage: 'Nenhum endpoint de login por email/senha do backend foi encontrado.',
      networkErrorMessage: 'Não foi possível conectar ao servidor. Verifique a URL configurada em BACKEND_BASE_URL.',
    );

    final session = _sessionFromResponse(
      responseData,
      fallbackEmail: email,
    );
    await _persistSession(session);
    return session;
  }

  Future<AuthSession> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
    };
    final responseData = await _authenticateWithFallbackPaths(
      paths: _registerPaths,
      payload: payload,
      notFoundMessage: 'Nenhum endpoint de cadastro do backend foi encontrado.',
      networkErrorMessage: 'Não foi possível conectar ao servidor. Verifique a URL configurada em BACKEND_BASE_URL.',
    );

    final session = _sessionFromResponse(
      responseData,
      fallbackName: name,
      fallbackEmail: email,
    );
    await _persistSession(session);
    return session;
  }

  Future<AuthSession> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser;
    try {
      googleUser = await _googleSignIn.signIn();
    } on PlatformException catch (error) {
      throw _googleSignInException(error);
    } catch (_) {
      throw const AuthException("Erro no Login com o Google");
    }
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

    final responseData = await _authenticateWithFallbackPaths(
      paths: _googleAuthPaths,
      payload: payload,
      notFoundMessage: 'Nenhum endpoint de autenticação Google do backend foi encontrado.',
      networkErrorMessage: 'Não foi possível conectar ao servidor. Verifique a URL configurada em BACKEND_BASE_URL.',
    );

    final session = _sessionFromResponse(
      responseData,
      fallbackName: googleUser.displayName,
      fallbackEmail: googleUser.email,
    );
    await _persistSession(session);
    return session;
  }

  Future<Map<String, dynamic>> _authenticateWithFallbackPaths({
    required List<String> paths,
    required Map<String, dynamic> payload,
    required String notFoundMessage,
    required String networkErrorMessage,
  }) async {
    try {
      for (final path in paths) {
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
    } on http.ClientException {
      throw AuthException(networkErrorMessage);
    }

    throw AuthException(notFoundMessage);
  }

  AuthSession _sessionFromResponse(
    Map<String, dynamic> responseData, {
    String? fallbackName,
    String? fallbackEmail,
  }) {
    return AuthSession(
      isAuthenticated: true,
      token: _extractString(responseData, const ['accessToken', 'token', 'jwt']),
      refreshToken: _extractString(responseData, const ['refreshToken']),
      userName: _extractString(responseData, const ['name', 'displayName']) ?? fallbackName,
      userEmail: _extractString(responseData, const ['email']) ?? fallbackEmail,
    );
  }

  Future<void> _persistSession(AuthSession session) async {
    await _secureStorage.write(
      key: _sessionStorageKey,
      value: jsonEncode(session.toJson()),
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

  AuthException _googleSignInException(PlatformException error) {
    final errorDetails = '${error.code} ${error.message ?? ''}'.toLowerCase();

    if (errorDetails.contains('10') ||
        errorDetails.contains('developer_error') ||
        errorDetails.contains('api_exception')) {
      return const AuthException(
        'O login do Google não está configurado para este aplicativo. '
        'Cadastre o pacote Android e a impressão digital SHA-1 no Google Cloud Console.',
      );
    }

    if (errorDetails.contains('network')) {
      return const AuthException(
        'Não foi possível conectar ao Google. Verifique sua conexão e tente novamente.',
      );
    }

    return const AuthException('Não foi possível concluir o login com o Google. Tente novamente.');
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
