import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../models/sale_model.dart';
import '../models/factory_model.dart';
import '../services/data_repository.dart';
import '../services/local_storage_service.dart';
import '../utils/validators.dart';
import '../widgets/confirmation_title_card.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/date_time_picker_widget.dart';
import '../widgets/entry_list_tile.dart';

class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _crop;
  String _unit = AppConstants.units.first;
  DateTime _dateTime = DateTime.now();

  final _factoryNameCtrl = TextEditingController();
  final _factoryContactCtrl = TextEditingController();
  final _factoryAddressCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  bool _saving = false;
  List<SaleModel> _entries = [];
  List<FactoryModel> _knownFactories = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    // 1. Instant load from local storage
    final cached = await LocalStorageService.loadSales();
    final cachedFactories = await LocalStorageService.loadFactories();
    if (mounted) {
      setState(() {
        _entries = cached;
        _knownFactories = cachedFactories;
      });
    }

    // 2. Background sync with Google Sheets & backend
    final fresh = await DataRepository.getSales(syncWithSheets: true);
    final freshFactories = await DataRepository.getFactories();
    if (!mounted) return;
    setState(() {
      _entries = fresh;
      _knownFactories = freshFactories;
    });
  }

  void _onFactorySelected(String name) {
    _factoryNameCtrl.text = name;
    final match = _knownFactories.firstWhere(
      (f) => f.name.trim().toLowerCase() == name.trim().toLowerCase(),
      orElse: () => FactoryModel(id: '', name: '', contact: '', address: ''),
    );
    if (match.contact.isNotEmpty && _factoryContactCtrl.text.isEmpty) {
      _factoryContactCtrl.text = match.contact;
    }
    if (match.address.isNotEmpty && _factoryAddressCtrl.text.isEmpty) {
      _factoryAddressCtrl.text = match.address;
    }
  }

  void _showEditSaleDialog(SaleModel sale) {
    String selectedCrop = sale.cropName;
    String selectedUnit = sale.unit;
    DateTime selectedDateTime = sale.dateTime;
    final nameCtrl = TextEditingController(text: sale.factoryName);
    final contactCtrl = TextEditingController(text: sale.factoryContact);
    final addressCtrl = TextEditingController(text: sale.factoryAddress);
    final qtyCtrl = TextEditingController(text: sale.quantity.toString());
    final amountCtrl = TextEditingController(text: sale.soldAmount.toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final q = double.tryParse(qtyCtrl.text.trim()) ?? 0;
          final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
          final rate = q > 0 ? (amt / q) : 0;

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.edit_note, color: AppColors.sell),
                SizedBox(width: 8),
                Text('Edit Sale Details'),
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
                        labelText: 'Factory / Mill Name *',
                        prefixIcon: Icon(Icons.business_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: contactCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Factory Contact (Optional)',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Factory Address (Optional)',
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
                              labelText: 'Quantity *',
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
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Total Sold Amount (\u20B9) *',
                        prefixIcon: Icon(Icons.currency_rupee),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDlgState(() {}),
                      validator: (v) =>
                          Validators.positiveNumber(v, field: 'Amount'),
                    ),
                    const SizedBox(height: 12),
                    DateTimePickerWidget(
                      value: selectedDateTime,
                      onChanged: (v) =>
                          setDlgState(() => selectedDateTime = v),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.sell.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Calculated Rate:',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            '\u20B9${rate.toStringAsFixed(2)} / $selectedUnit',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.sell,
                                fontSize: 15),
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
                    final updated = sale.copyWith(
                      cropName: selectedCrop,
                      factoryName: nameCtrl.text.trim(),
                      factoryContact: contactCtrl.text.trim(),
                      factoryAddress: addressCtrl.text.trim(),
                      quantity: double.parse(qtyCtrl.text.trim()),
                      unit: selectedUnit,
                      soldAmount: double.parse(amountCtrl.text.trim()),
                      dateTime: selectedDateTime,
                    );

                    await DataRepository.updateSale(updated);
                    nav.pop();
                    if (mounted) {
                      _loadEntries();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('✓ Sale updated successfully!'),
                          backgroundColor: AppColors.sell,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sell,
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

  void _confirmDeleteSale(SaleModel sale) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sale?'),
        content: Text(
          'Are you sure you want to delete this sale of ${sale.quantity} ${sale.unit} of ${sale.cropName} to ${sale.factoryName}? '
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
              await DataRepository.deleteSale(sale.id);
              nav.pop();
              if (mounted) {
                _loadEntries();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Sale entry removed')),
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
    final soldAmount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final ratePerUnit = quantity > 0 ? (soldAmount / quantity) : 0;

    final factoryName = _factoryNameCtrl.text.trim();
    final factoryContact = _factoryContactCtrl.text.trim();
    final factoryAddress = _factoryAddressCtrl.text.trim();

    // 1. Show the Title Card Confirmation Dialog
    final confirmed = await ConfirmationTitleCardDialog.show(
      context,
      title: 'Sale Confirmation',
      voucherBadge: 'Factory Sale Voucher',
      themeColor: AppColors.sell,
      dateTime: _dateTime,
      totalLabel: 'Total Sale Amount',
      totalAmount: soldAmount,
      confirmButtonText: 'Confirm & Save to Sheets',
      fields: [
        TitleCardField(
          icon: Icons.grass,
          label: 'Crop Name',
          value: _crop!,
          isHighlight: true,
        ),
        TitleCardField(
          icon: Icons.factory,
          label: 'Factory Name',
          value: factoryName,
          isHighlight: true,
        ),
        TitleCardField(
          icon: Icons.phone,
          label: 'Factory Contact',
          value: factoryContact.isEmpty ? 'Not provided' : factoryContact,
        ),
        TitleCardField(
          icon: Icons.location_city,
          label: 'Factory Address',
          value: factoryAddress.isEmpty ? 'Not provided' : factoryAddress,
        ),
        TitleCardField(
          icon: Icons.scale,
          label: 'Quantity',
          value: '$quantity $_unit',
        ),
        TitleCardField(
          icon: Icons.price_check,
          label: 'Rate / $_unit',
          value: '\u20B9${ratePerUnit.toStringAsFixed(2)}',
        ),
      ],
    );

    // If user cancelled or pressed edit, do not proceed with saving
    if (!confirmed || !mounted) return;

    final sale = SaleModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      cropName: _crop!,
      factoryName: factoryName,
      factoryContact: factoryContact,
      factoryAddress: factoryAddress,
      quantity: quantity,
      unit: _unit,
      soldAmount: soldAmount,
      dateTime: _dateTime,
    );

    setState(() => _saving = true);
    await LocalStorageService.addSale(sale);

    // Automatically record factory contact profile for Factory Details tab
    if (factoryName.isNotEmpty) {
      await DataRepository.saveFactory(FactoryModel(
        id: 'fac_${factoryName.hashCode}',
        name: factoryName,
        contact: factoryContact,
        address: factoryAddress,
        createdAt: DateTime.now(),
      ));
    }

    if (!mounted) return;
    setState(() {
      _entries = [sale, ..._entries.where((e) => e.id != sale.id)];
      _saving = false;
    });

    _formKey.currentState!.reset();
    _factoryNameCtrl.clear();
    _factoryContactCtrl.clear();
    _factoryAddressCtrl.clear();
    _quantityCtrl.clear();
    _amountCtrl.clear();
    setState(() {
      _crop = null;
      _unit = AppConstants.units.first;
      _dateTime = DateTime.now();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Sale recorded! Syncing with Google Sheets...'),
        duration: Duration(seconds: 2),
      ),
    );

    // Background sync to Google Sheets without freezing UI
    final synced = await DataRepository.syncSaleToSheets(sale);
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
    _factoryNameCtrl.dispose();
    _factoryContactCtrl.dispose();
    _factoryAddressCtrl.dispose();
    _quantityCtrl.dispose();
    _amountCtrl.dispose();
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
                  controller: _factoryNameCtrl,
                  label: 'Sold to (factory name)',
                  prefixIcon: const Icon(Icons.factory_outlined, size: 20),
                  validator: (v) =>
                      Validators.required(v, field: 'Factory name'),
                ),
                if (_knownFactories.isNotEmpty) ...[
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _knownFactories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (ctx, i) {
                        final fac = _knownFactories[i];
                        return ActionChip(
                          avatar: const Icon(Icons.factory_outlined,
                              size: 14, color: AppColors.sell),
                          label: Text(fac.name,
                              style: const TextStyle(fontSize: 11)),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _onFactorySelected(fac.name),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                CustomTextField(
                  controller: _factoryContactCtrl,
                  label: 'Factory contact details (phone / manager)',
                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      Validators.required(v, field: 'Factory contact details'),
                ),
                CustomTextField(
                  controller: _factoryAddressCtrl,
                  label: 'Factory address / location',
                  prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                  validator: (v) =>
                      Validators.required(v, field: 'Factory address'),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: CustomTextField(
                        controller: _quantityCtrl,
                        label: 'Quantity',
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
                  controller: _amountCtrl,
                  label: 'Sold amount (total \u20B9 for this quantity)',
                  prefixIcon: const Icon(Icons.currency_rupee, size: 20),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => Validators.positiveNumber(v, field: 'Amount'),
                ),
                const SizedBox(height: 8),

                // Dynamic Rate Calculation Card
                AnimatedBuilder(
                  animation: Listenable.merge([_quantityCtrl, _amountCtrl]),
                  builder: (context, _) {
                    final qty = double.tryParse(_quantityCtrl.text.trim()) ?? 0;
                    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0;
                    final rate = qty > 0 ? (amt / qty) : 0;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.sell.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.sell.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.sell.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.trending_up,
                                color: AppColors.sell, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Calculated Rate per Unit',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  qty > 0 && amt > 0
                                      ? '\u20B9${amt.toStringAsFixed(2)} \u00F7 $qty $_unit'
                                      : 'Enter quantity & total amount',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '\u20B9${rate.toStringAsFixed(2)} / $_unit',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.sell,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Save Sale Button
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
                            'Save sale',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sell,
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
          const Text('Recent sales',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          if (_entries.isEmpty && !_saving)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: Text('No sales yet',
                      style: TextStyle(color: AppColors.textSecondary))),
            ),
          ..._entries.map((s) => EntryListTile(
                title: s.cropName,
                subtitle: s.factoryContact.isNotEmpty
                    ? '${s.factoryName} (${s.factoryContact})'
                    : s.factoryName,
                quantityLabel: '${s.quantity} ${s.unit}',
                amount: s.soldAmount,
                dateTime: s.dateTime,
                accentColor: AppColors.sell,
                onEdit: () => _showEditSaleDialog(s),
                onDelete: () => _confirmDeleteSale(s),
              )),
        ],
      ),
    );
  }
}
