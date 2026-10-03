import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../models/farmer_model.dart';
import '../models/purchase_model.dart';
import '../services/data_repository.dart';
import '../services/local_storage_service.dart';
import '../utils/validators.dart';
import '../widgets/confirmation_title_card.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/date_time_picker_widget.dart';
import '../widgets/entry_list_tile.dart';

class BuyScreen extends StatefulWidget {
  const BuyScreen({super.key});

  @override
  State<BuyScreen> createState() => _BuyScreenState();
}

class _BuyScreenState extends State<BuyScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _crop;
  String _unit = AppConstants.units.first;
  DateTime _dateTime = DateTime.now(); // auto-set, user can edit

  final _farmerNameCtrl = TextEditingController();
  final _farmerPhoneCtrl = TextEditingController();
  final _farmerAddressCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _suitsCtrl = TextEditingController(); // Suits / Deduction in kg
  final _priceCtrl = TextEditingController();
  final _advancePaidCtrl = TextEditingController(); // Advance paid amount in ₹

  bool _saving = false;
  List<PurchaseModel> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    // 1. Instant load from local storage
    final cached = await LocalStorageService.loadPurchases();
    if (mounted) {
      setState(() => _entries = cached);
    }

    // 2. Background sync with Google Sheets
    final fresh = await DataRepository.getPurchases(syncWithSheets: true);
    if (!mounted) return;
    setState(() => _entries = fresh);
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
                      _loadEntries();
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
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: textColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePurchase(PurchaseModel purchase) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Purchase?'),
        content: Text(
          'Are you sure you want to delete this purchase of ${purchase.quantity} ${purchase.unit} of ${purchase.cropName} from ${purchase.farmerName}? '
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
                _loadEntries();
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate() || _crop == null) {
      if (_crop == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a crop')),
        );
      }
      return;
    }

    final quantity = double.tryParse(_quantityCtrl.text.trim()) ?? 0;
    final suitsKg = double.tryParse(_suitsCtrl.text.trim()) ?? 0;
    final pricePerUnit = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final advancePaid = double.tryParse(_advancePaidCtrl.text.trim()) ?? 0;

    double suitsInUnit = 0;
    final lowerUnit = _unit.toLowerCase();
    if (lowerUnit.contains('quintal')) {
      suitsInUnit = suitsKg / 100.0;
    } else if (lowerUnit.contains('ton')) {
      suitsInUnit = suitsKg / 1000.0;
    } else {
      suitsInUnit = suitsKg;
    }

    if (suitsKg < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Suits deduction cannot be negative')),
      );
      return;
    }

    if (suitsInUnit >= quantity && quantity > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Suits deduction cannot be greater than or equal to total quantity')),
      );
      return;
    }

    final netQuantity =
        (quantity - suitsInUnit) > 0 ? (quantity - suitsInUnit) : 0.0;
    final totalCropAmount = netQuantity * pricePerUnit;
    final netPayable = totalCropAmount - advancePaid;

    final farmerName = _farmerNameCtrl.text.trim();
    final farmerPhone = _farmerPhoneCtrl.text.trim();
    final farmerAddress = _farmerAddressCtrl.text.trim();

    // 1. Show the Title Card Confirmation Dialog
    final confirmed = await ConfirmationTitleCardDialog.show(
      context,
      title: 'Purchase Confirmation',
      voucherBadge: 'Farmer Buy Voucher',
      themeColor: AppColors.buy,
      dateTime: _dateTime,
      totalLabel:
          advancePaid > 0 ? 'Net Balance to Pay' : 'Total Purchase Amount',
      totalAmount: netPayable,
      confirmButtonText: 'Confirm & Save to Sheets',
      fields: [
        TitleCardField(
          icon: Icons.grass,
          label: 'Crop Name',
          value: _crop!,
          isHighlight: true,
        ),
        TitleCardField(
          icon: Icons.person,
          label: 'Farmer Name',
          value: farmerName,
          isHighlight: true,
        ),
        if (farmerPhone.isNotEmpty)
          TitleCardField(
            icon: Icons.phone,
            label: 'Mobile No.',
            value: farmerPhone,
          ),
        if (farmerAddress.isNotEmpty)
          TitleCardField(
            icon: Icons.location_on,
            label: 'Address / Village',
            value: farmerAddress,
          ),
        TitleCardField(
          icon: Icons.scale,
          label: 'Gross Quantity',
          value: '$quantity $_unit',
        ),
        if (suitsKg > 0)
          TitleCardField(
            icon: Icons.remove_circle_outline,
            label: 'Suits / Deduction',
            value: '-$suitsKg kg (-${suitsInUnit.toStringAsFixed(2)} $_unit)',
          ),
        TitleCardField(
          icon: Icons.check_circle_outline,
          label: 'Net Payable Weight',
          value: '${netQuantity.toStringAsFixed(2)} $_unit',
          isHighlight: true,
        ),
        TitleCardField(
          icon: Icons.payments_outlined,
          label: 'Rate / $_unit',
          value: '\u20B9${pricePerUnit.toStringAsFixed(2)}',
        ),
        TitleCardField(
          icon: Icons.calculate_outlined,
          label: 'Total Crop Amount',
          value: '\u20B9${totalCropAmount.toStringAsFixed(2)}',
          isHighlight: true,
        ),
        if (advancePaid > 0)
          TitleCardField(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Advance Paid',
            value: '-\u20B9${advancePaid.toStringAsFixed(2)}',
          ),
      ],
    );

    // If user cancelled or pressed edit, do not proceed with saving
    if (!confirmed || !mounted) return;

    final purchase = PurchaseModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      cropName: _crop!,
      farmerName: farmerName,
      farmerPhone: farmerPhone,
      farmerAddress: farmerAddress,
      quantity: quantity,
      suitsKg: suitsKg,
      unit: _unit,
      pricePerUnit: pricePerUnit,
      advancePaid: advancePaid,
      dateTime: _dateTime,
    );

    setState(() => _saving = true);

    // Save purchase locally
    await LocalStorageService.addPurchase(purchase);

    // Automatically record farmer contact profile for Farmer Details tab
    if (farmerName.isNotEmpty) {
      await DataRepository.saveFarmer(FarmerModel(
        id: 'f_${farmerName.hashCode}',
        name: farmerName,
        phone: farmerPhone,
        address: farmerAddress,
        createdAt: DateTime.now(),
      ));
    }

    if (!mounted) return;
    setState(() {
      _entries = [purchase, ..._entries.where((e) => e.id != purchase.id)];
      _saving = false;
    });

    _formKey.currentState!.reset();
    _farmerNameCtrl.clear();
    _farmerPhoneCtrl.clear();
    _farmerAddressCtrl.clear();
    _quantityCtrl.clear();
    _suitsCtrl.clear();
    _priceCtrl.clear();
    _advancePaidCtrl.clear();
    setState(() {
      _crop = null;
      _unit = AppConstants.units.first;
      _dateTime = DateTime.now();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Purchase recorded! Syncing with Google Sheets...'),
        duration: Duration(seconds: 2),
      ),
    );

    // Sync to Google Sheets in background
    final synced = await DataRepository.syncPurchaseToSheets(purchase);
    if (!mounted) return;

    if (synced) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Synced to Google Sheets successfully'),
          backgroundColor: AppColors.profit,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved locally. Google Sheets sync pending/offline.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _farmerNameCtrl.dispose();
    _farmerPhoneCtrl.dispose();
    _farmerAddressCtrl.dispose();
    _quantityCtrl.dispose();
    _suitsCtrl.dispose();
    _priceCtrl.dispose();
    _advancePaidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadEntries,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomDropdown(
                  label: 'Crop',
                  value: _crop,
                  items: AppConstants.crops,
                  onChanged: (v) => setState(() => _crop = v),
                ),
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Date & time',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ),
                const SizedBox(height: 4),
                DateTimePickerWidget(
                  value: _dateTime,
                  onChanged: (v) => setState(() => _dateTime = v),
                ),
                const SizedBox(height: 6),
                CustomTextField(
                  controller: _farmerNameCtrl,
                  label: 'Farmer name',
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                  validator: (v) =>
                      Validators.required(v, field: 'Farmer name'),
                ),
                CustomTextField(
                  controller: _farmerPhoneCtrl,
                  label: 'Farmer mobile no.',
                  keyboardType: TextInputType.phone,
                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                  validator: (v) =>
                      Validators.required(v, field: 'Farmer mobile no.'),
                ),
                CustomTextField(
                  controller: _farmerAddressCtrl,
                  label: 'Farmer address / village',
                  prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                  validator: (v) =>
                      Validators.required(v, field: 'Farmer address'),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: CustomTextField(
                        controller: _quantityCtrl,
                        label: 'Gross Quantity *',
                        prefixIcon: const Icon(Icons.scale_outlined, size: 20),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) =>
                            Validators.positiveNumber(v, field: 'Quantity'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(_unit),
                          initialValue: _unit,
                          items: AppConstants.units
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _unit = v);
                          },
                          decoration: InputDecoration(
                            labelText: 'Unit',
                            filled: true,
                            fillColor: AppColors.cardBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                CustomTextField(
                  controller: _suitsCtrl,
                  label: 'Suits / Deduction (in Kg) - Optional',
                  prefixIcon: const Icon(Icons.remove_circle_outline,
                      size: 20, color: Colors.deepOrange),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                CustomTextField(
                  controller: _priceCtrl,
                  label: 'Price per $_unit (\u20B9) *',
                  prefixIcon: const Icon(Icons.currency_rupee, size: 20),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => Validators.positiveNumber(v, field: 'Price'),
                ),
                CustomTextField(
                  controller: _advancePaidCtrl,
                  label: 'Advance Paid Amount (\u20B9) - Optional',
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined,
                      size: 20, color: Colors.blueGrey),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),

                // Dynamic Total Price & Deductions Calculation Card
                AnimatedBuilder(
                  animation: Listenable.merge(
                      [_quantityCtrl, _suitsCtrl, _priceCtrl, _advancePaidCtrl]),
                  builder: (context, _) {
                    final qty = double.tryParse(_quantityCtrl.text.trim()) ?? 0;
                    final suitsKg = double.tryParse(_suitsCtrl.text.trim()) ?? 0;
                    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
                    final advance =
                        double.tryParse(_advancePaidCtrl.text.trim()) ?? 0;

                    double suitsInUnit = 0;
                    final lowerUnit = _unit.toLowerCase();
                    if (lowerUnit.contains('quintal')) {
                      suitsInUnit = suitsKg / 100.0;
                    } else if (lowerUnit.contains('ton')) {
                      suitsInUnit = suitsKg / 1000.0;
                    } else {
                      suitsInUnit = suitsKg;
                    }

                    final netQty = (qty - suitsInUnit) > 0 ? (qty - suitsInUnit) : 0.0;
                    final cropTotal = netQty * price;
                    final netPayable = cropTotal - advance;

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.buy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.buy.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.buy.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.calculate,
                                    color: AppColors.buy, size: 22),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Calculated Total Price',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                '\u20B9${netPayable.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.buy,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Gross Quantity:',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                              Text(
                                '$qty $_unit',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          if (suitsKg > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('(-) Suits / Deduction:',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.deepOrange,
                                        fontWeight: FontWeight.w500)),
                                Text(
                                  '-$suitsKg kg (-${suitsInUnit.toStringAsFixed(2)} $_unit)',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepOrange),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('(=) Net Payable Weight:',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.buy)),
                                Text(
                                  '${netQty.toStringAsFixed(2)} $_unit',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.buy),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Rate (\u20B9 / $_unit):',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                              Text(
                                '\u20B9${price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Crop Total Amount:',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                              Text(
                                '\u20B9${cropTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          if (advance > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '(-) Advance Paid Amount:',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.amber,
                                      fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '-\u20B9${advance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade900),
                                ),
                              ],
                            ),
                          ],
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                advance > 0
                                    ? 'Final Net Balance to Pay:'
                                    : 'Net Payable Amount:',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary),
                              ),
                              Text(
                                '\u20B9${netPayable.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.buy,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Save / Review Purchase Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _handleSave,
                    icon: _saving
                        ? const SizedBox.shrink()
                        : const Icon(Icons.receipt_long, size: 20),
                    label: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Save purchase',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.buy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Recent purchases',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          if (_entries.isEmpty && !_saving)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: Text('No purchases yet',
                       style: TextStyle(color: AppColors.textSecondary))),
            ),
          ..._entries.map((p) => EntryListTile(
                title: p.cropName,
                subtitle: p.farmerPhone.isNotEmpty
                    ? '${p.farmerName} (${p.farmerPhone})'
                    : p.farmerName,
                quantityLabel: p.suitsKg > 0
                    ? '${p.quantity} ${p.unit} (Net: ${p.netQuantity.toStringAsFixed(2)})'
                    : '${p.quantity} ${p.unit}',
                amount: p.totalAmount,
                dateTime: p.dateTime,
                accentColor: AppColors.buy,
                extraDetails: p.suitsKg > 0
                    ? 'Suits: ${p.suitsKg.toStringAsFixed(1)} kg • Net: ${p.netQuantity.toStringAsFixed(2)} ${p.unit}'
                    : null,
                advancePaidLabel: p.advancePaid > 0
                    ? 'Adv: \u20B9${p.advancePaid.toStringAsFixed(0)} | Bal: \u20B9${p.netPayable.toStringAsFixed(2)}'
                    : null,
                onTap: () => _showPurchaseDetailsDialog(p),
                onEdit: () => _showEditPurchaseDialog(p),
                onDelete: () => _confirmDeletePurchase(p),
              )),
        ],
      ),
    );
  }
}
