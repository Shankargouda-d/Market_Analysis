import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:market_analysis/main.dart';
import 'package:market_analysis/services/auth_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.init();
    await dotenv.load(mergeWith: {'SHEETS_WEB_APP_URL': 'https://test.com/exec'});
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
    expect(find.text('Select Environment / User ID'), findsOneWidget);
    expect(find.text('Quick Select:'), findsOneWidget);
    expect(find.text('MarketP'), findsOneWidget);
    expect(find.text('MarketT'), findsOneWidget);

    // Tap MarketP quick select card
    await tester.tap(find.text('MarketP'));
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
    // Set a phone/tablet viewport
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Pre-authenticate as MarketP
    await AuthService.login(AuthService.prodUserId);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify all 6 navigation tabs/destinations are rendered
    expect(find.text('Buy'), findsWidgets);
    expect(find.text('Sell'), findsWidgets);
    expect(find.text('Analytics'), findsWidgets);
    expect(find.text('Farmers'), findsWidgets);
    expect(find.text('Factories'), findsWidgets);
    expect(find.text('Workers'), findsWidgets);

    // Verify Buy screen has separate farmer mobile no. and address
    expect(find.text('Farmer name'), findsOneWidget);
    expect(find.text('Farmer mobile no.'), findsOneWidget);
    expect(find.text('Farmer address / village'), findsOneWidget);
    expect(find.text('Calculated Total Price'), findsOneWidget);
    expect(find.text('Save purchase'), findsOneWidget);

    // Tap the Sell tab
    await tester.tap(find.text('Sell').first);
    await tester.pumpAndSettle();

    // Verify Sell screen has factory name, contact details, and address
    expect(find.text('Sold to (factory name)'), findsOneWidget);
    expect(find.text('Factory contact details (phone / manager)'), findsOneWidget);
    expect(find.text('Factory address / location'), findsOneWidget);
    expect(find.text('Calculated Rate per Unit'), findsOneWidget);
    expect(find.text('Save sale'), findsOneWidget);

    // Tap the Farmers tab
    await tester.tap(find.text('Farmers').first);
    await tester.pumpAndSettle();

    expect(find.text('Registered Farmers'), findsOneWidget);
    expect(find.text('Add Farmer'), findsOneWidget);

    // Tap the Factories tab
    await tester.tap(find.text('Factories').first);
    await tester.pumpAndSettle();

    expect(find.text('Factory Directory'), findsOneWidget);
    expect(find.text('Add Factory'), findsOneWidget);

    // Tap the Workers tab
    await tester.tap(find.text('Workers').first);
    await tester.pumpAndSettle();

    expect(find.text('Total Staff'), findsOneWidget);
    expect(find.text('Present Today'), findsWidgets);
    expect(find.text('Add Worker'), findsOneWidget);

    // Tap Google Sheets icon in AppBar
    await tester.tap(find.byIcon(Icons.table_chart_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Google Sheets Sync'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Tap Logout icon in AppBar
    await tester.tap(find.byIcon(Icons.logout_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Switch Environment'), findsOneWidget);
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();

    // Verify returned to LoginScreen
    expect(find.text('Select Environment / User ID'), findsOneWidget);
  });
}
