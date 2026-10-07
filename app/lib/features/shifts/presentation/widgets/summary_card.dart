import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/day_summary.dart';
import '../../domain/entities/payment_method.dart';
import 'payment_badge.dart';

/// Сводка за день: «на руки» крупно, под ней — из чего она сложилась.
class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.summaryNet,
            style: text.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxs),
          // Самое важное число дня. FittedBox: длинная сумма при крупном
          // системном шрифте сжимается, а не обрезается.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(summary.net),
              key: const ValueKey('summary-net'),
              style: text.displaySmall?.copyWith(
                color: colors.positive,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Stat(
                  label: l10n.summaryTrips,
                  value: formatNumber(summary.trips),
                  valueKey: const ValueKey('summary-trips'),
                ),
              ),
              Expanded(
                flex: 2,
                child: _Stat(
                  label: l10n.summaryRevenue,
                  value: formatMoney(summary.revenue),
                  valueKey: const ValueKey('summary-revenue'),
                ),
              ),
              Expanded(
                flex: 2,
                child: _Stat(
                  label: l10n.summaryCommission,
                  value: formatMoney(summary.commission),
                  valueKey: const ValueKey('summary-commission'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _PaymentTile(
                  payment: PaymentMethod.cash,
                  totals: summary.cash,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _PaymentTile(
                  payment: PaymentMethod.card,
                  totals: summary.card,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.valueKey});

  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.bodySmall?.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xxs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            key: valueKey,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Итог по одному способу оплаты: сколько денег и за сколько поездок.
class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment, required this.totals});

  final PaymentMethod payment;
  final PaymentTotals totals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final color = payment.color(colors);

    return Container(
      key: ValueKey('summary-${payment.wire}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: payment.background(colors),
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(payment.icon, size: 16, color: color),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  payment.label(l10n),
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge?.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(totals.amount),
              style: text.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            l10n.tripsCount(totals.trips),
            style: text.bodySmall?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
