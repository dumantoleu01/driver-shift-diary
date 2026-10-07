import 'dart:async';

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
import '../../../../core/widgets/day_picker.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../drivers/presentation/cubit/drivers_cubit.dart';
import '../../../drivers/presentation/cubit/drivers_state.dart';
import '../../../drivers/presentation/widgets/driver_button.dart';
import '../../domain/entities/day_report.dart';
import '../cubit/day_cubit.dart';
import '../cubit/day_state.dart';
import '../widgets/day_switcher.dart';
import '../widgets/summary_card.dart';
import '../widgets/trip_tile.dart';
import 'trip_form_exit.dart';

/// Главный экран: сводка за день, поездки и переключение дней.
class DayPage extends StatelessWidget {
  const DayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocListener<DriversCubit, DriversState>(
      listenWhen: (before, after) =>
          before.current?.id != after.current?.id ||
          before.errorSeq != after.errorSeq,
      listener: (context, drivers) {
        if (drivers.errorCode != null) {
          showErrorSnack(context, drivers.errorCode);
        } else {
          // Другой водитель — другой дневник.
          context.read<DayCubit>().restart();
        }
      },
      child: BlocConsumer<DayCubit, DayState>(
        listenWhen: (before, after) => before.noticeSeq != after.noticeSeq,
        listener: (context, state) => showErrorSnack(context, state.noticeCode),
        builder: (context, state) {
          final cubit = context.read<DayCubit>();
          final zone = state.zone;
          final day = state.day;
          final ready = zone != null && day != null;

          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.appTitle),
              actions: const [DriverButton()],
            ),
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
      ),
    );
  }

  Widget _body(BuildContext context, DayState state) {
    final cubit = context.read<DayCubit>();
    final report = state.report;
    final zone = state.zone;

    if (state.status == DayStatus.error) {
      return AppErrorView(error: state.errorCode, onRetry: cubit.start);
    }
    if (report == null || zone == null) return const _Loading();
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
    final picked = await pickDay(
      context,
      initial: day,
      today: zone.dayOf(DateTime.now()),
    );
    if (picked == null || !context.mounted) return;
    await context.read<DayCubit>().selectDay(picked);
  }

  Future<void> _addTrip(
    BuildContext context,
    ServiceZone zone,
    CalendarDay day,
  ) async {
    final cubit = context.read<DayCubit>();
    final exit = await context.push<TripFormExit>(
      AppRouter.newTrip,
      extra: TripFormArgs(zone: zone, day: day),
    );
    switch (exit) {
      case TripSaved(:final trip):
        await cubit.showTrip(trip);
      case TripOutcomeUnknown(:final day):
        // Отправка оборвалась, и форму закрыли, не дождавшись ответа. Поездка
        // могла записаться: открываем её день и просим свериться со списком —
        // иначе водитель введёт её второй раз.
        if (context.mounted) {
          showInfoSnack(
            context,
            AppLocalizations.of(context).formOutcomeUnknown,
          );
        }
        await cubit.showDay(day);
      case null:
        break;
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

/// Загрузка. Если ответа нет дольше нескольких секунд, объясняет почему: сервер
/// на бесплатном хостинге просыпается до минуты, и молчащий индикатор всё это
/// время выглядел бы как зависшее приложение.
class _Loading extends StatefulWidget {
  const _Loading();

  @override
  State<_Loading> createState() => _LoadingState();
}

class _LoadingState extends State<_Loading> {
  static const _patience = Duration(seconds: 4);

  Timer? _timer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_patience, () => setState(() => _slow = true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (_slow) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppLocalizations.of(context).loadingSlow,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
