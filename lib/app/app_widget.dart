import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../core/design_system/motion_system.dart';
import '../core/design_system/saas_design_system.dart';
import '../core/services/realtime_service.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/admin/presentation/admin_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/manager/presentation/manager_page.dart';
import '../features/doorman/presentation/pages/doorman_page.dart';
import '../core/http/http_client_wrapper.dart';
import '../features/home/data/home_service.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final AuthController _authController;
  String? _overrideRoleView;
  String? _cachedClaimsToken;
  Map<String, dynamic> _cachedClaims = const {};
  String? _syncedSessionToken;
  int _profileRequestGeneration = 0;

  void _resetNavigationStack() {
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  void initState() {
    super.initState();
    _authController = AuthController();
    _authController.addListener(_handleControllerChange);
    HttpClientWrapper.onUnauthorized = () {
      _overrideRoleView = null;
      _resetNavigationStack();
      _authController.signOut();
    };
    _authController.bootstrap();
  }

  @override
  void dispose() {
    _authController.removeListener(_handleControllerChange);
    _authController.dispose();
    HttpClientWrapper.onUnauthorized = null;
    RealtimeService.instance.setToken(null);
    super.dispose();
  }

  void _handleControllerChange() {
    final token = _authController.session?.token;
    if (token != _syncedSessionToken) {
      _syncedSessionToken = token;
      RealtimeService.instance.setToken(token);
      AppTheme.setThemePreference('SYSTEM');
      if (token != null && token.isNotEmpty) {
        unawaited(_loadThemePreference(token));
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _loadThemePreference(String token) async {
    final generation = ++_profileRequestGeneration;
    try {
      final profile = await HomeService(token: token).get('/users/me');
      if (!mounted ||
          generation != _profileRequestGeneration ||
          token != _authController.session?.token) {
        return;
      }
      if (profile is Map) {
        AppTheme.setThemePreference(profile['themePreference']?.toString());
      }
    } catch (_) {
      // Theme sync is best-effort; keep the current account usable if it fails.
    }
  }

  void _switchRole(String role) {
    setState(() {
      _overrideRoleView = role;
    });
  }

  Future<void> _handleLogout() async {
    _overrideRoleView = null;
    _resetNavigationStack();
    await _authController.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Âncora Gestão',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('pt', 'BR'), Locale('en', 'US')],
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return ShadTheme(
              data: isDark ? AppTheme.shadcnDark() : AppTheme.shadcnLight(),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: AncoraAnimatedSwitcher(child: _buildHome()),
        );
      },
    );
  }

  Widget _buildHome() {
    if (_authController.isBootstrapping) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: SaaSLoadingState(message: 'Inicializando o sistema...'),
          ),
        ),
      );
    }

    if (_authController.isAuthenticated) {
      final session = _authController.session;
      final token = session?.token;
      final availableRoles = _getAvailableRoles(token);
      final effectiveRole = _determineEffectiveRole(token);

      switch (effectiveRole) {
        case 'ADMIN':
          return AdminPage(
            token: token,
            userName: session?.userName,
            userEmail: session?.userEmail,
            authProvider: session?.provider ?? 'password',
            reauthenticateWithGoogle: _authController.reauthenticateWithGoogle,
            refreshWithCredentials: (email, password) => _authController
                .refreshAfterCredentialChange(email: email, password: password),
            refreshGoogleSession:
                _authController.refreshGoogleAfterCredentialChange,
            onLogout: _handleLogout,
            currentRole: effectiveRole,
            availableRoles: availableRoles,
            onSwitchRole: _switchRole,
          );
        case 'MANAGER':
          return ManagerPage(
            token: token,
            userName: session?.userName,
            userEmail: session?.userEmail,
            authProvider: session?.provider ?? 'password',
            reauthenticateWithGoogle: _authController.reauthenticateWithGoogle,
            refreshWithCredentials: (email, password) => _authController
                .refreshAfterCredentialChange(email: email, password: password),
            refreshGoogleSession:
                _authController.refreshGoogleAfterCredentialChange,
            onLogout: _handleLogout,
            currentRole: effectiveRole,
            availableRoles: availableRoles,
            onSwitchRole: _switchRole,
          );
        case 'DOORMAN':
          return DoormanPage(
            token: token,
            userName: session?.userName,
            userEmail: session?.userEmail,
            authProvider: session?.provider ?? 'password',
            reauthenticateWithGoogle: _authController.reauthenticateWithGoogle,
            refreshWithCredentials: (email, password) => _authController
                .refreshAfterCredentialChange(email: email, password: password),
            refreshGoogleSession:
                _authController.refreshGoogleAfterCredentialChange,
            onLogout: _handleLogout,
            currentRole: effectiveRole,
            availableRoles: availableRoles,
            onSwitchRole: _switchRole,
          );
        case 'RESIDENT':
        default:
          return HomePage(
            onLogout: _handleLogout,
            token: token,
            userName: session?.userName,
            userEmail: session?.userEmail,
            authProvider: session?.provider ?? 'password',
            reauthenticateWithGoogle: _authController.reauthenticateWithGoogle,
            refreshWithCredentials: (email, password) => _authController
                .refreshAfterCredentialChange(email: email, password: password),
            refreshGoogleSession:
                _authController.refreshGoogleAfterCredentialChange,
            currentRole: effectiveRole,
            availableRoles: availableRoles,
            onSwitchRole: _switchRole,
          );
      }
    }

    return LoginPage(
      onGoogleLogin: _authController.signInWithGoogle,
      onEmailLogin: _authController.signInWithEmailPassword,
      onSignUp: _authController.signUp,
      isLoading: _authController.isLoading,
      errorMessage: _authController.errorMessage,
      onAuthModeChanged: _authController.clearError,
    );
  }

  List<String> _getAvailableRoles(String? token) {
    final authorities = _claimsFor(token)['authorities'];
    if (authorities is List) {
      if (authorities.contains('ROLE_ADMIN')) {
        return const ['ADMIN', 'MANAGER', 'DOORMAN', 'RESIDENT'];
      }
      final roles = <String>[];
      if (authorities.contains('ROLE_MANAGER')) roles.add('MANAGER');
      if (authorities.contains('ROLE_DOORMAN')) roles.add('DOORMAN');
      roles.add('RESIDENT');
      return roles;
    }
    return const ['RESIDENT'];
  }

  Map<String, dynamic> _claimsFor(String? token) {
    if (token == null || token.isEmpty) return const {};
    if (_cachedClaimsToken == token) return _cachedClaims;
    _cachedClaimsToken = token;
    try {
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
      );
      _cachedClaims = decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      _cachedClaims = const {};
    }
    return _cachedClaims;
  }

  String _determineEffectiveRole(String? token) {
    final available = _getAvailableRoles(token);
    if (_overrideRoleView != null && available.contains(_overrideRoleView)) {
      return _overrideRoleView!;
    }
    if (_isAdministrator(token)) return 'ADMIN';
    if (_isManager(token)) return 'MANAGER';
    if (_isDoorman(token)) return 'DOORMAN';
    return 'RESIDENT';
  }

  bool _isAdministrator(String? token) {
    final authorities = _claimsFor(token)['authorities'];
    return authorities is List && authorities.contains('ROLE_ADMIN');
  }

  bool _isManager(String? token) {
    final authorities = _claimsFor(token)['authorities'];
    return authorities is List && authorities.contains('ROLE_MANAGER');
  }

  bool _isDoorman(String? token) {
    final authorities = _claimsFor(token)['authorities'];
    return authorities is List && authorities.contains('ROLE_DOORMAN');
  }
}
