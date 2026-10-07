import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/drivers_cubit.dart';
import '../cubit/drivers_state.dart';

/// Открыть список водителей.
Future<void> showDriversSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<DriversCubit>(),
        child: const _DriversSheet(),
      ),
    );

/// Водители на этом телефоне: выбрать другого или завести нового.
class _DriversSheet extends StatelessWidget {
  const _DriversSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return BlocBuilder<DriversCubit, DriversState>(
      builder: (context, state) {
        final cubit = context.read<DriversCubit>();
        final roster = state.roster;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.driversTitle, style: text.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.driversHint,
                  style: text.bodySmall?.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                // Водителей может накопиться больше, чем помещается на экране.
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final profile in roster?.profiles ?? const [])
                        ListTile(
                          key: ValueKey('driver-${profile.number}'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.person_outline),
                          title: Text(l10n.driverName(profile.number)),
                          trailing: profile.id == roster?.currentId
                              ? Icon(Icons.check, color: colors.accent)
                              : null,
                          onTap: () async {
                            // Сначала выбор, потом закрытие: главный экран
                            // начинает перечитывать дневник ещё под шторкой.
                            await cubit.select(profile.id);
                            if (context.mounted) Navigator.of(context).pop();
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.tonalIcon(
                  key: const ValueKey('driver-new'),
                  onPressed: () async {
                    await cubit.create();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.person_add_alt),
                  label: Text(l10n.driverNew),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.driverNewHint,
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
