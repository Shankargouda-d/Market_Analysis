/// Represents one "Buy" entry: crop bought from a farmer.
/// Supports:
/// - Gross quantity and unit (Quintal / Kg / Ton)
/// - "Suits" (wastage / tare / bag deduction entered in kg)
/// - Net quantity = Gross quantity - suitsInUnit
/// - Total crop amount = Net quantity * pricePerUnit
/// - Advance paid amount (deducted from bill)
/// - Net payable = Total crop amount - advancePaid
class PurchaseModel {
  final String id;
  final String cropName;
  final String farmerName;
  final String farmerPhone;
  final String farmerAddress;
  final String farmerDetails; // phone / village / combined note
  final double quantity; // Gross quantity
  final double suitsKg; // Deduction in kg (Suits / Chhoot / Wastage)
  final String unit; // Quintal / Kg / Ton
  final double pricePerUnit;
  final double advancePaid; // Advance amount already paid to farmer
  final DateTime dateTime;

  PurchaseModel({
    required this.id,
    required this.cropName,
    required this.farmerName,
    this.farmerPhone = '',
    this.farmerAddress = '',
    String? farmerDetails,
    required this.quantity,
    this.suitsKg = 0.0,
    required this.unit,
    required this.pricePerUnit,
    this.advancePaid = 0.0,
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

  /// Total purchase value for the net crop quantity (Net Quantity × Price per Unit).
  double get totalAmount => netQuantity * pricePerUnit;

  /// Net amount payable to the farmer after subtracting advance paid.
  double get netPayable => totalAmount - advancePaid;

  /// Balance due to the farmer (non-negative helper).
  double get balanceDue => (totalAmount - advancePaid) > 0 ? (totalAmount - advancePaid) : 0.0;

  PurchaseModel copyWith({
    String? id,
    String? cropName,
    String? farmerName,
    String? farmerPhone,
    String? farmerAddress,
    String? farmerDetails,
    double? quantity,
    double? suitsKg,
    String? unit,
    double? pricePerUnit,
    double? advancePaid,
    DateTime? dateTime,
  }) {
    return PurchaseModel(
      id: id ?? this.id,
      cropName: cropName ?? this.cropName,
      farmerName: farmerName ?? this.farmerName,
      farmerPhone: farmerPhone ?? this.farmerPhone,
      farmerAddress: farmerAddress ?? this.farmerAddress,
      farmerDetails: farmerDetails ?? this.farmerDetails,
      quantity: quantity ?? this.quantity,
      suitsKg: suitsKg ?? this.suitsKg,
      unit: unit ?? this.unit,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      advancePaid: advancePaid ?? this.advancePaid,
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
        'quantity': quantity,
        'suitsKg': suitsKg,
        'netQuantity': netQuantity,
        'unit': unit,
        'pricePerUnit': pricePerUnit,
        'totalAmount': totalAmount,
        'advancePaid': advancePaid,
        'netPayable': netPayable,
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
        'quantity': quantity,
        'suits_kg': suitsKg,
        'net_quantity': netQuantity,
        'unit': unit,
        'price_per_unit': pricePerUnit,
        'total_amount': totalAmount,
        'advance_paid': advancePaid,
        'net_payable': netPayable,
        'date': dateTime.toIso8601String(),
      };

  /// Builds a model back from Supabase, Sheets, or local storage JSON.
  factory PurchaseModel.fromJson(Map<String, dynamic> json) {
    final phone =
        (json['farmerPhone'] ?? json['farmer_phone'])?.toString() ?? '';
    final address =
        (json['farmerAddress'] ?? json['farmer_address'])?.toString() ?? '';
    final details =
        (json['farmerDetails'] ?? json['farmer_details'])?.toString() ?? '';
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
      quantity: double.tryParse(json['quantity']?.toString() ?? '') ?? 0,
      suitsKg: double.tryParse(suitsStr) ?? 0,
      unit: json['unit']?.toString() ?? '',
      pricePerUnit: double.tryParse(price) ?? 0,
      advancePaid: double.tryParse(advanceStr) ?? 0,
      dateTime: DateTime.tryParse(dateStr) ?? DateTime.now(),
    );
  }
}
