/// Represents one "Sell" entry: crop sold to a factory.
class SaleModel {
  final String id;
  final String cropName;
  final String factoryName;
  final String factoryContact;
  final String factoryAddress;
  final double quantity;
  final String unit; // Quintal / Kg / Ton
  final double soldAmount; // total amount received for the quantity
  final DateTime dateTime;

  SaleModel({
    required this.id,
    required this.cropName,
    required this.factoryName,
    this.factoryContact = '',
    this.factoryAddress = '',
    required this.quantity,
    required this.unit,
    required this.soldAmount,
    required this.dateTime,
  });

  double get pricePerUnit => quantity == 0 ? 0 : soldAmount / quantity;

  SaleModel copyWith({
    String? id,
    String? cropName,
    String? factoryName,
    String? factoryContact,
    String? factoryAddress,
    double? quantity,
    String? unit,
    double? soldAmount,
    DateTime? dateTime,
  }) {
    return SaleModel(
      id: id ?? this.id,
      cropName: cropName ?? this.cropName,
      factoryName: factoryName ?? this.factoryName,
      factoryContact: factoryContact ?? this.factoryContact,
      factoryAddress: factoryAddress ?? this.factoryAddress,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      soldAmount: soldAmount ?? this.soldAmount,
      dateTime: dateTime ?? this.dateTime,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cropName': cropName,
        'factoryName': factoryName,
        'factoryContact': factoryContact,
        'factoryAddress': factoryAddress,
        'quantity': quantity,
        'unit': unit,
        'soldAmount': soldAmount,
        'pricePerUnit': pricePerUnit,
        'date': dateTime.toIso8601String(),
      };

  /// Maps to Supabase PostgreSQL table columns.
  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'crop_name': cropName,
        'factory_name': factoryName,
        'factory_contact': factoryContact,
        'factory_address': factoryAddress,
        'quantity': quantity,
        'unit': unit,
        'sold_amount': soldAmount,
        'price_per_unit': pricePerUnit,
        'date': dateTime.toIso8601String(),
      };

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    final crop = (json['cropName'] ?? json['crop_name'])?.toString() ?? '';
    final factoryN =
        (json['factoryName'] ?? json['factory_name'])?.toString() ?? '';
    final contact =
        (json['factoryContact'] ?? json['factory_contact'])?.toString() ?? '';
    final address =
        (json['factoryAddress'] ?? json['factory_address'])?.toString() ?? '';
    final soldAmt =
        (json['soldAmount'] ?? json['sold_amount'])?.toString() ?? '';
    final dateStr = (json['date'] ?? json['created_at'])?.toString() ?? '';

    return SaleModel(
      id: json['id']?.toString() ?? '',
      cropName: crop,
      factoryName: factoryN,
      factoryContact: contact,
      factoryAddress: address,
      quantity: double.tryParse(json['quantity']?.toString() ?? '') ?? 0,
      unit: json['unit']?.toString() ?? '',
      soldAmount: double.tryParse(soldAmt) ?? 0,
      dateTime: DateTime.tryParse(dateStr) ?? DateTime.now(),
    );
  }
}
