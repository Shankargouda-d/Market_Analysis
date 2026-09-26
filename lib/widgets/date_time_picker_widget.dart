import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/date_utils.dart';

/// Shows the current date & time as two chips, auto-filled with
/// DateTime.now() when the screen opens, but tappable so the user
/// can correct them (e.g. entering yesterday's purchase).
class DateTimePickerWidget extends StatelessWidget {
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  const DateTimePickerWidget({
    super.key,
    required this.value,
    required this.onChanged,
  });

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onChanged(AppDateUtils.combine(picked, TimeOfDay.fromDateTime(value)));
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );
    if (picked != null) {
      onChanged(AppDateUtils.combine(value, picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Chip(
            icon: Icons.calendar_today,
            label: AppDateUtils.formatDate(value),
            onTap: () => _pickDate(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Chip(
            icon: Icons.access_time,
            label: AppDateUtils.formatTime(value),
            onTap: () => _pickTime(context),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Chip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
            const Spacer(),
            const Icon(Icons.edit, size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
