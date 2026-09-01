import '../../data/services/google_auth_service.dart';
import '../../domain/entities/auth_session.dart';

class AuthController {
  AuthController({GoogleAuthService? authService}) : _authService = authService ?? GoogleAuthService();

  final GoogleAuthService _authService;

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
}
