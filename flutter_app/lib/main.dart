import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firebase_options.dart';
import 'theme.dart';
import 'routes.dart';
import 'services/auth_provider.dart';
// Conditional import for platform-specific utilities
import 'utils/platform_utils_mobile.dart'
    if (dart.library.html) 'utils/platform_utils_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Get the initial route from browser URL for web, or default to login
  String _getInitialRoute() {
    if (kIsWeb) {
      // Get the current URL path
      final path = getCurrentPath() ?? '/';
      final search = getCurrentSearch() ?? '';

      // If there's a specific path (not just '/'), use it
      if (path != '/' && path.isNotEmpty) {
        return path + search;
      }
    }

    // Default to home (landing page) for mobile or root web path
    return AppRoutes.home;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'ChronoWorks',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        initialRoute: _getInitialRoute(),
        onGenerateRoute: AppRoutes.generateRoute,
      ),
    );
  }
}
