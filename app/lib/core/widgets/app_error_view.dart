import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../error/error_presenter.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// Ошибка вместо содержимого экрана: что случилось, что делать и кнопка повтора.
///
/// Принимает код ошибки из состояния, а не текст: текст выбирается здесь, на
/// языке интерфейса.
class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key, required this.error, required this.onRetry});

  /// Код из `ErrorCodes`.
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = describeError(l10n, error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: colors.textTertiary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              text.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              text.hint,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.tonal(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}
