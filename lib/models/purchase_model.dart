import 'dart:convert';

/// A single payment installment made for a purchase.
/// Tracks amount, date, payment method (Cash, UPI, etc.), and optional note.
class PaymentEntry {
  final String id;
  final double amount;
  final DateTime date;
  final String paymentMode; // e.g. 'Cash', 'UPI / Online', 'Bank Transfer', 'Cheque'
  final String notes;

  PaymentEntry({
    String? id,
    required this.amount,
    required this.date,
    this.paymentMode = 'Cash',
    this.notes = '',
  }) : id = id ?? 'pay_${date.millisecondsSinceEpoch}_${amount.toInt()}';

  PaymentEntry copyWith({
    String? id,
    double? amount,
    DateTime? date,
    String? paymentMode,
    String? notes,
  }) {
    return PaymentEntry(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      paymentMode: paymentMode ?? this.paymentMode,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'date': date.toIso8601String(),
        'paymentMode': paymentMode,
        'notes': notes,
      };

  factory PaymentEntry.fromJson(Map<String, dynamic> json) => PaymentEntry(
        id: json['id']?.toString(),
        amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
        date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
        paymentMode: (json['paymentMode'] ?? json['payment_mode'])?.toString() ?? 'Cash',
        notes: json['notes']?.toString() ?? '',
      );
}

/// Represents one "Buy" entry: crop bought from a farmer.
/// Supports:
/// - Gross quantity and unit (Quintal / Kg / Ton)
/// - "Suits" (wastage / tare / bag deduction entered in kg)
/// - Net quantity = Gross quantity - suitsInUnit
/// - Total crop amount = Net quantity * pricePerUnit
/// - Multiple payment installments over time (payments list)
/// - totalAmountPaid = sum of all payment installments (computed getter)
/// - remainingBalance = Total crop amount - totalAmountPaid
/// - isPaid = true when remaining balance reaches ₹0.00
/// - isPending = true when remaining balance > 0
class PurchaseModel {
  final String id;
  final String cropName;
  final String farmerName;
  final String farmerPhone;
  final String farmerAddress;
  final String farmerDetails; // phone / village / combined note
  final String workerName;
  final String workerPhone;
  final String workerAddress;
  final double quantity; // Gross quantity
  final double suitsKg; // Deduction in kg (Suits / Chhoot / Wastage)
  final String unit; // Quintal / Kg / Ton
  final double pricePerUnit;

  /// All payment installments made to this farmer for this purchase.
  /// Kept sorted by date when displayed.
  final List<PaymentEntry> payments;
  final DateTime dateTime;

  PurchaseModel({
    required this.id,
    required this.cropName,
    required this.farmerName,
    this.farmerPhone = '',
    this.farmerAddress = '',
    String? farmerDetails,
    this.workerName = '',
    this.workerPhone = '',
    this.workerAddress = '',
    required this.quantity,
    this.suitsKg = 0.0,
    required this.unit,
    required this.pricePerUnit,
    this.payments = const [],
    required this.dateTime,
  }) : farmerDetails = (farmerDetails != null && farmerDetails.isNotEmpty)
            ? farmerDetails
            : (farmerPhone.isNotEmpty && farmerAddress.isNotEmpty
                ? '$farmerPhone, $farmerAddress'
                : (farmerPhone.isNotEmpty ? farmerPhone : farmerAddress));

  /// Converts suits in KG into the active unit (Quintal, Ton, or Kg).
  double get suitsInUnit {
    if (suitsKg <= 0) return 0.0;
    final lower = unit.toLowerCase();
    if (lower.contains('quintal')) return suitsKg / 100.0;
    if (lower.contains('ton')) return suitsKg / 1000.0;
    return suitsKg;
  }

  /// Net payable quantity after deducting suits (in current unit).
  double get netQuantity {
    final net = quantity - suitsInUnit;
    return net > 0 ? net : 0.0;
  }

  /// Converts the net payable crop quantity to Kilograms (Kg).
  double get netQuantityKg {
    final lower = unit.toLowerCase();
    if (lower.contains('quintal')) return netQuantity * 100.0;
    if (lower.contains('ton')) return netQuantity * 1000.0;
    return netQuantity;
  }

  /// Converts the gross quantity to Kilograms (Kg).
  double get grossQuantityKg {
    final lower = unit.toLowerCase();
    if (lower.contains('quintal')) return quantity * 100.0;
    if (lower.contains('ton')) return quantity * 1000.0;
    return quantity;
  }

  /// Total purchase value for the net crop quantity (Net Quantity × Price per Unit).
  double get totalAmount => netQuantity * pricePerUnit;

  /// Total amount paid across all payment installments.
  double get totalAmountPaid =>
      payments.fold<double>(0, (sum, p) => sum + p.amount);

  /// Backward-compatible alias for totalAmountPaid.
  double get advancePaid => totalAmountPaid;

  /// Remaining balance to be paid (Total Amount - Total Amount Paid).
  double get remainingBalance => totalAmount - totalAmountPaid;

  /// Backward-compatible alias for remainingBalance.
  double get netPayable => remainingBalance;

  /// Balance due helper (guaranteed non-negative).
  double get balanceDue => remainingBalance > 0 ? remainingBalance : 0.0;

  /// True when the remaining balance reaches ₹0.00 (Fully Paid).
  bool get isPaid =>
      (totalAmount > 0 && remainingBalance <= 0.0001) ||
      (payments.isNotEmpty && remainingBalance <= 0.0001);

  /// Backward-compatible alias for isPaid.
  bool get isClosed => isPaid;

  /// True if there is still an amount remaining.
  bool get isPending => remainingBalance > 0.0001;

  /// String status: "Paid" or "Pending".
  String get paymentStatus => isPaid ? 'Paid' : 'Pending';

  /// Returns payments sorted in chronological order (oldest to newest).
  List<PaymentEntry> get sortedPayments =>
      [...payments]..sort((a, b) => a.date.compareTo(b.date));

  PurchaseModel copyWith({
    String? id,
    String? cropName,
    String? farmerName,
    String? farmerPhone,
    String? farmerAddress,
    String? farmerDetails,
    String? workerName,
    String? workerPhone,
    String? workerAddress,
    double? quantity,
    double? suitsKg,
    String? unit,
    double? pricePerUnit,
    List<PaymentEntry>? payments,
    DateTime? dateTime,
  }) {
    return PurchaseModel(
      id: id ?? this.id,
      cropName: cropName ?? this.cropName,
      farmerName: farmerName ?? this.farmerName,
      farmerPhone: farmerPhone ?? this.farmerPhone,
      farmerAddress: farmerAddress ?? this.farmerAddress,
      farmerDetails: farmerDetails ?? this.farmerDetails,
      workerName: workerName ?? this.workerName,
      workerPhone: workerPhone ?? this.workerPhone,
      workerAddress: workerAddress ?? this.workerAddress,
      quantity: quantity ?? this.quantity,
      suitsKg: suitsKg ?? this.suitsKg,
      unit: unit ?? this.unit,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      payments: payments ?? this.payments,
      dateTime: dateTime ?? this.dateTime,
    );
  }

  /// What gets sent to Google Sheets and saved locally.
  Map<String, dynamic> toJson() => {
        'id': id,
        'cropName': cropName,
        'farmerName': farmerName,
        'farmerPhone': farmerPhone,
        'farmerAddress': farmerAddress,
        'farmerDetails': farmerDetails,
        'workerName': workerName,
        'workerPhone': workerPhone,
        'workerAddress': workerAddress,
        'quantity': quantity,
        'suitsKg': suitsKg,
        'netQuantity': netQuantity,
        'unit': unit,
        'pricePerUnit': pricePerUnit,
        'totalAmount': totalAmount,
        'advancePaid': totalAmountPaid,
        'netPayable': remainingBalance,
        'status': paymentStatus,
        'payments': payments.map((p) => p.toJson()).toList(),
        'date': dateTime.toIso8601String(),
      };

  /// Maps to Supabase PostgreSQL table columns.
  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'crop_name': cropName,
        'farmer_name': farmerName,
        'farmer_phone': farmerPhone,
        'farmer_address': farmerAddress,
        'farmer_details': farmerDetails,
        'worker_name': workerName,
        'worker_phone': workerPhone,
        'worker_address': workerAddress,
        'quantity': quantity,
        'suits_kg': suitsKg,
        'net_quantity': netQuantity,
        'unit': unit,
        'price_per_unit': pricePerUnit,
        'total_amount': totalAmount,
        'advance_paid': totalAmountPaid,
        'net_payable': remainingBalance,
        'payments': payments.map((p) => p.toJson()).toList(),
        'date': dateTime.toIso8601String(),
      };

  /// Builds a model back from Supabase, Sheets, or local storage JSON.
  /// Auto-migrates legacy single advancePaid into a payments list entry.
  factory PurchaseModel.fromJson(Map<String, dynamic> json) {
    final phone =
        (json['farmerPhone'] ?? json['farmer_phone'])?.toString() ?? '';
    final address =
        (json['farmerAddress'] ?? json['farmer_address'])?.toString() ?? '';
    final details =
        (json['farmerDetails'] ?? json['farmer_details'])?.toString() ?? '';
    final worker =
        (json['workerName'] ?? json['worker_name'])?.toString() ?? '';
    final workerPh =
        (json['workerPhone'] ?? json['worker_phone'])?.toString() ?? '';
    final workerAddr =
        (json['workerAddress'] ?? json['worker_address'])?.toString() ?? '';
    final crop = (json['cropName'] ?? json['crop_name'])?.toString() ?? '';
    final farmer =
        (json['farmerName'] ?? json['farmer_name'])?.toString() ?? '';
    final price =
        (json['pricePerUnit'] ?? json['price_per_unit'])?.toString() ?? '';
    final dateStr =
        (json['date'] ?? json['created_at'])?.toString() ?? '';
    final suitsStr =
        (json['suitsKg'] ?? json['suits_kg'])?.toString() ?? '0';
    final advanceStr =
        (json['advancePaid'] ?? json['advance_paid'])?.toString() ?? '0';
    final purchaseDate = DateTime.tryParse(dateStr) ?? DateTime.now();

    // Parse payments list (handling both List and JSON string if serialized that way)
    List<PaymentEntry> payments = [];
    dynamic rawPayments = json['payments'];
    if (rawPayments is String && rawPayments.isNotEmpty) {
      try {
        rawPayments = jsonDecode(rawPayments);
      } catch (_) {}
    }
    if (rawPayments != null && rawPayments is List && rawPayments.isNotEmpty) {
      payments = rawPayments
          .map((e) => PaymentEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    } else {
      final advanceLegacy = double.tryParse(advanceStr) ?? 0;
      if (advanceLegacy > 0) {
        // Migrate: treat the old single advance as a dated payment entry.
        payments = [
          PaymentEntry(
            amount: advanceLegacy,
            date: purchaseDate,
            paymentMode: 'Cash',
            notes: 'Advance Paid',
          )
        ];
      }
    }

    return PurchaseModel(
      id: json['id']?.toString() ?? '',
      cropName: crop,
      farmerName: farmer,
      farmerPhone: phone,
      farmerAddress: address.isNotEmpty ? address : details,
      farmerDetails: details.isNotEmpty
          ? details
          : (phone.isNotEmpty && address.isNotEmpty
              ? '$phone, $address'
              : (phone.isNotEmpty ? phone : address)),
      workerName: worker,
      workerPhone: workerPh,
      workerAddress: workerAddr,
      quantity: double.tryParse(json['quantity']?.toString() ?? '') ?? 0,
      suitsKg: double.tryParse(suitsStr) ?? 0,
      unit: json['unit']?.toString() ?? '',
      pricePerUnit: double.tryParse(price) ?? 0,
      payments: payments,
      dateTime: purchaseDate,
    );
  }
}
