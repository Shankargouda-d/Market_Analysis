import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/daily_settlement_model.dart';
import '../models/expenditure_model.dart';
import '../models/purchase_model.dart';
import '../services/auth_service.dart';
import '../services/data_repository.dart';
import '../services/local_storage_service.dart';
import '../utils/date_utils.dart';

class DailySettlementScreen extends StatefulWidget {
  const DailySettlementScreen({super.key});

  @override
  State<DailySettlementScreen> createState() => _DailySettlementScreenState();
}

class _DailySettlementScreenState extends State<DailySettlementScreen> {
  DateTime _selectedDate = DateTime.now();
  DailySettlementModel? _settlement;
  List<PurchaseModel> _purchases = [];
  List<ExpenditureModel> _expenditures = [];
  List<DailySettlementModel> _allSettlements = [];
  bool _loading = true;
  bool _saving = false;

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

  Future<void> _load({bool syncRemote = true}) async {
    setState(() => _loading = true);

    // 1. Instant offline load from local cache
    final dateStr = AppDateUtils.toIsoDate(_selectedDate);
    final cached = await LocalStorageService.getDailySettlementForDate(dateStr);
    final cachedPurchases = await LocalStorageService.loadPurchases();
    final cachedExpenditures = await LocalStorageService.loadExpenditures();
    final cachedSettlements = await LocalStorageService.loadDailySettlements();

    final dayPurchases = cachedPurchases.where((p) {
      return AppDateUtils.isSameDay(p.dateTime, _selectedDate);
    }).toList();
    final dayExpenditures = cachedExpenditures.where((e) {
      return AppDateUtils.isSameDay(e.date, _selectedDate);
    }).toList();

    if (mounted) {
      setState(() {
        _settlement = cached;
        _purchases = dayPurchases;
        _expenditures = dayExpenditures;
        _allSettlements = cachedSettlements;
        _loading = false;
      });
    }

    // 2. Fetch fresh synced data from repository
    try {
      final settlement = await DataRepository.getDailySettlementForDate(
        _selectedDate,
        syncWithBackend: syncRemote,
      );
      final allPurchases = await DataRepository.getPurchases(
        syncWithBackend: syncRemote,
      );
      final allExpenditures = await DataRepository.getExpenditures(
        syncWithBackend: syncRemote,
      );
      final allSettlements = await DataRepository.getAllDailySettlements(
        syncWithBackend: syncRemote,
      );

      final freshDayPurchases = allPurchases.where((p) {
        return AppDateUtils.isSameDay(p.dateTime, _selectedDate);
      }).toList();
      final freshDayExpenditures = allExpenditures.where((e) {
        return AppDateUtils.isSameDay(e.date, _selectedDate);
      }).toList();

      if (!mounted) return;
      setState(() {
        _settlement = settlement;
        _purchases = freshDayPurchases;
        _expenditures = freshDayExpenditures;
        _allSettlements = allSettlements;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setDate(DateTime d) {
    setState(() {
      _selectedDate = DateTime(d.year, d.month, d.day);
    });
    _load(syncRemote: false);
    _load(syncRemote: true);
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
            colorScheme: ColorScheme.light(
              primary: AppColors.settlement,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _setDate(picked);
    }
  }

  // ====================================================================
  // Add Deposit Modal (Requirements 2, 3, 4)
  // ====================================================================
  void _showAddDepositDialog() {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String paymentMode = 'Cash';
    TimeOfDay selectedTime = TimeOfDay.now();
    DateTime depositDate = _selectedDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                              color: AppColors.settlement, size: 24),
                        ),
                        const SizedBox(width: 12),
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
                              'Enter deposit or cash inflow during the day',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Amount Field
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Deposit Amount (₹) *',
                        hintText: 'e.g. 25000',
                        prefixIcon: const Icon(Icons.currency_rupee,
                            color: AppColors.settlement),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.settlement, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Date & Time Selectors
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: depositDate,
                                firstDate: DateTime(2020),
                                lastDate:
                                    DateTime.now().add(const Duration(days: 365)),
                              );
                              if (d != null) {
                                setModalState(() => depositDate = d);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.divider),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today,
                                      size: 18, color: AppColors.textSecondary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      AppDateUtils.formatDate(depositDate),
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final t = await showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                              );
                              if (t != null) {
                                setModalState(() => selectedTime = t);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.divider),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time,
                                      size: 18, color: AppColors.textSecondary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      selectedTime.format(context),
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Payment Mode Selector
                    const Text('Payment Mode',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        'Cash',
                        'UPI / Online',
                        'Bank Transfer',
                        'Cheque',
                      ].map((mode) {
                        final selected = paymentMode == mode;
                        return ChoiceChip(
                          label: Text(mode),
                          selected: selected,
                          selectedColor:
                              AppColors.settlement.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: selected
                                ? AppColors.settlement
                                : AppColors.textPrimary,
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setModalState(() => paymentMode = mode);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Note / Reference Field
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: 'Optional Note / Reference',
                        hintText: 'e.g. Mandi cash infusion, Ref #1094',
                        prefixIcon: const Icon(Icons.note_alt_outlined,
                            color: AppColors.textSecondary),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.settlement,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_circle_outline),
                        label: Text(_saving ? 'Saving...' : 'Add Deposit Entry'),
                        onPressed: _saving
                            ? null
                            : () async {
                                final amt =
                                    double.tryParse(amountController.text.trim());
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

                                setModalState(() => _saving = true);
                                final combinedDateTime = AppDateUtils.combine(
                                    depositDate, selectedTime);
                                final sId =
                                    'settle_${AppDateUtils.toIsoDate(depositDate)}';

                                final entry = DailyDepositEntry(
                                  settlementId: sId,
                                  amount: amt,
                                  date: depositDate,
                                  time: combinedDateTime,
                                  paymentMode: paymentMode,
                                  notes: noteController.text.trim(),
                                );

                                final messenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(ctx);

                                await DataRepository.addDailyDeposit(entry);
                                if (!mounted) return;
                                navigator.pop();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Deposit of ₹${amt.toStringAsFixed(2)} added successfully!'),
                                    backgroundColor: AppColors.settlement,
                                  ),
                                );
                                _load();
                              },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ====================================================================
  // Complete Daily Settlement Dialog (Requirements 7, 8, 9)
  // ====================================================================
  void _showCompleteSettlementDialog() {
    if (_settlement == null) return;
    final noteController = TextEditingController();
    bool addBalancingDeposit = false;
    final remainingGap = _settlement!.effectiveRemainingAmount;
    final hasDeficit = remainingGap < 0;
    final deficitAmount = remainingGap.abs();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.verified, color: AppColors.settlement, size: 26),
                  SizedBox(width: 10),
                  Text(
                    'Complete Settlement',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Closing Business Day: ${AppDateUtils.formatDisplayDate(_selectedDate)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow(
                            'Total Deposits Infused',
                            '₹${_settlement!.computedDepositsTotal.toStringAsFixed(2)}',
                            AppColors.settlement,
                          ),
                          const Divider(height: 14),
                          _buildSummaryRow(
                            'Total Purchases Today',
                            '₹${_settlement!.totalPurchases.toStringAsFixed(2)}',
                            AppColors.buy,
                          ),
                          const Divider(height: 14),
                          _buildSummaryRow(
                            'Paid to Farmers Today',
                            '₹${_settlement!.totalPaidForPurchases.toStringAsFixed(2)}',
                            Colors.teal.shade800,
                          ),
                          const Divider(height: 14),
                          _buildSummaryRow(
                            'Total Expenditures Today',
                            '₹${_settlement!.totalExpenditures.toStringAsFixed(2)}',
                            AppColors.expenditure,
                          ),
                          const Divider(height: 14),
                          _buildSummaryRow(
                            hasDeficit ? 'Deficit (Shortage)' : 'Surplus (Remaining)',
                            '${remainingGap < 0 ? '-' : ''}₹${remainingGap.abs().toStringAsFixed(2)}',
                            hasDeficit ? Colors.red.shade700 : Colors.green.shade800,
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (hasDeficit) ...[
                      CheckboxListTile(
                        value: addBalancingDeposit,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Record balancing settlement deposit (₹${deficitAmount.toStringAsFixed(2)})',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Injects exact balancing deposit to cover purchases and expenditures',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                        activeColor: AppColors.settlement,
                        onChanged: (val) {
                          setDialogState(() => addBalancingDeposit = val ?? false);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],

                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: 'Closing Note (Optional)',
                        hintText: 'e.g. Day closed & verified by manager',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined,
                              size: 18, color: Colors.green),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Once settled, current remaining becomes ₹0.00. All historical deposit transactions & purchases remain stored permanently.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.settlement,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.of(ctx).pop();
                    setState(() => _saving = true);

                    try {
                      // If user chose to add balancing deposit
                      if (addBalancingDeposit && hasDeficit) {
                        final autoEntry = DailyDepositEntry(
                          settlementId: _settlement!.id,
                          amount: deficitAmount,
                          date: _selectedDate,
                          time: DateTime.now(),
                          paymentMode: 'Cash',
                          notes: 'Balancing settlement entry',
                        );
                        await DataRepository.addDailyDeposit(autoEntry);
                      }

                      await DataRepository.completeDailySettlement(
                        _settlement!.id,
                        _selectedDate,
                        notes: noteController.text.trim(),
                        settledBy: AuthService.currentUserId ?? 'User',
                      );

                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Settlement completed successfully! Remaining balance is ₹0.00.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _load();
                    } catch (_) {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
                  child: const Text('Confirm Settlement'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ====================================================================
  // Re-open Settlement Dialog
  // ====================================================================
  void _showReopenDialog() {
    if (_settlement == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Re-open Settlement?'),
        content: const Text(
          'Re-opening will switch status back to Open and re-calculate the remaining balance from the day\'s recorded purchases and deposits.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => _saving = true);
              await DataRepository.reopenDailySettlement(
                _settlement!.id,
                _selectedDate,
              );
              _load();
            },
            child: const Text('Re-open'),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // Settlement History Sheet (Requirement 10)
  // ====================================================================
  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.settlement.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.history,
                        color: AppColors.settlement, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Settlement History',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'View previous days\' deposits and settlement states',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _allSettlements.isEmpty
                    ? const Center(
                        child: Text(
                          'No historical settlements found yet.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _allSettlements.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final item = _allSettlements[i];
                          final isCurrent =
                              AppDateUtils.isSameDay(item.date, _selectedDate);

                          return InkWell(
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _setDate(item.date);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? AppColors.settlement.withValues(alpha: 0.08)
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isCurrent
                                      ? AppColors.settlement
                                      : AppColors.divider,
                                  width: isCurrent ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        AppDateUtils.formatDisplayDate(item.date),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isCurrent
                                              ? AppColors.settlement
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (AppDateUtils.isToday(item.date))
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.buy.withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Text('Today',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.buy)),
                                        ),
                                      const Spacer(),
                                      _buildStatusBadge(item.isSettled),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text('Purchases',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors
                                                        .textSecondary)),
                                            Text(
                                              '₹${item.totalPurchases.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text('Deposits',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors
                                                        .textSecondary)),
                                            Text(
                                              '₹${item.computedDepositsTotal.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.settlement),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            const Text('Remaining',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors
                                                        .textSecondary)),
                                            Text(
                                              item.isSettled
                                                  ? '₹0.00'
                                                  : (item.effectiveRemainingAmount < 0
                                                      ? '-₹${item.effectiveRemainingAmount.abs().toStringAsFixed(2)}'
                                                      : '₹${item.effectiveRemainingAmount.toStringAsFixed(2)}'),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: item.isSettled
                                                    ? Colors.green
                                                    : (item.effectiveRemainingAmount < 0
                                                        ? Colors.red.shade700
                                                        : Colors.teal.shade700),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(bool isSettled) {
    if (isSettled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade400, width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 12, color: Colors.green),
            SizedBox(width: 4),
            Text('Settled (₹0.00)',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green)),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade400, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timelapse, size: 12, color: Colors.orange.shade800),
            const SizedBox(width: 4),
            Text('Open',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800)),
          ],
        ),
      );
    }
  }

  Widget _buildSummaryRow(String label, String value, Color color,
      {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: AppColors.textPrimary)),
        Text(
          value,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSettled = _settlement?.isSettled ?? false;
    final totalPurchases = _settlement?.totalPurchases ??
        _purchases.fold<double>(0.0, (s, p) => s + p.totalAmount);
    final totalPaidForPurchases = _settlement?.totalPaidForPurchases ??
        _purchases.fold<double>(0.0, (s, p) => s + p.totalAmountPaid);
    final totalDeposits = _settlement?.computedDepositsTotal ?? 0.0;
    final totalExpenditures = (_settlement?.totalExpenditures != null &&
            _settlement!.totalExpenditures > 0)
        ? _settlement!.totalExpenditures
        : _expenditures.fold<double>(0.0, (s, e) => s + e.amount);

    final totalPaidAmount = totalPaidForPurchases + totalExpenditures;
    final remaining = isSettled
        ? 0.0
        : (_settlement?.effectiveRemainingAmount ??
            (totalDeposits - totalPaidAmount));
    final deposits = _settlement?.deposits ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.settlement,
        onRefresh: () => _load(syncRemote: true),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.settlement),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==================================================
                    // 1. DATE SELECTOR & STATUS BAR
                    // ==================================================
                    Container(
                      padding: const EdgeInsets.all(14),
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
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.settlement
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.account_balance_wallet,
                                    color: AppColors.settlement, size: 22),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppDateUtils.formatFullDate(_selectedDate),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      isSettled
                                          ? 'Settled on ${_settlement?.settledAt != null ? AppDateUtils.formatTime(_settlement!.settledAt!) : "Today"}'
                                          : 'Daily balance currently active',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              _buildStatusBadge(isSettled),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              _buildDateQuickChip(
                                'Today',
                                AppDateUtils.isToday(_selectedDate),
                                () => _setDate(DateTime.now()),
                              ),
                              const SizedBox(width: 8),
                              _buildDateQuickChip(
                                'Yesterday',
                                AppDateUtils.isYesterday(_selectedDate),
                                () => _setDate(DateTime.now()
                                    .subtract(const Duration(days: 1))),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  side: BorderSide(
                                    color: !AppDateUtils.isToday(_selectedDate) &&
                                            !AppDateUtils.isYesterday(
                                                _selectedDate)
                                        ? AppColors.settlement
                                        : AppColors.divider,
                                  ),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.date_range, size: 16),
                                label: const Text('Pick Date',
                                    style: TextStyle(fontSize: 12)),
                                onPressed: _pickDate,
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.history,
                                    color: AppColors.settlement),
                                tooltip: 'Settlement History',
                                onPressed: _showHistorySheet,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ==================================================
                    // 2. FINANCIAL DASHBOARD CARDS
                    // ==================================================
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Deposits Infused',
                            subtitle: '${deposits.length} deposits entered',
                            amount: totalDeposits,
                            color: AppColors.settlement,
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Purchases Activity',
                            subtitle: '${_purchases.length} purchases today',
                            amount: totalPurchases,
                            color: AppColors.buy,
                            icon: Icons.shopping_bag_outlined,
                          ),
                        ),
                      ],
                    ),
                    if (totalExpenditures > 0) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Other Expenditures',
                              subtitle: '${_expenditures.length} expense entries',
                              amount: totalExpenditures,
                              color: AppColors.expenditure,
                              icon: Icons.receipt_long_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Total Outflow Paid',
                              subtitle: 'Farmers Paid + Expenses',
                              amount: totalPaidAmount,
                              color: Colors.red.shade700,
                              icon: Icons.arrow_outward,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Remaining Amount Card (Requirement 7 & 8)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isSettled
                              ? [
                                  const Color(0xFF1B5E20),
                                  const Color(0xFF2E7D32)
                                ]
                              : (remaining < 0
                                  ? [
                                      const Color(0xFFC62828),
                                      const Color(0xFFD32F2F)
                                    ]
                                  : [
                                      const Color(0xFF00695C),
                                      const Color(0xFF00897B)
                                    ]),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: (isSettled
                                    ? Colors.green
                                    : (remaining < 0
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
                              const Text(
                                'CURRENT REMAINING BALANCE',
                                style: TextStyle(
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
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isSettled ? 'CLOSED' : (remaining < 0 ? 'DEFICIT' : 'SURPLUS / OPEN'),
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
                                    : (remaining < 0
                                        ? '-₹${remaining.abs().toStringAsFixed(2)}'
                                        : '₹${remaining.toStringAsFixed(2)}'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (isSettled &&
                                  _settlement?.preSettlementRemaining != null &&
                                  _settlement!.preSettlementRemaining > 0) ...[
                                const SizedBox(width: 10),
                                Text(
                                  '(Historical: ₹${_settlement!.preSettlementRemaining.toStringAsFixed(2)})',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Formula: Deposit (₹${totalDeposits.toStringAsFixed(0)}) - Paid to Farmers (₹${totalPaidForPurchases.toStringAsFixed(0)}) - Expenses (₹${totalExpenditures.toStringAsFixed(0)})',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isSettled
                              ? 'Day closed at ₹0.00. All historical deposit transactions & purchases remain stored.'
                              : (remaining < 0
                                  ? 'Deficit of ₹${remaining.abs().toStringAsFixed(2)} (purchases & expenses exceed deposits).'
                                  : (remaining > 0
                                      ? '₹${remaining.toStringAsFixed(2)} remaining cash in hand.'
                                      : 'Deposits exactly cover purchases and expenditures today.')),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ==================================================
                    // 3. ACTION BUTTONS
                    // ==================================================
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.settlement,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.add_circle, size: 20),
                            label: const Text('+ Add Deposit',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            onPressed: _showAddDepositDialog,
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (!isSettled)
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1B5E20),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                              ),
                              icon: const Icon(Icons.check_circle, size: 20),
                              label: const Text('Complete Settlement',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              onPressed: _showCompleteSettlementDialog,
                            ),
                          )
                        else
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange.shade900,
                                side: BorderSide(color: Colors.orange.shade700),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.lock_open, size: 18),
                              label: const Text('Re-open Day',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              onPressed: _showReopenDialog,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ==================================================
                    // 4. DEPOSITS RECORDED TODAY
                    // ==================================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance,
                                size: 18, color: AppColors.settlement),
                            const SizedBox(width: 8),
                            Text(
                              'Deposits Added (${deposits.length})',
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
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.settlement,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (deposits.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.savings_outlined,
                                size: 40,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            const Text(
                              'No deposits recorded yet for this day.',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap "+ Add Deposit" above to record payments or cash infusions throughout the day.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: deposits.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final dep = deposits[i];
                          return _buildDepositCard(dep, isSettled);
                        },
                      ),
                    const SizedBox(height: 24),

                    // ==================================================
                    // 5. CONNECTED BUSINESS PURCHASES (Requirement 6)
                    // ==================================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shopping_cart,
                                size: 18, color: AppColors.buy),
                            const SizedBox(width: 8),
                            Text(
                              'Purchases Activity (${_purchases.length})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Total: ₹${totalPurchases.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.buy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_purchases.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: const Center(
                          child: Text(
                            'No crop purchases recorded on this date.',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _purchases.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final p = _purchases[i];
                          return _buildPurchaseCard(p);
                        },
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDateQuickChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.settlement
              : AppColors.settlement.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.settlement,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String subtitle,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDepositCard(DailyDepositEntry dep, bool isSettled) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              color: AppColors.settlement.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_downward,
                color: AppColors.settlement, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '₹${dep.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.settlement,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Text(
                        dep.paymentMode,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      AppDateUtils.formatTime(dep.time),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    if (dep.notes.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      const Text('•',
                          style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dep.notes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!isSettled)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 20),
              tooltip: 'Remove Deposit',
              onPressed: () => _confirmDeleteDeposit(dep),
            ),
        ],
      ),
    );
  }

  void _confirmDeleteDeposit(DailyDepositEntry dep) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Deposit?'),
        content: Text(
            'Remove deposit of ₹${dep.amount.toStringAsFixed(2)} from today\'s settlement?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await DataRepository.deleteDailyDeposit(dep.id, dep.date);
              _load();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseCard(PurchaseModel p) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.buy.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.agriculture, color: AppColors.buy, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      p.farmerName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      '₹${p.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.buy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${p.cropName} (${p.netQuantity.toStringAsFixed(2)} ${p.unit})',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                    Text(
                      'Paid: ₹${p.totalAmountPaid.toStringAsFixed(2)}  •  Bal: ₹${p.remainingBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: p.remainingBalance > 0
                            ? Colors.orange.shade800
                            : Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
