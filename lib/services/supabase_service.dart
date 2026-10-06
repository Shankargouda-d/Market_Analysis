import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../models/farmer_model.dart';
import '../models/factory_model.dart';
import '../models/purchase_model.dart';
import '../models/sale_model.dart';
import '../models/worker_model.dart';
import '../models/expenditure_model.dart';
import '../models/daily_analysis_model.dart';
import '../models/daily_settlement_model.dart';
import 'auth_service.dart';

/// Production service providing direct, type-safe communication
/// with your Supabase PostgreSQL backend.
/// Automatically falls back gracefully when credentials are not yet entered.
/// Guarantees 100% database physical separation via dynamic table prefixing (p_* vs t_*).
class SupabaseService {
  SupabaseService._();

  static bool _initialized = false;

  static bool _networkUnreachable = false;

  /// When true or running in automated tests, network calls and timers are bypassed.
  static bool bypassForTesting = false;

  static bool get isRunningInTest {
    if (bypassForTesting) return true;
    try {
      return WidgetsBinding.instance.runtimeType
          .toString()
          .contains('TestWidgetsFlutterBinding');
    } catch (_) {
      return false;
    }
  }

  /// Resolves the table name based on tablePrefix.
  /// MarketT is completely and permanently disconnected from Supabase.
  static String table(String base) => '${AuthService.tablePrefix}$base';

  /// True if Supabase was successfully initialized with valid URL and key.
  static bool get isInitialized =>
      _initialized && AppConstants.isSupabaseConfigured && !_networkUnreachable;

  /// MarketT is completely disconnected from Supabase.
  /// Only MarketP (Production) is permitted to communicate with Supabase.
  static bool get canConnectToSupabase =>
      !isRunningInTest &&
      isInitialized &&
      AuthService.isProduction &&
      AuthService.currentUserId != AuthService.testUserId;

  /// Gets the active Supabase client instance exclusively for MarketP.
  /// Returns null for MarketT or when unconfigured/unreachable.
  static SupabaseClient? get client =>
      canConnectToSupabase ? Supabase.instance.client : null;

  /// Resets reachability status to re-attempt connection.
  static void resetReachability() {
    _networkUnreachable = false;
  }

  /// Checks whether Supabase is successfully connected.
  static Future<({bool isConnected, String message})> checkConnection() async {
    if (isRunningInTest) {
      return (
        isConnected: false,
        message: 'Test mode: Cloud connection bypassed',
      );
    }
    if (!AppConstants.isSupabaseConfigured) {
      return (
        isConnected: false,
        message:
            'Supabase credentials not configured in .env (Offline local storage active)',
      );
    }
    if (AuthService.currentUserId == AuthService.testUserId) {
      return (
        isConnected: false,
        message:
            'MarketT connection to Supabase is removed. Only MarketP connects to Supabase.',
      );
    }
    if (!_initialized) {
      try {
        await init();
      } catch (e) {
        return (isConnected: false, message: 'Initialization failed: $e');
      }
    }
    try {
      final c = Supabase.instance.client;
      await c.from('p_purchases').select('id').limit(1);
      _networkUnreachable = false;
      return (
        isConnected: true,
        message: 'Supabase connected successfully for MarketP (Production)!',
      );
    } catch (e) {
      _networkUnreachable = true;
      return (
        isConnected: false,
        message: 'Supabase unreachable or network issue: $e',
      );
    }
  }

  /// Initializes Supabase on app startup. Safe to call anytime;
  /// gracefully skips if configuration is missing.
  static Future<void> init() async {
    if (!AppConstants.isSupabaseConfigured) {
      _initialized = false;
      return;
    }

    try {
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: AppConstants.supabaseAnonKey,
      );
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  // ====================================================================
  // Purchases (Buy from Farmer)
  // ====================================================================

  static Future<bool> addPurchase(PurchaseModel purchase) async {
    final c = client;
    if (c == null) return false;
    try {
      await c.from(table('purchases')).upsert(purchase.toSupabaseMap());
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updatePurchase(PurchaseModel purchase) async {
    final c = client;
    if (c == null) return false;
    try {
      await c
          .from(table('purchases'))
          .update(purchase.toSupabaseMap())
          .eq('id', purchase.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deletePurchase(String id) async {
    final c = client;
    if (c == null) return false;
    try {
      await c.from(table('purchases')).delete().eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deletePurchasesByFarmer(String farmerName) async {
    final c = client;
    if (c == null) return false;
    try {
      await c.from(table('purchases')).delete().eq('farmer_name', farmerName);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<PurchaseModel>> fetchPurchases() async {
    final c = client;
    if (c == null) return [];
    try {
      final res = await c
          .from(table('purchases'))
          .select()
          .order('date', ascending: false);

      final list = (res as List)
          .map((row) =>
              PurchaseModel.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  // ====================================================================
  // Sales (Sell to Factory)
  // ====================================================================

  static Future<bool> addSale(SaleModel sale) async {
    final c = client;
    if (c == null) return false;
    try {
      await c.from(table('sales')).upsert(sale.toSupabaseMap());
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateSale(SaleModel sale) async {
    final c = client;
    if (c == null) return false;
    try {
      await c
          .from(table('sales'))
          .update(sale.toSupabaseMap())
          .eq('id', sale.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteSale(String id) async {
    final c = client;
    if (c == null) return false;
    try {
      await c.from(table('sales')).delete().eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteSalesByFactory(String factoryName) async {
    final c = client;
    if (c == null) return false;
    try {
      await c.from(table('sales')).delete().eq('factory_name', factoryName);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<SaleModel>> fetchSales() async {
    final c = client;
    if (c == null) return [];
    try {
      final res = await c
          .from(table('sales'))
          .select()
          .order('date', ascending: false);

      final list = (res as List)
          .map((row) => SaleModel.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  // ====================================================================
  // Farmers
  // ====================================================================

  static Future<bool> saveFarmer(FarmerModel farmer) async {
    final c = client;
    if (c == null) return false;
    try {
      await c.from(table('farmers')).upsert(farmer.toSupabaseMap());
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateFarmer(FarmerModel farmer) async {
    final c = client;
    if (c == null) return false;
    try {
      await c
          .from(table('farmers'))
          .update(farmer.toSupabaseMap())
          .eq('id', farmer.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteFarmer(String id) async {
    final c = client;
    if (c == null) return false;
    try {
      await c.from(table('farmers')).delete().eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<FarmerModel>> fetchFarmers() async {
    final c = client;
    if (c == null) return [];
    try {
      final res =
          await c.from(table('farmers')).select().order('name', ascending: true);

      final list = (res as List)
          .map((row) => FarmerModel.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  // ====================================================================
  // Factories
  // ====================================================================

  static Future<bool> saveFactory(FactoryModel factory) async {
    final c = client;
    if (c == null) return false;
    try {
      await c.from(table('factories')).upsert(factory.toSupabaseMap());
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateFactory(FactoryModel factory) async {
    final c = client;
    if (c == null) return false;
    try {
      await c
          .from(table('factories'))
          .update(factory.toSupabaseMap())
          .eq('id', factory.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteFactory(String id) async {
    final c = client;
    if (c == null) return false;
    try {
      await c.from(table('factories')).delete().eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<FactoryModel>> fetchFactories() async {
    final c = client;
    if (c == null) return [];
    try {
      final res = await c
          .from(table('factories'))
          .select()
          .order('name', ascending: true);

      final list = (res as List)
          .map((row) => FactoryModel.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  // ====================================================================
  // Workers
  // ====================================================================

  static Future<bool> saveWorker(WorkerModel worker) async {
    final c = client;
    if (c == null) return false;
    try {
      await c.from(table('workers')).upsert(worker.toSupabaseMap());
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateWorker(WorkerModel worker) async {
    final c = client;
    if (c == null) return false;
    try {
      await c
          .from(table('workers'))
          .update(worker.toSupabaseMap())
          .eq('id', worker.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteWorker(String id) async {
    final c = client;
    if (c == null) return false;
    try {
      await c.from(table('workers')).delete().eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<WorkerModel>> fetchWorkers() async {
    final c = client;
    if (c == null) return [];
    try {
      final res =
          await c.from(table('workers')).select().order('name', ascending: true);

      final list = (res as List)
          .map((row) => WorkerModel.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  // ====================================================================
  // Other Expenditure
  // ====================================================================

  static Future<bool> addExpenditure(ExpenditureModel expenditure) async {
    final c = client;
    if (c == null) return false;
    try {
      await c.from(table('expenditures')).upsert(expenditure.toSupabaseMap());
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateExpenditure(ExpenditureModel expenditure) async {
    final c = client;
    if (c == null) return false;
    try {
      await c
          .from(table('expenditures'))
          .update(expenditure.toSupabaseMap())
          .eq('id', expenditure.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteExpenditure(String id) async {
    final c = client;
    if (c == null) return false;
    try {
      await c.from(table('expenditures')).delete().eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<ExpenditureModel>> fetchExpenditures() async {
    final c = client;
    if (c == null) return [];
    try {
      final res = await c
          .from(table('expenditures'))
          .select()
          .order('date', ascending: false);

      final list = (res as List)
          .map((row) =>
              ExpenditureModel.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  // ====================================================================
  // Daily Analysis (Permanent date-wise historical snapshots)
  // ====================================================================

  static Future<bool> upsertDailyAnalysis(DailyAnalysisModel analysis) async {
    final c = client;
    if (c == null) return false;
    try {
      await c.from(table('daily_analysis')).upsert(analysis.toSupabaseMap());
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<DailyAnalysisModel>> fetchDailyAnalyses() async {
    final c = client;
    if (c == null) return [];
    try {
      final res = await c
          .from(table('daily_analysis'))
          .select()
          .order('date', ascending: false);

      final list = (res as List)
          .map((row) =>
              DailyAnalysisModel.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<DailyAnalysisModel?> fetchDailyAnalysisForDate(
      String dateStr) async {
    final c = client;
    if (c == null) return null;
    try {
      final res = await c
          .from(table('daily_analysis'))
          .select()
          .eq('date', dateStr)
          .maybeSingle();

      if (res != null) {
        return DailyAnalysisModel.fromJson(Map<String, dynamic>.from(res));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> deleteDailyAnalysis(String id) async {
    final c = client;
    if (c == null) return false;
    try {
      await c.from(table('daily_analysis')).delete().eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ====================================================================
  // Daily Settlements & Deposits
  // ====================================================================

  static Future<bool> upsertDailySettlement(DailySettlementModel settlement) async {
    final c = client;
    if (c == null) return false;
    try {
      await c.from(table('daily_settlements')).upsert(settlement.toSupabaseMap());
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<DailySettlementModel>> fetchDailySettlements() async {
    final c = client;
    if (c == null) return [];
    try {
      final res = await c
          .from(table('daily_settlements'))
          .select()
          .order('date', ascending: false);

      final deposits = await fetchDailyDeposits();

      final list = (res as List).map((row) {
        final map = Map<String, dynamic>.from(row);
        final sId = map['id']?.toString() ?? '';
        final sDate = map['date']?.toString() ?? '';
        final matchingDeposits = deposits.where((d) =>
            d.settlementId == sId ||
            d.settlementId == 'settle_$sDate' ||
            '${d.date.year.toString().padLeft(4, '0')}-${d.date.month.toString().padLeft(2, '0')}-${d.date.day.toString().padLeft(2, '0')}' == sDate).toList();
        return DailySettlementModel.fromJson(map, deposits: matchingDeposits);
      }).toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<DailySettlementModel?> fetchDailySettlementForDate(String dateStr) async {
    final c = client;
    if (c == null) return null;
    try {
      final res = await c
          .from(table('daily_settlements'))
          .select()
          .eq('date', dateStr)
          .maybeSingle();

      if (res != null) {
        final map = Map<String, dynamic>.from(res);
        final deposits = await fetchDailyDeposits(dateStr: dateStr);
        return DailySettlementModel.fromJson(map, deposits: deposits);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> completeDailySettlement(
    String settlementId, {
    String? settledBy,
    String? notes,
  }) async {
    final c = client;
    if (c == null) return false;
    try {
      // First attempt server-side PostgreSQL function for transactional guarantees
      try {
        await c.rpc('fn_complete_daily_settlement', params: {
          'p_prefix': AuthService.tablePrefix.replaceAll('_', ''),
          'p_settlement_id': settlementId,
          'p_settled_by': settledBy ?? (AuthService.currentUserId ?? 'User'),
          'p_notes': notes ?? '',
        });
        return true;
      } catch (_) {
        // Fallback to direct table update
      }

      await c.from(table('daily_settlements')).update({
        'status': 'settled',
        'remaining_amount': 0.0,
        'settled_at': DateTime.now().toIso8601String(),
        'settled_by': settledBy ?? (AuthService.currentUserId ?? 'User'),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', settlementId);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> insertDailyDeposit(DailyDepositEntry deposit) async {
    final c = client;
    if (c == null) return false;
    try {
      await c.from(table('daily_deposits')).upsert(deposit.toSupabaseMap());
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteDailyDeposit(String id) async {
    final c = client;
    if (c == null) return false;
    try {
      await c.from(table('daily_deposits')).delete().eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<DailyDepositEntry>> fetchDailyDeposits({
    String? dateStr,
    String? settlementId,
  }) async {
    final c = client;
    if (c == null) return [];
    try {
      var query = c.from(table('daily_deposits')).select();
      if (settlementId != null && settlementId.isNotEmpty) {
        query = query.eq('settlement_id', settlementId);
      } else if (dateStr != null && dateStr.isNotEmpty) {
        query = query.eq('date', dateStr);
      }
      final res = await query.order('created_time', ascending: true);
      final list = (res as List)
          .map((row) => DailyDepositEntry.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }
}

