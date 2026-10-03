import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/purchase_model.dart';
import '../models/sale_model.dart';
import '../models/farmer_model.dart';
import '../models/factory_model.dart';
import '../models/worker_model.dart';
import '../models/expenditure_model.dart';

import 'auth_service.dart';

/// Handles persistent local storage on the device using SharedPreferences.
/// Data is serialized to JSON strings so entries are always available
/// offline or when the app is restarted.
class LocalStorageService {
  LocalStorageService._();

  static String get _envSuffix =>
      AuthService.currentUserId != null ? '_${AuthService.currentUserId}' : '';
  static String get _purchasesKey => 'market_analysis_purchases$_envSuffix';
  static String get _salesKey => 'market_analysis_sales$_envSuffix';
  static String get _farmersKey => 'market_analysis_farmers$_envSuffix';
  static String get _factoriesKey => 'market_analysis_factories$_envSuffix';
  static String get _workersKey => 'market_analysis_workers$_envSuffix';
  static String get _expendituresKey => 'market_analysis_expenditures$_envSuffix';

  /// Loads locally saved purchases. Returns an empty list if none are saved.
  static Future<List<PurchaseModel>> loadPurchases() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_purchasesKey);
      if (jsonString == null || jsonString.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(jsonString);
      final list = decoded
          .map((e) => PurchaseModel.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Overwrites the locally saved purchases.
  static Future<void> savePurchases(List<PurchaseModel> purchases) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(purchases.map((p) => p.toJson()).toList());
      await prefs.setString(_purchasesKey, jsonString);
    } catch (_) {
      // Ignored - storage write fallback
    }
  }

  /// Appends a single purchase to local storage.
  static Future<void> addPurchase(PurchaseModel purchase) async {
    final list = await loadPurchases();
    // Avoid duplicate IDs
    list.removeWhere((p) => p.id == purchase.id);
    list.insert(0, purchase);
    await savePurchases(list);
  }

  /// Updates an existing purchase in local storage.
  static Future<void> updatePurchase(PurchaseModel purchase) async {
    final list = await loadPurchases();
    final index = list.indexWhere((p) => p.id == purchase.id);
    if (index != -1) {
      list[index] = purchase;
      await savePurchases(list);
    } else {
      await addPurchase(purchase);
    }
  }

  /// Deletes a purchase from local storage by id.
  static Future<void> deletePurchase(String id) async {
    final list = await loadPurchases();
    list.removeWhere((p) => p.id == id);
    await savePurchases(list);
  }

  /// Deletes all purchases linked to a farmer name.
  static Future<void> deletePurchasesByFarmer(String farmerName) async {
    final lower = farmerName.trim().toLowerCase();
    final list = await loadPurchases();
    list.removeWhere((p) => p.farmerName.trim().toLowerCase() == lower);
    await savePurchases(list);
  }

  /// Loads locally saved sales. Returns an empty list if none are saved.
  static Future<List<SaleModel>> loadSales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_salesKey);
      if (jsonString == null || jsonString.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(jsonString);
      final list = decoded
          .map((e) => SaleModel.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Overwrites the locally saved sales.
  static Future<void> saveSales(List<SaleModel> sales) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(sales.map((s) => s.toJson()).toList());
      await prefs.setString(_salesKey, jsonString);
    } catch (_) {
      // Ignored - storage write fallback
    }
  }

  /// Appends a single sale to local storage.
  static Future<void> addSale(SaleModel sale) async {
    final list = await loadSales();
    list.removeWhere((s) => s.id == sale.id);
    list.insert(0, sale);
    await saveSales(list);
  }

  /// Updates an existing sale in local storage.
  static Future<void> updateSale(SaleModel sale) async {
    final list = await loadSales();
    final index = list.indexWhere((s) => s.id == sale.id);
    if (index != -1) {
      list[index] = sale;
      await saveSales(list);
    } else {
      await addSale(sale);
    }
  }

  /// Deletes a sale from local storage by id.
  static Future<void> deleteSale(String id) async {
    final list = await loadSales();
    list.removeWhere((s) => s.id == id);
    await saveSales(list);
  }

  /// Deletes all sales linked to a factory name.
  static Future<void> deleteSalesByFactory(String factoryName) async {
    final lower = factoryName.trim().toLowerCase();
    final list = await loadSales();
    list.removeWhere((s) => s.factoryName.trim().toLowerCase() == lower);
    await saveSales(list);
  }

  /// Loads registered farmers.
  static Future<List<FarmerModel>> loadFarmers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_farmersKey);
      if (jsonString == null || jsonString.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded
          .map((e) => FarmerModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves registered farmers.
  static Future<void> saveFarmers(List<FarmerModel> farmers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(farmers.map((f) => f.toJson()).toList());
      await prefs.setString(_farmersKey, jsonString);
    } catch (_) {
      // Ignored
    }
  }

  /// Adds or updates a farmer.
  static Future<void> addFarmer(FarmerModel farmer) async {
    final list = await loadFarmers();
    list.removeWhere((f) => f.id == farmer.id || (f.phone.isNotEmpty && f.phone == farmer.phone));
    list.insert(0, farmer);
    await saveFarmers(list);
  }

  /// Updates an existing farmer in local storage.
  static Future<void> updateFarmer(FarmerModel farmer) async {
    final list = await loadFarmers();
    final index = list.indexWhere((f) => f.id == farmer.id);
    if (index != -1) {
      list[index] = farmer;
      await saveFarmers(list);
    } else {
      await addFarmer(farmer);
    }
  }

  /// Deletes a farmer by id.
  static Future<void> deleteFarmer(String id) async {
    final list = await loadFarmers();
    list.removeWhere((f) => f.id == id);
    await saveFarmers(list);
  }

  /// Loads registered factories.
  static Future<List<FactoryModel>> loadFactories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_factoriesKey);
      if (jsonString == null || jsonString.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded
          .map((e) => FactoryModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves registered factories.
  static Future<void> saveFactories(List<FactoryModel> factories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(factories.map((f) => f.toJson()).toList());
      await prefs.setString(_factoriesKey, jsonString);
    } catch (_) {
      // Ignored
    }
  }

  /// Adds or updates a factory.
  static Future<void> addFactory(FactoryModel factory) async {
    final list = await loadFactories();
    final lowerName = factory.name.trim().toLowerCase();
    list.removeWhere((f) =>
        f.id == factory.id ||
        (f.name.trim().toLowerCase() == lowerName && lowerName.isNotEmpty));
    list.insert(0, factory);
    await saveFactories(list);
  }

  /// Deletes a factory by id.
  static Future<void> deleteFactory(String id) async {
    final list = await loadFactories();
    list.removeWhere((f) => f.id == id);
    await saveFactories(list);
  }

  /// Loads workers without any sample / temporary data.
  static Future<List<WorkerModel>> loadWorkers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_workersKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        final list = decoded
            .map((e) => WorkerModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        // Automatically purge any old temporary / sample workers (w1-w4)
        final cleaned = list
            .where((w) => !['w1', 'w2', 'w3', 'w4'].contains(w.id))
            .toList();
        if (cleaned.length != list.length) {
          await saveWorkers(cleaned);
        }
        return cleaned;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Completely clears ALL local data across all environments and all legacy keys.
  static Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().toList();
      for (final key in keys) {
        if (key.startsWith('market_analysis_')) {
          await prefs.remove(key);
        }
      }
    } catch (_) {}
  }

  /// Clears local data for the currently active environment only.
  static Future<void> clearActiveEnvironmentData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_purchasesKey);
      await prefs.remove(_salesKey);
      await prefs.remove(_farmersKey);
      await prefs.remove(_factoriesKey);
      await prefs.remove(_workersKey);
      await prefs.remove(_expendituresKey);
    } catch (_) {}
  }

  /// Overwrites workers list.
  static Future<void> saveWorkers(List<WorkerModel> workers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(workers.map((w) => w.toJson()).toList());
      await prefs.setString(_workersKey, jsonString);
    } catch (_) {
      // Ignored
    }
  }

  /// Adds a worker.
  static Future<void> addWorker(WorkerModel worker) async {
    final list = await loadWorkers();
    list.removeWhere((w) => w.id == worker.id);
    list.insert(0, worker);
    await saveWorkers(list);
  }

  /// Updates a worker.
  static Future<void> updateWorker(WorkerModel worker) async {
    final list = await loadWorkers();
    final index = list.indexWhere((w) => w.id == worker.id);
    if (index != -1) {
      list[index] = worker;
      await saveWorkers(list);
    }
  }

  /// Deletes a worker.
  static Future<void> deleteWorker(String id) async {
    final list = await loadWorkers();
    list.removeWhere((w) => w.id == id);
    await saveWorkers(list);
  }

  // ====================================================================
  // Other Expenditure
  // ====================================================================

  /// Loads locally saved expenditures.
  static Future<List<ExpenditureModel>> loadExpenditures() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_expendituresKey);
      if (jsonString == null || jsonString.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(jsonString);
      final list = decoded
          .map((e) => ExpenditureModel.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Overwrites locally saved expenditures.
  static Future<void> saveExpenditures(List<ExpenditureModel> expenditures) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString =
          jsonEncode(expenditures.map((e) => e.toJson()).toList());
      await prefs.setString(_expendituresKey, jsonString);
    } catch (_) {}
  }

  /// Adds an expenditure.
  static Future<void> addExpenditure(ExpenditureModel expenditure) async {
    final list = await loadExpenditures();
    list.removeWhere((e) => e.id == expenditure.id);
    list.insert(0, expenditure);
    await saveExpenditures(list);
  }

  /// Updates an existing expenditure.
  static Future<void> updateExpenditure(ExpenditureModel expenditure) async {
    final list = await loadExpenditures();
    final index = list.indexWhere((e) => e.id == expenditure.id);
    if (index != -1) {
      list[index] = expenditure;
      await saveExpenditures(list);
    } else {
      await addExpenditure(expenditure);
    }
  }

  /// Deletes an expenditure by id.
  static Future<void> deleteExpenditure(String id) async {
    final list = await loadExpenditures();
    list.removeWhere((e) => e.id == id);
    await saveExpenditures(list);
  }
}
