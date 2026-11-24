import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app_widget.dart';
import 'core/config/api_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.initialize();
  await initializeDateFormatting('pt_BR');
  runApp(const AppWidget());
}
