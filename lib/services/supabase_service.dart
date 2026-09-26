import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../models/farmer_model.dart';
import '../models/factory_model.dart';
import '../models/purchase_model.dart';
import '../models/sale_model.dart';
import '../models/worker_model.dart';
import 'auth_service.dart';

/// Production service providing direct, type-safe communication
/// with your Supabase PostgreSQL backend.
/// Automatically falls back gracefully when credentials are not yet entered.
/// Guarantees 100% database physical separation via dynamic table prefixing (p_* vs t_*).
class SupabaseService {
  SupabaseService._();

  static bool _initialized = false;

  /// Resolves the physically isolated table name based on current user:
  /// MarketP -> 'p_purchases', 'p_sales', etc.
  /// MarketT -> 't_purchases', 't_sales', etc.
  static String table(String base) => '${AuthService.tablePrefix}$base';

  /// True if Supabase was successfully initialized with valid URL and key.
  static bool get isInitialized =>
      _initialized && AppConstants.isSupabaseConfigured;

  /// Gets the active Supabase client instance, or null if not configured.
  static SupabaseClient? get client =>
      isInitialized ? Supabase.instance.client : null;

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
}
