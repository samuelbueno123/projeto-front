import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/home/presentation/pages/home_page.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Condomínio App',
      theme: AppTheme.light(),
      home: const HomePage(),
    );
  }
}
