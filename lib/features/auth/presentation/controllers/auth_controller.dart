import 'dart:convert';

import '../../../../core/services/realtime_service.dart';
import '../../data/services/google_auth_service.dart';
import '../../domain/entities/auth_session.dart';

class AuthController {
  AuthController({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  bool _isBootstrapping = true;
  bool _isLoading = false;
  String? _errorMessage;
  AuthSession? _session;
  final List<void Function()> _listeners = [];
  bool _disposed = false;
  int _operationGeneration = 0;

  bool get isBootstrapping => _isBootstrapping;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _session?.isAuthenticated == true;
  String? get errorMessage => _errorMessage;
  AuthSession? get session => _session;

  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  void _notify() {
    if (_disposed) return;
    for (final listener in List<void Function()>.from(_listeners)) {
      if (_disposed) return;
      listener();
    }
  }

  void clearError() {
    if (_disposed || _errorMessage == null) return;
    _errorMessage = null;
    _notify();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _operationGeneration++;
    _listeners.clear();
  }

  bool _isSessionTokenValid(String? token) {
    if (token == null || token.isEmpty) return false;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (claims is! Map || claims['exp'] is! num) return false;
      final expiresAt = (claims['exp'] as num).toInt();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return expiresAt > now;
    } catch (_) {
      return false;
    }
  }

  Future<void> bootstrap() async {
    if (_disposed) return;
    final generation = ++_operationGeneration;
    _isBootstrapping = true;
    _notify();
    try {
      final storedSession = await _authService.readSession();
      if (_disposed || generation != _operationGeneration) return;
      if (storedSession?.isAuthenticated == true &&
          _isSessionTokenValid(storedSession?.token)) {
        _session = storedSession;
      } else {
        _session = null;
        if (storedSession != null) await _authService.clearSession();
      }
    } catch (_) {
      if (_disposed || generation != _operationGeneration) return;
      _session = null;
      _errorMessage = 'Não foi possível restaurar a sessão. Entre novamente.';
    }
    if (_disposed || generation != _operationGeneration) return;
    _isBootstrapping = false;
    _notify();
  }

  Future<void> signInWithGoogle() async {
    if (_disposed) return;
    final generation = ++_operationGeneration;
    _errorMessage = null;
    _isLoading = true;
    _notify();
    try {
      final session = await _authService.signInWithGoogle();
      if (_disposed || generation != _operationGeneration) return;
      _session = session;
    } on AuthException catch (error) {
      if (_disposed || generation != _operationGeneration) return;
      _errorMessage = error.message;
    } catch (_) {
      if (_disposed || generation != _operationGeneration) return;
      _errorMessage = 'Ocorreu um erro ao autenticar com o Google.';
    } finally {
      if (!_disposed && generation == _operationGeneration) {
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (_disposed) return;
    final generation = ++_operationGeneration;
    _errorMessage = null;
    _isLoading = true;
    _notify();
    try {
      final session = await _authService.signInWithEmailPassword(
        email: email,
        password: password,
      );
      if (_disposed || generation != _operationGeneration) return;
      _session = session;
    } on AuthException catch (error) {
      if (_disposed || generation != _operationGeneration) return;
      _errorMessage = error.message;
    } catch (_) {
      if (_disposed || generation != _operationGeneration) return;
      _errorMessage = 'Ocorreu um erro ao autenticar com email e senha.';
    } finally {
      if (!_disposed && generation == _operationGeneration) {
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    if (_disposed) return;
    final generation = ++_operationGeneration;
    _errorMessage = null;
    _isLoading = true;
    _notify();
    try {
      final session = await _authService.signUp(
        name: name,
        email: email,
        password: password,
      );
      if (_disposed || generation != _operationGeneration) return;
      _session = session;
    } on AuthException catch (error) {
      if (_disposed || generation != _operationGeneration) return;
      _errorMessage = error.message;
    } catch (_) {
      if (_disposed || generation != _operationGeneration) return;
      _errorMessage = 'Ocorreu um erro ao realizar o cadastro.';
    } finally {
      if (!_disposed && generation == _operationGeneration) {
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<void> signOut() async {
    if (_disposed) return;
    final generation = ++_operationGeneration;
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      RealtimeService.instance.disconnect();
      await _authService.signOut();
    } catch (_) {
      if (_disposed || generation != _operationGeneration) return;
      _errorMessage = 'Não foi possível encerrar a sessão.';
    } finally {
      if (!_disposed && generation == _operationGeneration) {
        _session = null;
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<String> reauthenticateWithGoogle() {
    clearError();
    return _authService.reauthenticateWithGoogle();
  }

  Future<void> refreshAfterCredentialChange({
    required String email,
    required String password,
  }) async {
    if (_disposed) return;
    final generation = ++_operationGeneration;
    final session = await _authService.refreshWithCredentials(
      email: email,
      password: password,
    );
    if (_disposed || generation != _operationGeneration) return;
    _session = session;
    _notify();
  }

  Future<void> refreshGoogleAfterCredentialChange() async {
    if (_disposed) return;
    final generation = ++_operationGeneration;
    final session = await _authService.refreshGoogleSession();
    if (_disposed || generation != _operationGeneration) return;
    _session = session;
    _notify();
  }

  Future<String?> refreshSessionToken() async {
    if (_disposed) return null;
    final generation = _operationGeneration;
    final refreshed = await _authService.refreshAccessToken();
    if (_disposed || generation != _operationGeneration || refreshed == null) {
      return null;
    }
    _session = refreshed;
    _notify();
    return refreshed.token;
  }
}
