import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/daily_analysis_model.dart';
import '../models/expenditure_model.dart';
import '../models/purchase_model.dart';
import '../models/sale_model.dart';
import '../models/daily_settlement_model.dart';
import 'daily_settlement_screen.dart';
import 'daily_analysis_detail_screen.dart';
import '../services/data_repository.dart';
import '../services/local_storage_service.dart';
import '../utils/date_utils.dart';

/// Available view modes for the Analysis section.
enum AnalysisViewMode {
  today,
  yesterday,
  customDate,
  allTime,
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _loading = true;
  AnalysisViewMode _viewMode = AnalysisViewMode.today;
  DateTime _selectedDate = DateTime.now();

  DailyAnalysisModel? _currentAnalysis;
  List<DailyAnalysisModel> _historyAnalyses = [];

  List<PurchaseModel> _activePurchases = [];
  List<SaleModel> _activeSales = [];
  List<ExpenditureModel> _activeExpenditures = [];

  List<PurchaseModel> _allPurchases = [];
  List<SaleModel> _allSales = [];
  List<ExpenditureModel> _allExpenditures = [];
  List<DailySettlementModel> _allSettlements = [];
  String _summaryFilter = 'all'; // 'all', 'today', 'yesterday', 'previous'

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    _load();
  }

  /// Loads analysis permanently from database and storage.
  /// (Requirement 1, 5: Fetch actual stored records from the database,
  /// do not calculate from temporary UI state).
  Future<void> _load({bool syncRemote = true}) async {
    // 1. Instant load from local storage cache
    final cachedPurchases = await LocalStorageService.loadPurchases();
    final cachedSales = await LocalStorageService.loadSales();
    final cachedExpenditures = await LocalStorageService.loadExpenditures();
    final cachedHistory = await LocalStorageService.loadDailyAnalyses();
    final cachedSettlements = await LocalStorageService.loadDailySettlements();

    _allSettlements = cachedSettlements;

    _updateStateWithTransactions(
      purchases: cachedPurchases,
      sales: cachedSales,
      expenditures: cachedExpenditures,
      history: cachedHistory,
    );

    if (mounted) {
      setState(() => _loading = false);
    }

    // 2. Fetch actual stored records from backend and persist snapshots
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

      // Fetch or compute & permanently save daily analysis in database
      final history = await DataRepository.getAllDailyAnalyses(
        syncWithBackend: syncRemote,
      );
      final settlements = await DataRepository.getAllDailySettlements(
        syncWithBackend: syncRemote,
      );

      if (!mounted) return;
      _allSettlements = settlements;
      _updateStateWithTransactions(
        purchases: purchases,
        sales: sales,
        expenditures: expenditures,
        history: history,
      );
      setState(() => _loading = false);
    } catch (_) {
      // Fallback gracefully on network error
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Calculates the 7 required summary metrics for any business date using real database records.
  _DailySummaryMetrics _computeDailyMetrics(DateTime date) {
    final normDate = DateTime(date.year, date.month, date.day);
    final dateStr = AppDateUtils.toIsoDate(normDate);

    // Filter purchases on this date
    final dayPurchases = _allPurchases
        .where((p) => AppDateUtils.isSameDay(p.dateTime, normDate))
        .toList();

    // 1. Total kg purchased (standardized to kilograms)
    final totalKg = dayPurchases.fold<double>(
        0.0, (sum, p) => sum + p.netQuantityKg);

    // 2. Total purchase amount
    final totalPurchaseAmount = dayPurchases.fold<double>(
        0.0, (sum, p) => sum + p.totalAmount);

    // 3. Total amount paid
    final totalAmountPaid = dayPurchases.fold<double>(
        0.0, (sum, p) => sum + p.totalAmountPaid);

    // 7. Number of purchase transactions
    final purchaseTransactionsCount = dayPurchases.length;

    // 4. Worker payments from database expenditures
    final dayExpenditures = _allExpenditures
        .where((e) => AppDateUtils.isSameDay(e.date, normDate))
        .toList();

    final workerExpenditures = dayExpenditures.where((e) {
      final cat = e.category.toLowerCase();
      final title = e.title.toLowerCase();
      return cat.contains('labor') ||
          cat.contains('wage') ||
          cat.contains('hamali') ||
          title.contains('labor') ||
          title.contains('wage') ||
          title.contains('hamali');
    }).toList();

    final workerPayments =
        workerExpenditures.fold<double>(0.0, (sum, e) => sum + e.amount);

    // 5. Total deposits & 6. Remaining amount
    DailySettlementModel? settlement;
    try {
      settlement = _allSettlements.firstWhere(
        (s) =>
            s.dateString == dateStr ||
            AppDateUtils.isSameDay(s.date, normDate),
      );
    } catch (_) {
      settlement = null;
    }

    final totalDayExpenditures =
        dayExpenditures.fold<double>(0.0, (sum, e) => sum + e.amount);

    final totalDeposits = settlement?.computedDepositsTotal ?? 0.0;
    final isSettled = settlement?.isSettled ?? false;

    final pendingFarmerBalance =
        dayPurchases.fold<double>(0.0, (sum, p) => sum + p.balanceDue);

    // Daily remaining drawer amount: deposit - (amount paid to farmers + day expenditures)
    final calculatedBalance =
        totalDeposits - (totalAmountPaid + totalDayExpenditures);
    final remainingAmount = isSettled
        ? 0.0
        : (settlement?.effectiveRemainingAmount ?? calculatedBalance);

    final preSettlementGap =
        settlement?.preSettlementRemaining ?? calculatedBalance;

    return _DailySummaryMetrics(
      date: normDate,
      totalKg: totalKg,
      totalPurchaseAmount: totalPurchaseAmount,
      totalAmountPaid: totalAmountPaid,
      pendingFarmerBalance: pendingFarmerBalance,
      workerPayments: workerPayments,
      totalDeposits: totalDeposits,
      remainingAmount: remainingAmount,
      purchaseTransactionsCount: purchaseTransactionsCount,
      isSettled: isSettled,
      preSettlementGap: preSettlementGap,
    );
  }

  /// Collects unique historical previous days (older than yesterday) from database records.
  List<DateTime> _getPreviousDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Set<String> dateStrings = {};
    for (final p in _allPurchases) {
      dateStrings.add(AppDateUtils.toIsoDate(p.dateTime));
    }
    for (final s in _allSales) {
      dateStrings.add(AppDateUtils.toIsoDate(s.dateTime));
    }
    for (final e in _allExpenditures) {
      dateStrings.add(AppDateUtils.toIsoDate(e.date));
    }
    for (final h in _historyAnalyses) {
      dateStrings.add(h.dateString);
    }
    for (final st in _allSettlements) {
      dateStrings.add(st.dateString);
    }

    final List<DateTime> list = [];
    for (final ds in dateStrings) {
      final parsed = DateTime.tryParse(ds);
      if (parsed != null) {
        final norm = DateTime(parsed.year, parsed.month, parsed.day);
        if (norm.isBefore(yesterday)) {
          if (!list.any((d) => AppDateUtils.isSameDay(d, norm))) {
            list.add(norm);
          }
        }
      }
    }

    list.sort((a, b) => b.compareTo(a)); // Descending: newest previous dates first
    return list;
  }

  void _updateStateWithTransactions({
    required List<PurchaseModel> purchases,
    required List<SaleModel> sales,
    required List<ExpenditureModel> expenditures,
    required List<DailyAnalysisModel> history,
  }) {
    _allPurchases = purchases;
    _allSales = sales;
    _allExpenditures = expenditures;
    _historyAnalyses = history;

    if (_viewMode == AnalysisViewMode.allTime) {
      _currentAnalysis = DailyAnalysisModel.cumulative(
        purchases: purchases,
        sales: sales,
        expenditures: expenditures,
      );
      _activePurchases = purchases;
      _activeSales = sales;
      _activeExpenditures = expenditures;
    } else {
      final normDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );

      _activePurchases = purchases
          .where((p) => AppDateUtils.isSameDay(p.dateTime, normDate))
          .toList();
      _activeSales = sales
          .where((s) => AppDateUtils.isSameDay(s.dateTime, normDate))
          .toList();
      _activeExpenditures = expenditures
          .where((e) => AppDateUtils.isSameDay(e.date, normDate))
          .toList();

      // Look up stored analysis record from database/cache
      final dateStr = AppDateUtils.toIsoDate(normDate);
      DailyAnalysisModel? stored;
      try {
        stored = history.firstWhere(
            (a) => a.dateString == dateStr || a.id == 'analysis_$dateStr');
      } catch (_) {
        stored = null;
      }

      _currentAnalysis = stored ??
          DailyAnalysisModel.fromTransactions(
            date: normDate,
            purchases: purchases,
            sales: sales,
            expenditures: expenditures,
            calculationTime: DateTime.now(),
          );
    }
  }

  void _selectToday() {
    setState(() {
      _selectedDate = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      _viewMode = AnalysisViewMode.today;
    });
    _load(syncRemote: false);
  }

  void _selectYesterday() {
    final yest = DateTime.now().subtract(const Duration(days: 1));
    setState(() {
      _selectedDate = DateTime(yest.year, yest.month, yest.day);
      _viewMode = AnalysisViewMode.yesterday;
    });
    _load(syncRemote: false);
  }

  void _selectAllTime() {
    setState(() {
      _viewMode = AnalysisViewMode.allTime;
    });
    _load(syncRemote: false);
  }

  void _openDailyAnalysis(DateTime date) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DailyAnalysisDetailScreen(initialDate: date),
      ),
    ).then((_) => _load());
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final date = DateTime(picked.year, picked.month, picked.day);
      setState(() {
        _selectedDate = date;
        if (AppDateUtils.isToday(_selectedDate)) {
          _viewMode = AnalysisViewMode.today;
        } else if (AppDateUtils.isYesterday(_selectedDate)) {
          _viewMode = AnalysisViewMode.yesterday;
        } else {
          _viewMode = AnalysisViewMode.customDate;
        }
      });
      _load(syncRemote: false);
      _openDailyAnalysis(date);
    }
  }

  void _changeDay(int offset) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: offset));
      if (AppDateUtils.isToday(_selectedDate)) {
        _viewMode = AnalysisViewMode.today;
      } else if (AppDateUtils.isYesterday(_selectedDate)) {
        _viewMode = AnalysisViewMode.yesterday;
      } else {
        _viewMode = AnalysisViewMode.customDate;
      }
    });
    _load(syncRemote: false);
  }

  String get _viewModeTitle {
    switch (_viewMode) {
      case AnalysisViewMode.today:
        return "Today's Analysis";
      case AnalysisViewMode.yesterday:
        return "Yesterday's Analysis";
      case AnalysisViewMode.customDate:
        return "Daily Analysis for ${AppDateUtils.formatDisplayDate(_selectedDate)}";
      case AnalysisViewMode.allTime:
        return "All-Time Cumulative Analysis";
    }
  }

  Widget _buildDateBasedSummarySection() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final previousDays = _getPreviousDays();

    final todayMetrics = _computeDailyMetrics(today);
    final yesterdayMetrics = _computeDailyMetrics(yesterday);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date-Based Daily Summaries',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap any date to open the full Daily Analysis screen',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.calendar_month,
                  color: AppColors.analytics, size: 22),
              tooltip: 'Pick Date for Daily Analysis',
              onPressed: _pickDate,
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Filter chips: All Days, Today, Yesterday, Previous Days
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChipButton(
                icon: Icons.dashboard_outlined,
                label: 'All Days',
                isSelected: _summaryFilter == 'all',
                onTap: () => setState(() => _summaryFilter = 'all'),
              ),
              const SizedBox(width: 8),
              _FilterChipButton(
                icon: Icons.today,
                label: 'Today',
                isSelected: _summaryFilter == 'today',
                onTap: () => setState(() => _summaryFilter = 'today'),
              ),
              const SizedBox(width: 8),
              _FilterChipButton(
                icon: Icons.history_toggle_off,
                label: 'Yesterday',
                isSelected: _summaryFilter == 'yesterday',
                onTap: () => setState(() => _summaryFilter = 'yesterday'),
              ),
              const SizedBox(width: 8),
              _FilterChipButton(
                icon: Icons.history,
                label: 'Previous Days (${previousDays.length})',
                isSelected: _summaryFilter == 'previous',
                onTap: () => setState(() => _summaryFilter = 'previous'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 1. TODAY SUMMARY CARD
        if (_summaryFilter == 'all' || _summaryFilter == 'today') ...[
          _DateSummaryCard(
            metrics: todayMetrics,
            tagLabel: 'TODAY',
            tagColor: AppColors.analytics,
            onTap: () => _openDailyAnalysis(today),
          ),
        ],

        // 2. YESTERDAY SUMMARY CARD
        if (_summaryFilter == 'all' || _summaryFilter == 'yesterday') ...[
          _DateSummaryCard(
            metrics: yesterdayMetrics,
            tagLabel: 'YESTERDAY',
            tagColor: Colors.orange.shade800,
            onTap: () => _openDailyAnalysis(yesterday),
          ),
        ],

        // 3. PREVIOUS DAYS
        if (_summaryFilter == 'all' || _summaryFilter == 'previous') ...[
          if (_summaryFilter == 'all' && previousDays.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.history,
                      size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Previous Days (${previousDays.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (previousDays.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.textSecondary, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'No prior previous days recorded in database.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: _pickDate,
                    child: const Text('Pick Date',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            )
          else
            ...previousDays.map((date) {
              final m = _computeDailyMetrics(date);
              return _DateSummaryCard(
                metrics: m,
                tagLabel: AppDateUtils.formatDisplayDate(date),
                tagColor: Colors.teal.shade700,
                onTap: () => _openDailyAnalysis(date),
              );
            }),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _currentAnalysis == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final analysis = _currentAnalysis ??
        DailyAnalysisModel.fromTransactions(
          date: _selectedDate,
          purchases: _allPurchases,
          sales: _allSales,
          expenditures: _allExpenditures,
        );

    final totalBought = analysis.totalBought;
    final totalSold = analysis.totalSold;
    final totalExpenditures = analysis.totalExpenditures;
    final net = analysis.netProfit;
    final isDateWise = _viewMode != AnalysisViewMode.allTime;
    final hasDayActivity = (analysis.purchasesCount +
            analysis.salesCount +
            analysis.expendituresCount) >
        0;

    return RefreshIndicator(
      onRefresh: () => _load(syncRemote: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Filter Chips: Today / Yesterday / Date Picker / All-Time (Requirement 3, 4, 8)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChipButton(
                  icon: Icons.today,
                  label: "Today",
                  isSelected: _viewMode == AnalysisViewMode.today,
                  onTap: _selectToday,
                ),
                const SizedBox(width: 8),
                _FilterChipButton(
                  icon: Icons.history_toggle_off,
                  label: "Yesterday",
                  isSelected: _viewMode == AnalysisViewMode.yesterday,
                  onTap: _selectYesterday,
                ),
                const SizedBox(width: 8),
                _FilterChipButton(
                  icon: Icons.calendar_month,
                  label: _viewMode == AnalysisViewMode.customDate
                      ? AppDateUtils.formatDisplayDate(_selectedDate)
                      : "Pick Date",
                  isSelected: _viewMode == AnalysisViewMode.customDate,
                  onTap: _pickDate,
                ),
                const SizedBox(width: 8),
                _FilterChipButton(
                  icon: Icons.bar_chart,
                  label: "All-Time",
                  isSelected: _viewMode == AnalysisViewMode.allTime,
                  onTap: _selectAllTime,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Active Date Navigation & Database Status Banner (Requirement 2, 4, 7)
          if (isDateWise)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.analytics.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.analytics.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left,
                        color: AppColors.analytics),
                    tooltip: 'Previous Day',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _changeDay(-1),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _openDailyAnalysis(_selectedDate),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.event,
                                  size: 16, color: AppColors.analytics),
                              const SizedBox(width: 6),
                              Text(
                                AppDateUtils.formatFullDate(_selectedDate),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.analytics,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.open_in_new,
                                  size: 13, color: AppColors.analytics),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.storage,
                                  size: 11, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                'Tap for Full Daily Analysis · ${AppDateUtils.formatTime(analysis.dateTime)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right,
                        color: AppColors.analytics),
                    tooltip: 'Next Day',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _changeDay(1),
                  ),
                ],
              ),
            ),

          // Button to open Full-Screen Daily Analysis Page
          if (isDateWise)
            InkWell(
              onTap: () => _openDailyAnalysis(_selectedDate),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF6A1B9A),
                      Color(0xFF8E24AA),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.analytics.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insights, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Open Full Daily Analysis Report',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Complete breakdown for ${AppDateUtils.formatDisplayDate(_selectedDate)} (Deposits, Kg, Prices, Farmer dues, Wages)',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.white, size: 14),
                  ],
                ),
              ),
            ),

          // 3. Financial Summary Card (Requirement 8)
          _OverallCard(
            title: _viewModeTitle,
            totalBought: totalBought,
            totalSold: totalSold,
            totalExpenditures: totalExpenditures,
            net: net,
            purchasesCount: analysis.purchasesCount,
            salesCount: analysis.salesCount,
            expendituresCount: analysis.expendituresCount,
            isDateWise: isDateWise,
            recordTimestamp: analysis.dateTime,
          ),
          const SizedBox(height: 14),

          // Daily Settlement Connection Banner (Requirements 6, 8, 10)
          if (isDateWise)
            FutureBuilder<DailySettlementModel>(
              future: DataRepository.getDailySettlementForDate(_selectedDate, syncWithBackend: false),
              builder: (context, snapshot) {
                final s = snapshot.data;
                final isSettled = s?.isSettled ?? false;
                final rem = isSettled ? 0.0 : (s?.effectiveRemainingAmount ?? 0.0);
                final depTotal = s?.computedDepositsTotal ?? 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSettled ? Colors.green.shade400 : AppColors.settlement.withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isSettled ? Colors.green : AppColors.settlement)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isSettled ? Icons.verified : Icons.account_balance_wallet,
                          color: isSettled ? Colors.green : AppColors.settlement,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  isSettled ? 'Daily Settlement: Settled (₹0.00)' : 'Daily Settlement: Open',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isSettled ? Colors.green.shade800 : AppColors.settlement,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isSettled
                                  ? 'Day closed at ₹0.00 · Stored in database'
                                  : 'Remaining: ${rem < 0 ? "-" : ""}₹${rem.abs().toStringAsFixed(2)} · Deposits: ₹${depTotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSettled ? Colors.green.shade700 : AppColors.settlement,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: const Size(60, 32),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(
                                  backgroundColor: AppColors.settlement,
                                  title: const Text('Daily Settlement'),
                                ),
                                body: const DailySettlementScreen(),
                              ),
                            ),
                          ).then((_) => _load());
                        },
                        child: Text(
                          isSettled ? 'View' : 'Settle',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          // Date-Based Daily Summaries Section (Today, Yesterday, Previous Days)
          _buildDateBasedSummarySection(),
          const SizedBox(height: 18),

          // Zero-activity alert for selected date
          if (isDateWise && !hasDayActivity)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No crop purchases, sales, or expenditures recorded for ${AppDateUtils.formatDisplayDate(_selectedDate)}.',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

          // 4. Performance by Crop Section (Requirement 8)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isDateWise
                    ? "Crop Performance (${AppDateUtils.formatDisplayDate(_selectedDate)})"
                    : "Performance by Crop (All-Time)",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              if (analysis.cropStats.isNotEmpty)
                Text(
                  '${analysis.cropStats.length} crops',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (analysis.cropStats.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text('No crop transactions for this period',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            ...analysis.cropStats.entries.map((e) => _CropStatTile(
                  crop: e.key,
                  stat: e.value,
                )),

          const SizedBox(height: 20),

          // 5. Other Expenditure Breakdown Section (Requirement 8)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isDateWise
                    ? "Expenditures (${AppDateUtils.formatDisplayDate(_selectedDate)})"
                    : "Other Expenditures by Category",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              if (analysis.expenditureStats.isNotEmpty)
                Text(
                  '₹${totalExpenditures.toStringAsFixed(0)} total',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.expenditure),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (analysis.expenditureStats.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text('No expenditures recorded for this period',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            ...analysis.expenditureStats.entries.map((entry) {
              final pct = totalExpenditures > 0
                  ? (entry.value / totalExpenditures * 100)
                  : 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.expenditure,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.key,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text('${pct.toStringAsFixed(1)}% of total expenses',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Text(
                      '₹${entry.value.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.expenditure,
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 20),

          // 6. Day's Detailed Activity Log (Requirement 7)
          if (isDateWise && hasDayActivity) ...[
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: ExpansionTile(
                  leading: const Icon(Icons.receipt_long,
                      color: AppColors.analytics),
                  title: Text(
                    "Day's Business Activity (${_activePurchases.length + _activeSales.length + _activeExpenditures.length} transactions)",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    "${_activePurchases.length} buys · ${_activeSales.length} sales · ${_activeExpenditures.length} expenses",
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  children: [
                    const Divider(height: 1),
                    if (_activePurchases.isNotEmpty) ...[
                      const Padding(
                        padding:
                            EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('CROP PURCHASES (BUYS)',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.buy)),
                        ),
                      ),
                      ..._activePurchases.map((p) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.arrow_downward,
                                size: 16, color: AppColors.buy),
                            title: Text('${p.cropName} from ${p.farmerName}'),
                            subtitle: Text(
                                '${p.quantity} ${p.unit} @ ₹${p.pricePerUnit}/${p.unit} · ${AppDateUtils.formatTime(p.dateTime)}'),
                            trailing: Text(
                              '₹${p.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.buy),
                            ),
                          )),
                    ],
                    if (_activeSales.isNotEmpty) ...[
                      const Padding(
                        padding:
                            EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('CROP SALES',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.sell)),
                        ),
                      ),
                      ..._activeSales.map((s) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.arrow_upward,
                                size: 16, color: AppColors.sell),
                            title: Text('${s.cropName} to ${s.factoryName}'),
                            subtitle: Text(
                                '${s.quantity} ${s.unit} @ ₹${s.pricePerUnit}/${s.unit} · ${AppDateUtils.formatTime(s.dateTime)}'),
                            trailing: Text(
                              '₹${s.soldAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.sell),
                            ),
                          )),
                    ],
                    if (_activeExpenditures.isNotEmpty) ...[
                      const Padding(
                        padding:
                            EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('OTHER EXPENDITURES',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.expenditure)),
                        ),
                      ),
                      ..._activeExpenditures.map((e) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.payment,
                                size: 16, color: AppColors.expenditure),
                            title: Text(e.title),
                            subtitle: Text(
                                '${e.category} · ${e.paymentMode} · ${AppDateUtils.formatTime(e.date)}'),
                            trailing: Text(
                              '₹${e.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.expenditure),
                            ),
                          )),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 7. Historical Business Days Explorer (Requirements 3, 6)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: ExpansionTile(
                initiallyExpanded: false,
                leading: const Icon(Icons.history, color: AppColors.analytics),
                title: const Text(
                  'Historical Days in Database',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  '${_historyAnalyses.length} daily snapshots permanently preserved',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
                children: [
                  const Divider(height: 1),
                  if (_historyAnalyses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No historical days recorded yet',
                          style: TextStyle(color: AppColors.textSecondary)),
                    )
                  else
                    ..._historyAnalyses.map((item) {
                      final isSelected = isDateWise &&
                          AppDateUtils.isSameDay(item.date, _selectedDate);
                      final isProf = item.netProfit >= 0;

                      return Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.analytics.withValues(alpha: 0.08)
                              : Colors.transparent,
                          border: Border(
                            bottom: BorderSide(
                                color: AppColors.divider.withValues(alpha: 0.5)),
                          ),
                        ),
                        child: ListTile(
                          onTap: () {
                            setState(() {
                              _selectedDate = item.date;
                              if (AppDateUtils.isToday(_selectedDate)) {
                                _viewMode = AnalysisViewMode.today;
                              } else if (AppDateUtils.isYesterday(_selectedDate)) {
                                _viewMode = AnalysisViewMode.yesterday;
                              } else {
                                _viewMode = AnalysisViewMode.customDate;
                              }
                            });
                            _load(syncRemote: false);
                            _openDailyAnalysis(item.date);
                          },
                          leading: CircleAvatar(
                            backgroundColor: isProf
                                ? Colors.green.withValues(alpha: 0.15)
                                : Colors.red.withValues(alpha: 0.15),
                            child: Icon(
                              isProf ? Icons.trending_up : Icons.trending_down,
                              color: isProf ? AppColors.profit : AppColors.loss,
                              size: 18,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                AppDateUtils.formatDisplayDate(item.date),
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? AppColors.analytics
                                      : AppColors.textPrimary,
                                ),
                              ),
                              if (AppDateUtils.isToday(item.date)) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('TODAY',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue)),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            'Buys: ₹${item.totalBought.toStringAsFixed(0)} · Sales: ₹${item.totalSold.toStringAsFixed(0)} · Exp: ₹${item.totalExpenditures.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isProf ? '+' : '-'}₹${item.netProfit.abs().toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isProf
                                      ? AppColors.profit
                                      : AppColors.loss,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isSelected ? 'Active ✓' : 'View',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? AppColors.analytics
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

/// Filter chip button for view mode selection.
class _FilterChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.analytics : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.analytics : AppColors.divider,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.analytics.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Comprehensive Financial Summary Card.
class _OverallCard extends StatelessWidget {
  final String title;
  final double totalBought;
  final double totalSold;
  final double totalExpenditures;
  final double net;
  final int purchasesCount;
  final int salesCount;
  final int expendituresCount;
  final bool isDateWise;
  final DateTime recordTimestamp;

  const _OverallCard({
    required this.title,
    required this.totalBought,
    required this.totalSold,
    required this.totalExpenditures,
    required this.net,
    this.purchasesCount = 0,
    this.salesCount = 0,
    this.expendituresCount = 0,
    this.isDateWise = false,
    required this.recordTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    final isProfit = net >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isProfit
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isProfit
                        ? Colors.green.withValues(alpha: 0.4)
                        : Colors.red.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  isProfit ? 'PROFIT' : 'LOSS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isProfit ? AppColors.profit : AppColors.loss,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Crop Purchases',
                  value: totalBought,
                  color: AppColors.buy,
                  badge: purchasesCount > 0 ? '$purchasesCount buys' : null,
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Crop Sales',
                  value: totalSold,
                  color: AppColors.sell,
                  badge: salesCount > 0 ? '$salesCount sales' : null,
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Expenditure',
                  value: totalExpenditures,
                  color: AppColors.expenditure,
                  badge: expendituresCount > 0 ? '$expendituresCount exp' : null,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isProfit ? 'Net Business Profit' : 'Net Business Loss',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '(Sales - Purchases - Expenses)',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Text(
                '${isProfit ? '+' : '-'}₹${net.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: isProfit ? AppColors.profit : AppColors.loss,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final String? badge;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '₹${value.toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(height: 2),
          Text(
            badge!,
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ],
    );
  }
}

class _CropStatTile extends StatelessWidget {
  final String crop;
  final dynamic stat; // supports CropAnalysisStat or _CropStat

  const _CropStatTile({required this.crop, required this.stat});

  @override
  Widget build(BuildContext context) {
    final net = stat.net;
    final isProfit = net >= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(crop, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  'Bought ${stat.qtyBought} · Sold ${stat.qtySold}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '${isProfit ? '+' : '-'}₹${net.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isProfit ? AppColors.profit : AppColors.loss,
            ),
          ),
        ],
      ),
    );
  }
}

/// Encapsulates the 7 required summary metrics for any single date.
class _DailySummaryMetrics {
  final DateTime date;
  final double totalKg;
  final double totalPurchaseAmount;
  final double totalAmountPaid;
  final double pendingFarmerBalance;
  final double workerPayments;
  final double totalDeposits;
  final double remainingAmount;
  final int purchaseTransactionsCount;
  final bool isSettled;
  final double preSettlementGap;

  const _DailySummaryMetrics({
    required this.date,
    required this.totalKg,
    required this.totalPurchaseAmount,
    required this.totalAmountPaid,
    required this.pendingFarmerBalance,
    required this.workerPayments,
    required this.totalDeposits,
    required this.remainingAmount,
    required this.purchaseTransactionsCount,
    required this.isSettled,
    required this.preSettlementGap,
  });
}

/// Mobile-friendly Date Summary Card displaying all 7 required items:
/// 1. Total kg purchased
/// 2. Total purchase amount
/// 3. Total amount paid
/// 4. Worker payments
/// 5. Total deposits
/// 6. Remaining amount
/// 7. Number of purchase transactions
/// Tapping opens the full Daily Analysis screen.
class _DateSummaryCard extends StatelessWidget {
  final _DailySummaryMetrics metrics;
  final VoidCallback onTap;
  final String? tagLabel;
  final Color? tagColor;

  const _DateSummaryCard({
    required this.metrics,
    required this.onTap,
    this.tagLabel,
    this.tagColor,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = AppDateUtils.isToday(metrics.date);
    final isYesterday = AppDateUtils.isYesterday(metrics.date);
    final effectiveTag = tagLabel ??
        (isToday
            ? 'TODAY'
            : (isYesterday ? 'YESTERDAY' : 'PREVIOUS'));
    final effectiveColor = tagColor ??
        (isToday
            ? AppColors.analytics
            : (isYesterday ? Colors.orange.shade800 : Colors.teal.shade700));

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isToday
              ? AppColors.analytics.withValues(alpha: 0.4)
              : AppColors.divider,
          width: isToday ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Date, Tag, Settlement status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: effectiveColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: effectiveColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      effectiveTag,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: effectiveColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppDateUtils.formatDisplayDate(metrics.date),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (metrics.isSettled)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              size: 11, color: Colors.green),
                          SizedBox(width: 3),
                          Text(
                            'Settled',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'Open',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // The 7 Required Items in Mobile-Friendly 2-Column Layout
              // Row 1: Total kg purchased & Total purchase amount
              Row(
                children: [
                  Expanded(
                    child: _DailySummaryItem(
                      icon: Icons.scale,
                      label: 'Total Kg Purchased',
                      value: '${metrics.totalKg.toStringAsFixed(1)} kg',
                      color: AppColors.analytics,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DailySummaryItem(
                      icon: Icons.shopping_bag,
                      label: 'Total Purchase Amount',
                      value: '₹${metrics.totalPurchaseAmount.toStringAsFixed(2)}',
                      color: AppColors.buy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row 2: Total amount paid & Worker payments
              Row(
                children: [
                  Expanded(
                    child: _DailySummaryItem(
                      icon: Icons.payments,
                      label: 'Total Amount Paid',
                      value: '₹${metrics.totalAmountPaid.toStringAsFixed(2)}',
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DailySummaryItem(
                      icon: Icons.engineering,
                      label: 'Worker Payments',
                      value: '₹${metrics.workerPayments.toStringAsFixed(2)}',
                      color: Colors.deepOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Pending to Pay Farmers Indicator
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: metrics.pendingFarmerBalance > 0
                      ? Colors.orange.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: metrics.pendingFarmerBalance > 0
                        ? Colors.orange.shade700.withValues(alpha: 0.3)
                        : Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          metrics.pendingFarmerBalance > 0
                              ? Icons.pending_actions
                              : Icons.check_circle_outline,
                          size: 14,
                          color: metrics.pendingFarmerBalance > 0
                              ? Colors.orange.shade900
                              : Colors.green.shade800,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          metrics.pendingFarmerBalance > 0
                              ? 'Pending to Pay Farmers:'
                              : 'Farmer Crop Dues:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: metrics.pendingFarmerBalance > 0
                                ? Colors.orange.shade900
                                : Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      metrics.pendingFarmerBalance > 0
                          ? '₹${metrics.pendingFarmerBalance.toStringAsFixed(2)} Due'
                          : 'All Paid ✓',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: metrics.pendingFarmerBalance > 0
                            ? Colors.orange.shade900
                            : Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),

              // Row 3: Total deposits & Remaining amount
              Row(
                children: [
                  Expanded(
                    child: _DailySummaryItem(
                      icon: Icons.account_balance_wallet,
                      label: 'Total Deposits',
                      value: '₹${metrics.totalDeposits.toStringAsFixed(2)}',
                      color: AppColors.settlement,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DailySummaryItem(
                      icon: Icons.account_balance,
                      label: 'Remaining Amount',
                      value: metrics.isSettled
                          ? '₹0.00'
                          : (metrics.remainingAmount < 0
                              ? '-₹${metrics.remainingAmount.abs().toStringAsFixed(2)}'
                              : '₹${metrics.remainingAmount.toStringAsFixed(2)}'),
                      color: metrics.isSettled
                          ? Colors.green.shade700
                          : (metrics.remainingAmount < 0
                              ? Colors.red.shade700
                              : (metrics.remainingAmount > 0
                                  ? Colors.teal.shade700
                                  : Colors.grey.shade700)),
                      extraNote: metrics.isSettled
                          ? 'Settled (₹0.00)'
                          : 'Dep - (Paid + Exp)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row 4: Purchase Transactions count & Tap prompt
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.analytics.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long,
                            size: 14, color: AppColors.analytics),
                        const SizedBox(width: 6),
                        Text(
                          '${metrics.purchaseTransactionsCount} purchase transaction${metrics.purchaseTransactionsCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'View Full Daily Analysis',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.analytics,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.arrow_forward_ios,
                            size: 10, color: AppColors.analytics),
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

class _DailySummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? extraNote;

  const _DailySummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.extraNote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (extraNote != null)
            Text(
              extraNote!,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}

