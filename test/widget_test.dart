import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:market_analysis/main.dart';
import 'package:market_analysis/models/daily_settlement_model.dart';
import 'package:market_analysis/models/purchase_model.dart';
import 'package:market_analysis/screens/analytics_screen.dart';
import 'package:market_analysis/screens/daily_analysis_detail_screen.dart';
import 'package:market_analysis/services/auth_service.dart';
import 'package:market_analysis/services/local_storage_service.dart';
import 'package:market_analysis/services/supabase_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SupabaseService.bypassForTesting = true;
    await AuthService.init();
    await dotenv.load(mergeWith: {
      'SUPABASE_URL': 'https://test.supabase.co',
      'SUPABASE_ANON_KEY': 'test_anon_key',
    });
  });

  testWidgets('Market Analysis login screen and authentication flow test',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify Login Screen appears initially
    expect(find.text('Market Analysis'), findsOneWidget);
    expect(find.text('Enter Password to Login'), findsOneWidget);
    expect(find.text('MarketP · Production System'), findsOneWidget);

    // Enter wrong password to test validation
    await tester.enterText(find.byType(TextField), 'WRONG');
    await tester.tap(find.text('Enter Market System'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect password! Enter "SBT" to access.'), findsOneWidget);

    // Enter correct password SBT
    await tester.enterText(find.byType(TextField), 'SBT');
    await tester.pumpAndSettle();

    // Tap "Enter Market System"
    await tester.tap(find.text('Enter Market System'));
    await tester.pumpAndSettle();

    // Verify navigated to HomePage
    expect(find.text('Buy'), findsWidgets);
    expect(find.text('MarketP'), findsWidgets);
  });

  testWidgets('Market Analysis app full navigation and features smoke test when logged in',
      (WidgetTester tester) async {
    // Set a tablet/desktop viewport so all 7 tabs fit comfortably
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Pre-authenticate as MarketP
    await AuthService.login(AuthService.prodUserId);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify Home Screen Hero with front-screen Daily Analysis and Deposit option
    expect(find.text('Market Analysis'), findsWidgets);
    expect(find.text('+ Add Deposit'), findsWidgets);
    expect(find.text('Total Deposits'), findsWidgets);
    expect(find.text('Remaining Amount'), findsWidgets);
    expect(find.text('Pending to Farmers'), findsWidgets);
    expect(find.text('Full Daily Analysis'), findsOneWidget);

    // Verify all 7 business modules/options are rendered below
    expect(find.text('Buy'), findsWidgets);
    expect(find.text('Sell'), findsWidgets);
    expect(find.text('Expenditure'), findsWidgets);
    expect(find.text('Analytics'), findsWidgets);
    expect(find.text('Settlement'), findsWidgets);
    expect(find.text('Farmers & Workers'), findsWidgets);
    expect(find.text('Factories'), findsWidgets);

    // Tap the Buy module card to enter full screen
    await tester.tap(find.text('Buy').first);
    await tester.pumpAndSettle();

    // Verify Buy screen displays full screen with farmer inputs and NO worker inputs
    expect(find.text('Farmer name'), findsOneWidget);
    expect(find.text('Farmer mobile no.'), findsOneWidget);
    expect(find.text('Farmer address / village'), findsOneWidget);
    expect(find.text('Worker / Labor Details (Hamali / Loader)'), findsNothing);
    expect(find.text('Worker name (Optional)'), findsNothing);
    expect(find.text('Suits / Deduction (in Kg) - Optional'), findsOneWidget);
    expect(find.text('Advance Paid Amount (\u20B9) - Optional'), findsOneWidget);
    expect(find.text('Calculated Total Price'), findsOneWidget);
    expect(find.text('Save purchase'), findsOneWidget);

    // Return to Home Screen
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Tap the Sell module card to enter full screen
    await tester.tap(find.text('Sell').first);
    await tester.pumpAndSettle();

    // Verify Sell screen displays full screen with factory inputs
    expect(find.text('Sold to (factory name)'), findsOneWidget);
    expect(find.text('Factory contact details (phone / manager)'), findsOneWidget);
    expect(find.text('Factory address / location'), findsOneWidget);
    expect(find.text('Calculated Rate per Unit'), findsOneWidget);
    expect(find.text('Save sale'), findsOneWidget);

    // Return to Home Screen
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Tap the Farmers & Workers module card to enter full screen
    await tester.ensureVisible(find.text('Farmers & Workers').first);
    await tester.tap(find.text('Farmers & Workers').first);
    await tester.pumpAndSettle();

    expect(find.text('Registered Farmers'), findsOneWidget);
    expect(find.text('Add Farmer'), findsOneWidget);

    // Return to Home Screen
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Tap the Factories module card to enter full screen
    await tester.ensureVisible(find.text('Factories').first);
    await tester.tap(find.text('Factories').first);
    await tester.pumpAndSettle();

    expect(find.text('Factory Directory'), findsWidgets);
    expect(find.text('Add Factory'), findsOneWidget);

    // Return to Home Screen
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Tap the Settlement module card to enter full screen
    await tester.ensureVisible(find.text('Settlement').first);
    await tester.tap(find.text('Settlement').first);
    await tester.pumpAndSettle();

    expect(find.text('Purchases Activity'), findsWidgets);
    expect(find.text('Deposits Infused'), findsWidgets);
    expect(find.text('CURRENT REMAINING BALANCE'), findsOneWidget);

    // Return to Home Screen
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Tap Logout icon in AppBar
    await tester.tap(find.byIcon(Icons.logout_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Log Out of System'), findsOneWidget);
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();

    // Verify returned to LoginScreen
    expect(find.text('Enter Password to Login'), findsOneWidget);
  });

  testWidgets('Daily Analysis full-screen page renders all 10 requirements and handles date selection & back button',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await AuthService.login(AuthService.prodUserId);

    final testDate = DateTime(2026, 10, 5);

    // Seed test data in local storage
    final p = PurchaseModel(
      id: 'p_test_analysis_1',
      cropName: 'Cotton',
      farmerName: 'Basavaraj',
      farmerPhone: '9845112233',
      farmerAddress: 'Dharwad',
      quantity: 20,
      suitsKg: 20,
      unit: 'Quintal',
      pricePerUnit: 3000,
      dateTime: testDate,
      payments: [
        PaymentEntry(
          amount: 25000,
          date: testDate,
          paymentMode: 'Cash',
        ),
      ],
    );
    await LocalStorageService.addPurchase(p);

    final dep = DailyDepositEntry(
      id: 'dep_test_analysis_1',
      settlementId: 'settle_2026-10-05',
      amount: 40000,
      date: testDate,
      time: testDate,
      paymentMode: 'Cash',
      notes: 'Counter float',
    );
    await LocalStorageService.addDailyDeposit(dep);

    // Pump DailyAnalysisDetailScreen
    await tester.pumpWidget(
      MaterialApp(
        home: DailyAnalysisDetailScreen(initialDate: testDate),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Date
    expect(find.text('Daily Analysis Report'), findsOneWidget);
    expect(find.textContaining('05 Oct 2026'), findsWidgets);

    // 2. Total deposit amount
    expect(find.text('Total Deposit Amount'), findsOneWidget);
    expect(find.text('₹40000.00'), findsOneWidget);

    // 3. Total quantity purchased (kg)
    expect(find.text('Total Quantity (Kg)'), findsOneWidget);
    expect(find.textContaining('1980.0 kg'), findsWidgets);

    // 4. Total purchase amount
    expect(find.text('Total Purchase Amount'), findsOneWidget);
    expect(find.text('₹59400.00'), findsWidgets);

    // 5. Purchase price/details
    expect(find.text('Purchase Prices & Crop Details'), findsOneWidget);
    expect(find.text('Cotton'), findsWidgets);

    // 6. Total amount paid
    expect(find.text('Total Amount Paid'), findsOneWidget);
    expect(find.text('₹25000.00'), findsOneWidget);

    // 7. Total amount paid to workers
    expect(find.text('Paid to Workers'), findsOneWidget);

    // 8. Remaining amount for that day: deposit - totalPaidAmount(expenditure or paid for purchased) = 40000 - 25000 = 15000
    expect(find.textContaining('REMAINING'), findsWidgets);
    expect(find.text('₹15000.00'), findsOneWidget);

    // 9. Number of purchases/transactions
    expect(find.text('Transactions Count'), findsOneWidget);

    // 10. Relevant farmers/purchases for that day
    expect(find.text('Basavaraj'), findsOneWidget);
    expect(find.textContaining('Dharwad'), findsWidgets);
    expect(find.text('₹59400.00'), findsWidgets);

    // Test Back button
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'Analysis dashboard date-based summary section displays Today, Yesterday, and Previous days with all 7 metrics and opens full Daily Analysis on tap',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await AuthService.login(AuthService.prodUserId);

    final today = DateTime.now();
    final normToday = DateTime(today.year, today.month, today.day);
    final normYest = normToday.subtract(const Duration(days: 1));

    // Seed purchases for today and yesterday
    final pToday = PurchaseModel(
      id: 'p_dash_today',
      cropName: 'Cotton',
      farmerName: 'Ramesh',
      farmerPhone: '9845012345',
      farmerAddress: 'Hubli',
      quantity: 15,
      suitsKg: 10,
      unit: 'Quintal',
      pricePerUnit: 4000,
      dateTime: normToday,
      payments: [
        PaymentEntry(
          amount: 30000,
          date: normToday,
          paymentMode: 'Cash',
        ),
      ],
    );
    await LocalStorageService.addPurchase(pToday);

    final pYest = PurchaseModel(
      id: 'p_dash_yest',
      cropName: 'Chilli',
      farmerName: 'Suresh',
      farmerPhone: '9845054321',
      farmerAddress: 'Byadgi',
      quantity: 5,
      suitsKg: 5,
      unit: 'Quintal',
      pricePerUnit: 8000,
      dateTime: normYest,
      payments: [
        PaymentEntry(
          amount: 20000,
          date: normYest,
          paymentMode: 'Online',
        ),
      ],
    );
    await LocalStorageService.addPurchase(pYest);

    // Pump AnalyticsScreen inside MaterialApp
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AnalyticsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Section Header and subtitle
    expect(find.text('Date-Based Daily Summaries'), findsOneWidget);
    expect(
        find.text('Tap any date to open the full Daily Analysis screen'),
        findsOneWidget);

    // Verify Filter Chips
    expect(find.text('All Days'), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Yesterday'), findsWidgets);
    expect(find.textContaining('Previous Days'), findsWidgets);

    // Verify 7 Metrics on the cards:
    // 1. Total Kg Purchased
    expect(find.text('Total Kg Purchased'), findsWidgets);
    // 2. Total Purchase Amount
    expect(find.text('Total Purchase Amount'), findsWidgets);
    // 3. Total Amount Paid
    expect(find.text('Total Amount Paid'), findsWidgets);
    // 4. Worker Payments
    expect(find.text('Worker Payments'), findsWidgets);
    // 5. Total Deposits
    expect(find.text('Total Deposits'), findsWidgets);
    // 6. Remaining Amount
    expect(find.text('Remaining Amount'), findsWidgets);
    // 7. Purchase Transactions
    expect(find.textContaining('purchase transaction'), findsWidgets);

    // Tap on the Today card / View Full Daily Analysis to open full Daily Analysis screen
    expect(find.text('View Full Daily Analysis'), findsWidgets);
    await tester.tap(find.text('View Full Daily Analysis').first);
    await tester.pumpAndSettle();

    // Verify navigated to Daily Analysis Detail Screen
    expect(find.text('Daily Analysis Report'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    // Tap Back button
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Returned to AnalyticsScreen
    expect(find.text('Date-Based Daily Summaries'), findsOneWidget);
  });
}
