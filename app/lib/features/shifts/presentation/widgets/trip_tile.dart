import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/time/service_zone.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/trip.dart';
import 'payment_badge.dart';

/// Строка поездки: время, длительность, сумма, оплата и комиссия.
class TripTile extends StatelessWidget {
  const TripTile({super.key, required this.trip, required this.zone});

  final Trip trip;

  /// Пояс сервиса: время показывается в нём, а не в поясе телефона.
  final ServiceZone zone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    final start = formatClock(zone.wallClock(trip.start));
    final end = formatClock(zone.wallClock(trip.end));
    // Поездка через полночь: без пометки «23:48 – 00:14» читается как ошибка.
    final endsNextDay = zone.dayOf(trip.end) != zone.dayOf(trip.start);

    final details = [
      _duration(l10n, trip.duration),
      if (endsNextDay) l10n.tripEndsNextDay,
      l10n.tripCommission(formatMoney(trip.commission)),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$start – $end',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  details,
                  style: text.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(trip.amount),
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              PaymentBadge(payment: trip.payment),
            ],
          ),
        ],
      ),
    );
  }

  String _duration(AppLocalizations l10n, Duration duration) {
    final minutes = duration.inMinutes;
    return minutes < 60
        ? l10n.durationMinutes(minutes)
        : l10n.durationHoursMinutes(minutes ~/ 60, minutes % 60);
  }
}
