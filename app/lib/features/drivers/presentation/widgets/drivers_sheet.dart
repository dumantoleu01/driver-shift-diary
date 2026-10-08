import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/driver_profile.dart';
import '../cubit/drivers_cubit.dart';
import '../cubit/drivers_state.dart';
import 'driver_label.dart';
import 'driver_name_dialog.dart';

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

/// Водители на этом телефоне: выбрать другого, переименовать, завести нового.
class _DriversSheet extends StatelessWidget {
  const _DriversSheet();

  /// Подписи водителей, кроме [except], в нижнем регистре — для проверки, что
  /// новое имя не совпадёт с чужим.
  Set<String> _labels(
    AppLocalizations l10n,
    DriverRoster roster, {
    DriverProfile? except,
  }) => {
    for (final profile in roster.profiles)
      if (profile.id != except?.id) profile.label(l10n).toLowerCase(),
  };

  Future<void> _create(BuildContext context, DriverRoster roster) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DriversCubit>();
    final name = await showDriverNameDialog(
      context,
      title: l10n.driverNew,
      confirmLabel: l10n.driverCreate,
      initial: '',
      fallback: l10n.driverName(roster.nextNumber),
      taken: _labels(l10n, roster),
    );
    if (name == null) return;
    await cubit.create(name);
    // Новый водитель сразу выбран — список больше не нужен.
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _rename(
    BuildContext context,
    DriverRoster roster,
    DriverProfile profile,
  ) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DriversCubit>();
    final name = await showDriverNameDialog(
      context,
      title: l10n.driverRename,
      confirmLabel: l10n.actionSave,
      initial: profile.name ?? '',
      fallback: l10n.driverName(profile.number),
      taken: _labels(l10n, roster, except: profile),
    );
    if (name == null) return;
    await cubit.rename(profile.id, name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return BlocBuilder<DriversCubit, DriversState>(
      builder: (context, state) {
        final cubit = context.read<DriversCubit>();
        final roster = state.roster;
        if (roster == null) return const SizedBox.shrink();

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
                      for (final profile in roster.profiles)
                        ListTile(
                          key: ValueKey('driver-${profile.number}'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.person_outline),
                          title: Text(
                            profile.label(l10n),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (profile.id == roster.currentId)
                                Icon(Icons.check, color: colors.accent),
                              IconButton(
                                key: ValueKey(
                                  'driver-rename-${profile.number}',
                                ),
                                tooltip: l10n.driverRename,
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () =>
                                    _rename(context, roster, profile),
                              ),
                            ],
                          ),
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
                  onPressed: () => _create(context, roster),
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
