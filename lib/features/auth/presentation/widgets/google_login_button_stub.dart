import 'package:flutter/material.dart';

Widget buildGoogleLoginButton({required VoidCallback onPressed}) =>
    OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.login),
      label: const Text('Continuar com Google'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
