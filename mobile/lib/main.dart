import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/auth_screen.dart';
import 'screens/service_list_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final savedUserId = prefs.getInt('userId');

  runApp(LocalServiceApp(savedUserId: savedUserId));
}

class LocalServiceApp extends StatelessWidget {
  final int? savedUserId;

  const LocalServiceApp({super.key, required this.savedUserId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Service App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      home: savedUserId == null
          ? const AuthScreen()
          : ServiceListScreen(userId: savedUserId!),
    );
  }
}