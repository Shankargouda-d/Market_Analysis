import '../models/farmer_model.dart';
import '../models/factory_model.dart';
import '../models/purchase_model.dart';
import '../models/sale_model.dart';
import '../models/worker_model.dart';
import 'local_storage_service.dart';
import 'sheets_service.dart';
import 'supabase_service.dart';

/// Single source of truth for the app's data in production.
/// Provides an offline-first architecture:
/// - Reads from local persistent storage instantly (0ms delay).
/// - Automatically syncs with Supabase PostgreSQL and/or Google Sheets.
/// - Saves new entries locally first (guaranteeing no data loss) and then uploads to backend.
class DataRepository {
  DataRepository._();

  /// Loads cached purchases immediately. If [syncWithBackend] is true,
  /// fetches the latest rows from Supabase (or Sheets fallback), merges them with local storage,
  /// and returns the combined list.
  static Future<List<PurchaseModel>> getPurchases(
      {bool syncWithBackend = true, bool syncWithSheets = true}) async {
    final cached = await LocalStorageService.loadPurchases();

    if (!syncWithBackend && !syncWithSheets) {
      return cached;
    }

    try {
      List<PurchaseModel> remote = [];

      // 1. Try Supabase first if configured
      if (SupabaseService.isInitialized) {
        remote = await SupabaseService.fetchPurchases();
      }

      // 2. Fallback to Sheets if Supabase had no rows or is not configured
      if (remote.isEmpty) {
        remote = await SheetsService.fetchPurchases();
      }

      if (remote.isNotEmpty) {
        // Merge remote and cached by ID, preferring newest entries
        final Map<String, PurchaseModel> map = {};
        for (final p in cached) {
          map[p.id] = p;
        }
        for (final p in remote) {
          map[p.id] = p;
        }
        final merged = map.values.toList()
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
        await LocalStorageService.savePurchases(merged);
        return merged;
      }
    } catch (_) {
      // Offline fallback: continue using cached
    }

    return cached;
  }

  /// Saves a purchase locally first (never lost), then pushes to Supabase and Google Sheets.
  /// Returns true if synced to at least one remote backend.
  static Future<bool> savePurchase(PurchaseModel purchase) async {
    await LocalStorageService.addPurchase(purchase);
    return syncPurchaseToBackend(purchase);
  }

  /// Pushes an existing local purchase to Supabase and Google Sheets in the background.
  static Future<bool> syncPurchaseToBackend(PurchaseModel purchase) async {
    bool syncedSupabase = false;
    bool syncedSheets = false;

    if (SupabaseService.isInitialized) {
      syncedSupabase = await SupabaseService.addPurchase(purchase);
    }

    syncedSheets = await SheetsService.addPurchase(purchase);

    return syncedSupabase || syncedSheets;
  }

  /// Updates an existing purchase locally and in Supabase.
  static Future<bool> updatePurchase(PurchaseModel purchase) async {
    await LocalStorageService.updatePurchase(purchase);
    if (SupabaseService.isInitialized) {
      await SupabaseService.updatePurchase(purchase);
    }
    return true;
  }

  /// Deletes a purchase locally and from Supabase.
  static Future<bool> deletePurchase(String id) async {
    await LocalStorageService.deletePurchase(id);
    if (SupabaseService.isInitialized) {
      await SupabaseService.deletePurchase(id);
    }
    return true;
  }

  /// Alias for backward compatibility with existing screen calls
  static Future<bool> syncPurchaseToSheets(PurchaseModel purchase) =>
      syncPurchaseToBackend(purchase);

  /// Loads cached sales immediately. If [syncWithBackend] is true,
  /// fetches latest rows from Supabase (or Sheets fallback).
  static Future<List<SaleModel>> getSales(
      {bool syncWithBackend = true, bool syncWithSheets = true}) async {
    final cached = await LocalStorageService.loadSales();

    if (!syncWithBackend && !syncWithSheets) {
      return cached;
    }

    try {
      List<SaleModel> remote = [];

      if (SupabaseService.isInitialized) {
        remote = await SupabaseService.fetchSales();
      }

      if (remote.isEmpty) {
        remote = await SheetsService.fetchSales();
      }

      if (remote.isNotEmpty) {
        final Map<String, SaleModel> map = {};
        for (final s in cached) {
          map[s.id] = s;
        }
        for (final s in remote) {
          map[s.id] = s;
        }
        final merged = map.values.toList()
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
        await LocalStorageService.saveSales(merged);
        return merged;
      }
    } catch (_) {
      // Offline fallback: continue using cached
    }

    return cached;
  }

  /// Saves a sale locally first, then pushes to Supabase and Google Sheets.
  static Future<bool> saveSale(SaleModel sale) async {
    await LocalStorageService.addSale(sale);
    return syncSaleToBackend(sale);
  }

  /// Pushes an existing local sale to Supabase and Google Sheets in the background.
  static Future<bool> syncSaleToBackend(SaleModel sale) async {
    bool syncedSupabase = false;
    bool syncedSheets = false;

    if (SupabaseService.isInitialized) {
      syncedSupabase = await SupabaseService.addSale(sale);
    }

    syncedSheets = await SheetsService.addSale(sale);

    return syncedSupabase || syncedSheets;
  }

  /// Updates an existing sale locally and in Supabase.
  static Future<bool> updateSale(SaleModel sale) async {
    await LocalStorageService.updateSale(sale);
    if (SupabaseService.isInitialized) {
      await SupabaseService.updateSale(sale);
    }
    return true;
  }

  /// Deletes a sale locally and from Supabase.
  static Future<bool> deleteSale(String id) async {
    await LocalStorageService.deleteSale(id);
    if (SupabaseService.isInitialized) {
      await SupabaseService.deleteSale(id);
    }
    return true;
  }

  /// Alias for backward compatibility with existing screen calls
  static Future<bool> syncSaleToSheets(SaleModel sale) =>
      syncSaleToBackend(sale);

  /// Loads farmers registered manually, merged with unique farmers from purchases and Supabase.
  static Future<List<FarmerModel>> getFarmers() async {
    final registered = await LocalStorageService.loadFarmers();
    final purchases = await LocalStorageService.loadPurchases();

    List<FarmerModel> remoteFarmers = [];
    if (SupabaseService.isInitialized) {
      try {
        remoteFarmers = await SupabaseService.fetchFarmers();
      } catch (_) {}
    }

    final Map<String, FarmerModel> map = {};

    // 1. Add registered local farmers
    for (final f in registered) {
      final key = f.name.trim().toLowerCase();
      map[key] = f;
    }

    // 2. Add remote Supabase farmers
    for (final f in remoteFarmers) {
      final key = f.name.trim().toLowerCase();
      if (!map.containsKey(key)) {
        map[key] = f;
      } else {
        final existing = map[key]!;
        map[key] = existing.copyWith(
          phone: existing.phone.isEmpty ? f.phone : existing.phone,
          address: existing.address.isEmpty ? f.address : existing.address,
          notes: existing.notes.isEmpty ? f.notes : existing.notes,
        );
      }
    }

    // 3. Merge unique farmers seen in purchases
    for (final p in purchases) {
      if (p.farmerName.trim().isEmpty) continue;
      final key = p.farmerName.trim().toLowerCase();
      if (!map.containsKey(key)) {
        map[key] = FarmerModel(
          id: 'auto_${p.farmerName.hashCode}',
          name: p.farmerName.trim(),
          phone: p.farmerPhone,
          address: p.farmerAddress,
          createdAt: p.dateTime,
        );
      } else {
        final existing = map[key]!;
        if (existing.phone.isEmpty && p.farmerPhone.isNotEmpty ||
            existing.address.isEmpty && p.farmerAddress.isNotEmpty) {
          map[key] = existing.copyWith(
            phone: existing.phone.isEmpty ? p.farmerPhone : existing.phone,
            address:
                existing.address.isEmpty ? p.farmerAddress : existing.address,
          );
        }
      }
    }

    final result = map.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // Cache updated list locally
    await LocalStorageService.saveFarmers(result);
    return result;
  }

  /// Adds or updates a farmer locally and pushes to Supabase.
  static Future<void> saveFarmer(FarmerModel farmer) async {
    await LocalStorageService.addFarmer(farmer);
    if (SupabaseService.isInitialized) {
      await SupabaseService.saveFarmer(farmer);
    }
  }

  /// Updates an existing farmer profile locally and pushes to Supabase.
  static Future<void> updateFarmer(FarmerModel farmer) async {
    await LocalStorageService.updateFarmer(farmer);
    if (SupabaseService.isInitialized) {
      await SupabaseService.updateFarmer(farmer);
    }
  }

  /// Deletes a farmer locally and from Supabase, and optionally deletes all linked purchases.
  static Future<void> deleteFarmer(String id,
      {bool deleteLinkedPurchases = false, String? farmerName}) async {
    await LocalStorageService.deleteFarmer(id);
    if (SupabaseService.isInitialized) {
      await SupabaseService.deleteFarmer(id);
    }
    if (deleteLinkedPurchases && farmerName != null && farmerName.isNotEmpty) {
      await LocalStorageService.deletePurchasesByFarmer(farmerName);
      if (SupabaseService.isInitialized) {
        await SupabaseService.deletePurchasesByFarmer(farmerName);
      }
    }
  }

  /// Loads factories registered manually, merged with unique factories from sales and Supabase.
  static Future<List<FactoryModel>> getFactories() async {
    final registered = await LocalStorageService.loadFactories();
    final sales = await LocalStorageService.loadSales();

    List<FactoryModel> remoteFactories = [];
    if (SupabaseService.isInitialized) {
      try {
        remoteFactories = await SupabaseService.fetchFactories();
      } catch (_) {}
    }

    final Map<String, FactoryModel> map = {};

    // 1. Add registered local factories
    for (final f in registered) {
      final key = f.name.trim().toLowerCase();
      map[key] = f;
    }

    // 2. Add remote Supabase factories
    for (final f in remoteFactories) {
      final key = f.name.trim().toLowerCase();
      if (!map.containsKey(key)) {
        map[key] = f;
      } else {
        final existing = map[key]!;
        map[key] = existing.copyWith(
          contact: existing.contact.isEmpty ? f.contact : existing.contact,
          address: existing.address.isEmpty ? f.address : existing.address,
          notes: existing.notes.isEmpty ? f.notes : existing.notes,
        );
      }
    }

    // 3. Merge unique factories seen in sales (e.g. added during selling)
    for (final s in sales) {
      if (s.factoryName.trim().isEmpty) continue;
      final key = s.factoryName.trim().toLowerCase();
      if (!map.containsKey(key)) {
        map[key] = FactoryModel(
          id: 'auto_fac_${s.factoryName.hashCode}',
          name: s.factoryName.trim(),
          contact: s.factoryContact,
          address: s.factoryAddress,
          createdAt: s.dateTime,
        );
      } else {
        final existing = map[key]!;
        if ((existing.contact.isEmpty && s.factoryContact.isNotEmpty) ||
            (existing.address.isEmpty && s.factoryAddress.isNotEmpty)) {
          map[key] = existing.copyWith(
            contact:
                existing.contact.isEmpty ? s.factoryContact : existing.contact,
            address:
                existing.address.isEmpty ? s.factoryAddress : existing.address,
          );
        }
      }
    }

    final result = map.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // Cache updated list locally
    await LocalStorageService.saveFactories(result);
    return result;
  }

  /// Adds or updates a factory locally and pushes to Supabase.
  static Future<void> saveFactory(FactoryModel factory) async {
    await LocalStorageService.addFactory(factory);
    if (SupabaseService.isInitialized) {
      await SupabaseService.saveFactory(factory);
    }
  }

  /// Updates an existing factory locally and pushes to Supabase.
  static Future<void> updateFactory(FactoryModel factory) async {
    await LocalStorageService.addFactory(factory);
    if (SupabaseService.isInitialized) {
      await SupabaseService.updateFactory(factory);
    }
  }

  /// Deletes a factory locally and from Supabase, and optionally deletes all linked sales.
  static Future<void> deleteFactory(String id,
      {bool deleteLinkedSales = false, String? factoryName}) async {
    await LocalStorageService.deleteFactory(id);
    if (SupabaseService.isInitialized) {
      await SupabaseService.deleteFactory(id);
    }
    if (deleteLinkedSales && factoryName != null && factoryName.isNotEmpty) {
      await LocalStorageService.deleteSalesByFactory(factoryName);
      if (SupabaseService.isInitialized) {
        await SupabaseService.deleteSalesByFactory(factoryName);
      }
    }
  }

  /// Loads workers from Supabase and/or persistent local storage.
  static Future<List<WorkerModel>> getWorkers() async {
    final local = await LocalStorageService.loadWorkers();

    if (SupabaseService.isInitialized) {
      try {
        final remote = await SupabaseService.fetchWorkers();
        if (remote.isNotEmpty) {
          await LocalStorageService.saveWorkers(remote);
          return remote;
        }
      } catch (_) {}
    }

    return local;
  }

  /// Adds a new worker locally and pushes to Supabase.
  static Future<void> saveWorker(WorkerModel worker) async {
    await LocalStorageService.addWorker(worker);
    if (SupabaseService.isInitialized) {
      await SupabaseService.saveWorker(worker);
    }
  }

  /// Updates an existing worker locally and pushes to Supabase.
  static Future<void> updateWorker(WorkerModel worker) async {
    await LocalStorageService.updateWorker(worker);
    if (SupabaseService.isInitialized) {
      await SupabaseService.updateWorker(worker);
    }
  }

  /// Deletes a worker locally and from Supabase.
  static Future<void> deleteWorker(String id) async {
    await LocalStorageService.deleteWorker(id);
    if (SupabaseService.isInitialized) {
      await SupabaseService.deleteWorker(id);
    }
  }
}
