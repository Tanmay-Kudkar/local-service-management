import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/auth_screen.dart';
import 'screens/provider_dashboard_screen.dart';
import 'screens/service_list_screen.dart';
import 'screens/startup_permissions_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final savedUserId = prefs.getInt('userId');
  final savedUserName = prefs.getString('userName') ?? '';
  final savedUserRole = prefs.getString('userRole') ?? 'USER';

  runApp(
    LocalServiceApp(
      savedUserId: savedUserId,
      savedUserName: savedUserName,
      savedUserRole: savedUserRole,
    ),
  );
}

class LocalServiceApp extends StatelessWidget {
  final int? savedUserId;
  final String savedUserName;
  final String savedUserRole;

  const LocalServiceApp({
    super.key,
    required this.savedUserId,
    required this.savedUserName,
    required this.savedUserRole,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Service App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      home: StartupPermissionsScreen(
        nextScreen: savedUserId == null
            ? const AuthScreen()
            : (savedUserRole == 'PROVIDER'
                ? ProviderDashboardScreen(
                    userId: savedUserId!,
                    userName: savedUserName,
                  )
                : ServiceListScreen(
                    userId: savedUserId!,
                    userName: savedUserName,
                  )),
      ),
    );
  }
}