import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/drivers_cubit.dart';
import '../cubit/drivers_state.dart';
import 'drivers_sheet.dart';

/// Кнопка в шапке: чей дневник сейчас открыт, и переход к смене водителя.
class DriverButton extends StatelessWidget {
  const DriverButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocBuilder<DriversCubit, DriversState>(
      buildWhen: (before, after) => before.current != after.current,
      builder: (context, state) {
        final current = state.current;
        // Список водителей не прочитан — менять не из кого.
        if (current == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: Tooltip(
            message: l10n.driverSwitch,
            child: TextButton.icon(
              key: const ValueKey('driver-button'),
              onPressed: () => showDriversSheet(context),
              icon: const Icon(Icons.person_outline),
              label: Text(l10n.driverName(current.number)),
            ),
          ),
        );
      },
    );
  }
}
