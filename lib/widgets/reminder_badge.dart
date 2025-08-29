import 'package:flutter/material.dart';

class ReminderBadge extends StatelessWidget {
  final DateTime when;
  final bool overdue;
  const ReminderBadge({super.key, required this.when, this.overdue = false});

  String _format(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final isToday = now.year == local.year && now.month == local.month && now.day == local.day;
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final isTomorrow = tomorrow.year == local.year && tomorrow.month == local.month && tomorrow.day == local.day;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (isToday) return '今日 $hh:$mm';
    if (isTomorrow) return '明日 $hh:$mm';
    return '${local.month}/${local.day} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final color = overdue ? Colors.red[400] : Colors.amber[400];
    return Transform.rotate(
      angle: -0.05,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(overdue ? Icons.notification_important : Icons.notifications, size: 14, color: Colors.black87),
            const SizedBox(width: 4),
            Text(
              _format(when),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}

