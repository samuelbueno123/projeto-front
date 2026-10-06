import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/home/presentation/pages/home_page.dart';

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
      return HomePage(
        onLogout: _authController.signOut,
        userName: _authController.session?.userName,
        userEmail: _authController.session?.userEmail,
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
}
