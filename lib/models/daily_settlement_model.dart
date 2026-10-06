import 'dart:convert';
import 'expenditure_model.dart';
import 'purchase_model.dart';

/// Represents a single deposit entry recorded during a business day.
/// Meets Requirements 2, 3, 4:
/// - Amount
/// - Date
/// - Time
/// - Optional note/reference
/// - Multiple deposits on the same day linked to the settlement
class DailyDepositEntry {
  final String id;
  final String settlementId;
  final double amount;
  final DateTime date; // Calendar date
  final DateTime time; // Exact time of deposit
  final String paymentMode; // e.g. Cash, UPI / Online, Bank Transfer, Cheque
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DailyDepositEntry({
    String? id,
    required this.settlementId,
    required this.amount,
    required this.date,
    required this.time,
    this.paymentMode = 'Cash',
    this.notes = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? 'dep_${time.millisecondsSinceEpoch}_${amount.toInt()}',
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  DailyDepositEntry copyWith({
    String? id,
    String? settlementId,
    double? amount,
    DateTime? date,
    DateTime? time,
    String? paymentMode,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailyDepositEntry(
      id: id ?? this.id,
      settlementId: settlementId ?? this.settlementId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      time: time ?? this.time,
      paymentMode: paymentMode ?? this.paymentMode,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'settlementId': settlementId,
        'amount': amount,
        'date': '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'time': time.toIso8601String(),
        'paymentMode': paymentMode,
        'notes': notes,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'settlement_id': settlementId,
        'amount': amount,
        'date': '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'created_time': time.toIso8601String(),
        'payment_mode': paymentMode,
        'notes': notes,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
        'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      };

  factory DailyDepositEntry.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    final rawDate = json['date']?.toString() ?? '';
    if (rawDate.contains('T')) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      final parts = rawDate.split('-');
      if (parts.length == 3) {
        parsedDate = DateTime(
          int.tryParse(parts[0]) ?? DateTime.now().year,
          int.tryParse(parts[1]) ?? DateTime.now().month,
          int.tryParse(parts[2]) ?? DateTime.now().day,
        );
      } else {
        parsedDate = DateTime.now();
      }
    }

    final rawTime = (json['time'] ?? json['created_time'])?.toString() ?? '';
    final parsedTime = DateTime.tryParse(rawTime) ?? DateTime.now();

    return DailyDepositEntry(
      id: json['id']?.toString() ?? 'dep_${DateTime.now().millisecondsSinceEpoch}',
      settlementId: (json['settlementId'] ?? json['settlement_id'])?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      time: parsedTime,
      paymentMode: (json['paymentMode'] ?? json['payment_mode'])?.toString() ?? 'Cash',
      notes: json['notes']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? json['updated_at']?.toString() ?? ''),
    );
  }
}

/// Represents a Daily Deposit / Daily Settlement record for a single business day.
/// Meets Requirements 1, 5, 6, 7, 8, 9, 10:
/// - Separate record per business day
/// - Calculates total deposit amount for that day
/// - Connects to business activity/purchases for that day
/// - Calculates remaining amount (or 0.00 once settled)
/// - Historical transactions and deposits are never deleted when closed
class DailySettlementModel {
  final String id; // e.g. settle_2026-10-05
  final DateTime date; // Normalized calendar date (YYYY-MM-DD)
  final String status; // 'open' or 'settled'
  final double totalPurchases; // Total purchase bill on that day
  final double totalPaidForPurchases; // Total amount paid to farmers for purchases on that day
  final double totalDeposits; // Total deposited funds on that day
  final double totalExpenditures; // Total other expenditures on that day
  final double remainingAmount; // Remaining balance: deposit - totalPaidAmount (paid for purchases + expenditure)
  final double preSettlementRemaining; // Historical remaining balance prior to settlement
  final DateTime? settledAt; // Timestamp when settlement was closed
  final String? settledBy; // User or operator who settled
  final String notes; // Day notes or closing remarks
  final List<DailyDepositEntry> deposits; // All individual deposit transactions
  final int purchasesCount; // Count of purchases linked to that day
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DailySettlementModel({
    String? id,
    required this.date,
    this.status = 'open',
    this.totalPurchases = 0.0,
    this.totalPaidForPurchases = 0.0,
    this.totalDeposits = 0.0,
    this.totalExpenditures = 0.0,
    double? remainingAmount,
    this.preSettlementRemaining = 0.0,
    this.settledAt,
    this.settledBy,
    this.notes = '',
    this.deposits = const [],
    this.purchasesCount = 0,
    this.createdAt,
    this.updatedAt,
  })  : id = id ?? 'settle_${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        remainingAmount = remainingAmount ??
            (totalDeposits - totalPaidForPurchases - totalExpenditures);

  bool get isSettled => status == 'settled';
  bool get isOpen => !isSettled;

  /// Formatted date key: YYYY-MM-DD
  String get dateString =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Sum of all deposits recorded in this model instance
  double get computedDepositsTotal =>
      deposits.fold<double>(0.0, (sum, d) => sum + d.amount);

  /// Total outflow actually paid out today (money paid to farmers + expenditures)
  double get totalPaidAmount => totalPaidForPurchases + totalExpenditures;

  /// Current remaining balance: deposit - totalPaidAmount (paid for purchases + expenditures)
  /// When settled, the remaining balance for the day is closed out to 0.0.
  double get effectiveRemainingAmount {
    if (isSettled) return 0.0;
    return computedDepositsTotal - totalPaidForPurchases - totalExpenditures;
  }

  /// Surplus amount if deposits exceed total paid outflows for the day
  double get surplusAmount {
    final diff = effectiveRemainingAmount;
    return diff > 0 ? diff : 0.0;
  }

  DailySettlementModel copyWith({
    String? id,
    DateTime? date,
    String? status,
    double? totalPurchases,
    double? totalPaidForPurchases,
    double? totalDeposits,
    double? totalExpenditures,
    double? remainingAmount,
    double? preSettlementRemaining,
    DateTime? settledAt,
    String? settledBy,
    String? notes,
    List<DailyDepositEntry>? deposits,
    int? purchasesCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailySettlementModel(
      id: id ?? this.id,
      date: date ?? this.date,
      status: status ?? this.status,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      totalPaidForPurchases:
          totalPaidForPurchases ?? this.totalPaidForPurchases,
      totalDeposits: totalDeposits ?? this.totalDeposits,
      totalExpenditures: totalExpenditures ?? this.totalExpenditures,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      preSettlementRemaining:
          preSettlementRemaining ?? this.preSettlementRemaining,
      settledAt: settledAt ?? this.settledAt,
      settledBy: settledBy ?? this.settledBy,
      notes: notes ?? this.notes,
      deposits: deposits ?? this.deposits,
      purchasesCount: purchasesCount ?? this.purchasesCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Builds a settlement model combining business purchases and deposit transactions
  /// for a specific business date using the formula:
  /// remaining balance = deposit - totalPaidAmount (expenditure or paid for purchased)
  factory DailySettlementModel.fromActivity({
    required DateTime date,
    required List<PurchaseModel> purchases,
    required List<DailyDepositEntry> deposits,
    List<ExpenditureModel> expenditures = const [],
    DailySettlementModel? existingRecord,
    String? notes,
  }) {
    final normDate = DateTime(date.year, date.month, date.day);
    final dateStr =
        '${normDate.year.toString().padLeft(4, '0')}-${normDate.month.toString().padLeft(2, '0')}-${normDate.day.toString().padLeft(2, '0')}';

    // 1. Filter purchases matching this calendar day
    final dayPurchases = purchases.where((p) {
      final pDate = DateTime(p.dateTime.year, p.dateTime.month, p.dateTime.day);
      return pDate.isAtSameMomentAs(normDate);
    }).toList();

    // 2. Filter deposits matching this calendar day
    final dayDeposits = deposits.where((d) {
      final dDate = DateTime(d.date.year, d.date.month, d.date.day);
      return dDate.isAtSameMomentAs(normDate);
    }).toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    // 3. Filter expenditures matching this calendar day
    final dayExpenditures = expenditures.where((e) {
      final eDate = DateTime(e.date.year, e.date.month, e.date.day);
      return eDate.isAtSameMomentAs(normDate);
    }).toList();

    final totalPurch = dayPurchases.fold<double>(0.0, (sum, p) => sum + p.totalAmount);
    final totalDep = dayDeposits.fold<double>(0.0, (sum, d) => sum + d.amount);
    final totalExp = dayExpenditures.isNotEmpty
        ? dayExpenditures.fold<double>(0.0, (sum, e) => sum + e.amount)
        : (existingRecord?.totalExpenditures ?? 0.0);

    // 4. Calculate total money actually paid for purchases on this business day
    double totalPaidForPurchases = 0.0;
    for (final p in purchases) {
      if (p.payments.isNotEmpty) {
        for (final pay in p.payments) {
          final payDate = DateTime(pay.date.year, pay.date.month, pay.date.day);
          if (payDate.isAtSameMomentAs(normDate)) {
            totalPaidForPurchases += pay.amount;
          }
        }
      } else {
        // Fallback for legacy purchase entries without payments breakdown
        final pDate = DateTime(p.dateTime.year, p.dateTime.month, p.dateTime.day);
        if (pDate.isAtSameMomentAs(normDate)) {
          totalPaidForPurchases += p.totalAmountPaid;
        }
      }
    }

    final isAlreadySettled = existingRecord?.status == 'settled';

    // Formula: deposit - totalPaidAmount(expenditure or paid for the purchased)
    final calculatedBalance = totalDep - totalPaidForPurchases - totalExp;

    return DailySettlementModel(
      id: existingRecord?.id ?? 'settle_$dateStr',
      date: normDate,
      status: isAlreadySettled ? 'settled' : (existingRecord?.status ?? 'open'),
      totalPurchases: totalPurch,
      totalPaidForPurchases: totalPaidForPurchases,
      totalDeposits: totalDep,
      totalExpenditures: totalExp,
      remainingAmount: calculatedBalance,
      preSettlementRemaining: isAlreadySettled
          ? (existingRecord?.preSettlementRemaining ?? calculatedBalance)
          : calculatedBalance,
      settledAt: existingRecord?.settledAt,
      settledBy: existingRecord?.settledBy,
      notes: notes ?? existingRecord?.notes ?? '',
      deposits: dayDeposits,
      purchasesCount: dayPurchases.length,
      createdAt: existingRecord?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': dateString,
        'status': status,
        'totalPurchases': totalPurchases,
        'totalPaidForPurchases': totalPaidForPurchases,
        'totalDeposits': totalDeposits,
        'totalExpenditures': totalExpenditures,
        'remainingAmount': remainingAmount,
        'preSettlementRemaining': preSettlementRemaining,
        'settledAt': settledAt?.toIso8601String(),
        'settledBy': settledBy,
        'notes': notes,
        'deposits': deposits.map((d) => d.toJson()).toList(),
        'purchasesCount': purchasesCount,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'date': dateString,
        'status': status,
        'total_purchases': totalPurchases,
        'total_paid_purchases': totalPaidForPurchases,
        'total_deposits': totalDeposits,
        'total_expenditures': totalExpenditures,
        'remaining_amount': remainingAmount,
        'pre_settlement_remaining': preSettlementRemaining,
        'settled_at': settledAt?.toIso8601String(),
        'settled_by': settledBy,
        'notes': notes,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
        'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      };

  factory DailySettlementModel.fromJson(
    Map<String, dynamic> json, {
    List<DailyDepositEntry>? deposits,
  }) {
    DateTime parsedDate;
    final rawDate = json['date']?.toString() ?? '';
    if (rawDate.contains('T')) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      final parts = rawDate.split('-');
      if (parts.length == 3) {
        parsedDate = DateTime(
          int.tryParse(parts[0]) ?? DateTime.now().year,
          int.tryParse(parts[1]) ?? DateTime.now().month,
          int.tryParse(parts[2]) ?? DateTime.now().day,
        );
      } else {
        parsedDate = DateTime.now();
      }
    }

    List<DailyDepositEntry> depList = deposits ?? [];
    if (json['deposits'] != null && json['deposits'] is List) {
      depList = (json['deposits'] as List)
          .map((item) => DailyDepositEntry.fromJson(
              item is String ? jsonDecode(item) : Map<String, dynamic>.from(item)))
          .toList();
    }

    final status = json['status']?.toString() ?? 'open';
    final totalPurch =
        double.tryParse(json['totalPurchases']?.toString() ?? json['total_purchases']?.toString() ?? '0') ?? 0;
    final totalDep =
        double.tryParse(json['totalDeposits']?.toString() ?? json['total_deposits']?.toString() ?? '0') ?? 0;
    final totalExp =
        double.tryParse(json['totalExpenditures']?.toString() ?? json['total_expenditures']?.toString() ?? '0') ?? 0;
    final rawPaidPurch =
        json['totalPaidForPurchases'] ?? json['total_paid_purchases'];
    final totalPaidPurch = rawPaidPurch != null
        ? (double.tryParse(rawPaidPurch.toString()) ?? 0.0)
        : 0.0;
    final calculatedBalance = totalDep - totalPaidPurch - totalExp;
    final rem = double.tryParse(json['remainingAmount']?.toString() ?? json['remaining_amount']?.toString() ?? '') ?? calculatedBalance;

    return DailySettlementModel(
      id: json['id']?.toString(),
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      status: status,
      totalPurchases: totalPurch,
      totalPaidForPurchases: totalPaidPurch,
      totalDeposits: totalDep,
      totalExpenditures: totalExp,
      remainingAmount: rem,
      preSettlementRemaining: double.tryParse(json['preSettlementRemaining']?.toString() ??
              json['pre_settlement_remaining']?.toString() ??
              '') ??
          calculatedBalance,
      settledAt: DateTime.tryParse(json['settledAt']?.toString() ?? json['settled_at']?.toString() ?? ''),
      settledBy: (json['settledBy'] ?? json['settled_by'])?.toString(),
      notes: json['notes']?.toString() ?? '',
      deposits: depList,
      purchasesCount: int.tryParse(json['purchasesCount']?.toString() ?? json['purchases_count']?.toString() ?? '0') ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? json['updated_at']?.toString() ?? ''),
    );
  }
}
