import 'package:flutter_test/flutter_test.dart';
import 'package:market_analysis/models/farmer_model.dart';
import 'package:market_analysis/models/factory_model.dart';
import 'package:market_analysis/models/purchase_model.dart';
import 'package:market_analysis/models/sale_model.dart';
import 'package:market_analysis/models/expenditure_model.dart';
import 'package:market_analysis/models/daily_analysis_model.dart';
import 'package:market_analysis/models/daily_settlement_model.dart';
import 'package:market_analysis/services/auth_service.dart';
import 'package:market_analysis/services/data_repository.dart';
import 'package:market_analysis/services/local_storage_service.dart';
import 'package:market_analysis/models/worker_model.dart';
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

  test('LocalStorageService and ExpenditureModel save worker/payee name, phone, and address', () async {
    final exp = ExpenditureModel(
      id: 'exp_worker_1',
      title: 'Hamali Loading Wages',
      category: 'Labor / Daily Wages',
      amount: 1500,
      dateTime: DateTime(2026, 4, 1, 11, 00),
      paidTo: 'Venkatesh',
      paidToPhone: '9988776655',
      paidToAddress: 'Mandi Gate 1, APMC Yard',
      paymentMode: 'Cash',
      notes: 'Paid for unloading 30 bags of wheat',
    );

    await LocalStorageService.addExpenditure(exp);
    final loaded = await LocalStorageService.loadExpenditures();
    expect(loaded.any((e) => e.id == 'exp_worker_1'), true);

    final saved = loaded.firstWhere((e) => e.id == 'exp_worker_1');
    expect(saved.paidTo, 'Venkatesh');
    expect(saved.paidToPhone, '9988776655');
    expect(saved.paidToAddress, 'Mandi Gate 1, APMC Yard');
    expect(saved.amount, 1500);
    expect(saved.category, 'Labor / Daily Wages');

    // Update expenditure
    final updated = saved.copyWith(amount: 1800, paidToPhone: '9988776600');
    await LocalStorageService.updateExpenditure(updated);
    final afterUpdate = await LocalStorageService.loadExpenditures();
    final item = afterUpdate.firstWhere((e) => e.id == 'exp_worker_1');
    expect(item.amount, 1800);
    expect(item.paidToPhone, '9988776600');

    // Delete expenditure
    await LocalStorageService.deleteExpenditure('exp_worker_1');
    final afterDelete = await LocalStorageService.loadExpenditures();
    expect(afterDelete.any((e) => e.id == 'exp_worker_1'), false);
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
    final purchaseDate = DateTime(2026, 3, 20);
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
      payments: [PaymentEntry(amount: 5000, date: purchaseDate)],
      dateTime: purchaseDate,
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

  test('Multi-installment payment tracking, remaining balance calculation, and farmer updates', () async {
    final d1 = DateTime(2026, 4, 1, 10, 0);
    final d2 = DateTime(2026, 4, 5, 14, 30);
    final d3 = DateTime(2026, 4, 10, 11, 0);

    // Initial purchase with advance payment of 4,000
    // 5 Quintal @ 2000 = 10,000 total.
    final purchase = PurchaseModel(
      id: 'p_installments_1',
      cropName: 'Corn',
      farmerName: 'Basavaraj Patil',
      farmerPhone: '9988776655',
      farmerAddress: 'Koppal',
      quantity: 5,
      unit: 'Quintal',
      pricePerUnit: 2000,
      payments: [
        PaymentEntry(
          id: 'pay_1',
          amount: 4000,
          date: d1,
          paymentMode: 'Cash',
          notes: 'Advance at harvest',
        ),
      ],
      dateTime: d1,
    );

    await LocalStorageService.addPurchase(purchase);

    // Initially: 10,000 total, 4,000 paid, 6,000 remaining -> Pending
    var loadedList = await LocalStorageService.loadPurchases();
    var p = loadedList.firstWhere((x) => x.id == 'p_installments_1');
    expect(p.totalAmount, 10000);
    expect(p.totalAmountPaid, 4000);
    expect(p.remainingBalance, 6000);
    expect(p.isPending, isTrue);
    expect(p.isPaid, isFalse);
    expect(p.paymentStatus, 'Pending');

    // Add installment 2: 3,000 via DataRepository
    final success2 = await DataRepository.addPaymentToPurchase(
      'p_installments_1',
      PaymentEntry(
        id: 'pay_2',
        amount: 3000,
        date: d2,
        paymentMode: 'UPI / Online',
        notes: 'GPay installment 2',
      ),
    );
    expect(success2, isTrue);

    loadedList = await LocalStorageService.loadPurchases();
    p = loadedList.firstWhere((x) => x.id == 'p_installments_1');
    expect(p.payments.length, 2);
    expect(p.totalAmountPaid, 7000);
    expect(p.remainingBalance, 3000);
    expect(p.isPending, isTrue);
    expect(p.isPaid, isFalse);

    // Add installment 3: final 3,000 to clear the balance
    final success3 = await DataRepository.addPaymentToPurchase(
      'p_installments_1',
      PaymentEntry(
        id: 'pay_3',
        amount: 3000,
        date: d3,
        paymentMode: 'Bank Transfer',
        notes: 'Final settlement',
      ),
    );
    expect(success3, isTrue);

    loadedList = await LocalStorageService.loadPurchases();
    p = loadedList.firstWhere((x) => x.id == 'p_installments_1');
    expect(p.payments.length, 3);
    expect(p.totalAmountPaid, 10000);
    expect(p.remainingBalance, 0);
    expect(p.balanceDue, 0);
    expect(p.isPaid, isTrue);
    expect(p.isPending, isFalse);
    expect(p.paymentStatus, 'Paid');

    // Payments are ordered chronologically
    final sorted = p.sortedPayments;
    expect(sorted[0].id, 'pay_1');
    expect(sorted[1].id, 'pay_2');
    expect(sorted[2].id, 'pay_3');

    // Editing farmer updates linked purchases without resetting payment records
    final farmer = FarmerModel(
      id: 'f_basava',
      name: 'Basavaraj S Patil',
      phone: '9988776655',
      address: 'Koppal Central',
    );
    await DataRepository.updateFarmer(farmer, oldName: 'Basavaraj Patil');

    loadedList = await LocalStorageService.loadPurchases();
    final updatedPurchase = loadedList.firstWhere((x) => x.id == 'p_installments_1');
    expect(updatedPurchase.farmerName, 'Basavaraj S Patil');
    expect(updatedPurchase.payments.length, 3);
    expect(updatedPurchase.totalAmountPaid, 10000);
    expect(updatedPurchase.isPaid, isTrue);
  });

  test('DailyAnalysisModel correctly aggregates transactions, serializes to database, and maintains date-wise history', () async {
    final today = DateTime(2026, 10, 5);
    final yesterday = DateTime(2026, 10, 4);

    // Today's business transactions:
    // 1. Purchase: 10 Q Cotton @ 2,000 = 20,000
    final pToday = PurchaseModel(
      id: 'p_today_1',
      cropName: 'Cotton',
      farmerName: 'Somanna',
      quantity: 10,
      unit: 'Quintal',
      pricePerUnit: 2000,
      dateTime: DateTime(2026, 10, 5, 10, 30),
    );
    // 2. Sale: 8 Q Cotton @ 2,500 = 20,000
    final sToday = SaleModel(
      id: 's_today_1',
      cropName: 'Cotton',
      factoryName: 'Kaveri Mills',
      quantity: 8,
      unit: 'Quintal',
      soldAmount: 20000,
      dateTime: DateTime(2026, 10, 5, 14, 0),
    );
    // 3. Expenditure: Transport = 1,500
    final eToday = ExpenditureModel(
      id: 'e_today_1',
      title: 'Truck Freight',
      category: 'Transportation',
      amount: 1500,
      dateTime: DateTime(2026, 10, 5, 16, 0),
    );

    // Yesterday's business transactions:
    // 1. Purchase: 5 Q Wheat @ 1,800 = 9,000
    final pYest = PurchaseModel(
      id: 'p_yest_1',
      cropName: 'Wheat',
      farmerName: 'Gowda',
      quantity: 5,
      unit: 'Quintal',
      pricePerUnit: 1800,
      dateTime: DateTime(2026, 10, 4, 11, 0),
    );
    // 2. Sale: 5 Q Wheat @ 2,200 = 11,000
    final sYest = SaleModel(
      id: 's_yest_1',
      cropName: 'Wheat',
      factoryName: 'Apex Foods',
      quantity: 5,
      unit: 'Quintal',
      soldAmount: 11000,
      dateTime: DateTime(2026, 10, 4, 15, 30),
    );

    await LocalStorageService.addPurchase(pToday);
    await LocalStorageService.addPurchase(pYest);
    await LocalStorageService.addSale(sToday);
    await LocalStorageService.addSale(sYest);
    await LocalStorageService.addExpenditure(eToday);

    // Fetch Today's stored daily analysis
    final DailyAnalysisModel todayAnalysis = await DataRepository.getDailyAnalysisForDate(today, syncWithBackend: false);

    expect(todayAnalysis.id, 'analysis_2026-10-05');
    expect(todayAnalysis.date.year, 2026);
    expect(todayAnalysis.date.month, 10);
    expect(todayAnalysis.date.day, 5);
    expect(todayAnalysis.totalBought, 20000);
    expect(todayAnalysis.totalSold, 20000);
    expect(todayAnalysis.totalExpenditures, 1500);
    expect(todayAnalysis.netProfit, -1500); // 20000 - 20000 - 1500 = -1500
    expect(todayAnalysis.isProfit, isFalse);
    expect(todayAnalysis.purchasesCount, 1);
    expect(todayAnalysis.salesCount, 1);
    expect(todayAnalysis.expendituresCount, 1);
    expect(todayAnalysis.cropStats['Cotton']!.qtyBought, 10);
    expect(todayAnalysis.cropStats['Cotton']!.qtySold, 8);
    expect(todayAnalysis.expenditureStats['Transportation'], 1500);

    // Fetch Yesterday's stored daily analysis
    final DailyAnalysisModel yestAnalysis = await DataRepository.getDailyAnalysisForDate(yesterday, syncWithBackend: false);

    expect(yestAnalysis.id, 'analysis_2026-10-04');
    expect(yestAnalysis.totalBought, 9000);
    expect(yestAnalysis.totalSold, 11000);
    expect(yestAnalysis.totalExpenditures, 0);
    expect(yestAnalysis.netProfit, 2000); // 11000 - 9000 = +2000
    expect(yestAnalysis.isProfit, isTrue);
    expect(yestAnalysis.purchasesCount, 1);
    expect(yestAnalysis.salesCount, 1);
    expect(yestAnalysis.cropStats['Wheat']!.qtyBought, 5);
    expect(yestAnalysis.cropStats['Wheat']!.qtySold, 5);

    // Verify both historical analyses are preserved in database and local storage
    final allHistory = await DataRepository.getAllDailyAnalyses(syncWithBackend: false);
    expect(allHistory.any((a) => a.dateString == '2026-10-05'), isTrue);
    expect(allHistory.any((a) => a.dateString == '2026-10-04'), isTrue);

    // Verify Supabase Map serialization
    final supaMap = todayAnalysis.toSupabaseMap();
    expect(supaMap['id'], 'analysis_2026-10-05');
    expect(supaMap['date'], '2026-10-05');
    expect(supaMap['total_bought'], 20000);
    expect(supaMap['total_sold'], 20000);
    expect(supaMap['total_expenditures'], 1500);
    expect(supaMap['net_profit'], -1500);
    expect(supaMap['purchases_count'], 1);
    expect(supaMap['sales_count'], 1);
    expect(supaMap['expenditures_count'], 1);
  });

  test('Daily Settlement & Deposits: Multiple deposits, purchase connection, total calculation, and settlement to 0.00', () async {
    final businessDate = DateTime(2026, 10, 5);
    final dateStr = '2026-10-05';

    // 1. Record purchases for the day (Business Activity - Requirement 6)
    final p1 = PurchaseModel(
      id: 'p_settle_1',
      cropName: 'Cotton',
      farmerName: 'Ramesh',
      quantity: 20,
      unit: 'Quintal',
      pricePerUnit: 2500, // Total = 50,000
      dateTime: DateTime(2026, 10, 5, 9, 30),
      payments: [
        PaymentEntry(
          amount: 50000,
          date: DateTime(2026, 10, 5, 9, 30),
          paymentMode: 'Cash',
        ),
      ],
    );
    final p2 = PurchaseModel(
      id: 'p_settle_2',
      cropName: 'Maize',
      farmerName: 'Suresh',
      quantity: 10,
      unit: 'Quintal',
      pricePerUnit: 1500, // Total = 15,000
      dateTime: DateTime(2026, 10, 5, 11, 15),
      payments: [
        PaymentEntry(
          amount: 15000,
          date: DateTime(2026, 10, 5, 11, 15),
          paymentMode: 'Cash',
        ),
      ],
    );
    await LocalStorageService.addPurchase(p1);
    await LocalStorageService.addPurchase(p2);

    // Initial settlement without deposits (Requirement 1, 6, 7)
    // Formula: deposit - totalPaidForPurchases - expenditure amount = 0 - 65000 - 0 = -65000
    final initialSettlement = await DataRepository.getDailySettlementForDate(businessDate, syncWithBackend: false);
    expect(initialSettlement.id, 'settle_2026-10-05');
    expect(initialSettlement.dateString, dateStr);
    expect(initialSettlement.status, 'open');
    expect(initialSettlement.totalPurchases, 65000); // 50,000 + 15,000
    expect(initialSettlement.totalPaidForPurchases, 65000);
    expect(initialSettlement.totalDeposits, 0.0);
    expect(initialSettlement.effectiveRemainingAmount, -65000);
    expect(initialSettlement.isSettled, isFalse);

    // 2. Add multiple deposits during the day (Requirements 2, 3, 4)
    final dep1 = DailyDepositEntry(
      id: 'dep_1',
      settlementId: initialSettlement.id,
      amount: 25000,
      date: businessDate,
      time: DateTime(2026, 10, 5, 10, 0),
      paymentMode: 'Cash',
      notes: 'Morning bank withdrawal',
    );
    final dep2 = DailyDepositEntry(
      id: 'dep_2',
      settlementId: initialSettlement.id,
      amount: 30000,
      date: businessDate,
      time: DateTime(2026, 10, 5, 14, 30),
      paymentMode: 'UPI / Online',
      notes: 'Partner transfer',
    );

    await DataRepository.addDailyDeposit(dep1);
    final settlementAfterDeps = await DataRepository.addDailyDeposit(dep2);

    // 3. Verify total deposits & remaining amount calculated: 55000 - 65000 = -10000
    expect(settlementAfterDeps.deposits.length, 2);
    expect(settlementAfterDeps.computedDepositsTotal, 55000); // 25,000 + 30,000
    expect(settlementAfterDeps.totalPurchases, 65000);
    expect(settlementAfterDeps.effectiveRemainingAmount, -10000); // 55,000 - 65,000
    expect(settlementAfterDeps.status, 'open');

    // 4. Complete the settlement (Requirements 8, 9)
    // Once settlement is completed, current remaining becomes 0.00
    final settled = await DataRepository.completeDailySettlement(
      settlementAfterDeps.id,
      businessDate,
      notes: 'Cash drawer balanced and audited',
      settledBy: 'MarketP',
    );

    expect(settled.status, 'settled');
    expect(settled.isSettled, isTrue);
    expect(settled.remainingAmount, 0.0); // Strictly 0.00 when settled
    expect(settled.effectiveRemainingAmount, 0.0);
    expect(settled.preSettlementRemaining, -10000); // Historical gap preserved
    expect(settled.settledBy, 'MarketP');
    expect(settled.settledAt, isNotNull);

    // 5. Verify all historical transactions remain stored permanently (Requirement 8, 9)
    final storedSettlement = await LocalStorageService.getDailySettlementForDate(dateStr);
    expect(storedSettlement, isNotNull);
    expect(storedSettlement!.isSettled, isTrue);
    expect(storedSettlement.remainingAmount, 0.0);
    expect(storedSettlement.deposits.length, 2);
    expect(storedSettlement.deposits[0].amount, 25000);
    expect(storedSettlement.deposits[1].amount, 30000);

    final storedPurchases = await LocalStorageService.loadPurchases();
    expect(storedPurchases.any((p) => p.id == 'p_settle_1'), isTrue);
    expect(storedPurchases.any((p) => p.id == 'p_settle_2'), isTrue);

    // 6. View previous days' deposits and settlements (Requirement 10)
    final pastDate = DateTime(2026, 10, 4);
    final pastPurchase = PurchaseModel(
      id: 'p_past_1',
      cropName: 'Paddy',
      farmerName: 'Somanna',
      quantity: 10,
      unit: 'Quintal',
      pricePerUnit: 2000,
      dateTime: pastDate,
      payments: [
        PaymentEntry(
          amount: 20000,
          date: pastDate,
          paymentMode: 'Cash',
        ),
      ],
    );
    await LocalStorageService.addPurchase(pastPurchase);
    final pastDep = DailyDepositEntry(
      id: 'dep_past_1',
      settlementId: 'settle_2026-10-04',
      amount: 20000,
      date: pastDate,
      time: DateTime(2026, 10, 4, 16, 0),
      notes: 'Full day cash counter',
    );
    await LocalStorageService.addDailyDeposit(pastDep);

    final pastSettlement = await DataRepository.getDailySettlementForDate(pastDate, syncWithBackend: false);
    expect(pastSettlement.id, 'settle_2026-10-04');
    expect(pastSettlement.totalPurchases, 20000);
    expect(pastSettlement.computedDepositsTotal, 20000);
    expect(pastSettlement.effectiveRemainingAmount, 0.0);

    final allHistory = await DataRepository.getAllDailySettlements(syncWithBackend: false);
    expect(allHistory.any((s) => s.dateString == '2026-10-05'), isTrue);
    expect(allHistory.any((s) => s.dateString == '2026-10-04'), isTrue);

    // 7. Verify multi-environment isolation between MarketP and MarketT
    await AuthService.login(AuthService.testUserId); // Switch to MarketT
    final testSettlements = await LocalStorageService.loadDailySettlements();
    expect(testSettlements.isEmpty, isTrue); // Clean isolation
    final testDeposits = await LocalStorageService.loadDailyDeposits();
    expect(testDeposits.isEmpty, isTrue);

    // Switch back to MarketP
    await AuthService.login(AuthService.prodUserId);
    final prodSettlements = await LocalStorageService.loadDailySettlements();
    expect(prodSettlements.any((s) => s.dateString == '2026-10-05'), isTrue);
  });

  test('Worker details saved and managed alongside farmers, including PurchaseModel worker fields', () async {
    // 1. WorkerModel CRUD
    final worker = WorkerModel(
      id: 'worker_1',
      name: 'Manjunath',
      phone: '9845112233',
      role: 'Labor',
      dailyWage: 500,
      address: 'APMC Yard Shed 4',
    );
    await DataRepository.saveWorker(worker);

    final workers = await DataRepository.getWorkers();
    expect(workers.any((w) => w.name == 'Manjunath'), isTrue);
    final savedWorker = workers.firstWhere((w) => w.name == 'Manjunath');
    expect(savedWorker.phone, '9845112233');
    expect(savedWorker.address, 'APMC Yard Shed 4');

    // Update worker
    final updatedWorker = savedWorker.copyWith(phone: '9845998877');
    await DataRepository.updateWorker(updatedWorker);
    final workersAfterUpdate = await DataRepository.getWorkers();
    expect(workersAfterUpdate.firstWhere((w) => w.id == 'worker_1').phone, '9845998877');

    // 2. PurchaseModel with worker details
    final purchaseWithWorker = PurchaseModel(
      id: 'p_with_worker',
      cropName: 'Cotton',
      farmerName: 'Basavaraj',
      farmerPhone: '9448123456',
      farmerAddress: 'Gadag',
      workerName: 'Manjunath',
      workerPhone: '9845998877',
      workerAddress: 'APMC Yard Shed 4',
      quantity: 15,
      unit: 'Quintal',
      pricePerUnit: 3000,
      dateTime: DateTime.now(),
    );

    final jsonMap = purchaseWithWorker.toJson();
    expect(jsonMap['workerName'], 'Manjunath');
    expect(jsonMap['workerPhone'], '9845998877');
    expect(jsonMap['workerAddress'], 'APMC Yard Shed 4');

    final supaMap = purchaseWithWorker.toSupabaseMap();
    expect(supaMap['worker_name'], 'Manjunath');
    expect(supaMap['worker_phone'], '9845998877');
    expect(supaMap['worker_address'], 'APMC Yard Shed 4');

    final reconstructed = PurchaseModel.fromJson(jsonMap);
    expect(reconstructed.workerName, 'Manjunath');
    expect(reconstructed.workerPhone, '9845998877');
    expect(reconstructed.workerAddress, 'APMC Yard Shed 4');

    // Delete worker
    await DataRepository.deleteWorker('worker_1');
    final workersAfterDelete = await DataRepository.getWorkers();
    expect(workersAfterDelete.any((w) => w.id == 'worker_1'), isFalse);
  });

  test('Deposit balance calculates strictly based on depositAmount - totalPaidAmount(expenditures or paid for purchases)', () async {
    final testDate = DateTime(2026, 10, 10);

    // Bill is 50,000, but only 15,000 actually paid out as advance
    final purchase = PurchaseModel(
      id: 'p_calc_test',
      cropName: 'Cotton',
      farmerName: 'Sidappa',
      quantity: 10,
      unit: 'Quintal',
      pricePerUnit: 5000, // Total 50,000
      dateTime: testDate,
      payments: [
        PaymentEntry(
          amount: 15000,
          date: testDate,
          paymentMode: 'Cash',
        ),
      ],
    );
    await LocalStorageService.addPurchase(purchase);

    // Expenditure paid
    final exp = ExpenditureModel(
      id: 'exp_calc_test',
      title: 'Packaging sacks',
      category: 'Supplies',
      amount: 3000,
      dateTime: testDate,
    );
    await LocalStorageService.addExpenditure(exp);

    // Deposit made
    final dep = DailyDepositEntry(
      id: 'dep_calc_test',
      settlementId: 'settle_2026-10-10',
      amount: 25000,
      date: testDate,
      time: testDate,
    );
    await LocalStorageService.addDailyDeposit(dep);

    final settlement = await DataRepository.getDailySettlementForDate(testDate, syncWithBackend: false);

    // Verification of new formula:
    // deposit (25000) - totalPaidAmount(paid for purchases [15000] + expenditures [3000]) = 25000 - 18000 = 7000
    expect(settlement.totalPurchases, 50000.0); // Full invoice value
    expect(settlement.totalPaidForPurchases, 15000.0); // Actually paid out
    expect(settlement.totalExpenditures, 3000.0);
    expect(settlement.totalPaidAmount, 18000.0);
    expect(settlement.totalDeposits, 25000.0);
    expect(settlement.effectiveRemainingAmount, 7000.0); // Exactly 25,000 - 18,000
  });

  test('Multi-installment payments: advance preserved, N installments with distinct dates (10m, 2 days later), pending balance tracked', () async {
    final t0 = DateTime(2026, 10, 1, 9, 0); // Day 1, 9:00 AM
    final t1 = t0.add(const Duration(minutes: 10)); // 10 minutes later
    final t2 = t0.add(const Duration(days: 2)); // 2 days later

    // Initial purchase with advance of ₹10,000 against total bill of ₹50,000
    final initialPurchase = PurchaseModel(
      id: 'p_multi_pay_1',
      cropName: 'Turmeric',
      farmerName: 'Chennappa',
      quantity: 10,
      unit: 'Quintal',
      pricePerUnit: 5000, // Total: ₹50,000
      dateTime: t0,
      payments: [
        PaymentEntry(
          amount: 10000,
          date: t0,
          paymentMode: 'Cash',
          notes: 'Advance at time of loading',
        ),
      ],
    );
    await LocalStorageService.addPurchase(initialPurchase);

    // Verify initial state
    expect(initialPurchase.totalAmount, 50000.0);
    expect(initialPurchase.totalAmountPaid, 10000.0);
    expect(initialPurchase.remainingBalance, 40000.0);
    expect(initialPurchase.balanceDue, 40000.0);
    expect(initialPurchase.isPaid, isFalse);
    expect(initialPurchase.isPending, isTrue);
    expect(initialPurchase.payments.length, 1);

    // Installment 2: 10 minutes later, pay ₹15,000 via UPI
    final pay2 = PaymentEntry(
      amount: 15000,
      date: t1,
      paymentMode: 'UPI',
      notes: 'Second payment 10 min later',
    );
    final success2 = await DataRepository.addPaymentToPurchase(initialPurchase.id, pay2);
    expect(success2, isTrue);

    final purchasesAfterPay2 = await LocalStorageService.loadPurchases();
    final pAfterPay2 = purchasesAfterPay2.firstWhere((p) => p.id == initialPurchase.id);

    expect(pAfterPay2.payments.length, 2);
    expect(pAfterPay2.payments[0].amount, 10000.0);
    expect(pAfterPay2.payments[0].date, t0);
    expect(pAfterPay2.payments[1].amount, 15000.0);
    expect(pAfterPay2.payments[1].date, t1);
    expect(pAfterPay2.totalAmountPaid, 25000.0);
    expect(pAfterPay2.remainingBalance, 25000.0);
    expect(pAfterPay2.isPending, isTrue);

    // Installment 3: 2 days later, pay remaining ₹25,000 via Bank Transfer
    final pay3 = PaymentEntry(
      amount: 25000,
      date: t2,
      paymentMode: 'Bank Transfer',
      notes: 'Final settlement after 2 days',
    );
    final success3 = await DataRepository.addPaymentToPurchase(initialPurchase.id, pay3);
    expect(success3, isTrue);

    final purchasesAfterPay3 = await LocalStorageService.loadPurchases();
    final pAfterPay3 = purchasesAfterPay3.firstWhere((p) => p.id == initialPurchase.id);

    // Verify full settlement
    expect(pAfterPay3.payments.length, 3);
    expect(pAfterPay3.payments[0].amount, 10000.0);
    expect(pAfterPay3.payments[0].date, t0);
    expect(pAfterPay3.payments[1].amount, 15000.0);
    expect(pAfterPay3.payments[1].date, t1);
    expect(pAfterPay3.payments[2].amount, 25000.0);
    expect(pAfterPay3.payments[2].date, t2);
    expect(pAfterPay3.totalAmountPaid, 50000.0);
    expect(pAfterPay3.remainingBalance, 0.0);
    expect(pAfterPay3.balanceDue, 0.0);
    expect(pAfterPay3.isPaid, isTrue);
    expect(pAfterPay3.isPending, isFalse);
  });
}


