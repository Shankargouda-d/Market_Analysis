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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Market Analysis',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
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
                    size: 13,
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
          IconButton(
            icon: const Icon(Icons.add_card),
            tooltip: 'Add Deposit',
            onPressed: _showAddDepositDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear All Local Data',
            onPressed: _confirmClearLocalStorage,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Switch User / Logout',
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadHomeData(syncRemote: true),
              child: ListView(
                padding: const EdgeInsets.all(16),
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
                  const SizedBox(height: 20),

                  // ========================================================
                  // 2. BUSINESS OPERATIONS GRID (Sell, Buy, Analysis, etc.)
                  // ========================================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Business Modules',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Tap any option for full screen',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Grid of 8 options that navigate full-screen
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.35,
                    children: [
                      // 1. BUY
                      _ModuleOptionCard(
                        title: 'Buy',
                        subtitle: 'Farmer crop purchases & weight slips',
                        badgeText: '${todayPurchases.length} today',
                        icon: Icons.shopping_cart,
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
                        subtitle: 'Factory crop sales & dispatch invoices',
                        badgeText: '${todaySales.length} today',
                        icon: Icons.storefront,
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
                        subtitle: 'Daily & historical date-wise analysis',
                        badgeText: 'Reports',
                        icon: Icons.bar_chart,
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
                        subtitle: 'Operational & mandi expenses',
                        badgeText: '${todayExpenditures.length} today',
                        icon: Icons.receipt_long,
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
                        subtitle: 'Daily account closing & deposit float',
                        badgeText: isSettled ? 'Settled ₹0.00' : 'Open',
                        icon: Icons.account_balance_wallet,
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
                        subtitle: 'Farmer & worker contacts, ledgers',
                        badgeText: '${_allFarmers.length} farmers',
                        icon: Icons.people_alt_outlined,
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
                        subtitle: 'Factory directory & sale invoices',
                        badgeText: '${_allFactories.length} registered',
                        icon: Icons.factory,
                        color: AppColors.factory,
                        onTap: () => _openFullScreen(
                          'Factory Directory',
                          AppColors.factory,
                          const FactoryDetailsScreen(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
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
    final effectiveColor = isSettled
        ? Colors.green.shade800
        : (isNegative ? Colors.red.shade700 : const Color(0xFF2E7D32));
    final effectiveBg = isSettled
        ? Colors.green.withValues(alpha: 0.08)
        : (isNegative
            ? Colors.red.withValues(alpha: 0.08)
            : Colors.green.withValues(alpha: 0.08));
    final effectiveBorder = isSettled
        ? Colors.green.withValues(alpha: 0.25)
        : (isNegative
            ? Colors.red.withValues(alpha: 0.3)
            : Colors.green.withValues(alpha: 0.3));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSettled
              ? Colors.green.shade400
              : AppColors.analytics.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Date & Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSettled
                  ? Colors.green.withValues(alpha: 0.1)
                  : AppColors.analytics.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event,
                        size: 16, color: AppColors.analytics),
                    const SizedBox(width: 6),
                    Text(
                      'Today · ${AppDateUtils.formatDisplayDate(date)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSettled
                        ? Colors.green.shade700
                        : Colors.amber.shade800,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isSettled ? '✓ SETTLED (₹0.00)' : 'ACTIVE / OPEN',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Balance Row: Total Deposits vs Daily Remaining Balance
                Row(
                  children: [
                    // Total Deposits Infused
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.settlement.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.settlement
                                  .withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.account_balance_wallet,
                                    size: 14, color: AppColors.settlement),
                                SizedBox(width: 4),
                                Text(
                                  'Total Deposits',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${totalDeposits.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.settlement,
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: effectiveBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: effectiveBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isSettled
                                      ? Icons.check_circle
                                      : (isNegative
                                          ? Icons.warning_amber_rounded
                                          : Icons.account_balance_wallet),
                                  size: 14,
                                  color: effectiveColor,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Remaining Amount',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: effectiveColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isSettled
                                  ? '₹0.00'
                                  : (remainingAmount < 0
                                      ? '-₹${remainingAmount.abs().toStringAsFixed(2)}'
                                      : '₹${remainingAmount.toStringAsFixed(2)}'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: effectiveColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isSettled
                                  ? 'Settled'
                                  : 'Dep - Paid(Buy+Exp)',
                              style: TextStyle(
                                fontSize: 9,
                                color: effectiveColor.withValues(alpha: 0.8),
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
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.settlement,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text(
                          '+ Add Deposit',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        onPressed: onAddDepositTap,
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isSettled
                            ? Colors.green.shade700
                            : AppColors.settlement,
                        side: BorderSide(
                          color: isSettled
                              ? Colors.green.shade400
                              : AppColors.settlement,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: Icon(
                        isSettled ? Icons.verified : Icons.calculate_outlined,
                        size: 16,
                      ),
                      label: Text(
                        isSettled ? 'Settled' : 'Settle Day',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: onSettlementTap,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                const Divider(height: 1),
                const SizedBox(height: 10),

                // Today's Activity Metrics Grid
                Row(
                  children: [
                    Expanded(
                      child: _HeroMetricMini(
                        label: 'Purchases Total',
                        value: '₹${totalPurchaseAmount.toStringAsFixed(2)}',
                        icon: Icons.shopping_bag,
                        color: AppColors.buy,
                      ),
                    ),
                    Expanded(
                      child: _HeroMetricMini(
                        label: 'Total Qty (Kg)',
                        value: '${totalKg.toStringAsFixed(1)} kg',
                        icon: Icons.scale,
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
                        icon: Icons.payments,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HeroMetricMini(
                        label: 'Pending to Farmers',
                        value: '₹${pendingFarmerDue.toStringAsFixed(2)}',
                        icon: Icons.pending_actions,
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
                        icon: Icons.receipt_long,
                        color: AppColors.expenditure,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HeroMetricMini(
                        label: 'Total Drawer Outflow',
                        value:
                            '₹${(totalAmountPaidFarmers + totalExpenditures).toStringAsFixed(2)}',
                        icon: Icons.arrow_outward,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Open Full Daily Analysis Navigation Strip
                InkWell(
                  onTap: onViewFullAnalysisTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.analytics.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.receipt_long,
                                size: 15, color: AppColors.analytics),
                            const SizedBox(width: 6),
                            Text(
                              '$purchasesCount purchase transaction${purchasesCount == 1 ? '' : 's'} recorded today',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const Row(
                          children: [
                            Text(
                              'Full Daily Analysis',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.analytics,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios,
                                size: 10, color: AppColors.analytics),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.divider.withValues(alpha: 0.8)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
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
            ],
          ),
        ),
      ),
    );
  }
}
