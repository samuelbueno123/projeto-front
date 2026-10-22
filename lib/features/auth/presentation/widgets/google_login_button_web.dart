import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

import '../../../../core/config/api_config.dart';

Widget buildGoogleLoginButton({required VoidCallback onPressed}) =>
    _GoogleLoginButton(onPressed: onPressed);

class _GoogleLoginButton extends StatefulWidget {
  const _GoogleLoginButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_GoogleLoginButton> createState() => _GoogleLoginButtonState();
}

class _GoogleLoginButtonState extends State<_GoogleLoginButton> {
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: ApiConfig.googleWebClientId,
    scopes: const ['email', 'profile'],
  );
  StreamSubscription<GoogleSignInAccount?>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = _googleSignIn.onCurrentUserChanged.listen((account) {
      if (account != null) widget.onPressed();
    });
    unawaited(_googleSignIn.signInSilently());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 44, child: google_web.renderButton());
}
