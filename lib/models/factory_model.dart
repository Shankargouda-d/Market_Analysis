/// Model representing a factory / mill profile and contact details.
class FactoryModel {
  final String id;
  final String name;
  final String contact;
  final String address;
  final DateTime createdAt;
  final String notes;

  FactoryModel({
    required this.id,
    required this.name,
    required this.contact,
    required this.address,
    DateTime? createdAt,
    this.notes = '',
  }) : createdAt = createdAt ?? DateTime.now();

  FactoryModel copyWith({
    String? id,
    String? name,
    String? contact,
    String? address,
    DateTime? createdAt,
    String? notes,
  }) {
    return FactoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      contact: contact ?? this.contact,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'contact': contact,
        'address': address,
        'createdAt': createdAt.toIso8601String(),
        'notes': notes,
      };

  /// Maps to Supabase PostgreSQL table columns.
  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'name': name,
        'contact': contact,
        'address': address,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory FactoryModel.fromJson(Map<String, dynamic> json) => FactoryModel(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        contact: (json['contact'] ?? json['phone'])?.toString() ?? '',
        address: json['address']?.toString() ?? '',
        createdAt: DateTime.tryParse(
                (json['createdAt'] ?? json['created_at'])?.toString() ?? '') ??
            DateTime.now(),
        notes: json['notes']?.toString() ?? '',
      );
}
