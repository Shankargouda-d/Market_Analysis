import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/daily_settlement_model.dart';
import '../models/expenditure_model.dart';
import '../models/factory_model.dart';
import '../models/farmer_model.dart';
import '../models/purchase_model.dart';
import '../models/sale_model.dart';
import '../services/auth_service.dart';
import '../services/data_repository.dart';
import '../services/local_storage_service.dart';
import '../utils/date_utils.dart';
import 'analytics_screen.dart';
import 'buy_screen.dart';
import 'daily_analysis_detail_screen.dart';
import 'daily_settlement_screen.dart';
import 'expenditure_screen.dart';
import 'factory_details_screen.dart';
import 'farmer_details_screen.dart';
import 'login_screen.dart';
import 'sell_screen.dart';

/// The central Home Screen of Market Analysis.
/// Features:
/// 1. Top Bar with Environment identifier, Google Sheets export, Clear Data, and Logout.
/// 2. Front Screen Hero: Date-wise Daily Analysis based on deposits (Deposits Infused,
///    Total Purchases, Daily Remaining Balance, Net Kg, and Worker Payments).
/// 3. Front Screen Deposit Action: Direct "+ Add Deposit" option to record float/cash immediately.
/// 4. Business Operations Grid: Sell, Buy, Analysis, Expenditure, Settlement, Farmers,
///    Factories, Workers - each navigating full-screen with native back navigation.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = true;

  List<PurchaseModel> _allPurchases = [];
  List<SaleModel> _allSales = [];
  List<ExpenditureModel> _allExpenditures = [];
  DailySettlementModel? _todaySettlement;
  List<DailyDepositEntry> _todayDeposits = [];
  List<FarmerModel> _allFarmers = [];
  List<FactoryModel> _allFactories = [];

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  /// Loads real database records from local cache and remote repository.
  Future<void> _loadHomeData({bool syncRemote = true}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateStr = AppDateUtils.toIsoDate(today);

    // 1. Instant load from local cache
    final cachedPurchases = await LocalStorageService.loadPurchases();
    final cachedSales = await LocalStorageService.loadSales();
    final cachedExpenditures = await LocalStorageService.loadExpenditures();
    final cachedSettlement =
        await LocalStorageService.getDailySettlementForDate(dateStr);
    final cachedDeposits =
        await LocalStorageService.loadDailyDepositsForDate(dateStr);
    final cachedFarmers = await LocalStorageService.loadFarmers();
    final cachedFactories = await LocalStorageService.loadFactories();

    if (mounted) {
      setState(() {
        _allPurchases = cachedPurchases;
        _allSales = cachedSales;
        _allExpenditures = cachedExpenditures;
        _todaySettlement = cachedSettlement;
        _todayDeposits = cachedDeposits;
        _allFarmers = cachedFarmers;
        _allFactories = cachedFactories;
        _loading = false;
      });
    }

    // 2. Fresh background sync with remote database
    try {
      final purchases = await DataRepository.getPurchases(
        syncWithBackend: syncRemote,
      );
      final sales = await DataRepository.getSales(
        syncWithBackend: syncRemote,
      );
      final expenditures = await DataRepository.getExpenditures(
        syncWithBackend: syncRemote,
      );
      final settlement = await DataRepository.getDailySettlementForDate(
        today,
        syncWithBackend: syncRemote,
      );
      final deposits =
          await LocalStorageService.loadDailyDepositsForDate(dateStr);
      final farmers = await DataRepository.getFarmers();
      final factories = await DataRepository.getFactories();

      if (!mounted) return;
      setState(() {
        _allPurchases = purchases;
        _allSales = sales;
        _allExpenditures = expenditures;
        _todaySettlement = settlement;
        _todayDeposits = deposits;
        _allFarmers = farmers;
        _allFactories = factories;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Navigates to any destination screen in full screen mode.
  void _openFullScreen(String title, Color color, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            backgroundColor: color,
            foregroundColor: Colors.white,
            leading: const BackButton(color: Colors.white),
          ),
          body: screen,
        ),
      ),
    ).then((_) => _loadHomeData());
  }

  /// Direct Front Screen Deposit Dialog: Allows user to infuse capital / counter float
  /// immediately from the Home Screen and updates daily analysis on the fly.
  void _showAddDepositDialog() {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController(text: 'Front Screen Deposit');
    String paymentMode = 'Cash';
    final depositDate = DateTime.now();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.settlement.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add_card,
                            color: AppColors.settlement, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Daily Deposit',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Record cash or bank float for today',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Amount Input
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.settlement,
                ),
                decoration: InputDecoration(
                  labelText: 'Deposit Amount (₹) *',
                  hintText: 'e.g. 50000',
                  prefixIcon: const Icon(Icons.currency_rupee,
                      color: AppColors.settlement),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.settlement.withValues(alpha: 0.04),
                ),
              ),
              const SizedBox(height: 14),

              // Payment Mode Selection
              DropdownButtonFormField<String>(
                initialValue: paymentMode,
                decoration: InputDecoration(
                  labelText: 'Payment Mode',
                  prefixIcon: const Icon(Icons.payment,
                      color: AppColors.settlement),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(
                      value: 'UPI / Online', child: Text('UPI / Online')),
                  DropdownMenuItem(
                      value: 'Bank Transfer / NEFT',
                      child: Text('Bank Transfer / NEFT')),
                  DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                  DropdownMenuItem(value: 'RTGS', child: Text('RTGS')),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => paymentMode = val);
                },
              ),
              const SizedBox(height: 14),

              // Notes / Reference Input
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: 'Notes / Reference',
                  hintText: 'e.g. Morning counter float, Bank withdrawal',
                  prefixIcon: const Icon(Icons.notes,
                      color: AppColors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.settlement,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    saving ? 'Saving Deposit...' : 'Confirm & Save Deposit',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          final amt =
                              double.tryParse(amountCtrl.text.trim());
                          if (amt == null || amt <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Please enter a valid positive deposit amount'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setModalState(() => saving = true);
                          final sId =
                              'settle_${AppDateUtils.toIsoDate(depositDate)}';
                          final entry = DailyDepositEntry(
                            settlementId: sId,
                            amount: amt,
                            date: depositDate,
                            time: DateTime.now(),
                            paymentMode: paymentMode,
                            notes: noteCtrl.text.trim(),
                          );

                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);

                          await DataRepository.addDailyDeposit(entry);
                          if (!mounted) return;
                          nav.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Deposit of ₹${amt.toStringAsFixed(2)} added! Daily Analysis updated.'),
                              backgroundColor: AppColors.settlement,
                            ),
                          );
                          _loadHomeData();
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout() {
    final userId = AuthService.currentUserId ?? 'User';
    final isProd = AuthService.isProduction;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded,
                color: isProd ? AppColors.primary : Colors.amber.shade800),
            const SizedBox(width: 10),
            const Text('Switch Environment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Currently active User ID: $userId',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isProd
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                AuthService.environmentName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isProd ? AppColors.primary : Colors.amber.shade900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Logging out will return you to the login screen where you can switch between MarketP (Production) and MarketT (Testing).',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AuthService.logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _confirmClearLocalStorage() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep, color: Colors.red),
            SizedBox(width: 10),
            Text('Clear Local Data',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove offline cached records from this device? Real database records remain safe in Supabase.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await LocalStorageService.clearAllData();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All local data cleared!'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              );
            },
            child: const Text('Remove All Data'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Filter today's activity from database records
    final todayPurchases = _allPurchases
        .where((p) => AppDateUtils.isSameDay(p.dateTime, today))
        .toList();
    final todaySales = _allSales
        .where((s) => AppDateUtils.isSameDay(s.dateTime, today))
        .toList();
    final todayExpenditures = _allExpenditures
        .where((e) => AppDateUtils.isSameDay(e.date, today))
        .toList();

    // Calculations based on actual records
    final totalKg = todayPurchases.fold<double>(
        0.0, (s, p) => s + p.netQuantityKg);
    final totalPurchaseAmount = todayPurchases.fold<double>(
        0.0, (s, p) => s + p.totalAmount);
    final totalAmountPaidFarmers = todayPurchases.fold<double>(
        0.0, (s, p) => s + p.totalAmountPaid);
    final totalFarmerDue = todayPurchases.fold<double>(
        0.0, (s, p) => s + p.balanceDue);

    final totalExpendituresToday = todayExpenditures.fold<double>(
        0.0, (s, e) => s + e.amount);

    final totalDeposits = _todaySettlement?.computedDepositsTotal ??
        _todayDeposits.fold<double>(0.0, (s, d) => s + d.amount);

    final isSettled = _todaySettlement?.isSettled ?? false;

    // Remaining amount for today: deposit - totalPaidAmount (paid to farmers + expenditures)
    final calculatedRemaining =
        totalDeposits - totalAmountPaidFarmers - totalExpendituresToday;
    final remainingAmount = isSettled
        ? 0.0
        : (_todaySettlement?.effectiveRemainingAmount ?? calculatedRemaining);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F5),
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0D3222), // deep forest green
                Color(0xFF134E39), // dark emerald
                Color(0xFF1E6F52), // rich agricultural emerald
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.analytics_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Market Analysis',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: 0.2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AuthService.isProduction
                        ? Icons.verified
                        : Icons.science_outlined,
                    size: 12,
                    color: AuthService.isProduction
                        ? const Color(0xFFB9F6CA)
                        : const Color(0xFFFFE082),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AuthService.currentUserId ?? 'MarketP',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AuthService.isProduction
                          ? const Color(0xFFB9F6CA)
                          : const Color(0xFFFFE082),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.add_card, color: Colors.white, size: 20),
              tooltip: 'Add Deposit',
              onPressed: _showAddDepositDialog,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.delete_sweep_outlined,
                  color: Colors.white, size: 20),
              tooltip: 'Clear All Local Data',
              onPressed: _confirmClearLocalStorage,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 2, right: 10, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded,
                  color: Colors.white, size: 20),
              tooltip: 'Switch User / Logout',
              onPressed: _confirmLogout,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadHomeData(syncRemote: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  // ========================================================
                  // 1. FRONT SCREEN HERO: DAILY ANALYSIS BASED ON DEPOSITS
                  // ========================================================
                  _FrontDailyAnalysisCard(
                    date: now,
                    totalDeposits: totalDeposits,
                    totalPurchaseAmount: totalPurchaseAmount,
                    totalExpenditures: totalExpendituresToday,
                    remainingAmount: remainingAmount,
                    totalKg: totalKg,
                    totalAmountPaidFarmers: totalAmountPaidFarmers,
                    pendingFarmerDue: totalFarmerDue,
                    purchasesCount: todayPurchases.length,
                    isSettled: isSettled,
                    onAddDepositTap: _showAddDepositDialog,
                    onViewFullAnalysisTap: () {
                      _openFullScreen(
                        'Daily Analysis Report',
                        AppColors.analytics,
                        DailyAnalysisDetailScreen(initialDate: now),
                      );
                    },
                    onSettlementTap: () {
                      _openFullScreen(
                        'Daily Settlement',
                        AppColors.settlement,
                        const DailySettlementScreen(),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // ========================================================
                  // 2. QUICK JUMP ACTIONS (Fast entry shortcuts)
                  // ========================================================
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _QuickJumpPill(
                          icon: Icons.add_shopping_cart,
                          label: '+ Buy Produce',
                          color: AppColors.buy,
                          onTap: () => _openFullScreen(
                            'Buy / Purchase Produce',
                            AppColors.buy,
                            const BuyScreen(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _QuickJumpPill(
                          icon: Icons.storefront,
                          label: '+ Sell Produce',
                          color: AppColors.sell,
                          onTap: () => _openFullScreen(
                            'Sell / Factory Dispatch',
                            AppColors.sell,
                            const SellScreen(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _QuickJumpPill(
                          icon: Icons.receipt_long,
                          label: '+ Mandi Expense',
                          color: AppColors.expenditure,
                          onTap: () => _openFullScreen(
                            'Other Expenditures',
                            AppColors.expenditure,
                            const ExpenditureScreen(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _QuickJumpPill(
                          icon: Icons.insights_rounded,
                          label: 'Analytics Reports',
                          color: AppColors.analytics,
                          onTap: () => _openFullScreen(
                            'Daily & Date Analysis',
                            AppColors.analytics,
                            const AnalyticsScreen(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ========================================================
                  // 3. BUSINESS OPERATIONS GRID (Sell, Buy, Analysis, etc.)
                  // ========================================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Business Modules',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Tap any option for full screen',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Grid of 7 options that navigate full-screen
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.30,
                    children: [
                      // 1. BUY
                      _ModuleOptionCard(
                        title: 'Buy',
                        subtitle: 'Farmer purchases & slips',
                        badgeText: '${todayPurchases.length} today',
                        icon: Icons.shopping_cart_rounded,
                        color: AppColors.buy,
                        onTap: () => _openFullScreen(
                          'Buy / Purchase Produce',
                          AppColors.buy,
                          const BuyScreen(),
                        ),
                      ),

                      // 2. SELL
                      _ModuleOptionCard(
                        title: 'Sell',
                        subtitle: 'Factory dispatch invoices',
                        badgeText: '${todaySales.length} today',
                        icon: Icons.storefront_rounded,
                        color: AppColors.sell,
                        onTap: () => _openFullScreen(
                          'Sell / Factory Dispatch',
                          AppColors.sell,
                          const SellScreen(),
                        ),
                      ),

                      // 3. ANALYTICS
                      _ModuleOptionCard(
                        title: 'Analytics',
                        subtitle: 'Daily & historical data',
                        badgeText: 'Reports',
                        icon: Icons.bar_chart_rounded,
                        color: AppColors.analytics,
                        onTap: () => _openFullScreen(
                          'Daily & Date Analysis',
                          AppColors.analytics,
                          const AnalyticsScreen(),
                        ),
                      ),

                      // 4. EXPENDITURE
                      _ModuleOptionCard(
                        title: 'Expenditure',
                        subtitle: 'Mandi operational expenses',
                        badgeText: '${todayExpenditures.length} today',
                        icon: Icons.receipt_long_rounded,
                        color: AppColors.expenditure,
                        onTap: () => _openFullScreen(
                          'Other Expenditures',
                          AppColors.expenditure,
                          const ExpenditureScreen(),
                        ),
                      ),

                      // 5. SETTLEMENT
                      _ModuleOptionCard(
                        title: 'Settlement',
                        subtitle: 'Day closing & cash float',
                        badgeText: isSettled ? 'Settled ₹0.00' : 'Open',
                        icon: Icons.account_balance_wallet_rounded,
                        color: AppColors.settlement,
                        onTap: () => _openFullScreen(
                          'Daily Settlement',
                          AppColors.settlement,
                          const DailySettlementScreen(),
                        ),
                      ),

                      // 6. FARMERS & WORKERS
                      _ModuleOptionCard(
                        title: 'Farmers & Workers',
                        subtitle: 'Ledgers & worker contacts',
                        badgeText: '${_allFarmers.length} farmers',
                        icon: Icons.people_alt_rounded,
                        color: AppColors.farmer,
                        onTap: () => _openFullScreen(
                          'Farmers & Workers',
                          AppColors.farmer,
                          const FarmerDetailsScreen(),
                        ),
                      ),

                      // 7. FACTORIES
                      _ModuleOptionCard(
                        title: 'Factories',
                        subtitle: 'Factory directory & ledgers',
                        badgeText: '${_allFactories.length} registered',
                        icon: Icons.factory_rounded,
                        color: AppColors.factory,
                        onTap: () => _openFullScreen(
                          'Factory Directory',
                          AppColors.factory,
                          const FactoryDetailsScreen(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}

/// Front Screen Hero Card for Daily Analysis based on Deposits.
class _FrontDailyAnalysisCard extends StatelessWidget {
  final DateTime date;
  final double totalDeposits;
  final double totalPurchaseAmount;
  final double totalExpenditures;
  final double remainingAmount;
  final double totalKg;
  final double totalAmountPaidFarmers;
  final double pendingFarmerDue;
  final int purchasesCount;
  final bool isSettled;
  final VoidCallback onAddDepositTap;
  final VoidCallback onViewFullAnalysisTap;
  final VoidCallback onSettlementTap;

  const _FrontDailyAnalysisCard({
    required this.date,
    required this.totalDeposits,
    required this.totalPurchaseAmount,
    required this.totalExpenditures,
    required this.remainingAmount,
    required this.totalKg,
    required this.totalAmountPaidFarmers,
    required this.pendingFarmerDue,
    required this.purchasesCount,
    required this.isSettled,
    required this.onAddDepositTap,
    required this.onViewFullAnalysisTap,
    required this.onSettlementTap,
  });

  @override
  Widget build(BuildContext context) {
    // Daily Remaining Amount (deposit - purchasedAmount - expenditure amount)
    final isNegative = !isSettled && remainingAmount < 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSettled ? Colors.green.shade300 : const Color(0xFFD6E4DC),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Date & Status Banner with soft gradient
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isSettled
                    ? [const Color(0xFFE8F5E9), const Color(0xFFF1F8E9)]
                    : [const Color(0xFFE8F4F0), const Color(0xFFF0F7F4)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Today · ${AppDateUtils.formatDisplayDate(date)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isSettled
                        ? const Color(0xFF1B5E20)
                        : const Color(0xFFE65100),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (isSettled
                                ? const Color(0xFF1B5E20)
                                : const Color(0xFFE65100))
                            .withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isSettled ? '✓ SETTLED (₹0.00)' : 'ACTIVE / OPEN',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Balance Row: Total Deposits vs Daily Remaining Balance (Rich Gradient Cards)
                Row(
                  children: [
                    // Total Deposits Infused
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF0D47A1), // Deep navy blue
                              Color(0xFF1976D2), // Royal blue
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0D47A1)
                                  .withValues(alpha: 0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Expanded(
                                  child: Text(
                                    'Total Deposits',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹${totalDeposits.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Counter Float Infused',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Daily Remaining Amount Card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isSettled
                                ? [
                                    const Color(0xFF1B5E20),
                                    const Color(0xFF2E7D32)
                                  ]
                                : (isNegative
                                    ? [
                                        const Color(0xFFB71C1C),
                                        const Color(0xFFD32F2F)
                                      ]
                                    : [
                                        const Color(0xFF00695C),
                                        const Color(0xFF00897B)
                                      ]),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: (isSettled || !isNegative
                                      ? const Color(0xFF00695C)
                                      : const Color(0xFFD32F2F))
                                  .withValues(alpha: 0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isSettled
                                        ? Icons.check_circle_rounded
                                        : (isNegative
                                            ? Icons.warning_amber_rounded
                                            : Icons.savings_rounded),
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Expanded(
                                  child: Text(
                                    'Remaining Amount',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isSettled
                                  ? '₹0.00'
                                  : (remainingAmount < 0
                                      ? '-₹${remainingAmount.abs().toStringAsFixed(2)}'
                                      : '₹${remainingAmount.toStringAsFixed(2)}'),
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isSettled ? 'Settled' : 'Dep - Paid(Buy+Exp)',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Deposit and Settlement Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E6F52), Color(0xFF2E7D32)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E6F52)
                                  .withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text(
                            '+ Add Deposit',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          onPressed: onAddDepositTap,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isSettled
                            ? Colors.green.shade800
                            : AppColors.settlement,
                        side: BorderSide(
                          color: isSettled
                              ? Colors.green.shade400
                              : AppColors.settlement.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        backgroundColor:
                            (isSettled ? Colors.green : AppColors.settlement)
                                .withValues(alpha: 0.06),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        isSettled
                            ? Icons.verified_rounded
                            : Icons.calculate_outlined,
                        size: 16,
                      ),
                      label: Text(
                        isSettled ? 'Settled' : 'Settle Day',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: onSettlementTap,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const Divider(height: 1),
                const SizedBox(height: 12),

                // Today's Activity Metrics Grid (2x2 + 1 Row)
                Row(
                  children: [
                    Expanded(
                      child: _HeroMetricMini(
                        label: 'Purchases Total',
                        value: '₹${totalPurchaseAmount.toStringAsFixed(2)}',
                        icon: Icons.shopping_bag_outlined,
                        color: AppColors.buy,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HeroMetricMini(
                        label: 'Total Qty (Kg)',
                        value: '${totalKg.toStringAsFixed(1)} kg',
                        icon: Icons.scale_outlined,
                        color: AppColors.analytics,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _HeroMetricMini(
                        label: 'Paid to Farmers',
                        value: '₹${totalAmountPaidFarmers.toStringAsFixed(2)}',
                        icon: Icons.payments_outlined,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HeroMetricMini(
                        label: 'Pending to Farmers',
                        value: '₹${pendingFarmerDue.toStringAsFixed(2)}',
                        icon: Icons.pending_actions_outlined,
                        color: pendingFarmerDue > 0
                            ? Colors.orange.shade800
                            : Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _HeroMetricMini(
                        label: 'Mandi Expenses',
                        value: '₹${totalExpenditures.toStringAsFixed(2)}',
                        icon: Icons.receipt_long_outlined,
                        color: AppColors.expenditure,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HeroMetricMini(
                        label: 'Total Drawer Outflow',
                        value:
                            '₹${(totalAmountPaidFarmers + totalExpenditures).toStringAsFixed(2)}',
                        icon: Icons.arrow_outward_rounded,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Open Full Daily Analysis Navigation Strip
                InkWell(
                  onTap: onViewFullAnalysisTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.analytics.withValues(alpha: 0.08),
                          AppColors.analytics.withValues(alpha: 0.03),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.analytics.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.analytics
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.receipt_long,
                                    size: 14, color: AppColors.analytics),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$purchasesCount purchase transaction${purchasesCount == 1 ? '' : 's'} recorded today',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Full Daily Analysis',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.analytics,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios,
                                size: 11, color: AppColors.analytics),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetricMini extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _HeroMetricMini({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 12, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Quick Jump Action Pill above the main modules grid
class _QuickJumpPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickJumpPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Module Card for the Options Grid (Buy, Sell, Analysis, Expenditure, etc.)
class _ModuleOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badgeText;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModuleOptionCard({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Left vertical colored accent bar
              Positioned(
                left: 0,
                top: 14,
                bottom: 14,
                child: Container(
                  width: 3.5,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(3),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                color.withValues(alpha: 0.85),
                                color,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: Colors.white, size: 18),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: color.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: color.withValues(alpha: 0.45),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}