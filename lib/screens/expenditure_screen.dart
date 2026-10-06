import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../models/expenditure_model.dart';
import '../services/data_repository.dart';
import '../services/local_storage_service.dart';
import '../utils/date_utils.dart';
import '../utils/validators.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/date_time_picker_widget.dart';

class ExpenditureScreen extends StatefulWidget {
  const ExpenditureScreen({super.key});

  @override
  State<ExpenditureScreen> createState() => _ExpenditureScreenState();
}

class _ExpenditureScreenState extends State<ExpenditureScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _paidToCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _category = AppConstants.expenditureCategories.first;
  String _paymentMode = AppConstants.paymentModes.first;
  DateTime _dateTime = DateTime.now();

  bool _saving = false;
  String _filterCategory = 'All';
  String _searchQuery = '';
  List<ExpenditureModel> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _paidToCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    final cached = await LocalStorageService.loadExpenditures();
    if (mounted) {
      setState(() => _entries = cached);
    }

    final fresh = await DataRepository.getExpenditures(syncWithBackend: true);
    if (!mounted) return;
    setState(() => _entries = fresh);
  }

  Future<void> _saveExpenditure() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount greater than 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final expenditure = ExpenditureModel(
      id: 'exp_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      category: _category,
      amount: amount,
      dateTime: _dateTime,
      paidTo: _paidToCtrl.text.trim(),
      paymentMode: _paymentMode,
      notes: _notesCtrl.text.trim(),
    );

    await DataRepository.saveExpenditure(expenditure);
    await _loadEntries();

    if (!mounted) return;
    setState(() {
      _saving = false;
      _titleCtrl.clear();
      _amountCtrl.clear();
      _paidToCtrl.clear();
      _notesCtrl.clear();
      _dateTime = DateTime.now();
      _category = AppConstants.expenditureCategories.first;
      _paymentMode = AppConstants.paymentModes.first;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Expenditure saved successfully!'),
        backgroundColor: AppColors.expenditure,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showEditDialog(ExpenditureModel item) {
    final editTitleCtrl = TextEditingController(text: item.title);
    final editAmountCtrl = TextEditingController(text: item.amount.toStringAsFixed(2));
    final editPaidToCtrl = TextEditingController(text: item.paidTo);
    final editNotesCtrl = TextEditingController(text: item.notes);
    String editCategory = item.category;
    String editPaymentMode = item.paymentMode;
    DateTime editDateTime = item.dateTime;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit_note, color: AppColors.expenditure),
              SizedBox(width: 8),
              Text('Edit Expenditure', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomTextField(
                    label: 'Description / Purpose',
                    controller: editTitleCtrl,
                    validator: (v) => Validators.required(v, field: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Category',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: editCategory,
                        isExpanded: true,
                        items: AppConstants.expenditureCategories.map((c) {
                          return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)));
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setModalState(() => editCategory = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Amount (₹)',
                    controller: editAmountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => Validators.positiveNumber(v, field: 'Amount'),
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Paid To (Optional)',
                    controller: editPaidToCtrl,
                  ),
                  const SizedBox(height: 12),
                  const Text('Payment Mode',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: editPaymentMode,
                        isExpanded: true,
                        items: AppConstants.paymentModes.map((m) {
                          return DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)));
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setModalState(() => editPaymentMode = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DateTimePickerWidget(
                    value: editDateTime,
                    onChanged: (dt) => setModalState(() => editDateTime = dt),
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Notes / Remarks (Optional)',
                    controller: editNotesCtrl,
                    maxLines: 2,
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.expenditure,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final amt = double.tryParse(editAmountCtrl.text.trim()) ?? 0;
                if (editTitleCtrl.text.trim().isEmpty || amt <= 0) return;

                final updated = item.copyWith(
                  title: editTitleCtrl.text.trim(),
                  category: editCategory,
                  amount: amt,
                  paidTo: editPaidToCtrl.text.trim(),
                  paymentMode: editPaymentMode,
                  dateTime: editDateTime,
                  notes: editNotesCtrl.text.trim(),
                );

                Navigator.of(ctx).pop();
                await DataRepository.updateExpenditure(updated);
                await _loadEntries();

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Expenditure updated!')),
                );
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(ExpenditureModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Expenditure', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${item.title}" of ₹${item.amount.toStringAsFixed(2)}?',
          style: const TextStyle(fontSize: 14),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await DataRepository.deleteExpenditure(item.id);
              await _loadEntries();

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Expenditure deleted')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  List<ExpenditureModel> get _filteredEntries {
    return _entries.where((e) {
      final matchesCategory = _filterCategory == 'All' || e.category == _filterCategory;
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          e.title.toLowerCase().contains(q) ||
          e.paidTo.toLowerCase().contains(q) ||
          e.category.toLowerCase().contains(q) ||
          e.notes.toLowerCase().contains(q);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  double get _totalAmount => _entries.fold(0, (sum, e) => sum + e.amount);

  double get _todayAmount {
    final now = DateTime.now();
    return _entries.where((e) {
      return e.dateTime.year == now.year &&
          e.dateTime.month == now.month &&
          e.dateTime.day == now.day;
    }).fold(0, (sum, e) => sum + e.amount);
  }

  double get _thisMonthAmount {
    final now = DateTime.now();
    return _entries.where((e) {
      return e.dateTime.year == now.year && e.dateTime.month == now.month;
    }).fold(0, (sum, e) => sum + e.amount);
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return RefreshIndicator(
      onRefresh: _loadEntries,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Summary Row
            Row(
              children: [
                Expanded(
                  child: _SummaryBox(
                    title: 'Total Spent',
                    value: formatCurrency.format(_totalAmount),
                    color: AppColors.expenditure,
                    icon: Icons.account_balance_wallet,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryBox(
                    title: 'This Month',
                    value: formatCurrency.format(_thisMonthAmount),
                    color: Colors.orange.shade800,
                    icon: Icons.calendar_month,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryBox(
                    title: "Today's Expense",
                    value: formatCurrency.format(_todayAmount),
                    color: Colors.teal.shade700,
                    icon: Icons.today,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Add Expenditure Form Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.add_card, color: AppColors.expenditure, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Add Other Expenditure',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Description / Purpose
                    CustomTextField(
                      label: 'Description / Purpose (e.g. Diesel, Hamali, Bags)',
                      controller: _titleCtrl,
                      prefixIcon: const Icon(Icons.description_outlined),
                      validator: (v) => Validators.required(v, field: 'Description'),
                    ),
                    const SizedBox(height: 12),

                    // Category Dropdown
                    const Text('Category',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _category,
                          isExpanded: true,
                          items: AppConstants.expenditureCategories.map((c) {
                            return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)));
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _category = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Amount & Payment Mode Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: CustomTextField(
                            label: 'Amount (₹)',
                            controller: _amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            prefixIcon: const Icon(Icons.currency_rupee),
                            validator: (v) => Validators.positiveNumber(v, field: 'Amount'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Mode',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _paymentMode,
                                    isExpanded: true,
                                    items: AppConstants.paymentModes.map((m) {
                                      return DropdownMenuItem(
                                          value: m,
                                          child: Text(m,
                                              style: const TextStyle(fontSize: 12)));
                                    }).toList(),
                                    onChanged: (v) {
                                      if (v != null) setState(() => _paymentMode = v);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Paid To (Optional)
                    CustomTextField(
                      label: 'Paid To (Optional)',
                      controller: _paidToCtrl,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    const SizedBox(height: 12),

                    // Date & Time Picker
                    DateTimePickerWidget(
                      value: _dateTime,
                      onChanged: (dt) => setState(() => _dateTime = dt),
                    ),
                    const SizedBox(height: 12),

                    // Notes / Remarks
                    CustomTextField(
                      label: 'Notes / Remarks (Optional)',
                      controller: _notesCtrl,
                      prefixIcon: const Icon(Icons.notes),
                    ),
                    const SizedBox(height: 16),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _saveExpenditure,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.expenditure,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 1,
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.check, size: 20),
                        label: Text(
                          _saving ? 'Saving...' : 'Record Expenditure',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Entries List Header & Search
            Row(
              children: [
                const Icon(Icons.history, color: AppColors.textPrimary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Expenses History (${_filteredEntries.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by title, paid to, category...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.cardBackground,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 10),

            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', ...AppConstants.expenditureCategories].map((cat) {
                  final active = _filterCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      selected: active,
                      label: Text(cat, style: TextStyle(fontSize: 12, color: active ? Colors.white : AppColors.textPrimary)),
                      selectedColor: AppColors.expenditure,
                      backgroundColor: AppColors.cardBackground,
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: active ? AppColors.expenditure : AppColors.divider),
                      ),
                      onSelected: (_) => setState(() => _filterCategory = cat),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // List of Expenses
            if (_filteredEntries.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36),
                alignment: Alignment.center,
                child: const Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textSecondary),
                    SizedBox(height: 8),
                    Text('No expenditures found', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredEntries.length,
                itemBuilder: (ctx, i) {
                  final item = _filteredEntries[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left accent pill
                        Container(
                          width: 4,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.expenditure,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Main info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.expenditure.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.category,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.expenditure,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '• ${item.paymentMode}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              if (item.paidTo.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.person, size: 13, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Paid to: ${item.paidTo}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 2),
                              Text(
                                AppDateUtils.formatDateTime(item.dateTime),
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),

                        // Amount & Popup Menu
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '- ₹${item.amount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFC2185B),
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textSecondary),
                              onSelected: (val) {
                                if (val == 'edit') {
                                  _showEditDialog(item);
                                } else if (val == 'delete') {
                                  _confirmDelete(item);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 18, color: AppColors.expenditure),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryBox({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
