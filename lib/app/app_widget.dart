import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/admin/presentation/admin_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/manager/presentation/manager_page.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> {
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    _authController = AuthController();
    _authController.addListener(_handleControllerChange);
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Condomínio App',
      theme: AppTheme.light(),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_authController.isBootstrapping) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_authController.isAuthenticated) {
      final session = _authController.session;
      if (_isAdministrator(session?.token)) {
        return AdminPage(
          token: session?.token,
          userName: session?.userName,
          userEmail: session?.userEmail,
          authProvider: session?.provider ?? 'password',
          reauthenticateWithGoogle: _authController.reauthenticateWithGoogle,
          refreshWithCredentials: (email, password) => _authController
              .refreshAfterCredentialChange(email: email, password: password),
          refreshGoogleSession:
              _authController.refreshGoogleAfterCredentialChange,
          onLogout: _authController.signOut,
        );
      }
      if (_isManager(session?.token)) {
        return ManagerPage(
          token: session?.token,
          userName: session?.userName,
          onLogout: _authController.signOut,
        );
      }
      return HomePage(
        onLogout: _authController.signOut,
        token: session?.token,
        userName: session?.userName,
        userEmail: session?.userEmail,
        authProvider: session?.provider ?? 'password',
        reauthenticateWithGoogle: _authController.reauthenticateWithGoogle,
        refreshWithCredentials: (email, password) => _authController
            .refreshAfterCredentialChange(email: email, password: password),
        refreshGoogleSession:
            _authController.refreshGoogleAfterCredentialChange,
      );
    }

    return LoginPage(
      onGoogleLogin: _authController.signInWithGoogle,
      onEmailLogin: _authController.signInWithEmailPassword,
      onSignUp: _authController.signUp,
      isLoading: _authController.isLoading,
      errorMessage: _authController.errorMessage,
    );
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
}
