import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusPill extends StatelessWidget {
  final String text;
  final String?
  kind; // e.g., completed, pending, in_process, paid, open, draft, error, success
  const StatusPill(this.text, {super.key, this.kind});

  Color _bg() {
    switch ((kind ?? text).toLowerCase()) {
      case 'completed':
      case 'paid':
      case 'success':
        return AppColors.success.withOpacity(0.18);
      case 'in_process':
      case 'processing':
      case 'open':
        return AppColors.accent.withOpacity(0.18);
      case 'pending':
        return AppColors.warning.withOpacity(0.18);
      case 'error':
      case 'failed':
        return AppColors.error.withOpacity(0.18);
      default:
        return AppColors.surfaceGlassStrong;
    }
  }

  Color _fg() {
    switch ((kind ?? text).toLowerCase()) {
      case 'completed':
      case 'paid':
      case 'success':
        return const Color(0xFF7CF2B1);
      case 'in_process':
      case 'processing':
      case 'open':
        return AppColors.accent;
      case 'pending':
        return const Color(0xFFFFD18A);
      case 'error':
      case 'failed':
        return const Color(0xFFFF9AA1);
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: ShapeDecoration(
        color: _bg(),
        shape: StadiumBorder(
          side: BorderSide(color: Colors.white.withOpacity(0.14), width: 1),
        ),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: _fg(),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
