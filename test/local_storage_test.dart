import 'package:flutter_test/flutter_test.dart';
import 'package:market_analysis/models/farmer_model.dart';
import 'package:market_analysis/models/factory_model.dart';
import 'package:market_analysis/models/purchase_model.dart';
import 'package:market_analysis/models/sale_model.dart';
import 'package:market_analysis/models/worker_model.dart';
import 'package:market_analysis/services/auth_service.dart';
import 'package:market_analysis/services/data_repository.dart';
import 'package:market_analysis/services/local_storage_service.dart';
import 'package:market_analysis/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.login(AuthService.prodUserId);
  });

  test('LocalStorageService saves and retrieves purchases correctly with phone and address', () async {
    final purchase = PurchaseModel(
      id: 'p1',
      cropName: 'Wheat',
      farmerName: 'Ramesh Gowda',
      farmerPhone: '9876543210',
      farmerAddress: 'Hunsur Village',
      quantity: 10,
      unit: 'Quintal',
      pricePerUnit: 2200,
      dateTime: DateTime(2026, 3, 15, 10, 30),
    );

    await LocalStorageService.addPurchase(purchase);

    final loaded = await LocalStorageService.loadPurchases();
    expect(loaded.length, 1);
    expect(loaded.first.id, 'p1');
    expect(loaded.first.cropName, 'Wheat');
    expect(loaded.first.farmerPhone, '9876543210');
    expect(loaded.first.farmerAddress, 'Hunsur Village');
    expect(loaded.first.totalAmount, 22000);
  });

  test('LocalStorageService saves and retrieves sales correctly with contact and address', () async {
    final sale = SaleModel(
      id: 's1',
      cropName: 'Rice',
      factoryName: 'Agro Mill',
      factoryContact: '9845012345',
      factoryAddress: 'Industrial Zone Mandya',
      quantity: 5,
      unit: 'Ton',
      soldAmount: 150000,
      dateTime: DateTime(2026, 3, 15, 14, 00),
    );

    await LocalStorageService.addSale(sale);

    final loaded = await LocalStorageService.loadSales();
    expect(loaded.length, 1);
    expect(loaded.first.id, 's1');
    expect(loaded.first.factoryName, 'Agro Mill');
    expect(loaded.first.factoryContact, '9845012345');
    expect(loaded.first.factoryAddress, 'Industrial Zone Mandya');
    expect(loaded.first.soldAmount, 150000);
  });

  test('LocalStorageService saves and retrieves farmers correctly', () async {
    final farmer = FarmerModel(
      id: 'f1',
      name: 'Nagaraj',
      phone: '9844001122',
      address: 'Pandavapura',
      notes: 'Sugarcane & Paddy',
    );

    await LocalStorageService.addFarmer(farmer);

    final loaded = await LocalStorageService.loadFarmers();
    expect(loaded.length, 1);
    expect(loaded.first.name, 'Nagaraj');
    expect(loaded.first.phone, '9844001122');
    expect(loaded.first.address, 'Pandavapura');
  });

  test('LocalStorageService handles worker lifecycle: load, update, delete', () async {
    final workers = await LocalStorageService.loadWorkers();
    expect(workers.isEmpty, true); // No fake/temporary sample workers

    final customWorker = WorkerModel(
      id: 'test_w1',
      name: 'Venkatesh',
      phone: '9988776655',
      role: 'Loading & Unloading',
      address: 'Mandi Gate 1',
      dailyWage: 700,
      isPresentToday: false,
    );

    await LocalStorageService.addWorker(customWorker);
    var all = await LocalStorageService.loadWorkers();
    expect(all.any((w) => w.id == 'test_w1'), true);

    // Update worker attendance
    await LocalStorageService.updateWorker(customWorker.copyWith(isPresentToday: true));
    all = await LocalStorageService.loadWorkers();
    final updated = all.firstWhere((w) => w.id == 'test_w1');
    expect(updated.isPresentToday, true);

    // Delete worker
    await LocalStorageService.deleteWorker('test_w1');
    all = await LocalStorageService.loadWorkers();
    expect(all.any((w) => w.id == 'test_w1'), false);
  });

  test('DataRepository.getFarmers merges registered farmers with purchase records', () async {
    final purchase = PurchaseModel(
      id: 'p_farmer_test',
      cropName: 'Cotton',
      farmerName: 'Shivanna',
      farmerPhone: '9448012345',
      farmerAddress: 'Belagavi',
      quantity: 20,
      unit: 'Quintal',
      pricePerUnit: 6000,
      dateTime: DateTime.now(),
    );
    await LocalStorageService.addPurchase(purchase);

    final farmers = await DataRepository.getFarmers();
    expect(farmers.any((f) => f.name.toLowerCase() == 'shivanna'), true);
    final shivanna = farmers.firstWhere((f) => f.name.toLowerCase() == 'shivanna');
    expect(shivanna.phone, '9448012345');
    expect(shivanna.address, 'Belagavi');
  });

  test('Supabase mapping and safe fallback when unconfigured', () async {
    final purchase = PurchaseModel(
      id: 'sup_p1',
      cropName: 'Maize',
      farmerName: 'Govindappa',
      farmerPhone: '9845012345',
      farmerAddress: 'Davanagere',
      quantity: 50,
      unit: 'Quintal',
      pricePerUnit: 2100,
      dateTime: DateTime(2026, 3, 20),
    );

    final map = purchase.toSupabaseMap();
    expect(map['crop_name'], 'Maize');
    expect(map['farmer_name'], 'Govindappa');
    expect(map['farmer_phone'], '9845012345');
    expect(map['farmer_address'], 'Davanagere');
    expect(map['quantity'], 50);
    expect(map['total_amount'], 105000);

    // Verify deserialization from Supabase snake_case map
    final fromSupabase = PurchaseModel.fromJson(map);
    expect(fromSupabase.cropName, 'Maize');
    expect(fromSupabase.farmerPhone, '9845012345');
    expect(fromSupabase.farmerAddress, 'Davanagere');
    expect(fromSupabase.totalAmount, 105000);
  });

  test('LocalStorageService saves, retrieves and deletes factories correctly', () async {
    final factory = FactoryModel(
      id: 'fac_1',
      name: 'Mysore Rice Mill',
      contact: '9900112233',
      address: 'Industrial Area, Mysuru',
      notes: 'Buys Paddy & Rice',
    );

    await LocalStorageService.addFactory(factory);

    var loaded = await LocalStorageService.loadFactories();
    expect(loaded.length, 1);
    expect(loaded.first.id, 'fac_1');
    expect(loaded.first.name, 'Mysore Rice Mill');
    expect(loaded.first.contact, '9900112233');
    expect(loaded.first.address, 'Industrial Area, Mysuru');

    // Delete factory
    await LocalStorageService.deleteFactory('fac_1');
    loaded = await LocalStorageService.loadFactories();
    expect(loaded.isEmpty, true);
  });

  test('DataRepository.getFactories merges registered factories with sales records', () async {
    // Add a sale with a new factory
    final sale = SaleModel(
      id: 's_fac_test',
      cropName: 'Sugarcane',
      factoryName: 'Chamundeshwari Sugars',
      factoryContact: '9845998877',
      factoryAddress: 'K.M. Doddi',
      quantity: 100,
      unit: 'Ton',
      soldAmount: 320000,
      dateTime: DateTime.now(),
    );
    await LocalStorageService.addSale(sale);

    // Call getFactories
    final factories = await DataRepository.getFactories();
    expect(factories.any((f) => f.name.toLowerCase() == 'chamundeshwari sugars'), true);
    final match = factories.firstWhere((f) => f.name.toLowerCase() == 'chamundeshwari sugars');
    expect(match.contact, '9845998877');
    expect(match.address, 'K.M. Doddi');
  });

  test('LocalStorageService updates and deletes purchases correctly', () async {
    final purchase = PurchaseModel(
      id: 'p_edit_del',
      cropName: 'Wheat',
      farmerName: 'Eshwar',
      farmerPhone: '9900990099',
      quantity: 10,
      unit: 'Quintal',
      pricePerUnit: 2000,
      dateTime: DateTime.now(),
    );
    await LocalStorageService.addPurchase(purchase);

    // Update price
    final updated = purchase.copyWith(pricePerUnit: 2500, quantity: 12);
    await LocalStorageService.updatePurchase(updated);

    var list = await LocalStorageService.loadPurchases();
    final item = list.firstWhere((p) => p.id == 'p_edit_del');
    expect(item.pricePerUnit, 2500);
    expect(item.quantity, 12);
    expect(item.totalAmount, 30000);

    // Delete
    await LocalStorageService.deletePurchase('p_edit_del');
    list = await LocalStorageService.loadPurchases();
    expect(list.any((p) => p.id == 'p_edit_del'), false);
  });

  test('DataRepository deletes farmer and all linked purchases everywhere', () async {
    final p1 = PurchaseModel(
      id: 'p_link_1',
      cropName: 'Paddy',
      farmerName: 'Mallappa',
      quantity: 15,
      unit: 'Quintal',
      pricePerUnit: 1800,
      dateTime: DateTime.now(),
    );
    final farmer = FarmerModel(
      id: 'f_mallappa',
      name: 'Mallappa',
      phone: '9880011223',
      address: 'Mandya',
    );
    await LocalStorageService.addPurchase(p1);
    await LocalStorageService.addFarmer(farmer);

    // Delete farmer and linked purchases
    await DataRepository.deleteFarmer(farmer.id,
        deleteLinkedPurchases: true, farmerName: 'Mallappa');

    final remainingFarmers = await LocalStorageService.loadFarmers();
    expect(remainingFarmers.any((f) => f.id == 'f_mallappa'), false);

    final remainingPurchases = await LocalStorageService.loadPurchases();
    expect(remainingPurchases.any((p) => p.id == 'p_link_1'), false);
  });

  test('MarketP (Production) and MarketT (Test) data are 100% physically isolated and never overlap', () async {
    // 1. Log in as MarketP (Production)
    await AuthService.login(AuthService.prodUserId);
    expect(AuthService.isProduction, true);
    expect(AuthService.tablePrefix, 'p_');
    expect(SupabaseService.table('purchases'), 'p_purchases');
    expect(SupabaseService.table('sales'), 'p_sales');

    final prodPurchase = PurchaseModel(
      id: 'p_prod_exclusive',
      cropName: 'Production Cotton',
      farmerName: 'Real Business Farmer',
      quantity: 50,
      unit: 'Quintal',
      pricePerUnit: 7000,
      dateTime: DateTime.now(),
    );
    await LocalStorageService.addPurchase(prodPurchase);

    var prodList = await LocalStorageService.loadPurchases();
    expect(prodList.length, 1);
    expect(prodList.first.id, 'p_prod_exclusive');

    // 2. Switch to MarketT (Testing)
    await AuthService.login(AuthService.testUserId);
    expect(AuthService.isTest, true);
    expect(AuthService.tablePrefix, 't_');
    expect(SupabaseService.table('purchases'), 't_purchases');
    expect(SupabaseService.table('sales'), 't_sales');

    // Verify MarketT starts with zero purchases (never sees MarketP data!)
    var testList = await LocalStorageService.loadPurchases();
    expect(testList.isEmpty, true);

    // Add a test purchase in MarketT
    final testPurchase = PurchaseModel(
      id: 't_test_exclusive',
      cropName: 'Sandbox Test Maize',
      farmerName: 'Dummy Test Farmer',
      quantity: 5,
      unit: 'Quintal',
      pricePerUnit: 1500,
      dateTime: DateTime.now(),
    );
    await LocalStorageService.addPurchase(testPurchase);

    testList = await LocalStorageService.loadPurchases();
    expect(testList.length, 1);
    expect(testList.first.id, 't_test_exclusive');

    // 3. Switch back to MarketP (Production)
    await AuthService.login(AuthService.prodUserId);
    prodList = await LocalStorageService.loadPurchases();

    // Verify MarketP still only has its original production data and NOT the test data!
    expect(prodList.length, 1);
    expect(prodList.first.id, 'p_prod_exclusive');
    expect(prodList.any((p) => p.id == 't_test_exclusive'), false);
  });

  test('PurchaseModel correctly deducts suits in kg, calculates crop amount, and subtracts advance paid', () async {
    // 10 Quintals, 50 kg suits -> net = 9.5 Quintals.
    // Price = 2000 per Quintal. Total = 9.5 * 2000 = 19,000.
    // Advance paid = 5,000 -> Net Payable = 14,000.
    final p = PurchaseModel(
      id: 'p_suits_test',
      cropName: 'Cotton',
      farmerName: 'Mallikarjun',
      farmerPhone: '9845112233',
      farmerAddress: 'Raichur',
      quantity: 10,
      suitsKg: 50,
      unit: 'Quintal',
      pricePerUnit: 2000,
      advancePaid: 5000,
      dateTime: DateTime(2026, 3, 20),
    );

    expect(p.suitsInUnit, 0.5); // 50 kg / 100
    expect(p.netQuantity, 9.5); // 10 - 0.5
    expect(p.totalAmount, 19000); // 9.5 * 2000
    expect(p.advancePaid, 5000);
    expect(p.netPayable, 14000); // 19000 - 5000
    expect(p.balanceDue, 14000);

    // Save and load through LocalStorageService
    await LocalStorageService.addPurchase(p);
    final loadedList = await LocalStorageService.loadPurchases();
    final loaded = loadedList.firstWhere((item) => item.id == 'p_suits_test');

    expect(loaded.suitsKg, 50);
    expect(loaded.suitsInUnit, 0.5);
    expect(loaded.netQuantity, 9.5);
    expect(loaded.totalAmount, 19000);
    expect(loaded.advancePaid, 5000);
    expect(loaded.netPayable, 14000);

    // Verify Supabase Map serialization
    final supaMap = loaded.toSupabaseMap();
    expect(supaMap['suits_kg'], 50);
    expect(supaMap['net_quantity'], 9.5);
    expect(supaMap['advance_paid'], 5000);
    expect(supaMap['net_payable'], 14000);
  });
}

