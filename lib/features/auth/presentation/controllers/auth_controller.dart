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
    for (final listener in List<void Function()>.from(_listeners)) {
      listener();
    }
  }

  Future<void> bootstrap() async {
    _isBootstrapping = true;
    _notify();
    _session = await _authService.readSession();
    _isBootstrapping = false;
    _notify();
  }

  Future<void> signInWithGoogle() async {
    _errorMessage = null;
    _isLoading = true;
    _notify();
    try {
      _session = await _authService.signInWithGoogle();
    } on AuthException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Ocorreu um erro ao autenticar com o Google.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    _errorMessage = null;
    _isLoading = true;
    _notify();
    try {
      _session = await _authService.signInWithEmailPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Ocorreu um erro ao autenticar com email e senha.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _errorMessage = null;
    _isLoading = true;
    _notify();
    try {
      _session = await _authService.signUp(
        name: name,
        email: email,
        password: password,
      );
    } on AuthException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Ocorreu um erro ao realizar o cadastro.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      await _authService.signOut();
      _session = null;
    } catch (_) {
      _errorMessage = 'Não foi possível encerrar a sessão.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<String> reauthenticateWithGoogle() =>
      _authService.reauthenticateWithGoogle();

  Future<void> refreshAfterCredentialChange({
    required String email,
    required String password,
  }) async {
    _session = await _authService.refreshWithCredentials(
      email: email,
      password: password,
    );
    _notify();
  }

  Future<void> refreshGoogleAfterCredentialChange() async {
    _session = await _authService.refreshGoogleSession();
    _notify();
  }
}
