import 'package:shared_preferences/shared_preferences.dart';

/// Manages authentication and environment isolation between:
/// - MarketP: Production Environment (Real Business)
/// - MarketT: Test Environment (Bug fixing, experimenting, new features)
class AuthService {
  AuthService._();

  static const String prodUserId = 'MarketP';
  static const String testUserId = 'MarketT';
  static const String _sessionKey = 'market_analysis_active_user_id';

  static String? _currentUserId;

  /// Current logged-in User ID ('MarketP' or 'MarketT'), or null if logged out.
  static String? get currentUserId => _currentUserId;

  /// True if a valid user is logged in.
  static bool get isLoggedIn =>
      _currentUserId == prodUserId || _currentUserId == testUserId;

  /// True if logged in as MarketP (Production / Real Business).
  static bool get isProduction => _currentUserId == prodUserId;

  /// True if logged in as MarketT (Testing / Bug fixing).
  static bool get isTest => _currentUserId == testUserId;

  /// Prefix for Supabase tables to guarantee 100% physical database separation.
  /// MarketP -> 'p_' (e.g. p_purchases, p_sales)
  /// MarketT -> 't_' (e.g. t_purchases, t_sales)
  static String get tablePrefix => isProduction ? 'p_' : 't_';

  /// Human-readable environment name.
  static String get environmentName =>
      isProduction ? 'Production (Real Business)' : 'Testing / Sandbox';

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

  /// Logs in with either 'MarketP' or 'MarketT'.
  /// Returns true if successful, false if invalid User ID.
  static Future<bool> login(String rawId) async {
    final cleanId = rawId.trim();
    if (cleanId != prodUserId && cleanId != testUserId) {
      return false;
    }

    _currentUserId = cleanId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, cleanId);
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
