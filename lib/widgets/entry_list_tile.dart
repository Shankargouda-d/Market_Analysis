import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/date_utils.dart';

/// One row in the "recent entries" list shown under Buy, Sell, and Directories.
class EntryListTile extends StatelessWidget {
  final String title; // crop name
  final String subtitle; // farmer / factory name
  final String quantityLabel; // e.g. "12 Quintal"
  final double amount; // total ₹
  final DateTime dateTime;
  final Color accentColor;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onAddPayment;
  final String? extraDetails; // e.g. "Suits: 20 kg • Net: 49.80 Quintal"
  final String? advancePaidLabel; // e.g. "Adv: ₹10,000 | Bal: ₹1,14,500"

  const EntryListTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.quantityLabel,
    required this.amount,
    required this.dateTime,
    required this.accentColor,
    this.onEdit,
    this.onDelete,
    this.onTap,
    this.onAddPayment,
    this.extraDetails,
    this.advancePaidLabel,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppDateUtils.formatDateTime(dateTime),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (extraDetails != null && extraDetails!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        extraDetails!,
                        style: TextStyle(
                          fontSize: 11,
                          color: accentColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\u20B9${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  quantityLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (advancePaidLabel != null &&
                    advancePaidLabel!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    advancePaidLabel!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
              ],
            ),
            if (onTap != null || onEdit != null || onDelete != null || onAddPayment != null) ...[
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (val) {
                  if (val == 'view' && onTap != null) onTap!();
                  if (val == 'pay' && onAddPayment != null) onAddPayment!();
                  if (val == 'edit' && onEdit != null) onEdit!();
                  if (val == 'delete' && onDelete != null) onDelete!();
                },
                itemBuilder: (ctx) => [
                  if (onTap != null)
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('View Details'),
                        ],
                      ),
                    ),
                  if (onAddPayment != null)
                    const PopupMenuItem(
                      value: 'pay',
                      child: Row(
                        children: [
                          Icon(Icons.add_card, size: 16, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Record Payment',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  if (onEdit != null)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('Edit Entry'),
                        ],
                      ),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Entry',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
