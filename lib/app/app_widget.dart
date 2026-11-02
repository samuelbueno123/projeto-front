import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/admin/presentation/admin_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/manager/presentation/manager_page.dart';
import '../features/doorman/presentation/pages/doorman_page.dart';
import '../core/http/http_client_wrapper.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> {
  late final AuthController _authController;
  String? _overrideRoleView;

  @override
  void initState() {
    super.initState();
    _authController = AuthController();
    _authController.addListener(_handleControllerChange);
    HttpClientWrapper.onUnauthorized = () {
      _overrideRoleView = null;
      _authController.signOut();
    };
    _authController.bootstrap();
  }

  @override
  void dispose() {
    _authController.removeListener(_handleControllerChange);
    super.dispose();
  }

  void _handleControllerChange() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _switchRole(String role) {
    setState(() {
      _overrideRoleView = role;
    });
  }

  Future<void> _handleLogout() async {
    _overrideRoleView = null;
    await _authController.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Âncora Gestão',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          home: _buildHome(),
        );
      },
    );
  }

  Widget _buildHome() {
    if (_authController.isBootstrapping) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
            onLogout: _handleLogout,
            currentRole: effectiveRole,
            availableRoles: availableRoles,
            onSwitchRole: _switchRole,
          );
        case 'DOORMAN':
          return DoormanPage(
            token: token,
            userName: session?.userName,
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
    );
  }

  List<String> _getAvailableRoles(String? token) {
    if (token == null) return const ['RESIDENT'];
    try {
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
      );
      final authorities = claims is Map ? claims['authorities'] : null;
      if (authorities is List) {
        if (authorities.contains('ROLE_ADMIN')) {
          return const ['ADMIN', 'MANAGER', 'DOORMAN', 'RESIDENT'];
        }
        final roles = <String>[];
        if (authorities.contains('ROLE_MANAGER')) {
          roles.add('MANAGER');
        }
        if (authorities.contains('ROLE_DOORMAN')) {
          roles.add('DOORMAN');
        }
        roles.add('RESIDENT');
        return roles.isNotEmpty ? roles : const ['RESIDENT'];
      }
    } catch (_) {}
    return const ['RESIDENT'];
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
    if (token == null) return false;
    try {
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
      );
      final authorities = claims is Map ? claims['authorities'] : null;
      return authorities is List && authorities.contains('ROLE_ADMIN');
    } catch (_) {
      return false;
    }
  }

  bool _isManager(String? token) {
    if (token == null) return false;
    try {
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
      );
      final authorities = claims is Map ? claims['authorities'] : null;
      return authorities is List && authorities.contains('ROLE_MANAGER');
    } catch (_) {
      return false;
    }
  }

  bool _isDoorman(String? token) {
    if (token == null) return false;
    try {
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
      );
      final authorities = claims is Map ? claims['authorities'] : null;
      return authorities is List && authorities.contains('ROLE_DOORMAN');
    } catch (_) {
      return false;
    }
  }
}
