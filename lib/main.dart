import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/app_colors.dart';
import 'screens/home_page.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/local_storage_service.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // If .env file is missing in production/tests, fallback gracefully
  }

  // Purge all old local storage data to start with a 100% clean slate
  const String purgeKey = 'market_analysis_fresh_wipe_v1';
  try {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(purgeKey)) {
      await LocalStorageService.clearAllData();
      final freshPrefs = await SharedPreferences.getInstance();
      await freshPrefs.setBool(purgeKey, true);
    }
  } catch (_) {}

  // Initialize active environment/user session
  await AuthService.init();

  // Initialize Supabase if credentials are provided in .env
  await SupabaseService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Market Analysis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: AuthService.isLoggedIn ? const HomePage() : const LoginScreen(),
    );
  }
}
