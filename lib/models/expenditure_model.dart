/// Represents an entry under "Other Expenditure".
/// Tracks mandi operating costs such as transport, hamali, packaging, diesel, etc.
class ExpenditureModel {
  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime dateTime;
  final String paidTo;
  final String paymentMode;
  final String notes;

  ExpenditureModel({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.dateTime,
    this.paidTo = '',
    this.paymentMode = 'Cash',
    this.notes = '',
  });

  ExpenditureModel copyWith({
    String? id,
    String? title,
    String? category,
    double? amount,
    DateTime? dateTime,
    String? paidTo,
    String? paymentMode,
    String? notes,
  }) {
    return ExpenditureModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      dateTime: dateTime ?? this.dateTime,
      paidTo: paidTo ?? this.paidTo,
      paymentMode: paymentMode ?? this.paymentMode,
      notes: notes ?? this.notes,
    );
  }

  /// JSON map for SharedPreferences & Google Sheets.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'date': dateTime.toIso8601String(),
        'paidTo': paidTo,
        'paymentMode': paymentMode,
        'notes': notes,
      };

  /// PostgreSQL column map for Supabase.
  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'date': dateTime.toIso8601String(),
        'paid_to': paidTo,
        'payment_mode': paymentMode,
        'notes': notes,
      };

  /// Builds model from JSON / Supabase row.
  factory ExpenditureModel.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] ?? json['expense_title'])?.toString() ?? '';
    final category = (json['category'] ?? json['expense_category'])?.toString() ??
        'Other / Miscellaneous';
    final amount = double.tryParse((json['amount'] ?? json['total_amount'])?.toString() ?? '') ?? 0.0;
    final dateStr = (json['date'] ?? json['created_at'])?.toString() ?? '';
    final paidTo = (json['paidTo'] ?? json['paid_to'])?.toString() ?? '';
    final paymentMode =
        (json['paymentMode'] ?? json['payment_mode'])?.toString() ?? 'Cash';
    final notes = json['notes']?.toString() ?? '';

    return ExpenditureModel(
      id: json['id']?.toString() ?? '',
      title: title,
      category: category,
      amount: amount,
      dateTime: DateTime.tryParse(dateStr) ?? DateTime.now(),
      paidTo: paidTo,
      paymentMode: paymentMode,
      notes: notes,
    );
  }
}
