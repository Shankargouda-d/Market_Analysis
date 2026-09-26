/// Model representing a farmer profile and contact details.
class FarmerModel {
  final String id;
  final String name;
  final String phone;
  final String address;
  final DateTime createdAt;
  final String notes;

  FarmerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    DateTime? createdAt,
    this.notes = '',
  }) : createdAt = createdAt ?? DateTime.now();

  FarmerModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    DateTime? createdAt,
    String? notes,
  }) {
    return FarmerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'createdAt': createdAt.toIso8601String(),
        'notes': notes,
      };

  /// Maps to Supabase PostgreSQL table columns.
  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory FarmerModel.fromJson(Map<String, dynamic> json) => FarmerModel(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        address: json['address']?.toString() ?? '',
        createdAt: DateTime.tryParse(
                (json['createdAt'] ?? json['created_at'])?.toString() ?? '') ??
            DateTime.now(),
        notes: json['notes']?.toString() ?? '',
      );
}
