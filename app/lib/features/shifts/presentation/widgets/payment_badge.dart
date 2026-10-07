import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/payment_method.dart';

extension PaymentMethodView on PaymentMethod {
  String label(AppLocalizations l10n) => switch (this) {
    PaymentMethod.cash => l10n.paymentCash,
    PaymentMethod.card => l10n.paymentCard,
  };

  IconData get icon => switch (this) {
    PaymentMethod.cash => Icons.payments_outlined,
    PaymentMethod.card => Icons.credit_card,
  };

  Color color(AppColors colors) => switch (this) {
    PaymentMethod.cash => colors.cash,
    PaymentMethod.card => colors.card,
  };

  Color background(AppColors colors) => switch (this) {
    PaymentMethod.cash => colors.cashBg,
    PaymentMethod.card => colors.cardBg,
  };
}

/// Метка способа оплаты в строке поездки.
class PaymentBadge extends StatelessWidget {
  const PaymentBadge({super.key, required this.payment});

  final PaymentMethod payment;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = payment.color(colors);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: payment.background(colors),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(payment.icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            payment.label(AppLocalizations.of(context)),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
