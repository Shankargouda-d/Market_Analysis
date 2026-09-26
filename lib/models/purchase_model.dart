/// Represents one "Buy" entry: crop bought from a farmer.
class PurchaseModel {
  final String id;
  final String cropName;
  final String farmerName;
  final String farmerPhone;
  final String farmerAddress;
  final String farmerDetails; // phone / village / combined note
  final double quantity;
  final String unit; // Quintal / Kg / Ton
  final double pricePerUnit;
  final DateTime dateTime;

  PurchaseModel({
    required this.id,
    required this.cropName,
    required this.farmerName,
    this.farmerPhone = '',
    this.farmerAddress = '',
    String? farmerDetails,
    required this.quantity,
    required this.unit,
    required this.pricePerUnit,
    required this.dateTime,
  }) : farmerDetails = (farmerDetails != null && farmerDetails.isNotEmpty)
            ? farmerDetails
            : (farmerPhone.isNotEmpty && farmerAddress.isNotEmpty
                ? '$farmerPhone, $farmerAddress'
                : (farmerPhone.isNotEmpty ? farmerPhone : farmerAddress));

  double get totalAmount => quantity * pricePerUnit;

  PurchaseModel copyWith({
    String? id,
    String? cropName,
    String? farmerName,
    String? farmerPhone,
    String? farmerAddress,
    String? farmerDetails,
    double? quantity,
    String? unit,
    double? pricePerUnit,
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
      unit: unit ?? this.unit,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
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
        'unit': unit,
        'pricePerUnit': pricePerUnit,
        'totalAmount': totalAmount,
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
        'unit': unit,
        'price_per_unit': pricePerUnit,
        'total_amount': totalAmount,
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
      unit: json['unit']?.toString() ?? '',
      pricePerUnit: double.tryParse(price) ?? 0,
      dateTime: DateTime.tryParse(dateStr) ?? DateTime.now(),
    );
  }
}
