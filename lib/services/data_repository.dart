import '../models/farmer_model.dart';
import '../models/factory_model.dart';
import '../models/purchase_model.dart';
import '../models/sale_model.dart';
import '../models/expenditure_model.dart';
import '../models/daily_analysis_model.dart';
import '../models/daily_settlement_model.dart';
import '../models/worker_model.dart';
import 'local_storage_service.dart';
import 'supabase_service.dart';
import 'auth_service.dart';

/// Single source of truth for the app's data in production.
/// Provides an offline-first architecture:
/// - Reads from local persistent storage instantly (0ms delay).
/// - Automatically syncs with Supabase PostgreSQL backend.
/// - Saves new entries locally first (guaranteeing no data loss) and then uploads to backend.
class DataRepository {
  DataRepository._();

  /// Loads cached purchases immediately. If [syncWithBackend] is true,
  /// fetches the latest rows from Supabase, merges them with local storage,
  /// and returns the combined list.
  static Future<List<PurchaseModel>> getPurchases(
      {bool syncWithBackend = true}) async {
    final cached = await LocalStorageService.loadPurchases();

    if (!syncWithBackend) {
      return cached;
    }

    try {
      List<PurchaseModel> remote = [];

      // 1. Try Supabase first if configured
      if (SupabaseService.isInitialized) {
        remote = await SupabaseService.fetchPurchases();
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

  /// Saves a purchase locally first (never lost), then pushes to Supabase.
  /// Returns true if synced to Supabase (or saved offline).
  static Future<bool> savePurchase(PurchaseModel purchase) async {
    await LocalStorageService.addPurchase(purchase);
    return syncPurchaseToBackend(purchase);
  }

  /// Pushes an existing local purchase to Supabase in the background.
  static Future<bool> syncPurchaseToBackend(PurchaseModel purchase) async {
    if (SupabaseService.isInitialized) {
      return await SupabaseService.addPurchase(purchase);
    }
    return true;
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
  /// fetches latest rows from Supabase.
  static Future<List<SaleModel>> getSales(
      {bool syncWithBackend = true}) async {
    final cached = await LocalStorageService.loadSales();

    if (!syncWithBackend) {
      return cached;
    }

    try {
      List<SaleModel> remote = [];

      if (SupabaseService.isInitialized) {
        remote = await SupabaseService.fetchSales();
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

  /// Saves a sale locally first, then pushes to Supabase.
  static Future<bool> saveSale(SaleModel sale) async {
    await LocalStorageService.addSale(sale);
    return syncSaleToBackend(sale);
  }

  /// Pushes an existing local sale to Supabase in the background.
  static Future<bool> syncSaleToBackend(SaleModel sale) async {
    if (SupabaseService.isInitialized) {
      return await SupabaseService.addSale(sale);
    }
    return true;
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

  /// Records a new payment installment against a purchase.
  /// Appends the payment to the purchase's payments list, sorts by date,
  /// updates remaining balance, and pushes to local storage & backend.
  static Future<bool> addPaymentToPurchase(
      String purchaseId, PaymentEntry payment) async {
    final purchases = await LocalStorageService.loadPurchases();
    final idx = purchases.indexWhere((p) => p.id == purchaseId);
    if (idx == -1) return false;

    final existing = purchases[idx];
    final updatedPayments = [...existing.payments, payment]
      ..sort((a, b) => a.date.compareTo(b.date));

    final updatedPurchase = existing.copyWith(payments: updatedPayments);
    return updatePurchase(updatedPurchase);
  }

  /// Adds or updates a farmer locally and pushes to Supabase.
  static Future<void> saveFarmer(FarmerModel farmer) async {
    await LocalStorageService.addFarmer(farmer);
    if (SupabaseService.isInitialized) {
      await SupabaseService.saveFarmer(farmer);
    }
  }

  /// Updates an existing farmer profile locally and pushes to Supabase.
  /// If [oldName] is provided and changed, updates all linked purchases
  /// to ensure no payment records or purchase histories are ever disconnected or reset.
  static Future<void> updateFarmer(FarmerModel farmer, {String? oldName}) async {
    await LocalStorageService.updateFarmer(farmer);
    if (SupabaseService.isInitialized) {
      await SupabaseService.updateFarmer(farmer);
    }

    if (oldName != null &&
        oldName.trim().isNotEmpty &&
        oldName.trim().toLowerCase() != farmer.name.trim().toLowerCase()) {
      final oldLower = oldName.trim().toLowerCase();
      final purchases = await LocalStorageService.loadPurchases();
      bool anyUpdated = false;
      for (int i = 0; i < purchases.length; i++) {
        if (purchases[i].farmerName.trim().toLowerCase() == oldLower) {
          purchases[i] = purchases[i].copyWith(
            farmerName: farmer.name.trim(),
            farmerPhone: farmer.phone.trim().isNotEmpty
                ? farmer.phone.trim()
                : purchases[i].farmerPhone,
            farmerAddress: farmer.address.trim().isNotEmpty
                ? farmer.address.trim()
                : purchases[i].farmerAddress,
          );
          anyUpdated = true;
          if (SupabaseService.isInitialized) {
            await SupabaseService.updatePurchase(purchases[i]);
          }
        }
      }
      if (anyUpdated) {
        await LocalStorageService.savePurchases(purchases);
      }
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

  /// Completely wipes all local persistent data from the device across all environments.
  static Future<void> clearAllLocalData() async {
    await LocalStorageService.clearAllData();
  }

  // ====================================================================
  // Workers / Labor (Profiles & Contacts)
  // ====================================================================

  /// Loads cached workers immediately and syncs with Supabase in background.
  /// Also merges distinct worker names recorded in purchases.
  static Future<List<WorkerModel>> getWorkers(
      {bool syncWithBackend = true}) async {
    final cached = await LocalStorageService.loadWorkers();

    List<WorkerModel> remoteList = [];
    if (syncWithBackend && SupabaseService.isInitialized) {
      try {
        remoteList = await SupabaseService.fetchWorkers();
      } catch (_) {}
    }

    final Map<String, WorkerModel> map = {};
    for (final w in cached) {
      map[w.id] = w;
    }
    for (final w in remoteList) {
      map[w.id] = w;
    }

    // Merge distinct workers found in purchases
    final purchases = await LocalStorageService.loadPurchases();
    for (final p in purchases) {
      if (p.workerName.trim().isNotEmpty) {
        final existingId = map.values
            .where((w) =>
                w.name.trim().toLowerCase() ==
                p.workerName.trim().toLowerCase())
            .map((w) => w.id)
            .firstOrNull;
        if (existingId == null) {
          final autoId = 'w_${p.workerName.hashCode}';
          map[autoId] = WorkerModel(
            id: autoId,
            name: p.workerName.trim(),
            phone: p.workerPhone.trim(),
            address: p.workerAddress.trim(),
            role: 'Hamali / Labor',
            dailyWage: 0.0,
            joinedDate: p.dateTime,
          );
        }
      }
    }

    final result = map.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await LocalStorageService.saveWorkers(result);
    return result;
  }

  /// Saves a worker profile locally and pushes to Supabase.
  static Future<bool> saveWorker(WorkerModel worker) async {
    await LocalStorageService.addWorker(worker);
    if (SupabaseService.isInitialized) {
      await SupabaseService.saveWorker(worker);
    }
    return true;
  }

  /// Updates a worker profile locally and pushes to Supabase.
  static Future<bool> updateWorker(WorkerModel worker) async {
    await LocalStorageService.updateWorker(worker);
    if (SupabaseService.isInitialized) {
      await SupabaseService.updateWorker(worker);
    }
    return true;
  }

  /// Deletes a worker profile locally and in Supabase.
  static Future<bool> deleteWorker(String id) async {
    await LocalStorageService.deleteWorker(id);
    if (SupabaseService.isInitialized) {
      await SupabaseService.deleteWorker(id);
    }
    return true;
  }

  // ====================================================================
  // Other Expenditure
  // ====================================================================

  /// Loads cached expenditures immediately and syncs with Supabase in background.
  static Future<List<ExpenditureModel>> getExpenditures(
      {bool syncWithBackend = true}) async {
    final cached = await LocalStorageService.loadExpenditures();

    if (!syncWithBackend) {
      return cached;
    }

    try {
      if (SupabaseService.isInitialized) {
        final remote = await SupabaseService.fetchExpenditures();
        if (remote.isNotEmpty) {
          final Map<String, ExpenditureModel> map = {};
          for (final e in cached) {
            map[e.id] = e;
          }
          for (final e in remote) {
            map[e.id] = e;
          }
          final merged = map.values.toList()
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
          await LocalStorageService.saveExpenditures(merged);
          return merged;
        }
      }
    } catch (_) {}

    return cached;
  }

  /// Saves an expenditure locally and pushes to Supabase.
  static Future<bool> saveExpenditure(ExpenditureModel expenditure) async {
    await LocalStorageService.addExpenditure(expenditure);
    if (SupabaseService.isInitialized) {
      await SupabaseService.addExpenditure(expenditure);
    }
    return true;
  }

  /// Updates an expenditure locally and in Supabase.
  static Future<bool> updateExpenditure(ExpenditureModel expenditure) async {
    await LocalStorageService.updateExpenditure(expenditure);
    if (SupabaseService.isInitialized) {
      await SupabaseService.updateExpenditure(expenditure);
    }
    return true;
  }

  /// Deletes an expenditure locally and from Supabase.
  static Future<bool> deleteExpenditure(String id) async {
    await LocalStorageService.deleteExpenditure(id);
    if (SupabaseService.isInitialized) {
      await SupabaseService.deleteExpenditure(id);
    }
    return true;
  }

  // ====================================================================
  // Daily Analysis (Permanent date-wise historical snapshots)
  // ====================================================================

  /// Fetches the permanent daily analysis record for a given [date].
  /// Loads actual stored database records (purchases, sales, expenditures)
  /// and ensures the daily analysis snapshot is permanently saved in Supabase
  /// and local storage with proper date and time (Requirements 1, 2, 5, 6, 7).
  static Future<DailyAnalysisModel> getDailyAnalysisForDate(
    DateTime date, {
    bool syncWithBackend = true,
  }) async {
    final normDate = DateTime(date.year, date.month, date.day);

    // 1. Fetch actual stored database records (purchases, sales, expenditures)
    final purchases = await getPurchases(
        syncWithBackend: syncWithBackend);
    final sales = await getSales(
        syncWithBackend: syncWithBackend);
    final expenditures =
        await getExpenditures(syncWithBackend: syncWithBackend);

    // 2. Compute the exact date-wise analysis from stored database records
    final analysis = DailyAnalysisModel.fromTransactions(
      date: normDate,
      purchases: purchases,
      sales: sales,
      expenditures: expenditures,
      calculationTime: DateTime.now(),
    );

    // 3. Store permanently in local storage
    await LocalStorageService.saveDailyAnalysis(analysis);

    // 4. Store permanently in Supabase database if configured
    if (SupabaseService.isInitialized) {
      await SupabaseService.upsertDailyAnalysis(analysis);
    }

    return analysis;
  }

  /// Fetches all historical daily analysis records stored permanently in the database.
  /// Also ensures any past day with recorded business activity has a persistent snapshot.
  static Future<List<DailyAnalysisModel>> getAllDailyAnalyses({
    bool syncWithBackend = true,
  }) async {
    final cached = await LocalStorageService.loadDailyAnalyses();

    if (syncWithBackend && SupabaseService.isInitialized) {
      try {
        final remote = await SupabaseService.fetchDailyAnalyses();
        if (remote.isNotEmpty) {
          final Map<String, DailyAnalysisModel> map = {};
          for (final a in cached) {
            map[a.dateString] = a;
          }
          for (final a in remote) {
            map[a.dateString] = a;
          }
          final merged = map.values.toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          await LocalStorageService.saveDailyAnalyses(merged);
          return merged;
        }
      } catch (_) {}
    }

    // Automatically generate & persist snapshots for any dates with transactions
    final purchases =
        await getPurchases(syncWithBackend: false);
    final sales =
        await getSales(syncWithBackend: false);
    final expenditures = await getExpenditures(syncWithBackend: false);

    final Set<String> activeDates = {};
    for (final p in purchases) {
      activeDates.add(
          '${p.dateTime.year.toString().padLeft(4, '0')}-${p.dateTime.month.toString().padLeft(2, '0')}-${p.dateTime.day.toString().padLeft(2, '0')}');
    }
    for (final s in sales) {
      activeDates.add(
          '${s.dateTime.year.toString().padLeft(4, '0')}-${s.dateTime.month.toString().padLeft(2, '0')}-${s.dateTime.day.toString().padLeft(2, '0')}');
    }
    for (final e in expenditures) {
      activeDates.add(
          '${e.date.year.toString().padLeft(4, '0')}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}');
    }

    // Also include today
    final now = DateTime.now();
    activeDates.add(
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}');

    final Map<String, DailyAnalysisModel> map = {};
    for (final a in cached) {
      map[a.dateString] = a;
    }

    bool updated = false;
    for (final dStr in activeDates) {
      if (!map.containsKey(dStr)) {
        final parts = dStr.split('-');
        if (parts.length == 3) {
          final d = DateTime(
              int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          final model = DailyAnalysisModel.fromTransactions(
            date: d,
            purchases: purchases,
            sales: sales,
            expenditures: expenditures,
          );
          map[dStr] = model;
          if (SupabaseService.isInitialized) {
            SupabaseService.upsertDailyAnalysis(model);
          }
          updated = true;
        }
      }
    }

    final result = map.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    if (updated) {
      await LocalStorageService.saveDailyAnalyses(result);
    }
    return result;
  }

  // ====================================================================
  // Daily Settlements & Deposits (Permanent settlement records)
  // Meets Requirements 1, 2, 4, 5, 6, 7, 8, 9, 10
  // ====================================================================

  /// Fetches the daily settlement record for a specific business [date].
  /// Links deposits and business purchases for that day.
  /// If settled, remaining balance is strictly 0.00 while preserving all history.
  static Future<DailySettlementModel> getDailySettlementForDate(
    DateTime date, {
    bool syncWithBackend = true,
  }) async {
    final normDate = DateTime(date.year, date.month, date.day);
    final dateStr =
        '${normDate.year.toString().padLeft(4, '0')}-${normDate.month.toString().padLeft(2, '0')}-${normDate.day.toString().padLeft(2, '0')}';

    // 1. Load cached settlement & deposits
    final cachedRecord = await LocalStorageService.getDailySettlementForDate(dateStr);
    List<DailyDepositEntry> deposits =
        await LocalStorageService.loadDailyDepositsForDate(dateStr);

    // 2. Sync with Supabase if online
    DailySettlementModel? remoteRecord;
    if (syncWithBackend && SupabaseService.isInitialized) {
      try {
        final remoteDeps = await SupabaseService.fetchDailyDeposits(dateStr: dateStr);
        if (remoteDeps.isNotEmpty) {
          final Map<String, DailyDepositEntry> dMap = {
            for (final d in deposits) d.id: d,
          };
          for (final d in remoteDeps) {
            dMap[d.id] = d;
          }
          deposits = dMap.values.toList()..sort((a, b) => a.time.compareTo(b.time));
          await LocalStorageService.saveDailyDeposits(deposits);
        }

        remoteRecord = await SupabaseService.fetchDailySettlementForDate(dateStr);
      } catch (_) {}
    }

    // 3. Load actual stored purchases and expenditures to connect business activity
    final purchases = await getPurchases(
      syncWithBackend: syncWithBackend,
    );
    final expenditures = await getExpenditures(
      syncWithBackend: syncWithBackend,
    );

    // Prefer remote record if marked settled, otherwise cached record
    DailySettlementModel? existing = (remoteRecord?.isSettled ?? false)
        ? remoteRecord
        : (cachedRecord ?? remoteRecord);

    // 4. Compute settlement from transactions (deposit - purchasedAmount - expenditure amount)
    final settlement = DailySettlementModel.fromActivity(
      date: normDate,
      purchases: purchases,
      deposits: deposits,
      expenditures: expenditures,
      existingRecord: existing,
    );

    // 5. Persist locally
    await LocalStorageService.saveDailySettlement(settlement);

    // 6. Persist to Supabase
    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.upsertDailySettlement(settlement);
      } catch (_) {}
    }

    return settlement;
  }

  /// Fetches all historical daily settlements stored in the database.
  /// Also ensures any business day with recorded purchases has an active settlement record.
  static Future<List<DailySettlementModel>> getAllDailySettlements({
    bool syncWithBackend = true,
  }) async {
    final cached = await LocalStorageService.loadDailySettlements();

    if (syncWithBackend && SupabaseService.isInitialized) {
      try {
        final remote = await SupabaseService.fetchDailySettlements();
        if (remote.isNotEmpty) {
          final Map<String, DailySettlementModel> map = {};
          for (final s in cached) {
            map[s.dateString] = s;
          }
          for (final s in remote) {
            map[s.dateString] = s;
          }
          final merged = map.values.toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          await LocalStorageService.saveDailySettlements(merged);
          return merged;
        }
      } catch (_) {}
    }

    // Discover any dates with purchases, deposits, or expenditures that don't have a settlement record yet
    final purchases = await getPurchases(syncWithBackend: false);
    final deposits = await LocalStorageService.loadDailyDeposits();
    final expenditures = await getExpenditures(syncWithBackend: false);

    final Set<String> activeDates = {};
    for (final p in purchases) {
      activeDates.add(
          '${p.dateTime.year.toString().padLeft(4, '0')}-${p.dateTime.month.toString().padLeft(2, '0')}-${p.dateTime.day.toString().padLeft(2, '0')}');
    }
    for (final d in deposits) {
      activeDates.add(
          '${d.date.year.toString().padLeft(4, '0')}-${d.date.month.toString().padLeft(2, '0')}-${d.date.day.toString().padLeft(2, '0')}');
    }
    for (final e in expenditures) {
      activeDates.add(
          '${e.date.year.toString().padLeft(4, '0')}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}');
    }

    // Also include today
    final now = DateTime.now();
    activeDates.add(
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}');

    final Map<String, DailySettlementModel> map = {};
    for (final s in cached) {
      map[s.dateString] = s;
    }

    bool updated = false;
    for (final dStr in activeDates) {
      if (!map.containsKey(dStr)) {
        final parts = dStr.split('-');
        if (parts.length == 3) {
          final d = DateTime(
              int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          final model = DailySettlementModel.fromActivity(
            date: d,
            purchases: purchases,
            deposits: deposits,
            expenditures: expenditures,
          );
          map[dStr] = model;
          if (SupabaseService.isInitialized) {
            SupabaseService.upsertDailySettlement(model);
          }
          updated = true;
        }
      }
    }

    final result = map.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    if (updated) {
      await LocalStorageService.saveDailySettlements(result);
    }
    return result;
  }

  /// Adds a new deposit amount during the day.
  /// Meets Requirements 2, 3, 4, 5, 6, 7.
  static Future<DailySettlementModel> addDailyDeposit(
      DailyDepositEntry deposit) async {
    // 1. Save deposit locally
    await LocalStorageService.addDailyDeposit(deposit);

    // 2. Upload deposit to Supabase
    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.insertDailyDeposit(deposit);
      } catch (_) {}
    }

    // 3. Recalculate settlement for that day
    return getDailySettlementForDate(deposit.date, syncWithBackend: false);
  }

  /// Deletes a deposit entry and recalculates settlement totals.
  static Future<DailySettlementModel> deleteDailyDeposit(
      String depositId, DateTime date) async {
    await LocalStorageService.deleteDailyDeposit(depositId);

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.deleteDailyDeposit(depositId);
      } catch (_) {}
    }

    return getDailySettlementForDate(date, syncWithBackend: false);
  }

  /// Completes a day's settlement.
  /// Meets Requirement 8, 9:
  /// - Current remaining amount becomes ₹0.00
  /// - Complete historical transactions, deposits, and purchases remain stored in database.
  /// - Never deletes the day's transactions.
  static Future<DailySettlementModel> completeDailySettlement(
    String settlementId,
    DateTime date, {
    String? notes,
    String? settledBy,
  }) async {
    final normDate = DateTime(date.year, date.month, date.day);
    final current = await getDailySettlementForDate(normDate, syncWithBackend: false);

    final preRemaining = current.effectiveRemainingAmount;

    final updated = current.copyWith(
      status: 'settled',
      remainingAmount: 0.0,
      preSettlementRemaining: preRemaining,
      settledAt: DateTime.now(),
      settledBy: settledBy ?? (AuthService.currentUserId ?? 'User'),
      notes: notes != null && notes.isNotEmpty ? notes : current.notes,
    );

    // 1. Save locally
    await LocalStorageService.saveDailySettlement(updated);

    // 2. Update Supabase
    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.completeDailySettlement(
          settlementId,
          settledBy: settledBy,
          notes: notes,
        );
        await SupabaseService.upsertDailySettlement(updated);
      } catch (_) {}
    }

    return updated;
  }

  /// Reopens a previously settled day for emergency adjustments.
  static Future<DailySettlementModel> reopenDailySettlement(
    String settlementId,
    DateTime date,
  ) async {
    final normDate = DateTime(date.year, date.month, date.day);
    final current = await getDailySettlementForDate(normDate, syncWithBackend: false);

    // Re-calculate remaining balance: deposit - totalPaidAmount (paid for purchases + expenditure)
    final calculatedRem = current.computedDepositsTotal -
        current.totalPaidForPurchases -
        current.totalExpenditures;

    final updated = current.copyWith(
      status: 'open',
      remainingAmount: calculatedRem,
    );

    await LocalStorageService.saveDailySettlement(updated);

    if (SupabaseService.isInitialized) {
      try {
        await SupabaseService.upsertDailySettlement(updated);
      } catch (_) {}
    }

    return updated;
  }
}

