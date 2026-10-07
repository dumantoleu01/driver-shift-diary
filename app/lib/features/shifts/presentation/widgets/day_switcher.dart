import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/time/calendar_day.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';

/// Переключатель дня: стрелки на соседние дни и календарь по нажатию на дату.
class DaySwitcher extends StatelessWidget {
  const DaySwitcher({
    super.key,
    required this.day,
    required this.today,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final CalendarDay day;

  /// Сегодняшний день в поясе сервиса — для подписей «Сегодня» и «Вчера».
  final CalendarDay today;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    final note = day == today
        ? l10n.dayToday
        : day == today.previous
        ? l10n.dayYesterday
        : day.year.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('day-previous'),
            onPressed: onPrevious,
            tooltip: l10n.dayPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: InkWell(
              key: const ValueKey('day-pick'),
              onTap: onPick,
              borderRadius: AppRadius.lgAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Semantics(
                  button: true,
                  label: l10n.dayPick,
                  child: Column(
                    children: [
                      Text(
                        formatDayTitle(day),
                        key: const ValueKey('day-title'),
                        textAlign: TextAlign.center,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        note,
                        style: text.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('day-next'),
            onPressed: onNext,
            tooltip: l10n.dayNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
