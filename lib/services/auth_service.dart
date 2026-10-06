import 'package:shared_preferences/shared_preferences.dart';

/// Manages authentication for Market Analysis.
/// Exclusively dedicated to MarketP (Production System) with password authentication ('SBT').
class AuthService {
  AuthService._();

  static const String prodUserId = 'MarketP';
  static const String testUserId = 'MarketT'; // Kept for backwards-compatible offline tests
  static const String _sessionKey = 'market_analysis_active_user_id';
  static const String systemPassword = 'SBT';

  static String? _currentUserId;

  /// Current logged-in User ID ('MarketP'), or null if logged out.
  static String? get currentUserId => _currentUserId;

  /// True if a valid user is logged in.
  static bool get isLoggedIn =>
      _currentUserId == prodUserId || _currentUserId == testUserId;

  /// True if logged in as MarketP (Production / Real Business).
  static bool get isProduction => _currentUserId == prodUserId;

  /// True if test mode.
  static bool get isTest => _currentUserId == testUserId;

  /// Prefix for tables ('p_' for MarketP, 't_' for MarketT).
  static String get tablePrefix => isTest ? 't_' : 'p_';

  /// Human-readable environment name.
  static String get environmentName =>
      isProduction ? 'MarketP (Production)' : 'MarketT (Sandbox / Test)';

  /// Verifies if the entered password is correct ('SBT').
  static bool verifyPassword(String password) {
    return password.trim().toUpperCase() == systemPassword;
  }

  /// Initializes session on app startup.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_sessionKey)?.trim();
      if (savedId == prodUserId || savedId == testUserId) {
        _currentUserId = savedId;
      } else {
        _currentUserId = null;
      }
    } catch (_) {
      _currentUserId = null;
    }
  }

  /// Logs in as MarketP (or custom ID).
  static Future<bool> login([String rawId = prodUserId]) async {
    final cleanId = rawId.trim();
    if (cleanId == testUserId) {
      _currentUserId = testUserId;
    } else {
      _currentUserId = prodUserId;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, _currentUserId!);
    } catch (_) {}
    return true;
  }

  /// Logs out of the current session.
  static Future<void> logout() async {
    _currentUserId = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (_) {}
  }
}
