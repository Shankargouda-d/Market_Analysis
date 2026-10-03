import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../models/farmer_model.dart';
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
  List<PurchaseModel> _purchases = [];
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final purchases = await DataRepository.getPurchases(syncWithSheets: false);
    final farmers = await DataRepository.getFarmers();
    if (!mounted) return;
    setState(() {
      _purchases = purchases;
      _farmers = farmers;
      _loading = false;
    });
  }

  List<PurchaseModel> _getPurchasesForFarmer(String farmerName) {
    final lower = farmerName.trim().toLowerCase();
    return _purchases
        .where((p) => p.farmerName.trim().toLowerCase() == lower)
        .toList();
  }

  double _getTotalPaidForFarmer(String farmerName) {
    final list = _getPurchasesForFarmer(farmerName);
    return list.fold<double>(0, (sum, item) => sum + item.totalAmount);
  }

  void _showAddFarmerDialog([FarmerModel? existing]) {
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
                  id: existing?.id ?? 'f_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  address: addressCtrl.text.trim(),
                  notes: notesCtrl.text.trim(),
                  createdAt: existing?.createdAt ?? DateTime.now(),
                );
                await DataRepository.saveFarmer(farmer);
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
    final advanceCtrl = TextEditingController(
        text: purchase.advancePaid > 0 ? purchase.advancePaid.toString() : '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final q = double.tryParse(qtyCtrl.text.trim()) ?? 0;
          final sKg = double.tryParse(suitsCtrl.text.trim()) ?? 0;
          final pr = double.tryParse(priceCtrl.text.trim()) ?? 0;
          final adv = double.tryParse(advanceCtrl.text.trim()) ?? 0;

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
          final netPay = cropTot - adv;

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.edit_note, color: AppColors.buy),
                SizedBox(width: 8),
                Text('Edit Purchase Details'),
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
                    TextFormField(
                      controller: advanceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Advance Paid (\u20B9) - Optional',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined,
                            color: Colors.blueGrey),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDlgState(() {}),
                    ),
                    const SizedBox(height: 12),
                    DateTimePickerWidget(
                      value: selectedDateTime,
                      onChanged: (v) =>
                          setDlgState(() => selectedDateTime = v),
                    ),
                    const SizedBox(height: 12),
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
                                Text('-$sKg kg (-${sInUnit.toStringAsFixed(2)} $selectedUnit)',
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
                                Text('${netQ.toStringAsFixed(2)} $selectedUnit',
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
                          if (adv > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('(-) Advance Paid:',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.brown)),
                                Text('-\u20B9${adv.toStringAsFixed(2)}',
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
                                adv > 0
                                    ? 'Net Balance to Pay:'
                                    : 'Total Amount:',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                              Text(
                                '\u20B9${netPay.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.buy,
                                    fontSize: 16),
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
                      advancePaid:
                          double.tryParse(advanceCtrl.text.trim()) ?? 0,
                      dateTime: selectedDateTime,
                    );

                    await DataRepository.updatePurchase(updated);
                    nav.pop();
                    if (mounted) {
                      _loadData();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('✓ Purchase updated successfully!'),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: AppColors.buy),
            SizedBox(width: 8),
            Text('Purchase Details Voucher',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
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
              _buildVoucherRow('Date & Time',
                  '${p.dateTime.day}/${p.dateTime.month}/${p.dateTime.year} ${p.dateTime.hour.toString().padLeft(2, '0')}:${p.dateTime.minute.toString().padLeft(2, '0')}'),
              const Divider(height: 16),
              _buildVoucherRow('Gross Quantity', '${p.quantity} ${p.unit}'),
              if (p.suitsKg > 0) ...[
                _buildVoucherRow('Suits / Deduction',
                    '-${p.suitsKg} kg (-${p.suitsInUnit.toStringAsFixed(2)} ${p.unit})',
                    textColor: Colors.deepOrange),
                _buildVoucherRow('Net Payable Quantity',
                    '${p.netQuantity.toStringAsFixed(2)} ${p.unit}',
                    isBold: true, textColor: AppColors.buy),
              ],
              _buildVoucherRow('Price per ${p.unit}',
                  '\u20B9${p.pricePerUnit.toStringAsFixed(2)}'),
              _buildVoucherRow(
                  'Total Crop Amount', '\u20B9${p.totalAmount.toStringAsFixed(2)}',
                  isBold: true),
              if (p.advancePaid > 0)
                _buildVoucherRow('Advance Paid',
                    '-\u20B9${p.advancePaid.toStringAsFixed(2)}',
                    textColor: Colors.amber.shade900),
              const Divider(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.buy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      p.advancePaid > 0
                          ? 'Net Balance to Pay:'
                          : 'Total Amount:',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '\u20B9${p.netPayable.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.buy,
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

    final totalFarmers = _farmers.length;
    final totalSpentWithFarmers =
        _purchases.fold<double>(0, (sum, p) => sum + p.totalAmount);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFarmerDialog(),
        backgroundColor: AppColors.farmer,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Farmer'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                final totalPaid = _getTotalPaidForFarmer(farmer.name);

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
                          icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
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
                                  Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete Farmer', style: TextStyle(color: Colors.red)),
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
                            const Spacer(),
                            Text(
                              'Total: \u20B9${totalPaid.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.profit,
                              ),
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
                            const Text(
                              'Purchase History',
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
                              ...purchases.map((p) => InkWell(
                                    onTap: () => _showPurchaseDetailsDialog(p),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: AppColors.divider),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.grass,
                                              size: 16,
                                              color: AppColors.buy),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  p.cropName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                Text(
                                                  '${p.dateTime.day}/${p.dateTime.month}/${p.dateTime.year} \u2022 ${p.quantity} ${p.unit} @ \u20B9${p.pricePerUnit}',
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
                                                if (p.advancePaid > 0)
                                                  Text(
                                                    'Adv: -\u20B9${p.advancePaid.toStringAsFixed(0)} \u2022 Net Bal: \u20B9${p.netPayable.toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.amber.shade900,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '\u20B9${p.totalAmount.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: AppColors.buy,
                                                ),
                                              ),
                                              if (p.advancePaid > 0)
                                                Text(
                                                  'Bal: \u20B9${p.netPayable.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(width: 4),
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert,
                                                size: 16,
                                                color: AppColors.textSecondary),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onSelected: (val) {
                                              if (val == 'view') {
                                                _showPurchaseDetailsDialog(p);
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
                                                    Text('View Details'),
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
        ),
      ),
    );
  }
}
