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
  }) : _googleSignIn =
           googleSignIn ??
           GoogleSignIn(
             clientId: ApiConfig.googleWebClientId,
             serverClientId: ApiConfig.googleWebClientId,
             scopes: const ['email', 'profile'],
           ),
       _httpClient = httpClient ?? http.Client(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _sessionStorageKey = 'auth_session';
  static const String _backendBaseUrl = ApiConfig.baseUrl;

  final GoogleSignIn _googleSignIn;
  final http.Client _httpClient;
  final FlutterSecureStorage _secureStorage;
  AuthSession? _memorySession;

  Future<AuthSession?> readSession() async {
    String? jsonString;
    try {
      jsonString = await _secureStorage.read(key: _sessionStorageKey);
    } catch (_) {
      return _memorySession;
    }
    if (jsonString == null || jsonString.isEmpty) {
      return _memorySession;
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
    _memorySession = null;
    try {
      await _secureStorage.delete(key: _sessionStorageKey);
    } catch (_) {}
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
    final normalizedEmail = email.trim().toLowerCase();
    final http.Response response;
    try {
      response = await _httpClient.post(
        Uri.parse('$_backendBaseUrl/oauth2/token'),
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('${ApiConfig.oauthClientId}:${ApiConfig.oauthClientSecret}'))}',
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'grant_type': 'password',
          'username': normalizedEmail,
          'password': password,
          'scope': 'read write',
        },
      );
    } on http.ClientException {
      throw const AuthException(
        'Não foi possível conectar ao servidor. Verifique sua conexão e tente novamente.',
      );
    } catch (_) {
      throw const AuthException(
        'Não foi possível conectar ao servidor. Verifique sua conexão e tente novamente.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        _extractErrorMessage(response.body) ?? 'Email ou senha inválidos.',
      );
    }
    final decoded = jsonDecode(response.body);
    final responseData = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    final session = _sessionFromResponse(
      responseData,
      fallbackEmail: normalizedEmail,
    );
    if (session.token == null) {
      throw const AuthException(
        'A API autenticou a conta, mas não retornou um token de acesso. Tente novamente.',
      );
    }
    await _persistSession(session);
    return session;
  }

  Future<AuthSession> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final parts = name.trim().split(RegExp(r'\s+'));
    final http.Response response;
    try {
      response = await _httpClient.post(
        Uri.parse('$_backendBaseUrl${ApiConfig.usersEndpoint}'),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'firstName': parts.first,
          'lastName': parts.length > 1 ? parts.skip(1).join(' ') : '',
          'email': normalizedEmail,
          'password': password,
        }),
      );
    } catch (error) {
      throw AuthException(
        'Não foi possível conectar à API para criar a conta. Detalhe: $error',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        _extractErrorMessage(response.body) ??
            'Não foi possível criar sua conta.',
      );
    }
    try {
      return await signInWithEmailPassword(
        email: normalizedEmail,
        password: password,
      );
    } catch (error) {
      final detail = error is AuthException ? error.message : error.toString();
      throw AuthException(
        'A conta foi criada, mas não foi possível iniciar a sessão automaticamente. '
        'Volte para “Já tem conta? Entrar” e use o mesmo email e senha. Detalhe: $detail',
      );
    }
  }

  Future<AuthSession> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser;
    try {
      googleUser =
          _googleSignIn.currentUser ??
          await _googleSignIn.signInSilently() ??
          await _googleSignIn.signIn();
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
    if (idToken == null) {
      throw const AuthException(
        'O Google não forneceu um token de identidade. Confira a configuração OAuth do aplicativo.',
      );
    }

    final response = await _httpClient.post(
      Uri.parse('$_backendBaseUrl${ApiConfig.authGoogleEndpoint}'),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'idToken': idToken}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        _extractErrorMessage(response.body) ?? 'Falha ao autenticar no Google.',
      );
    }
    final decoded = jsonDecode(response.body);
    final responseData = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    final session = _sessionFromResponse(
      responseData,
      fallbackName: googleUser.displayName,
      fallbackEmail: googleUser.email,
      provider: 'google',
    );
    await _persistSession(session);
    return session;
  }

  Future<String> reauthenticateWithGoogle() async {
    final account =
        _googleSignIn.currentUser ??
        await _googleSignIn.signInSilently() ??
        await _googleSignIn.signIn();
    if (account == null) {
      throw const AuthException('Reautenticação cancelada.');
    }
    final token = (await account.authentication).idToken;
    if (token == null) {
      throw const AuthException(
        'O Google não forneceu um token de identidade.',
      );
    }
    return token;
  }

  Future<AuthSession> refreshWithCredentials({
    required String email,
    required String password,
  }) => signInWithEmailPassword(email: email, password: password);

  Future<AuthSession> refreshGoogleSession() => signInWithGoogle();

  AuthSession _sessionFromResponse(
    Map<String, dynamic> responseData, {
    String? fallbackName,
    String? fallbackEmail,
    String provider = 'password',
  }) {
    return AuthSession(
      isAuthenticated: true,
      token: _extractString(responseData, const [
        'access_token',
        'accessToken',
        'token',
        'jwt',
      ]),
      refreshToken: _extractString(responseData, const [
        'refresh_token',
        'refreshToken',
      ]),
      userName:
          _extractString(responseData, const ['name', 'displayName']) ??
          fallbackName,
      userEmail: _extractString(responseData, const ['email']) ?? fallbackEmail,
      provider: provider,
    );
  }

  Future<void> _persistSession(AuthSession session) async {
    _memorySession = session;
    try {
      await _secureStorage.write(
        key: _sessionStorageKey,
        value: jsonEncode(session.toJson()),
      );
    } catch (_) {
      // A sessão continua válida durante o uso atual mesmo se o navegador
      // bloquear o armazenamento local.
    }
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
        final oauthError = decoded['error_description'];
        if (oauthError is String && oauthError.trim().isNotEmpty) {
          return oauthError;
        }
        final message = decoded['message'];
        final errors = decoded['errors'];
        if (errors is List && errors.isNotEmpty) {
          final details = errors
              .whereType<Map>()
              .map((error) {
                final field = error['fieldName']?.toString();
                final reason = error['message']?.toString();
                if (reason == null || reason.isEmpty) return null;
                final label = switch (field) {
                  'firstName' => 'Nome',
                  'lastName' => 'Sobrenome',
                  'email' => 'Email',
                  'password' => 'Senha',
                  _ => null,
                };
                final localized = switch (reason) {
                  'Email já existe' => 'este email já está cadastrado',
                  'Informe um email válido' => 'informe um email válido',
                  'Deve ter no mínimo 8 caracteres' =>
                    'use pelo menos 8 caracteres',
                  'Campo obrigatório' => 'campo obrigatório',
                  _ => reason,
                };
                return label == null ? localized : '$label: $localized';
              })
              .whereType<String>()
              .toSet()
              .toList();
          if (details.isNotEmpty) return details.join('\n');
        }
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

    return const AuthException(
      'Não foi possível concluir o login com o Google. Tente novamente.',
    );
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
