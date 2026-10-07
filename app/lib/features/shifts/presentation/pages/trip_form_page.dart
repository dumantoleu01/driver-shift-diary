import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/error/errors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/time/calendar_day.dart';
import '../../../../core/time/clock_time.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/payment_method.dart';
import '../../domain/rules/trip_rules.dart';
import '../cubit/trip_form_cubit.dart';
import '../cubit/trip_form_state.dart';
import '../widgets/field_error_text.dart';
import '../widgets/payment_badge.dart';

/// Форма новой поездки.
class TripFormPage extends StatelessWidget {
  const TripFormPage({super.key, required this.args});

  final TripFormArgs args;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => getIt<TripFormCubit>(param1: args),
    child: const TripFormView(),
  );
}

/// Сама форма — отдельно от создания кубита, чтобы в тестах подставлять свой.
class TripFormView extends StatefulWidget {
  const TripFormView({super.key});

  @override
  State<TripFormView> createState() => _TripFormViewState();
}

class _TripFormViewState extends State<TripFormView> {
  final _amount = TextEditingController();
  final _commission = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _commission.dispose();
    super.dispose();
  }

  void _onState(BuildContext context, TripFormState state) {
    // Комиссию форма подставляет сама, пока водитель её не трогал, — поле
    // должно показать подставленное. Свой ввод водителя не перезаписывается:
    // иначе курсор прыгал бы в конец на каждом нажатии.
    if (!state.commissionEdited && _commission.text != state.commissionText) {
      _commission.text = state.commissionText;
    }

    final result = state.result;
    if (state.status == TripFormStatus.saved && result != null) {
      final l10n = AppLocalizations.of(context);
      // «Уже записана» — только если поездка была на сервере до этой формы.
      // После обрыва связи повтор тоже вернёт «не создана», но записала её
      // именно эта форма, первой попыткой.
      final isNews = result.created || state.outcomeUnknown;
      showInfoSnack(context, isNews ? l10n.formSaved : l10n.formAlreadySaved);
      context.pop(result.trip);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocConsumer<TripFormCubit, TripFormState>(
      listener: _onState,
      builder: (context, state) {
        final cubit = context.read<TripFormCubit>();
        String? errorOf(TripField field) {
          final code = state.fieldErrors[field];
          return code == null ? null : fieldErrorText(l10n, code);
        }

        return Scaffold(
          appBar: AppBar(title: Text(l10n.formTitle)),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      _MomentRow(
                        title: l10n.formStart,
                        day: state.startDay,
                        time: state.startTime,
                        error: errorOf(TripField.start),
                        enabled: state.canEdit,
                        onDay: cubit.startDayChanged,
                        onTime: cubit.startTimeChanged,
                        keyPrefix: 'start',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _MomentRow(
                        title: l10n.formEnd,
                        day: state.endDay,
                        time: state.endTime,
                        error: errorOf(TripField.end),
                        enabled: state.canEdit,
                        onDay: cubit.endDayChanged,
                        onTime: cubit.endTimeChanged,
                        keyPrefix: 'end',
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      TextField(
                        key: const ValueKey('field-amount'),
                        controller: _amount,
                        enabled: state.canEdit,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [LengthLimitingTextInputFormatter(12)],
                        onChanged: cubit.amountChanged,
                        decoration: InputDecoration(
                          labelText: l10n.formAmount(AppConfig.currencySign),
                          errorText: errorOf(TripField.amount),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _PaymentPicker(
                        value: state.payment,
                        enabled: state.canEdit,
                        error: errorOf(TripField.payment),
                        onChanged: cubit.paymentChanged,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        key: const ValueKey('field-commission'),
                        controller: _commission,
                        enabled: state.canEdit,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [LengthLimitingTextInputFormatter(12)],
                        onChanged: cubit.commissionChanged,
                        decoration: InputDecoration(
                          labelText: l10n.formCommission(
                            AppConfig.currencySign,
                          ),
                          errorText: errorOf(TripField.commission),
                          // Заблокированной форме подсказка «можно изменить»
                          // ни к чему.
                          helperText:
                              state.canEdit &&
                                  !state.commissionEdited &&
                                  state.commissionText.isNotEmpty
                              ? l10n.formCommissionAuto(
                                  AppConfig.defaultCommissionPercent,
                                )
                              : null,
                          helperMaxLines: 2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _NetPreview(state: state),
                    ],
                  ),
                ),
                // Кнопка и сбой отправки закреплены под списком: после ошибки
                // форма становится выше, и «Повторить» иначе уезжало бы за
                // край экрана.
                _SubmitBar(state: state, onSubmit: cubit.submit),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Низ формы: сбой отправки, если он был, и кнопка.
class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.state, required this.onSubmit});

  final TripFormState state;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: colors.bgPrimary,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.errorCode != null) ...[
            _SubmitError(
              code: state.errorCode,
              canRetrySafely: state.outcomeUnknown,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          FilledButton(
            key: const ValueKey('form-submit'),
            onPressed: state.isSubmitting ? null : onSubmit,
            child: state.isSubmitting
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(state.outcomeUnknown ? l10n.formRetry : l10n.formSave),
          ),
        ],
      ),
    );
  }
}

/// Дата и время одного из концов поездки.
class _MomentRow extends StatelessWidget {
  const _MomentRow({
    required this.title,
    required this.day,
    required this.time,
    required this.error,
    required this.enabled,
    required this.onDay,
    required this.onTime,
    required this.keyPrefix,
  });

  final String title;
  final CalendarDay day;
  final ClockTime time;
  final String? error;
  final bool enabled;
  final ValueChanged<CalendarDay> onDay;
  final ValueChanged<ClockTime> onTime;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            title,
            style: text.titleSmall?.copyWith(color: colors.textSecondary),
          ),
        ),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _PickerField(
                key: ValueKey('$keyPrefix-day'),
                label: l10n.formDate,
                value: formatDayShort(day),
                icon: Icons.calendar_today_outlined,
                enabled: enabled,
                hasError: error != null,
                onTap: () => _pickDay(context),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 2,
              child: _PickerField(
                key: ValueKey('$keyPrefix-time'),
                label: l10n.formTime,
                value: time.toString(),
                icon: Icons.schedule,
                enabled: enabled,
                hasError: error != null,
                onTap: () => _pickTime(context),
              ),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              top: AppSpacing.xs,
            ),
            child: Text(
              error!,
              key: ValueKey('$keyPrefix-error'),
              style: text.bodySmall?.copyWith(color: colors.negative),
            ),
          ),
      ],
    );
  }

  Future<void> _pickDay(BuildContext context) async {
    // Календарю нужен DateTime, но берутся из него только год, месяц и число.
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(day.year, day.month, day.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(day.year + 1, 12, 31),
    );
    if (picked != null) {
      onDay(CalendarDay(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: time.hour, minute: time.minute),
    );
    if (picked != null) onTime(ClockTime(picked.hour, picked.minute));
  }
}

/// Поле, которое открывает выбор даты или времени по нажатию.
class _PickerField extends StatelessWidget {
  const _PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.enabled,
    required this.hasError,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool enabled;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: AppRadius.lgAll,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          suffixIcon: Icon(icon, size: 18, color: colors.textTertiary),
          enabledBorder: hasError
              ? OutlineInputBorder(
                  borderRadius: AppRadius.lgAll,
                  borderSide: BorderSide(color: colors.negative),
                )
              : null,
        ),
        child: Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: enabled ? colors.textPrimary : colors.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _PaymentPicker extends StatelessWidget {
  const _PaymentPicker({
    required this.value,
    required this.enabled,
    required this.error,
    required this.onChanged,
  });

  final PaymentMethod value;
  final bool enabled;
  final String? error;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            l10n.formPayment,
            style: text.titleSmall?.copyWith(color: colors.textSecondary),
          ),
        ),
        SizedBox(
          width: double.infinity,
          // Заблокированный выбор гасится прозрачностью, а не выключением
          // кнопки: выключенная кнопка перестаёт показывать, что было выбрано.
          child: IgnorePointer(
            ignoring: !enabled,
            child: Opacity(
              opacity: enabled ? 1 : 0.55,
              child: SegmentedButton<PaymentMethod>(
                key: const ValueKey('field-payment'),
                segments: [
                  for (final method in PaymentMethod.values)
                    ButtonSegment(
                      value: method,
                      icon: Icon(method.icon),
                      label: Text(method.label(l10n)),
                    ),
                ],
                selected: {value},
                showSelectedIcon: false,
                onSelectionChanged: (selected) => onChanged(selected.single),
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              top: AppSpacing.xs,
            ),
            child: Text(
              error!,
              style: text.bodySmall?.copyWith(color: colors.negative),
            ),
          ),
      ],
    );
  }
}

/// «На руки» по введённым сумме и комиссии — видно до отправки.
class _NetPreview extends StatelessWidget {
  const _NetPreview({required this.state});

  final TripFormState state;

  @override
  Widget build(BuildContext context) {
    final amount = parseWholeNumber(state.amountText);
    final commission = parseWholeNumber(state.commissionText);
    if (amount == null || commission == null || commission > amount) {
      return const SizedBox.shrink();
    }

    return Text(
      AppLocalizations.of(context).formNet(formatMoney(amount - commission)),
      key: const ValueKey('form-net'),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: context.colors.positive,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Сбой отправки: что случилось и можно ли повторять.
class _SubmitError extends StatelessWidget {
  const _SubmitError({required this.code, required this.canRetrySafely});

  final String? code;

  /// Исход отправки неизвестен — повтор безопасен, дубль не появится.
  final bool canRetrySafely;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final error = describeError(l10n, code);

    return Container(
      key: const ValueKey('form-error'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.negativeBg,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            error.title,
            style: text.titleSmall?.copyWith(color: colors.negative),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            canRetrySafely ? l10n.formRetryHint : error.hint,
            style: text.bodySmall?.copyWith(color: colors.textPrimary),
          ),
        ],
      ),
    );
  }
}
