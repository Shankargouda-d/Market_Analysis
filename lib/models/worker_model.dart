/// Model representing a worker/labor profile, role, wages, and status.
class WorkerModel {
  final String id;
  final String name;
  final String phone;
  final String role; // Loader, Weigher, Harvester, Driver, Sorter, General Labor
  final String address;
  final double dailyWage;
  final bool isPresentToday;
  final DateTime joinedDate;
  final String notes;

  WorkerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.address = '',
    required this.dailyWage,
    this.isPresentToday = false,
    DateTime? joinedDate,
    this.notes = '',
  }) : joinedDate = joinedDate ?? DateTime.now();

  WorkerModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? role,
    String? address,
    double? dailyWage,
    bool? isPresentToday,
    DateTime? joinedDate,
    String? notes,
  }) {
    return WorkerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      address: address ?? this.address,
      dailyWage: dailyWage ?? this.dailyWage,
      isPresentToday: isPresentToday ?? this.isPresentToday,
      joinedDate: joinedDate ?? this.joinedDate,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'role': role,
        'address': address,
        'dailyWage': dailyWage,
        'isPresentToday': isPresentToday,
        'joinedDate': joinedDate.toIso8601String(),
        'notes': notes,
      };

  /// Maps to Supabase PostgreSQL table columns.
  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'role': role,
        'address': address,
        'daily_wage': dailyWage,
        'is_present_today': isPresentToday,
        'joined_date': joinedDate.toIso8601String(),
        'notes': notes,
      };

  factory WorkerModel.fromJson(Map<String, dynamic> json) => WorkerModel(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        role: json['role']?.toString() ?? 'General Labor',
        address: json['address']?.toString() ?? '',
        dailyWage: double.tryParse(
                (json['dailyWage'] ?? json['daily_wage'])?.toString() ?? '') ??
            0,
        isPresentToday: (json['isPresentToday'] ?? json['is_present_today']) ==
                true ||
            (json['isPresentToday'] ?? json['is_present_today']) == 1 ||
            (json['isPresentToday'] ?? json['is_present_today'])?.toString() ==
                'true',
        joinedDate: DateTime.tryParse(
                (json['joinedDate'] ?? json['joined_date'])?.toString() ??
                    '') ??
            DateTime.now(),
        notes: json['notes']?.toString() ?? '',
      );
}
