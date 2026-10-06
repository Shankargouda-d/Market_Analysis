import 'dart:convert';
import 'expenditure_model.dart';
import 'purchase_model.dart';
import 'sale_model.dart';

/// Single crop performance metric within a daily analysis.
class CropAnalysisStat {
  final String cropName;
  final double boughtAmount;
  final double soldAmount;
  final double qtyBought;
  final double qtySold;

  CropAnalysisStat({
    required this.cropName,
    required this.boughtAmount,
    required this.soldAmount,
    required this.qtyBought,
    required this.qtySold,
  });

  double get net => soldAmount - boughtAmount;
  bool get isProfit => net >= 0;

  Map<String, dynamic> toJson() => {
        'cropName': cropName,
        'boughtAmount': boughtAmount,
        'soldAmount': soldAmount,
        'qtyBought': qtyBought,
        'qtySold': qtySold,
        'net': net,
      };

  factory CropAnalysisStat.fromJson(Map<String, dynamic> json) =>
      CropAnalysisStat(
        cropName: json['cropName']?.toString() ?? '',
        boughtAmount:
            double.tryParse(json['boughtAmount']?.toString() ?? '0') ?? 0,
        soldAmount: double.tryParse(json['soldAmount']?.toString() ?? '0') ?? 0,
        qtyBought: double.tryParse(json['qtyBought']?.toString() ?? '0') ?? 0,
        qtySold: double.tryParse(json['qtySold']?.toString() ?? '0') ?? 0,
      );
}

/// Permanent record of a day's business analysis, stored permanently in the database.
/// Tracks financial totals, crop breakdown, expenditure categories, and exact timestamps.
class DailyAnalysisModel {
  final String id;
  final DateTime date; // The calendar day of activity (normalized YYYY-MM-DD)
  final DateTime dateTime; // Exact calculation / recording timestamp
  final double totalBought;
  final double totalSold;
  final double totalExpenditures;
  final double netProfit;
  final int purchasesCount;
  final int salesCount;
  final int expendituresCount;
  final Map<String, CropAnalysisStat> cropStats;
  final Map<String, double> expenditureStats;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DailyAnalysisModel({
    required this.id,
    required this.date,
    required this.dateTime,
    required this.totalBought,
    required this.totalSold,
    required this.totalExpenditures,
    required this.netProfit,
    this.purchasesCount = 0,
    this.salesCount = 0,
    this.expendituresCount = 0,
    this.cropStats = const {},
    this.expenditureStats = const {},
    this.createdAt,
    this.updatedAt,
  });

  bool get isProfit => netProfit >= 0;

  /// Formatted date key: YYYY-MM-DD
  String get dateString =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Generates a DailyAnalysisModel from actual stored database records.
  factory DailyAnalysisModel.fromTransactions({
    required DateTime date,
    required List<PurchaseModel> purchases,
    required List<SaleModel> sales,
    required List<ExpenditureModel> expenditures,
    DateTime? calculationTime,
  }) {
    final normDate = DateTime(date.year, date.month, date.day);
    final calcTime = calculationTime ?? DateTime.now();
    final dateStr =
        '${normDate.year.toString().padLeft(4, '0')}-${normDate.month.toString().padLeft(2, '0')}-${normDate.day.toString().padLeft(2, '0')}';

    // Filter transactions matching this calendar day
    final dayPurchases = purchases.where((p) =>
        p.dateTime.year == normDate.year &&
        p.dateTime.month == normDate.month &&
        p.dateTime.day == normDate.day).toList();

    final daySales = sales.where((s) =>
        s.dateTime.year == normDate.year &&
        s.dateTime.month == normDate.month &&
        s.dateTime.day == normDate.day).toList();

    final dayExpenditures = expenditures.where((e) =>
        e.date.year == normDate.year &&
        e.date.month == normDate.month &&
        e.date.day == normDate.day).toList();

    final totalBought =
        dayPurchases.fold<double>(0, (sum, p) => sum + p.totalAmount);
    final totalSold = daySales.fold<double>(0, (sum, s) => sum + s.soldAmount);
    final totalExpenditures =
        dayExpenditures.fold<double>(0, (sum, e) => sum + e.amount);
    final netProfit = totalSold - totalBought - totalExpenditures;

    final Map<String, CropAnalysisStat> cropMap = {};
    for (final p in dayPurchases) {
      final existing = cropMap[p.cropName];
      cropMap[p.cropName] = CropAnalysisStat(
        cropName: p.cropName,
        boughtAmount: (existing?.boughtAmount ?? 0) + p.totalAmount,
        soldAmount: existing?.soldAmount ?? 0,
        qtyBought: (existing?.qtyBought ?? 0) + p.quantity,
        qtySold: existing?.qtySold ?? 0,
      );
    }
    for (final s in daySales) {
      final existing = cropMap[s.cropName];
      cropMap[s.cropName] = CropAnalysisStat(
        cropName: s.cropName,
        boughtAmount: existing?.boughtAmount ?? 0,
        soldAmount: (existing?.soldAmount ?? 0) + s.soldAmount,
        qtyBought: existing?.qtyBought ?? 0,
        qtySold: (existing?.qtySold ?? 0) + s.quantity,
      );
    }

    final Map<String, double> expMap = {};
    for (final e in dayExpenditures) {
      expMap[e.category] = (expMap[e.category] ?? 0) + e.amount;
    }

    return DailyAnalysisModel(
      id: 'analysis_$dateStr',
      date: normDate,
      dateTime: calcTime,
      totalBought: totalBought,
      totalSold: totalSold,
      totalExpenditures: totalExpenditures,
      netProfit: netProfit,
      purchasesCount: dayPurchases.length,
      salesCount: daySales.length,
      expendituresCount: dayExpenditures.length,
      cropStats: cropMap,
      expenditureStats: expMap,
      createdAt: calcTime,
      updatedAt: calcTime,
    );
  }

  /// Builds a cumulative all-time analysis model for overall performance.
  factory DailyAnalysisModel.cumulative({
    required List<PurchaseModel> purchases,
    required List<SaleModel> sales,
    required List<ExpenditureModel> expenditures,
  }) {
    final now = DateTime.now();
    final totalBought =
        purchases.fold<double>(0, (sum, p) => sum + p.totalAmount);
    final totalSold = sales.fold<double>(0, (sum, s) => sum + s.soldAmount);
    final totalExpenditures =
        expenditures.fold<double>(0, (sum, e) => sum + e.amount);
    final netProfit = totalSold - totalBought - totalExpenditures;

    final Map<String, CropAnalysisStat> cropMap = {};
    for (final p in purchases) {
      final existing = cropMap[p.cropName];
      cropMap[p.cropName] = CropAnalysisStat(
        cropName: p.cropName,
        boughtAmount: (existing?.boughtAmount ?? 0) + p.totalAmount,
        soldAmount: existing?.soldAmount ?? 0,
        qtyBought: (existing?.qtyBought ?? 0) + p.quantity,
        qtySold: existing?.qtySold ?? 0,
      );
    }
    for (final s in sales) {
      final existing = cropMap[s.cropName];
      cropMap[s.cropName] = CropAnalysisStat(
        cropName: s.cropName,
        boughtAmount: existing?.boughtAmount ?? 0,
        soldAmount: (existing?.soldAmount ?? 0) + s.soldAmount,
        qtyBought: existing?.qtyBought ?? 0,
        qtySold: (existing?.qtySold ?? 0) + s.quantity,
      );
    }

    final Map<String, double> expMap = {};
    for (final e in expenditures) {
      expMap[e.category] = (expMap[e.category] ?? 0) + e.amount;
    }

    return DailyAnalysisModel(
      id: 'analysis_cumulative',
      date: DateTime(now.year, now.month, now.day),
      dateTime: now,
      totalBought: totalBought,
      totalSold: totalSold,
      totalExpenditures: totalExpenditures,
      netProfit: netProfit,
      purchasesCount: purchases.length,
      salesCount: sales.length,
      expendituresCount: expenditures.length,
      cropStats: cropMap,
      expenditureStats: expMap,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': dateString,
        'dateTime': dateTime.toIso8601String(),
        'totalBought': totalBought,
        'totalSold': totalSold,
        'totalExpenditures': totalExpenditures,
        'netProfit': netProfit,
        'purchasesCount': purchasesCount,
        'salesCount': salesCount,
        'expendituresCount': expendituresCount,
        'cropStats': cropStats.map((k, v) => MapEntry(k, v.toJson())),
        'expenditureStats': expenditureStats,
        'createdAt': (createdAt ?? dateTime).toIso8601String(),
        'updatedAt': (updatedAt ?? dateTime).toIso8601String(),
      };

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'date': dateString,
        'date_time': dateTime.toIso8601String(),
        'total_bought': totalBought,
        'total_sold': totalSold,
        'total_expenditures': totalExpenditures,
        'net_profit': netProfit,
        'purchases_count': purchasesCount,
        'sales_count': salesCount,
        'expenditures_count': expendituresCount,
        'crop_stats': cropStats.map((k, v) => MapEntry(k, v.toJson())),
        'expenditure_stats': expenditureStats,
        'created_at': (createdAt ?? dateTime).toIso8601String(),
        'updated_at': (updatedAt ?? dateTime).toIso8601String(),
      };

  factory DailyAnalysisModel.fromJson(Map<String, dynamic> json) {
    final dateStr = (json['date'] ?? json['date_time'])?.toString() ?? '';
    final dateTimeStr = (json['dateTime'] ??
            json['date_time'] ??
            json['updated_at'] ??
            json['created_at'])
        ?.toString() ??
        '';

    final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
    final parsedDateTime = DateTime.tryParse(dateTimeStr) ?? DateTime.now();

    // Parse cropStats
    final Map<String, CropAnalysisStat> cropMap = {};
    dynamic rawCrops = json['cropStats'] ?? json['crop_stats'];
    if (rawCrops is String && rawCrops.isNotEmpty) {
      try {
        rawCrops = jsonDecode(rawCrops);
      } catch (_) {}
    }
    if (rawCrops is Map) {
      rawCrops.forEach((k, v) {
        if (v is Map) {
          cropMap[k.toString()] =
              CropAnalysisStat.fromJson(Map<String, dynamic>.from(v));
        }
      });
    }

    // Parse expenditureStats
    final Map<String, double> expMap = {};
    dynamic rawExp = json['expenditureStats'] ?? json['expenditure_stats'];
    if (rawExp is String && rawExp.isNotEmpty) {
      try {
        rawExp = jsonDecode(rawExp);
      } catch (_) {}
    }
    if (rawExp is Map) {
      rawExp.forEach((k, v) {
        expMap[k.toString()] = double.tryParse(v.toString()) ?? 0;
      });
    }

    final tb = double.tryParse(
            (json['totalBought'] ?? json['total_bought'])?.toString() ?? '0') ??
        0;
    final ts = double.tryParse(
            (json['totalSold'] ?? json['total_sold'])?.toString() ?? '0') ??
        0;
    final te = double.tryParse((json['totalExpenditures'] ??
                json['total_expenditures'])
            ?.toString() ??
        '0') ??
        0;
    final np = double.tryParse(
            (json['netProfit'] ?? json['net_profit'])?.toString() ?? '0') ??
        (ts - tb - te);

    final pCount = int.tryParse((json['purchasesCount'] ??
                json['purchases_count'])
            ?.toString() ??
        '0') ??
        0;
    final sCount = int.tryParse(
            (json['salesCount'] ?? json['sales_count'])?.toString() ?? '0') ??
        0;
    final eCount = int.tryParse((json['expendituresCount'] ??
                json['expenditures_count'])
            ?.toString() ??
        '0') ??
        0;

    final cAt = DateTime.tryParse(
        (json['createdAt'] ?? json['created_at'])?.toString() ?? '');
    final uAt = DateTime.tryParse(
        (json['updatedAt'] ?? json['updated_at'])?.toString() ?? '');

    return DailyAnalysisModel(
      id: json['id']?.toString() ??
          'analysis_${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}',
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      dateTime: parsedDateTime,
      totalBought: tb,
      totalSold: ts,
      totalExpenditures: te,
      netProfit: np,
      purchasesCount: pCount,
      salesCount: sCount,
      expendituresCount: eCount,
      cropStats: cropMap,
      expenditureStats: expMap,
      createdAt: cAt,
      updatedAt: uAt,
    );
  }
}
