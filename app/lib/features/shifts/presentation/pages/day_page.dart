import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/time/calendar_day.dart';
import '../../../../core/time/service_zone.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/day_report.dart';
import '../../domain/entities/trip.dart';
import '../cubit/day_cubit.dart';
import '../cubit/day_state.dart';
import '../widgets/day_switcher.dart';
import '../widgets/summary_card.dart';
import '../widgets/trip_tile.dart';

/// Главный экран: сводка за день, поездки и переключение дней.
class DayPage extends StatelessWidget {
  const DayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocConsumer<DayCubit, DayState>(
      listenWhen: (before, after) => before.noticeSeq != after.noticeSeq,
      listener: (context, state) => showErrorSnack(context, state.noticeCode),
      builder: (context, state) {
        final cubit = context.read<DayCubit>();
        final zone = state.zone;
        final day = state.day;
        final ready = zone != null && day != null;

        return Scaffold(
          appBar: AppBar(title: Text(l10n.appTitle)),
          body: SafeArea(
            child: Column(
              children: [
                if (ready)
                  DaySwitcher(
                    day: day,
                    today: zone.dayOf(DateTime.now()),
                    onPrevious: cubit.previousDay,
                    onNext: cubit.nextDay,
                    onPick: () => _pickDay(context, zone, day),
                  ),
                Expanded(child: _body(context, state)),
              ],
            ),
          ),
          floatingActionButton: ready
              ? FloatingActionButton.extended(
                  key: const ValueKey('trip-add'),
                  onPressed: () => _addTrip(context, zone, day),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.tripAdd),
                )
              : null,
        );
      },
    );
  }

  Widget _body(BuildContext context, DayState state) {
    final cubit = context.read<DayCubit>();
    final report = state.report;
    final zone = state.zone;

    if (state.status == DayStatus.error) {
      return AppErrorView(error: state.errorCode, onRetry: cubit.start);
    }
    if (report == null || zone == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: cubit.refresh,
      child: _DayContent(report: report, zone: zone),
    );
  }

  Future<void> _pickDay(
    BuildContext context,
    ServiceZone zone,
    CalendarDay day,
  ) async {
    final today = zone.dayOf(DateTime.now());
    // Календарю нужен DateTime, но смысл у него здесь — только дата: год,
    // месяц и число берутся как есть, без перевода между поясами.
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(day.year, day.month, day.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(today.year + 1, 12, 31),
    );
    if (picked == null || !context.mounted) return;
    await context.read<DayCubit>().selectDay(
      CalendarDay(picked.year, picked.month, picked.day),
    );
  }

  Future<void> _addTrip(
    BuildContext context,
    ServiceZone zone,
    CalendarDay day,
  ) async {
    final cubit = context.read<DayCubit>();
    final added = await context.push<Trip>(
      AppRouter.newTrip,
      extra: TripFormArgs(zone: zone, day: day),
    );
    if (added != null) {
      await cubit.showTrip(added);
    } else {
      // Форму закрыли без подтверждения от сервера. Если отправка оборвалась
      // на полпути, поездка могла записаться — список покажет, как есть.
      await cubit.refresh();
    }
  }
}

class _DayContent extends StatelessWidget {
  const _DayContent({required this.report, required this.zone});

  final DayReport report;
  final ServiceZone zone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return ListView(
      // Всегда прокручивается: потянуть вниз для обновления можно и на пустом дне.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        // Место под кнопку «Поездка», чтобы она не закрывала последнюю строку.
        96,
      ),
      children: [
        SummaryCard(summary: report.summary),
        const SizedBox(height: AppSpacing.xl),
        if (report.trips.isEmpty)
          const _EmptyDay()
        else ...[
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              l10n.tripsHeader,
              style: text.titleSmall?.copyWith(color: colors.textSecondary),
            ),
          ),
          for (final trip in report.trips)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: TripTile(
                key: ValueKey('trip-${trip.id}'),
                trip: trip,
                zone: zone,
              ),
            ),
        ],
      ],
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Icon(Icons.event_busy_outlined, size: 40, color: colors.textTertiary),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.tripsEmptyTitle, style: text.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.tripsEmptyHint,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
