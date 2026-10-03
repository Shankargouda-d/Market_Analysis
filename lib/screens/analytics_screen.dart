import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/expenditure_model.dart';
import '../models/purchase_model.dart';
import '../models/sale_model.dart';
import '../services/data_repository.dart';
import '../services/local_storage_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

/// Simple per-crop totals used to compute profit / loss.
class _CropStat {
  double bought = 0; // total ₹ spent buying this crop
  double sold = 0; // total ₹ received selling this crop
  double qtyBought = 0;
  double qtySold = 0;

  double get net => sold - bought;
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _loading = true;
  List<PurchaseModel> _purchases = [];
  List<SaleModel> _sales = [];
  List<ExpenditureModel> _expenditures = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 1. Instant load from local cache
    final cachedPurchases = await LocalStorageService.loadPurchases();
    final cachedSales = await LocalStorageService.loadSales();
    final cachedExpenditures = await LocalStorageService.loadExpenditures();
    if (mounted) {
      setState(() {
        _purchases = cachedPurchases;
        _sales = cachedSales;
        _expenditures = cachedExpenditures;
        _loading = false;
      });
    }

    // 2. Background sync with backend
    final purchases = await DataRepository.getPurchases(syncWithSheets: true);
    final sales = await DataRepository.getSales(syncWithSheets: true);
    final expenditures = await DataRepository.getExpenditures(syncWithBackend: true);
    if (!mounted) return;
    setState(() {
      _purchases = purchases;
      _sales = sales;
      _expenditures = expenditures;
      _loading = false;
    });
  }

  Map<String, _CropStat> _buildStats() {
    final stats = <String, _CropStat>{};
    for (final p in _purchases) {
      final s = stats.putIfAbsent(p.cropName, () => _CropStat());
      s.bought += p.totalAmount;
      s.qtyBought += p.quantity;
    }
    for (final s in _sales) {
      final st = stats.putIfAbsent(s.cropName, () => _CropStat());
      st.sold += s.soldAmount;
      st.qtySold += s.quantity;
    }
    return stats;
  }

  Map<String, double> _buildExpenditureStats() {
    final map = <String, double>{};
    for (final e in _expenditures) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = _buildStats();
    final expStats = _buildExpenditureStats();
    final totalBought = _purchases.fold<double>(0, (a, p) => a + p.totalAmount);
    final totalSold = _sales.fold<double>(0, (a, s) => a + s.soldAmount);
    final totalExpenditures = _expenditures.fold<double>(0, (a, e) => a + e.amount);
    final net = totalSold - totalBought - totalExpenditures;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _OverallCard(
            totalBought: totalBought,
            totalSold: totalSold,
            totalExpenditures: totalExpenditures,
            net: net,
          ),
          const SizedBox(height: 20),

          // Crop Performance Section
          const Text('Performance by Crop',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          if (stats.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: Text('No crop transactions yet',
                      style: TextStyle(color: AppColors.textSecondary))),
            ),
          ...stats.entries.map((e) => _CropStatTile(crop: e.key, stat: e.value)),

          const SizedBox(height: 20),

          // Other Expenditure Breakdown Section
          const Text('Other Expenditures by Category',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          if (expStats.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: Text('No expenditures recorded yet',
                      style: TextStyle(color: AppColors.textSecondary))),
            )
          else
            ...expStats.entries.map((entry) {
              final pct = totalExpenditures > 0 ? (entry.value / totalExpenditures * 100) : 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.expenditure,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.key,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text('${pct.toStringAsFixed(1)}% of total expenses',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Text(
                      '₹${entry.value.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.expenditure,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _OverallCard extends StatelessWidget {
  final double totalBought;
  final double totalSold;
  final double totalExpenditures;
  final double net;

  const _OverallCard({
    required this.totalBought,
    required this.totalSold,
    required this.totalExpenditures,
    required this.net,
  });

  @override
  Widget build(BuildContext context) {
    final isProfit = net >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Financial Summary',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                    label: 'Crop Purchases',
                    value: totalBought,
                    color: AppColors.buy),
              ),
              Expanded(
                child: _MiniStat(
                    label: 'Crop Sales',
                    value: totalSold,
                    color: AppColors.sell),
              ),
              Expanded(
                child: _MiniStat(
                    label: 'Expenditure',
                    value: totalExpenditures,
                    color: AppColors.expenditure),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isProfit ? 'Net Business Profit' : 'Net Business Loss',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  const Text('(Sales - Purchases - Expenses)',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
              Text(
                '${isProfit ? '+' : '-'}₹${net.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: isProfit ? AppColors.profit : AppColors.loss,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text('\u20B9${value.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _CropStatTile extends StatelessWidget {
  final String crop;
  final _CropStat stat;

  const _CropStatTile({required this.crop, required this.stat});

  @override
  Widget build(BuildContext context) {
    final net = stat.net;
    final isProfit = net >= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(crop, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  'Bought ${stat.qtyBought} · Sold ${stat.qtySold}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '${isProfit ? '+' : '-'}\u20B9${net.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isProfit ? AppColors.profit : AppColors.loss,
            ),
          ),
        ],
      ),
    );
  }
}
