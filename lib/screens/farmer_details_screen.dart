import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../models/farmer_model.dart';
import '../models/worker_model.dart';
import '../models/purchase_model.dart';
import '../services/data_repository.dart';
import '../utils/validators.dart';
import '../widgets/date_time_picker_widget.dart';

class FarmerDetailsScreen extends StatefulWidget {
  const FarmerDetailsScreen({super.key});

  @override
  State<FarmerDetailsScreen> createState() => _FarmerDetailsScreenState();
}

class _FarmerDetailsScreenState extends State<FarmerDetailsScreen> {
  bool _loading = true;
  List<FarmerModel> _farmers = [];
  List<WorkerModel> _workers = [];
  List<PurchaseModel> _purchases = [];
  String _searchQuery = '';
  int _selectedTab = 0; // 0 = Farmers, 1 = Workers
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final purchases = await DataRepository.getPurchases();
    final farmers = await DataRepository.getFarmers();
    final workers = await DataRepository.getWorkers();
    if (!mounted) return;
    setState(() {
      _purchases = purchases;
      _farmers = farmers;
      _workers = workers;
      _loading = false;
    });
  }

  List<PurchaseModel> _getPurchasesForFarmer(String farmerName) {
    final lower = farmerName.trim().toLowerCase();
    return _purchases
        .where((p) => p.farmerName.trim().toLowerCase() == lower)
        .toList();
  }

  double _getTotalAmountForFarmer(String farmerName) {
    final list = _getPurchasesForFarmer(farmerName);
    return list.fold<double>(0, (sum, item) => sum + item.totalAmount);
  }

  double _getTotalPaidForFarmer(String farmerName) {
    final list = _getPurchasesForFarmer(farmerName);
    return list.fold<double>(0, (sum, item) => sum + item.totalAmountPaid);
  }

  double _getRemainingBalanceForFarmer(String farmerName) {
    final list = _getPurchasesForFarmer(farmerName);
    return list.fold<double>(0, (sum, item) => sum + item.remainingBalance);
  }

  /// Collects all payments made across all purchases for this farmer,
  /// sorted in chronological date order (Requirement 9).
  List<MapEntry<PurchaseModel, PaymentEntry>> _getAllPaymentsForFarmer(
      String farmerName) {
    final list = _getPurchasesForFarmer(farmerName);
    final all = <MapEntry<PurchaseModel, PaymentEntry>>[];
    for (final p in list) {
      for (final pay in p.payments) {
        all.add(MapEntry(p, pay));
      }
    }
    all.sort((a, b) => a.value.date.compareTo(b.value.date));
    return all;
  }

  void _showAddFarmerDialog([FarmerModel? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    final totalAmt = existing != null ? _getTotalAmountForFarmer(existing.name) : 0.0;
    final totalPaid = existing != null ? _getTotalPaidForFarmer(existing.name) : 0.0;
    final remaining = existing != null ? _getRemainingBalanceForFarmer(existing.name) : 0.0;
    final isPaid = existing != null &&
        ((totalAmt > 0 && remaining <= 0.0001) || (_getPurchasesForFarmer(existing.name).isNotEmpty && remaining <= 0.0001));

    final purchases = existing != null
        ? _getPurchasesForFarmer(existing.name)
        : <PurchaseModel>[];
    final allPayments = existing != null
        ? _getAllPaymentsForFarmer(existing.name)
        : <MapEntry<PurchaseModel, PaymentEntry>>[];
    final pendingPurchases = purchases.where((p) => p.isPending).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.person_add_alt_1, color: AppColors.farmer),
            const SizedBox(width: 8),
            Text(existing == null ? 'Add Farmer' : 'Edit Farmer Details'),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (existing != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.farmer.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.farmer.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Payment & Ledger Status',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.farmer,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isPaid
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isPaid
                                      ? Colors.green
                                      : Colors.amber.shade800,
                                ),
                              ),
                              child: Text(
                                isPaid ? 'PAID ✓' : 'PENDING',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isPaid
                                      ? Colors.green.shade800
                                      : Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Amount:',
                                style: TextStyle(fontSize: 12)),
                            Text('₹${totalAmt.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Amount Paid:',
                                style: TextStyle(fontSize: 12)),
                            Text('₹${totalPaid.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.buy)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Remaining Balance:',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                            Text(
                              isPaid
                                  ? '₹0.00'
                                  : '₹${remaining.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isPaid
                                    ? Colors.green.shade800
                                    : Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                        if (purchases.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (pendingPurchases.isNotEmpty)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.add_card, size: 14),
                                    label: const Text('Record Payment',
                                        style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.buy,
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 6),
                                    ),
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                      _showRecordPaymentForPurchase(
                                          pendingPurchases.first);
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ],
                        if (allPayments.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Theme(
                            data: Theme.of(ctx)
                                .copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.history,
                                  size: 15, color: AppColors.buy),
                              title: Text(
                                'Payment History (${allPayments.length} entries in date order)',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.buy),
                              ),
                              children: [
                                ...allPayments.map((entry) {
                                  final pay = entry.value;
                                  final d = pay.date;
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} (${pay.paymentMode})',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary),
                                        ),
                                        Text(
                                          '+ ₹${pay.amount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.buy),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Farmer Name *',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                    helperText:
                        'Payment history remains safely preserved when edited',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number *',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Address / Village *',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Crops grown (Optional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                final farmer = FarmerModel(
                  id: existing?.id ??
                      'f_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  address: addressCtrl.text.trim(),
                  notes: notesCtrl.text.trim(),
                  createdAt: existing?.createdAt ?? DateTime.now(),
                );
                if (existing != null) {
                  // Safe update preserving all payment records even if name changed
                  await DataRepository.updateFarmer(farmer,
                      oldName: existing.name);
                } else {
                  await DataRepository.saveFarmer(farmer);
                }
                navigator.pop();
                if (mounted) {
                  _loadData();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('✓ Farmer ${farmer.name} saved!'),
                      backgroundColor: AppColors.farmer,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.farmer,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Farmer'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFarmer(FarmerModel farmer) {
    final linkedPurchases = _getPurchasesForFarmer(farmer.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Farmer?'),
        content: Text(
          linkedPurchases.isNotEmpty
              ? 'Are you sure you want to delete "${farmer.name}"? '
                  'There are ${linkedPurchases.length} purchase record(s) linked to this farmer. '
                  'Would you also like to delete all linked purchases everywhere?'
              : 'Are you sure you want to delete "${farmer.name}" from your farmer directory?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          if (linkedPurchases.isNotEmpty)
            TextButton(
              onPressed: () async {
                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                await DataRepository.deleteFarmer(farmer.id,
                    deleteLinkedPurchases: false);
                nav.pop();
                if (mounted) {
                  _loadData();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Removed ${farmer.name} profile'),
                      backgroundColor: AppColors.farmer,
                    ),
                  );
                }
              },
              child: const Text('Profile Only'),
            ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              await DataRepository.deleteFarmer(
                farmer.id,
                deleteLinkedPurchases: true,
                farmerName: farmer.name,
              );
              nav.pop();
              if (mounted) {
                _loadData();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      linkedPurchases.isNotEmpty
                          ? 'Deleted ${farmer.name} and all linked purchases'
                          : 'Removed ${farmer.name}',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              linkedPurchases.isNotEmpty ? 'Delete Everywhere' : 'Delete',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddWorkerDialog([WorkerModel? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.engineering, color: Colors.orange),
            const SizedBox(width: 8),
            Text(existing == null ? 'Add Worker' : 'Edit Worker Details'),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Worker Name *',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number (Optional)',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Address (Optional)',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Remarks (Optional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                final worker = WorkerModel(
                  id: existing?.id ?? 'w_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  address: addressCtrl.text.trim(),
                  role: 'Hamali / Labor',
                  dailyWage: 0.0,
                  notes: notesCtrl.text.trim(),
                  joinedDate: existing?.joinedDate ?? DateTime.now(),
                );
                if (existing != null) {
                  await DataRepository.updateWorker(worker);
                } else {
                  await DataRepository.saveWorker(worker);
                }
                navigator.pop();
                if (mounted) {
                  _loadData();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('✓ Worker ${worker.name} saved!'),
                      backgroundColor: Colors.orange.shade800,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Worker'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteWorker(WorkerModel worker) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Worker?'),
        content: Text('Are you sure you want to remove "${worker.name}" from your workers list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              await DataRepository.deleteWorker(worker.id);
              nav.pop();
              if (mounted) {
                _loadData();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Removed worker ${worker.name}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // Add Payment sub-dialog (called from within the edit dialog)
  // ----------------------------------------------------------------
  void _showAddPaymentDialog({
    required BuildContext parentContext,
    required List<PaymentEntry> payments,
    required double remaining,
    required VoidCallback onSaved,
  }) {
    final amountCtrl = TextEditingController(
      text: remaining > 0 ? remaining.toStringAsFixed(2) : '',
    );
    final notesCtrl = TextEditingController();
    String selectedMode = AppConstants.paymentModes.first;
    DateTime payDate = DateTime.now();
    final fk = GlobalKey<FormState>();

    showDialog(
      context: parentContext,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setLocal) {
          final entered = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
          final newBal = remaining - entered;
          final isPaid = newBal <= 0.0001;

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.add_card, color: AppColors.buy),
                SizedBox(width: 8),
                Text('Record Payment'),
              ],
            ),
            content: Form(
              key: fk,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (remaining > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Current Balance Due:',
                                style: TextStyle(fontSize: 12)),
                            Text(
                              '₹${remaining.toStringAsFixed(2)}',
                              style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    TextFormField(
                      controller: amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Payment Amount (₹) *',
                        prefixIcon: Icon(Icons.currency_rupee),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setLocal(() {}),
                      validator: (v) =>
                          Validators.positiveNumber(v, field: 'Amount'),
                    ),
                    const SizedBox(height: 12),
                    DateTimePickerWidget(
                      value: payDate,
                      onChanged: (v) => setLocal(() => payDate = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedMode,
                      items: AppConstants.paymentModes
                          .map((m) =>
                              DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setLocal(() => selectedMode = v);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        prefixIcon: Icon(Icons.payment),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Payment Note / Remarks (Optional)',
                        prefixIcon: Icon(Icons.notes),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (entered > 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isPaid
                                ? Colors.green
                                : Colors.amber.shade800,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isPaid ? 'Status: Paid' : 'Status: Pending',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isPaid
                                    ? Colors.green.shade800
                                    : Colors.amber.shade900,
                              ),
                            ),
                            Text(
                              isPaid
                                  ? '₹0.00 Remaining'
                                  : '₹${(newBal > 0 ? newBal : 0.0).toStringAsFixed(2)} Remaining',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isPaid
                                    ? Colors.green.shade800
                                    : Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (fk.currentState!.validate()) {
                    payments.add(PaymentEntry(
                      amount: double.parse(amountCtrl.text.trim()),
                      date: payDate,
                      paymentMode: selectedMode,
                      notes: notesCtrl.text.trim(),
                    ));
                    // Keep payments sorted oldest → newest
                    payments.sort((a, b) => a.date.compareTo(b.date));
                    Navigator.of(ctx).pop();
                    onSaved();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buy,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add Payment'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ----------------------------------------------------------------
  // Direct Record Payment Dialog for a specific Purchase
  // ----------------------------------------------------------------
  void _showRecordPaymentForPurchase(PurchaseModel purchase) {
    final amountCtrl = TextEditingController(
      text: purchase.remainingBalance > 0
          ? purchase.remainingBalance.toStringAsFixed(2)
          : '',
    );
    final notesCtrl = TextEditingController();
    DateTime payDate = DateTime.now();
    String selectedMode = AppConstants.paymentModes.first;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setLocal) {
          final enteredAmt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
          final newTotalPaid = purchase.totalAmountPaid + enteredAmt;
          final newRemaining = purchase.totalAmount - newTotalPaid;
          final isNowPaid =
              (purchase.totalAmount > 0 && newRemaining <= 0.0001);

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.add_card, color: AppColors.buy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Record Payment: ${purchase.cropName}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Farmer: ${purchase.farmerName}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: purchase.isPaid
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: purchase.isPaid
                                        ? Colors.green
                                        : Colors.amber.shade800,
                                  ),
                                ),
                                child: Text(
                                  purchase.isPaid ? 'PAID ✓' : 'PENDING',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: purchase.isPaid
                                        ? Colors.green.shade800
                                        : Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Amount:',
                                  style: TextStyle(fontSize: 12)),
                              Text(
                                '₹${purchase.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Amount Paid:',
                                  style: TextStyle(fontSize: 12)),
                              Text(
                                '₹${purchase.totalAmountPaid.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.buy),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Remaining Balance:',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                purchase.isPaid
                                    ? '₹0.00'
                                    : '₹${purchase.remainingBalance.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: purchase.isPaid
                                      ? Colors.green.shade800
                                      : Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Amount input with quick fill
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Payment Amount (₹) *',
                              prefixIcon: Icon(Icons.currency_rupee),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setLocal(() {}),
                            validator: (v) => Validators.positiveNumber(v,
                                field: 'Amount'),
                          ),
                        ),
                        if (purchase.remainingBalance > 0) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              amountCtrl.text = purchase.remainingBalance
                                  .toStringAsFixed(2);
                              setLocal(() {});
                            },
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  AppColors.buy.withValues(alpha: 0.1),
                              foregroundColor: AppColors.buy,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 14),
                            ),
                            child: const Text('Full Bal',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Date & Time Picker
                    DateTimePickerWidget(
                      value: payDate,
                      onChanged: (v) => setLocal(() => payDate = v),
                    ),
                    const SizedBox(height: 12),

                    // Payment Method Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: selectedMode,
                      items: AppConstants.paymentModes
                          .map((m) => DropdownMenuItem(
                              value: m, child: Text(m)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setLocal(() => selectedMode = v);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Payment Method / Mode',
                        prefixIcon: Icon(Icons.payment),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Optional Notes / Reference
                    TextFormField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Payment Note / Remarks (Optional)',
                        prefixIcon: Icon(Icons.note_alt_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Live calculation card (Requirements 5, 6, 7)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isNowPaid
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isNowPaid
                              ? Colors.green.withValues(alpha: 0.4)
                              : Colors.amber.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('New Remaining Balance:',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                              Text(
                                isNowPaid
                                    ? '₹0.00'
                                    : '₹${(newRemaining > 0 ? newRemaining : 0.0).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isNowPaid
                                      ? Colors.green.shade800
                                      : Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Status After Payment:',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isNowPaid
                                      ? Colors.green
                                      : Colors.amber.shade800,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isNowPaid ? 'Paid' : 'Pending',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
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
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final nav = Navigator.of(ctx);
                    final messenger = ScaffoldMessenger.of(context);
                    final payment = PaymentEntry(
                      amount: double.parse(amountCtrl.text.trim()),
                      date: payDate,
                      paymentMode: selectedMode,
                      notes: notesCtrl.text.trim(),
                    );
                    await DataRepository.addPaymentToPurchase(
                        purchase.id, payment);
                    nav.pop();
                    if (mounted) {
                      _loadData();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                              '✓ Payment of ₹${payment.amount.toStringAsFixed(2)} recorded for ${purchase.farmerName}!'),
                          backgroundColor: Colors.green.shade700,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Record Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buy,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditPurchaseDialog(PurchaseModel purchase) {
    String selectedCrop = purchase.cropName;
    String selectedUnit = purchase.unit;
    DateTime selectedDateTime = purchase.dateTime;
    final nameCtrl = TextEditingController(text: purchase.farmerName);
    final phoneCtrl = TextEditingController(text: purchase.farmerPhone);
    final addressCtrl = TextEditingController(text: purchase.farmerAddress);
    final qtyCtrl = TextEditingController(text: purchase.quantity.toString());
    final suitsCtrl = TextEditingController(
        text: purchase.suitsKg > 0 ? purchase.suitsKg.toString() : '');
    final priceCtrl =
        TextEditingController(text: purchase.pricePerUnit.toString());
    final formKey = GlobalKey<FormState>();
    // Mutable local copy of payments; mutated in place then passed to copyWith.
    final editPayments = [...purchase.payments]
      ..sort((a, b) => a.date.compareTo(b.date));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final q = double.tryParse(qtyCtrl.text.trim()) ?? 0;
          final sKg = double.tryParse(suitsCtrl.text.trim()) ?? 0;
          final pr = double.tryParse(priceCtrl.text.trim()) ?? 0;

          double sInUnit = 0;
          final lower = selectedUnit.toLowerCase();
          if (lower.contains('quintal')) {
            sInUnit = sKg / 100.0;
          } else if (lower.contains('ton')) {
            sInUnit = sKg / 1000.0;
          } else {
            sInUnit = sKg;
          }
          final netQ = (q - sInUnit) > 0 ? (q - sInUnit) : 0.0;
          final cropTot = netQ * pr;
          final totalPaid =
              editPayments.fold<double>(0, (s, p) => s + p.amount);
          final netPay = cropTot - totalPaid;
          final isPaid = (cropTot > 0 && netPay <= 0.0001) ||
              (editPayments.isNotEmpty && netPay <= 0.0001);

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.edit_note, color: AppColors.buy),
                const SizedBox(width: 8),
                const Expanded(child: Text('Edit Purchase Details')),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.amber.withValues(alpha: 0.15),
                    border: Border.all(
                      color: isPaid ? Colors.green : Colors.amber.shade800,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPaid ? 'PAID ✓' : 'PENDING',
                    style: TextStyle(
                      color: isPaid
                          ? Colors.green.shade800
                          : Colors.amber.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedCrop,
                      items: AppConstants.crops
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDlgState(() => selectedCrop = v);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Crop *',
                        prefixIcon: Icon(Icons.grass),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Farmer Name *',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Farmer Mobile (Optional)',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Address / Village (Optional)',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: qtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Gross Quantity *',
                              prefixIcon: Icon(Icons.scale_outlined),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setDlgState(() {}),
                            validator: (v) =>
                                Validators.positiveNumber(v, field: 'Quantity'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedUnit,
                            items: AppConstants.units
                                .map((u) =>
                                    DropdownMenuItem(value: u, child: Text(u)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setDlgState(() => selectedUnit = v);
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: suitsCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Suits / Deduction (in Kg) - Optional',
                        prefixIcon: Icon(Icons.remove_circle_outline,
                            color: Colors.deepOrange),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Price per $selectedUnit (\u20B9) *',
                        prefixIcon: const Icon(Icons.currency_rupee),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDlgState(() {}),
                      validator: (v) =>
                          Validators.positiveNumber(v, field: 'Price'),
                    ),
                    const SizedBox(height: 12),
                    DateTimePickerWidget(
                      value: selectedDateTime,
                      onChanged: (v) =>
                          setDlgState(() => selectedDateTime = v),
                    ),
                    const SizedBox(height: 16),

                    // ──────────────────────────────────────────────
                    // PAYMENT HISTORY SECTION
                    // ──────────────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isPaid
                              ? Colors.green.withValues(alpha: 0.5)
                              : AppColors.divider,
                          width: isPaid ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isPaid
                                    ? Icons.verified
                                    : Icons.payments_outlined,
                                size: 15,
                                color: isPaid
                                    ? Colors.green.shade800
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isPaid
                                    ? 'Payment History (FULLY PAID ✓)'
                                    : 'Payment History',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isPaid
                                      ? Colors.green.shade800
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (editPayments.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'No payments recorded yet.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                            )
                          else
                            ...editPayments.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final pay = entry.value;
                              final d = pay.date;
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 10,
                                      backgroundColor: AppColors.buy
                                          .withValues(alpha: 0.15),
                                      child: Text('${idx + 1}',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.buy,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textPrimary),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  pay.paymentMode,
                                                  style: const TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.blue),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (pay.notes.isNotEmpty)
                                            Text(
                                              pay.notes,
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.textSecondary),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '\u20B9${pay.amount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.buy),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () {
                                        setDlgState(
                                            () => editPayments.removeAt(idx));
                                      },
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.close,
                                            size: 14,
                                            color: Colors.redAccent),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Paid:',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                '\u20B9${totalPaid.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.buy),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isPaid
                                    ? 'Payment Status:'
                                    : 'Remaining Balance:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isPaid
                                      ? Colors.green.shade800
                                      : Colors.amber.shade900,
                                ),
                              ),
                              Text(
                                isPaid
                                    ? 'PAID ✓ (₹0.00 Balance)'
                                    : '₹${netPay.toStringAsFixed(2)} (PENDING)',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isPaid
                                        ? Colors.green.shade800
                                        : Colors.amber.shade900),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (!isPaid)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _showAddPaymentDialog(
                                  parentContext: context,
                                  payments: editPayments,
                                  remaining: netPay > 0 ? netPay : 0,
                                  onSaved: () => setDlgState(() {}),
                                ),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add Payment'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.buy,
                                  side:
                                      const BorderSide(color: AppColors.buy),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Calculation summary card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.buy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.buy.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Gross Quantity:',
                                  style: TextStyle(fontSize: 12)),
                              Text('$q $selectedUnit',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          if (sKg > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('(-) Suits Deduction:',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.deepOrange)),
                                Text(
                                    '-$sKg kg (-${sInUnit.toStringAsFixed(2)} $selectedUnit)',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepOrange)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('(=) Net Weight:',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    '${netQ.toStringAsFixed(2)} $selectedUnit',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.buy)),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Crop Total Amount:',
                                  style: TextStyle(fontSize: 12)),
                              Text('\u20B9${cropTot.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          if (totalPaid > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('(-) Total Paid:',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.brown)),
                                Text('-\u20B9${totalPaid.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.brown)),
                              ],
                            ),
                          ],
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isPaid
                                    ? 'Payment Status:'
                                    : 'Remaining Balance:',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                              Text(
                                isPaid
                                    ? 'PAID ✓ (₹0.00)'
                                    : '\u20B9${netPay.toStringAsFixed(2)} (PENDING)',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isPaid ? Colors.green.shade800 : Colors.amber.shade900,
                                    fontSize: 15),
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
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final nav = Navigator.of(ctx);
                    final messenger = ScaffoldMessenger.of(context);
                    final updated = purchase.copyWith(
                      cropName: selectedCrop,
                      farmerName: nameCtrl.text.trim(),
                      farmerPhone: phoneCtrl.text.trim(),
                      farmerAddress: addressCtrl.text.trim(),
                      quantity: double.parse(qtyCtrl.text.trim()),
                      suitsKg: double.tryParse(suitsCtrl.text.trim()) ?? 0,
                      unit: selectedUnit,
                      pricePerUnit: double.parse(priceCtrl.text.trim()),
                      payments: List.unmodifiable(editPayments),
                      dateTime: selectedDateTime,
                    );

                    await DataRepository.updatePurchase(updated);
                    nav.pop();
                    if (mounted) {
                      _loadData();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('\u2713 Purchase updated successfully!'),
                          backgroundColor: AppColors.buy,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buy,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeletePurchase(PurchaseModel purchase) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Purchase?'),
        content: Text(
          'Are you sure you want to delete this purchase of ${purchase.quantity} ${purchase.unit} of ${purchase.cropName}? '
          'It will be permanently removed everywhere and analytics will be updated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              await DataRepository.deletePurchase(purchase.id);
              nav.pop();
              if (mounted) {
                _loadData();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Purchase entry removed')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPurchaseDetailsDialog(PurchaseModel p) {
    final sortedPayments = p.sortedPayments;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: AppColors.buy),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Purchase Details Voucher',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: p.isPaid ? Colors.green : Colors.amber.shade800,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(6),
                color: p.isPaid
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.amber.withValues(alpha: 0.1),
              ),
              child: Text(
                p.isPaid ? 'PAID ✓' : 'PENDING',
                style: TextStyle(
                  color: p.isPaid
                      ? Colors.green.shade800
                      : Colors.amber.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildVoucherRow('Crop Name', p.cropName, isBold: true),
              _buildVoucherRow('Farmer Name', p.farmerName, isBold: true),
              if (p.farmerPhone.isNotEmpty)
                _buildVoucherRow('Mobile Number', p.farmerPhone),
              if (p.farmerAddress.isNotEmpty)
                _buildVoucherRow('Address / Village', p.farmerAddress),
              _buildVoucherRow(
                  'Date & Time',
                  '${p.dateTime.day}/${p.dateTime.month}/${p.dateTime.year} '
                      '${p.dateTime.hour.toString().padLeft(2, '0')}:${p.dateTime.minute.toString().padLeft(2, '0')}'),
              const Divider(height: 16),
              _buildVoucherRow('Gross Quantity', '${p.quantity} ${p.unit}'),
              if (p.suitsKg > 0) ...[
                _buildVoucherRow(
                    'Suits / Deduction',
                    '-${p.suitsKg} kg '
                        '(-${p.suitsInUnit.toStringAsFixed(2)} ${p.unit})',
                    textColor: Colors.deepOrange),
                _buildVoucherRow(
                    'Net Payable Quantity',
                    '${p.netQuantity.toStringAsFixed(2)} ${p.unit}',
                    isBold: true,
                    textColor: AppColors.buy),
              ],
              _buildVoucherRow('Price per ${p.unit}',
                  '₹${p.pricePerUnit.toStringAsFixed(2)}'),
              _buildVoucherRow(
                  'Total Crop Amount',
                  '₹${p.totalAmount.toStringAsFixed(2)}',
                  isBold: true),
              _buildVoucherRow(
                  'Total Amount Paid',
                  '₹${p.totalAmountPaid.toStringAsFixed(2)}',
                  textColor: AppColors.buy,
                  isBold: true),
              _buildVoucherRow(
                  'Remaining Balance',
                  p.isPaid
                      ? '₹0.00'
                      : '₹${p.remainingBalance.toStringAsFixed(2)}',
                  textColor: p.isPaid
                      ? Colors.green.shade800
                      : Colors.amber.shade900,
                  isBold: true),
              _buildVoucherRow(
                  'Payment Status',
                  p.isPaid ? 'Paid' : 'Pending',
                  textColor: p.isPaid
                      ? Colors.green.shade800
                      : Colors.amber.shade900,
                  isBold: true),

              // ── Payment History ──────────────────────────────
              if (sortedPayments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: p.isPaid
                        ? Colors.green.withValues(alpha: 0.05)
                        : AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: p.isPaid
                          ? Colors.green.withValues(alpha: 0.3)
                          : AppColors.divider,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            p.isPaid
                                ? Icons.verified_rounded
                                : Icons.payment,
                            size: 13,
                            color: p.isPaid
                                ? Colors.green.shade800
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            p.isPaid
                                ? 'Payment History (Fully Settled)'
                                : 'Payment History',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: p.isPaid
                                    ? Colors.green.shade800
                                    : AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...sortedPayments.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final pay = entry.value;
                        final d = pay.date;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Text(
                                '#${idx + 1}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.blue
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            pay.paymentMode,
                                            style: const TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (pay.notes.isNotEmpty)
                                      Text(
                                        pay.notes,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textSecondary),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹${pay.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.buy),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Paid:',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                          Text('₹${p.totalAmountPaid.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.buy)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const Divider(height: 16),
              // Final balance / status container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.isPaid
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: p.isPaid
                        ? Colors.green.withValues(alpha: 0.4)
                        : Colors.amber.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: p.isPaid
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: Colors.green, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'PAID IN FULL (₹0.00 Balance)',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 13,
                                letterSpacing: 0.5),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment Status: Pending',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                              Text(
                                'Remaining Balance:',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          Text(
                            '₹${p.remainingBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
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
            child: const Text('Close'),
          ),
          if (p.isPending)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _showRecordPaymentForPurchase(p);
              },
              icon: const Icon(Icons.add_card, size: 16),
              label: const Text('Record Payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showEditPurchaseDialog(p);
            },
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Edit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.buy,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildVoucherRow(String label, String value,
      {bool isBold = false, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: isBold ? FontWeight.w600 : FontWeight.normal)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                    color: textColor ?? AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }


  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _farmers.where((f) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return f.name.toLowerCase().contains(query) ||
          f.phone.toLowerCase().contains(query) ||
          f.address.toLowerCase().contains(query);
    }).toList();

    final filteredWorkers = _workers.where((w) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return w.name.toLowerCase().contains(query) ||
          w.phone.toLowerCase().contains(query) ||
          w.address.toLowerCase().contains(query);
    }).toList();

    final totalFarmers = _farmers.length;
    final totalSpentWithFarmers =
        _purchases.fold<double>(0, (sum, p) => sum + p.totalAmount);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _selectedTab == 0
            ? _showAddFarmerDialog()
            : _showAddWorkerDialog(),
        backgroundColor: _selectedTab == 0 ? AppColors.farmer : Colors.orange.shade800,
        foregroundColor: Colors.white,
        icon: Icon(_selectedTab == 0 ? Icons.person_add : Icons.engineering),
        label: Text(_selectedTab == 0 ? 'Add Farmer' : 'Add Worker'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Directory Segmented Control: Farmers / Workers
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() {
                        _selectedTab = 0;
                        _searchCtrl.clear();
                        _searchQuery = '';
                      }),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0
                              ? AppColors.farmer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person,
                                size: 16,
                                color: _selectedTab == 0
                                    ? Colors.white
                                    : AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'Farmers (${_farmers.length})',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _selectedTab == 0
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() {
                        _selectedTab = 1;
                        _searchCtrl.clear();
                        _searchQuery = '';
                      }),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1
                              ? Colors.orange.shade800
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.engineering,
                                size: 16,
                                color: _selectedTab == 1
                                    ? Colors.white
                                    : AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'Workers (${_workers.length})',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _selectedTab == 1
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_selectedTab == 1) ...[
              _buildWorkersSection(filteredWorkers),
            ] else ...[
            // Top Stats Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Registered Farmers',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalFarmers',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 36,
                    width: 1,
                    color: Colors.white30,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Paid to Farmers',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\u20B9${totalSpentWithFarmers.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search farmer by name, mobile, address...',
                prefixIcon: const Icon(Icons.search, color: AppColors.farmer),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.cardBackground,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Farmers List
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.farmer),
                ),
              )
            else if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.person_off_outlined,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No farmers recorded yet'
                            : 'No farmer matches "$_searchQuery"',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Farmers are automatically created when you record a purchase, or you can add them manually.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...filtered.map((farmer) {
                final purchases = _getPurchasesForFarmer(farmer.name);
                final totalAmt = _getTotalAmountForFarmer(farmer.name);
                final totalPaid = _getTotalPaidForFarmer(farmer.name);
                final remainingBal = _getRemainingBalanceForFarmer(farmer.name);
                final allPayments = _getAllPaymentsForFarmer(farmer.name);
                final isFarmerPaid =
                    purchases.isNotEmpty && remainingBal <= 0.0001;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.divider),
                  ),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.farmer.withValues(alpha: 0.15),
                      child: Text(
                        farmer.name.isNotEmpty
                            ? farmer.name[0].toUpperCase()
                            : 'F',
                        style: const TextStyle(
                          color: AppColors.farmer,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            farmer.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert,
                              size: 18, color: AppColors.textSecondary),
                          padding: EdgeInsets.zero,
                          onSelected: (val) {
                            if (val == 'edit') {
                              _showAddFarmerDialog(farmer);
                            } else if (val == 'delete') {
                              _confirmDeleteFarmer(farmer);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 16),
                                  SizedBox(width: 8),
                                  Text('Edit Profile'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline,
                                      size: 16, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete Farmer',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (farmer.phone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          InkWell(
                            onTap: () =>
                                _copyToClipboard(farmer.phone, 'Mobile number'),
                            child: Row(
                              children: [
                                const Icon(Icons.phone,
                                    size: 14, color: AppColors.farmer),
                                const SizedBox(width: 4),
                                Text(
                                  farmer.phone,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.copy,
                                    size: 12, color: Colors.grey),
                              ],
                            ),
                          ),
                        ],
                        if (farmer.address.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 14, color: Colors.redAccent),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  farmer.address,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.farmer.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${purchases.length} transactions',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.farmer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (purchases.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isFarmerPaid
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isFarmerPaid
                                        ? Colors.green
                                        : Colors.amber.shade800,
                                  ),
                                ),
                                child: Text(
                                  isFarmerPaid ? 'PAID ✓' : 'PENDING',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isFarmerPaid
                                        ? Colors.green.shade800
                                        : Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Total: ₹${totalAmt.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  isFarmerPaid
                                      ? 'Paid: ₹${totalPaid.toStringAsFixed(2)}'
                                      : 'Bal: ₹${(remainingBal > 0 ? remainingBal : 0.0).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isFarmerPaid
                                        ? Colors.green.shade800
                                        : Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    children: [
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Farmer Financial Overview Summary Card
                            if (purchases.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.farmer.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.farmer.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Total Amount',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '₹${totalAmt.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Total Paid',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '₹${totalPaid.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.buy,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          const Text(
                                            'Remaining Balance',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isFarmerPaid
                                                ? '₹0.00 (PAID)'
                                                : '₹${(remainingBal > 0 ? remainingBal : 0.0).toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: isFarmerPaid
                                                  ? Colors.green.shade800
                                                  : Colors.amber.shade900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (purchases.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (!isFarmerPaid) ...[
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.add_card,
                                              size: 14),
                                          label: const Text('Record Payment',
                                              style: TextStyle(fontSize: 12)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.buy,
                                            foregroundColor: Colors.white,
                                            visualDensity:
                                                VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8),
                                          ),
                                          onPressed: () {
                                            final pending = purchases
                                                .where((p) => p.isPending)
                                                .toList();
                                            if (pending.isNotEmpty) {
                                              _showRecordPaymentForPurchase(
                                                  pending.first);
                                            } else {
                                              _showRecordPaymentForPurchase(
                                                  purchases.first);
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.edit_outlined,
                                            size: 14),
                                        label: const Text('Edit Profile',
                                            style: TextStyle(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                        ),
                                        onPressed: () =>
                                            _showAddFarmerDialog(farmer),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                              ],
                            ],

                            // 2. Chronological Payment History (Requirement 9)
                            if (allPayments.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBackground,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.history,
                                            size: 15, color: AppColors.buy),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Payment History (${allPayments.length} entries in date order)',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...allPayments.asMap().entries.map((entry) {
                                      final idx = entry.key;
                                      final purchase = entry.value.key;
                                      final pay = entry.value.value;
                                      final d = pay.date;
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 10,
                                              backgroundColor: AppColors.buy
                                                  .withValues(alpha: 0.12),
                                              child: Text(
                                                '${idx + 1}',
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.buy),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 5,
                                                                vertical: 1),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.blue
                                                              .withValues(
                                                                  alpha: 0.1),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                        ),
                                                        child: Text(
                                                          pay.paymentMode,
                                                          style: const TextStyle(
                                                              fontSize: 9,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  Colors.blue),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        '• ${purchase.cropName}',
                                                        style: const TextStyle(
                                                            fontSize: 11,
                                                            color: AppColors
                                                                .textSecondary),
                                                      ),
                                                    ],
                                                  ),
                                                  if (pay.notes.isNotEmpty)
                                                    Text(
                                                      pay.notes,
                                                      style: const TextStyle(
                                                          fontSize: 10,
                                                          color: AppColors
                                                              .textSecondary),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              '+ ₹${pay.amount.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],

                            // 3. Purchase Records List
                            const Text(
                              'Purchase Records',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (purchases.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'No crop purchases recorded with this farmer yet.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                ),
                              )
                            else
                              ...purchases.map((p) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: p.isPaid
                                          ? Colors.green.withValues(alpha: 0.04)
                                          : AppColors.background,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: p.isPaid
                                            ? Colors.green.withValues(alpha: 0.35)
                                            : AppColors.divider,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Icon(
                                            p.isPaid
                                                ? Icons.check_circle_rounded
                                                : Icons.grass,
                                            size: 18,
                                            color: p.isPaid
                                                ? Colors.green
                                                : AppColors.buy,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    p.cropName,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: p.isPaid
                                                          ? Colors.green
                                                              .withValues(
                                                                  alpha: 0.12)
                                                          : Colors.amber
                                                              .withValues(
                                                                  alpha: 0.15),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                      border: Border.all(
                                                        color: p.isPaid
                                                            ? Colors.green
                                                            : Colors.amber
                                                                .shade800,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      p.isPaid
                                                          ? 'PAID ✓'
                                                          : 'PENDING: ₹${p.remainingBalance.toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: p.isPaid
                                                            ? Colors
                                                                .green.shade800
                                                            : Colors
                                                                .amber.shade900,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${p.dateTime.day}/${p.dateTime.month}/${p.dateTime.year} • ${p.quantity} ${p.unit} @ ₹${p.pricePerUnit}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                              if (p.suitsKg > 0)
                                                Text(
                                                  'Suits: -${p.suitsKg} kg (Net: ${p.netQuantity.toStringAsFixed(2)} ${p.unit})',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.deepOrange,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Total: ₹${p.totalAmount.toStringAsFixed(2)} • Paid: ₹${p.totalAmountPaid.toStringAsFixed(2)} (${p.payments.length} pay)',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: p.isPaid
                                                      ? Colors.green.shade800
                                                      : Colors.brown,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '₹${p.totalAmount.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: AppColors.buy,
                                              ),
                                            ),
                                            if (p.isPending) ...[
                                              const SizedBox(height: 4),
                                              InkWell(
                                                onTap: () =>
                                                    _showRecordPaymentForPurchase(
                                                        p),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green
                                                        .withValues(
                                                            alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    border: Border.all(
                                                        color: Colors.green),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.add,
                                                          size: 11,
                                                          color: Colors.green),
                                                      SizedBox(width: 2),
                                                      Text(
                                                        'Pay',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.green,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(width: 2),
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert,
                                              size: 16,
                                              color: AppColors.textSecondary),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onSelected: (val) {
                                            if (val == 'view') {
                                              _showPurchaseDetailsDialog(p);
                                            } else if (val == 'pay') {
                                              _showRecordPaymentForPurchase(p);
                                            } else if (val == 'edit') {
                                              _showEditPurchaseDialog(p);
                                            } else if (val == 'delete') {
                                              _confirmDeletePurchase(p);
                                            }
                                          },
                                          itemBuilder: (ctx) => [
                                            const PopupMenuItem(
                                              value: 'view',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.receipt_long,
                                                      size: 16,
                                                      color: AppColors.buy),
                                                  SizedBox(width: 8),
                                                  Text('View Voucher'),
                                                ],
                                              ),
                                            ),
                                            if (p.isPending)
                                              const PopupMenuItem(
                                                value: 'pay',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.add_card,
                                                        size: 16,
                                                        color: Colors.green),
                                                    SizedBox(width: 8),
                                                    Text('Record Payment'),
                                                  ],
                                                ),
                                              ),
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit_outlined,
                                                      size: 16),
                                                  SizedBox(width: 8),
                                                  Text('Edit Purchase'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete_outline,
                                                      size: 16,
                                                      color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text('Delete Purchase',
                                                      style: TextStyle(
                                                          color: Colors.red)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  )),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 80), // spacing for FAB
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWorkersSection(List<WorkerModel> filteredWorkers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Worker Stats Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade800, Colors.deepOrange.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Registered Workers',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_workers.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 36, width: 1, color: Colors.white30),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assigned Lots / Purchases',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_purchases.where((p) => p.workerName.trim().isNotEmpty).length} Lots',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Worker Search Bar
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Search worker by name, mobile, address...',
            prefixIcon: const Icon(Icons.search, color: Colors.orange),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: AppColors.cardBackground,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Workers Cards List
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: Colors.orange),
            ),
          )
        else if (filteredWorkers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.engineering_outlined,
                      size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    _searchQuery.isEmpty
                        ? 'No workers recorded yet'
                        : 'No worker matches "$_searchQuery"',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Workers can be added when recording a purchase in the Buy screen, or added manually here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          ...filteredWorkers.map((worker) {
            final assignedPurchases = _purchases
                .where((p) =>
                    p.workerName.trim().toLowerCase() ==
                    worker.name.trim().toLowerCase())
                .toList();

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.divider),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.orange.withValues(alpha: 0.15),
                          child: const Icon(Icons.engineering,
                              color: Colors.orange, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                worker.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (worker.phone.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_outlined,
                                        size: 13,
                                        color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      worker.phone,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (worker.address.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 13,
                                        color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        worker.address,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          onSelected: (val) {
                            if (val == 'edit') {
                              _showAddWorkerDialog(worker);
                            } else if (val == 'delete') {
                              _confirmDeleteWorker(worker);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 16),
                                  SizedBox(width: 8),
                                  Text('Edit Details'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete,
                                      size: 16, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (assignedPurchases.isNotEmpty) ...[
                      const Divider(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${assignedPurchases.length} Purchase Lot(s) Worked On',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.buy,
                            ),
                          ),
                          Text(
                            assignedPurchases
                                .map((p) => p.cropName)
                                .toSet()
                                .join(', '),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 80),
      ],
    );
  }
}