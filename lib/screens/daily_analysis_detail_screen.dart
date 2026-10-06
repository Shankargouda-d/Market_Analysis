import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/daily_settlement_model.dart';
import '../models/expenditure_model.dart';
import '../models/purchase_model.dart';
import '../services/data_repository.dart';
import '../services/local_storage_service.dart';
import '../utils/date_utils.dart';
import 'daily_settlement_screen.dart';

/// Full-screen Date-wise Daily Analysis page.
/// Satisfies all 10 requirements:
/// 1. Date
/// 2. Total deposit amount
/// 3. Total quantity purchased (kg)
/// 4. Total purchase amount
/// 5. Purchase price/details breakdown
/// 6. Total amount paid (to farmers)
/// 7. Total amount paid to workers
/// 8. Remaining amount for that day (handles settled ₹0.00 & pre-settlement history)
/// 9. Number of purchases/transactions
/// 10. Relevant farmers/purchases for that day
class DailyAnalysisDetailScreen extends StatefulWidget {
  final DateTime initialDate;

  const DailyAnalysisDetailScreen({
    super.key,
    required this.initialDate,
  });

  @override
  State<DailyAnalysisDetailScreen> createState() =>
      _DailyAnalysisDetailScreenState();
}

class _DailyAnalysisDetailScreenState extends State<DailyAnalysisDetailScreen> {
  late DateTime _selectedDate;
  bool _loading = true;

  List<PurchaseModel> _dayPurchases = [];
  DailySettlementModel? _daySettlement;
  List<DailyDepositEntry> _dayDeposits = [];
  List<ExpenditureModel> _dayExpenditures = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _loadData();
  }

  Future<void> _loadData({bool syncRemote = true}) async {
    setState(() => _loading = true);

    final dateStr = AppDateUtils.toIsoDate(_selectedDate);

    // 1. Instant offline load from local cache
    final cachedPurchases = await LocalStorageService.loadPurchases();
    final cachedSettlement =
        await LocalStorageService.getDailySettlementForDate(dateStr);
    final cachedDeposits =
        await LocalStorageService.loadDailyDepositsForDate(dateStr);
    final cachedExpenditures = await LocalStorageService.loadExpenditures();

    _applyLoadedData(
      allPurchases: cachedPurchases,
      settlement: cachedSettlement,
      deposits: cachedDeposits,
      allExpenditures: cachedExpenditures,
    );

    if (mounted) setState(() => _loading = false);

    // 2. Fetch fresh synced records from backend
    try {
      final purchases = await DataRepository.getPurchases(
        syncWithBackend: syncRemote,
      );
      final settlement = await DataRepository.getDailySettlementForDate(
        _selectedDate,
        syncWithBackend: syncRemote,
      );
      final deposits =
          await LocalStorageService.loadDailyDepositsForDate(dateStr);
      final expenditures = await DataRepository.getExpenditures(
        syncWithBackend: syncRemote,
      );

      if (!mounted) return;
      _applyLoadedData(
        allPurchases: purchases,
        settlement: settlement,
        deposits: deposits,
        allExpenditures: expenditures,
      );
      setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyLoadedData({
    required List<PurchaseModel> allPurchases,
    required DailySettlementModel? settlement,
    required List<DailyDepositEntry> deposits,
    required List<ExpenditureModel> allExpenditures,
  }) {
    // Filter purchases matching the selected business date
    _dayPurchases = allPurchases.where((p) {
      return AppDateUtils.isSameDay(p.dateTime, _selectedDate);
    }).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    // Deposits for this date
    _dayDeposits = deposits.where((d) {
      return AppDateUtils.isSameDay(d.date, _selectedDate);
    }).toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    _daySettlement = settlement;

    // Expenditures on this date
    _dayExpenditures = allExpenditures.where((e) {
      return AppDateUtils.isSameDay(e.dateTime, _selectedDate);
    }).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  void _changeDate(int offsetDays) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: offsetDays));
    });
    _loadData();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.analytics,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- AUTOMATIC METRIC CALCULATIONS FROM ACTUAL DATABASE RECORDS ---

    // 2. Total deposit amount
    final totalDeposits = _dayDeposits.fold<double>(0.0, (s, d) => s + d.amount);

    // 3. Total quantity purchased (kg)
    final totalQuantityKg =
        _dayPurchases.fold<double>(0.0, (s, p) => s + p.netQuantityKg);
    final totalGrossQuantityKg =
        _dayPurchases.fold<double>(0.0, (s, p) => s + p.grossQuantityKg);
    final totalSuitsKg =
        _dayPurchases.fold<double>(0.0, (s, p) => s + p.suitsKg);

    // 4. Total purchase amount
    final totalPurchaseAmount =
        _dayPurchases.fold<double>(0.0, (s, p) => s + p.totalAmount);

    // 6. Total amount paid to farmers
    final totalAmountPaidFarmers =
        _dayPurchases.fold<double>(0.0, (s, p) => s + p.totalAmountPaid);
    final totalFarmerBalanceDue =
        _dayPurchases.fold<double>(0.0, (s, p) => s + p.balanceDue);

    // 7. Total amount paid to workers / labor (Labor/Wages expenditures on that date)
    final workerExpenditures = _dayExpenditures.where((e) {
      final cat = e.category.toLowerCase();
      final title = e.title.toLowerCase();
      return cat.contains('labor') ||
          cat.contains('wage') ||
          cat.contains('hamali') ||
          title.contains('labor') ||
          title.contains('wage') ||
          title.contains('hamali');
    }).toList();

    final totalWorkerWagesPaid =
        workerExpenditures.fold<double>(0.0, (s, e) => s + e.amount);

    final totalExpendituresAmount =
        _dayExpenditures.fold<double>(0.0, (s, e) => s + e.amount);

    // 8. Remaining amount for that day: deposit - totalPaidAmount (paid to farmers + expenditures)
    final isSettled = _daySettlement?.isSettled ?? false;
    final totalPaidToday = totalAmountPaidFarmers + totalExpendituresAmount;
    final calculatedRemaining =
        totalDeposits - totalPaidToday;
    final effectiveRemainingAmount = isSettled
        ? 0.0
        : (_daySettlement?.effectiveRemainingAmount ?? calculatedRemaining);
    final preSettlementGap =
        _daySettlement?.preSettlementRemaining ?? calculatedRemaining;

    // 9. Number of purchases/transactions
    final purchasesCount = _dayPurchases.length;
    final depositsCount = _dayDeposits.length;
    final workerTransactionsCount = workerExpenditures.length;
    final totalTransactionsCount = purchasesCount + depositsCount + _dayExpenditures.length;

    // 5. Purchase price & crop details map
    final Map<String, _CropSummary> cropMap = {};
    for (final p in _dayPurchases) {
      if (!cropMap.containsKey(p.cropName)) {
        cropMap[p.cropName] = _CropSummary(cropName: p.cropName, unit: p.unit);
      }
      final item = cropMap[p.cropName]!;
      item.netQty += p.netQuantity;
      item.netQtyKg += p.netQuantityKg;
      item.suitsKg += p.suitsKg;
      item.totalAmount += p.totalAmount;
      item.count++;
      item.prices.add(p.pricePerUnit);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.analytics,
        leading: BackButton(
          color: Colors.white,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Daily Analysis Report',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.white),
            tooltip: 'Pick Date',
            onPressed: _pickDate,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () => _loadData(syncRemote: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.analytics,
        onRefresh: () => _loadData(syncRemote: true),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.analytics),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==================================================
                    // 1. DATE SELECTOR & NAVIGATION (Requirement 1)
                    // ==================================================
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left,
                                    color: AppColors.analytics),
                                tooltip: 'Previous Day',
                                onPressed: () => _changeDate(-1),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: _pickDate,
                                  child: Column(
                                    children: [
                                      Text(
                                        AppDateUtils.formatFullDate(_selectedDate),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.analytics,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        AppDateUtils.isToday(_selectedDate)
                                            ? 'Today\'s Business Activity'
                                            : (AppDateUtils.isYesterday(
                                                    _selectedDate)
                                                ? 'Yesterday\'s Business Activity'
                                                : 'Historical Daily Activity'),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right,
                                    color: AppColors.analytics),
                                tooltip: 'Next Day',
                                onPressed: () => _changeDate(1),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Wrap(
                                spacing: 8,
                                children: [
                                  _buildQuickChip(
                                    'Today',
                                    AppDateUtils.isToday(_selectedDate),
                                    () {
                                      setState(() => _selectedDate =
                                          DateTime.now());
                                      _loadData();
                                    },
                                  ),
                                  _buildQuickChip(
                                    'Yesterday',
                                    AppDateUtils.isYesterday(_selectedDate),
                                    () {
                                      setState(() => _selectedDate =
                                          DateTime.now().subtract(
                                              const Duration(days: 1)));
                                      _loadData();
                                    },
                                  ),
                                ],
                              ),
                              _buildSettlementBadge(isSettled),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ==================================================
                    // 2 - 8. SUMMARY KPI METRIC TILES
                    // ==================================================
                    // Row 1: Purchases Amount (4) & Deposits Amount (2)
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Total Purchase Amount',
                            value: '₹${totalPurchaseAmount.toStringAsFixed(2)}',
                            caption: '$purchasesCount purchases recorded',
                            color: AppColors.buy,
                            icon: Icons.shopping_bag_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Total Deposit Amount',
                            value: '₹${totalDeposits.toStringAsFixed(2)}',
                            caption: '$depositsCount deposits recorded',
                            color: AppColors.settlement,
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Row 2: Quantity in Kg (3) & Amount Paid (6)
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Total Quantity (Kg)',
                            value: '${totalQuantityKg.toStringAsFixed(1)} kg',
                            caption: totalSuitsKg > 0
                                ? 'Suits tare: ${totalSuitsKg.toStringAsFixed(1)} kg'
                                : 'Gross: ${totalGrossQuantityKg.toStringAsFixed(1)} kg',
                            color: const Color(0xFFE65100),
                            icon: Icons.scale_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Total Amount Paid',
                            value: '₹${totalAmountPaidFarmers.toStringAsFixed(2)}',
                            caption: totalFarmerBalanceDue > 0
                                ? 'Farmer Due: ₹${totalFarmerBalanceDue.toStringAsFixed(0)}'
                                : 'All Farmers Paid',
                            color: Colors.green.shade800,
                            icon: Icons.payments_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Row 3: Paid to Workers (7) & Total Transactions (9)
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Paid to Workers',
                            value: '₹${totalWorkerWagesPaid.toStringAsFixed(2)}',
                            caption: workerExpenditures.isNotEmpty
                                ? '${workerExpenditures.length} wage expense entries'
                                : 'Attendance / labor wages',
                            color: AppColors.worker,
                            icon: Icons.engineering_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Transactions Count',
                            value: '$totalTransactionsCount total',
                            caption:
                                '$purchasesCount buys, $depositsCount dep, $workerTransactionsCount wages',
                            color: AppColors.analytics,
                            icon: Icons.receipt_long_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ==================================================
                    // 8. REMAINING AMOUNT CARD (Requirement 8)
                    // ==================================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isSettled
                              ? [
                                  const Color(0xFF1B5E20),
                                  const Color(0xFF2E7D32),
                                ]
                              : (effectiveRemainingAmount < 0
                                  ? [
                                      const Color(0xFFC62828),
                                      const Color(0xFFD32F2F),
                                    ]
                                  : [
                                      const Color(0xFF00695C),
                                      const Color(0xFF00897B),
                                    ]),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: (isSettled
                                    ? Colors.green
                                    : (effectiveRemainingAmount < 0
                                        ? Colors.red
                                        : Colors.teal))
                                .withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
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
                                isSettled
                                    ? 'DAILY REMAINING AMOUNT'
                                    : (effectiveRemainingAmount < 0
                                        ? 'REMAINING DEFICIT BALANCE'
                                        : 'DAILY REMAINING AMOUNT'),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isSettled
                                      ? 'SETTLED & BALANCED'
                                      : (effectiveRemainingAmount < 0
                                          ? 'DEFICIT (SHORTAGE)'
                                          : 'SURPLUS / OPEN'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                isSettled
                                    ? '₹0.00'
                                    : (effectiveRemainingAmount < 0
                                        ? '-₹${effectiveRemainingAmount.abs().toStringAsFixed(2)}'
                                        : '₹${effectiveRemainingAmount.toStringAsFixed(2)}'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (isSettled && preSettlementGap != 0) ...[
                                const SizedBox(width: 10),
                                Text(
                                  '(Pre-Settlement: ${preSettlementGap < 0 ? "-" : ""}₹${preSettlementGap.abs().toStringAsFixed(2)})',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Formula: Deposit (₹${totalDeposits.toStringAsFixed(0)}) - Paid to Farmers (₹${totalAmountPaidFarmers.toStringAsFixed(0)}) - Expenses (₹${totalExpendituresAmount.toStringAsFixed(0)})',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isSettled
                                ? 'Settlement completed for this date. Remaining is ₹0.00. Original transactions and audit records are permanently saved.'
                                : (effectiveRemainingAmount < 0
                                    ? 'Deficit of ₹${effectiveRemainingAmount.abs().toStringAsFixed(2)} (purchases & expenses exceed deposits).'
                                    : (effectiveRemainingAmount > 0
                                        ? 'Surplus of ₹${effectiveRemainingAmount.toStringAsFixed(2)} remaining for this business date.'
                                        : 'Deposits exactly balance purchases and expenses today.')),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ==================================================
                    // PENDING BALANCE PAYABLE TO FARMERS
                    // ==================================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: totalFarmerBalanceDue > 0
                            ? const Color(0xFFFFF8E1)
                            : const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: totalFarmerBalanceDue > 0
                              ? Colors.amber.shade800
                              : Colors.green.shade700,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: totalFarmerBalanceDue > 0
                                  ? Colors.amber.shade100
                                  : Colors.green.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              totalFarmerBalanceDue > 0
                                  ? Icons.pending_actions
                                  : Icons.check_circle,
                              color: totalFarmerBalanceDue > 0
                                  ? Colors.amber.shade900
                                  : Colors.green.shade800,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  totalFarmerBalanceDue > 0
                                      ? 'Still Pending to Pay to Farmers'
                                      : 'Farmer Payments Settled in Full',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: totalFarmerBalanceDue > 0
                                        ? Colors.amber.shade900
                                        : Colors.green.shade900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  totalFarmerBalanceDue > 0
                                      ? '${_dayPurchases.where((p) => p.isPending).length} purchase(s) with remaining balance dues'
                                      : 'All farmer crop purchases for this date are fully paid',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            totalFarmerBalanceDue > 0
                                ? '₹${totalFarmerBalanceDue.toStringAsFixed(2)}'
                                : '₹0.00',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: totalFarmerBalanceDue > 0
                                  ? Colors.amber.shade900
                                  : Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ==================================================
                    // 5. PURCHASE PRICE & CROP DETAILS BREAKDOWN (Requirement 5)
                    // ==================================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.pie_chart_outline,
                                size: 18, color: AppColors.analytics),
                            SizedBox(width: 8),
                            Text(
                              'Purchase Prices & Crop Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${cropMap.length} crops',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (cropMap.isEmpty)
                      _buildEmptyCard('No crops purchased on this date.')
                    else
                      Column(
                        children: cropMap.values.map((item) {
                          final avgPrice = item.prices.isNotEmpty
                              ? item.prices.reduce((a, b) => a + b) /
                                  item.prices.length
                              : 0.0;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.buy.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.grain,
                                      color: AppColors.buy, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.cropName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.netQty.toStringAsFixed(2)} ${item.unit} (${item.netQtyKg.toStringAsFixed(1)} kg) · ${item.count} lots',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${item.totalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.buy,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Avg: ₹${avgPrice.toStringAsFixed(0)}/${item.unit}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 20),

                    // ==================================================
                    // 10. RELEVANT FARMERS & PURCHASES LIST (Requirement 10)
                    // ==================================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.agriculture,
                                size: 18, color: AppColors.farmer),
                            const SizedBox(width: 8),
                            Text(
                              'Farmers & Purchases ($purchasesCount)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Paid: ₹${totalAmountPaidFarmers.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_dayPurchases.isEmpty)
                      _buildEmptyCard('No purchases recorded for ${AppDateUtils.formatDisplayDate(_selectedDate)}.')
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _dayPurchases.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final p = _dayPurchases[i];
                          return _buildFarmerPurchaseCard(p);
                        },
                      ),
                    const SizedBox(height: 20),

                    // ==================================================
                    // DEPOSITS LOG SECTION (Supports Requirement 2, 4)
                    // ==================================================
                    if (_dayDeposits.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.savings_outlined,
                                  size: 18, color: AppColors.settlement),
                              const SizedBox(width: 8),
                              Text(
                                'Deposits Added ($depositsCount)',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Total: ₹${totalDeposits.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.settlement,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _dayDeposits.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, i) {
                          final dep = _dayDeposits[i];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.south_west,
                                    size: 16, color: AppColors.settlement),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '₹${dep.amount.toStringAsFixed(2)} (${dep.paymentMode})',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppColors.settlement),
                                      ),
                                      if (dep.notes.isNotEmpty)
                                        Text(
                                          dep.notes,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  AppDateUtils.formatTime(dep.time),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Settlement quick button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.settlement,
                          side: const BorderSide(color: AppColors.settlement),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.account_balance_wallet_outlined),
                        label: Text(
                          isSettled
                              ? 'View Settlement Record (Closed)'
                              : 'Open Daily Settlement Screen',
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
                          ).then((_) => _loadData());
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildQuickChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.analytics
              : AppColors.analytics.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.analytics,
          ),
        ),
      ),
    );
  }

  Widget _buildSettlementBadge(bool isSettled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSettled
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSettled ? Colors.green.shade400 : Colors.orange.shade400,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSettled ? Icons.check_circle : Icons.timelapse,
            size: 12,
            color: isSettled ? Colors.green : Colors.orange.shade800,
          ),
          const SizedBox(width: 4),
          Text(
            isSettled ? 'Settled (₹0.00)' : 'Open',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSettled ? Colors.green : Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String caption,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerPurchaseCard(PurchaseModel p) {
    final balance = p.balanceDue;
    final isFullyPaid = balance <= 0.001;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.farmer.withValues(alpha: 0.15),
                child: Text(
                  p.farmerName.isNotEmpty
                      ? p.farmerName[0].toUpperCase()
                      : 'F',
                  style: const TextStyle(
                      color: AppColors.farmer,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.farmerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (p.farmerPhone.isNotEmpty || p.farmerAddress.isNotEmpty)
                      Text(
                        [
                          if (p.farmerPhone.isNotEmpty) p.farmerPhone,
                          if (p.farmerAddress.isNotEmpty) p.farmerAddress
                        ].join(' · '),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              Text(
                '₹${p.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.buy,
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Crop & Rate',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  Text(
                    '${p.cropName} @ ₹${p.pricePerUnit.toStringAsFixed(0)}/${p.unit}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Net Qty (Kg)',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  Text(
                    '${p.netQuantity.toStringAsFixed(2)} ${p.unit} (${p.netQuantityKg.toStringAsFixed(0)} kg)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Payment Status',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isFullyPaid
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isFullyPaid
                          ? 'Paid'
                          : 'Due: ₹${balance.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isFullyPaid ? Colors.green : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (p.suitsKg > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Suits tare deducted: ${p.suitsKg.toStringAsFixed(1)} kg',
              style: const TextStyle(
                  fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ),
    );
  }
}

class _CropSummary {
  final String cropName;
  final String unit;
  double netQty = 0.0;
  double netQtyKg = 0.0;
  double suitsKg = 0.0;
  double totalAmount = 0.0;
  int count = 0;
  List<double> prices = [];

  _CropSummary({required this.cropName, required this.unit});
}
