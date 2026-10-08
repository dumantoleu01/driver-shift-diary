import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/driver_profile.dart';

/// Спросить имя водителя.
///
/// Возвращает `null`, если окно закрыли без подтверждения, и введённое имя,
/// если подтвердили. Пустая строка — осознанный ответ «без имени»: такой
/// водитель показывается как [fallback].
///
/// [taken] — подписи остальных водителей в нижнем регистре: два водителя с
/// одной подписью в списке неотличимы, поэтому повтор не принимается.
Future<String?> showDriverNameDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required String initial,
  required String fallback,
  required Set<String> taken,
}) => showDialog<String>(
  context: context,
  builder: (_) => _DriverNameDialog(
    title: title,
    confirmLabel: confirmLabel,
    initial: initial,
    fallback: fallback,
    taken: taken,
  ),
);

class _DriverNameDialog extends StatefulWidget {
  const _DriverNameDialog({
    required this.title,
    required this.confirmLabel,
    required this.initial,
    required this.fallback,
    required this.taken,
  });

  final String title;
  final String confirmLabel;
  final String initial;
  final String fallback;
  final Set<String> taken;

  @override
  State<_DriverNameDialog> createState() => _DriverNameDialogState();
}

class _DriverNameDialogState extends State<_DriverNameDialog> {
  late final _name = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = normalizeDriverName(_name.text);
    // Сравнивается подпись, под которой водитель окажется в списке: без имени
    // это его номер.
    if (widget.taken.contains((name ?? widget.fallback).toLowerCase())) {
      setState(() => _error = AppLocalizations.of(context).driverNameTaken);
      return;
    }
    Navigator.of(context).pop(name ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // В теме кнопки растянуты на всю ширину — так нужно в формах. В окне
    // кнопки стоят в ряд, поэтому здесь ширина по содержимому.
    final compact = FilledButton.styleFrom(minimumSize: const Size(0, 44));

    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('driver-name-field'),
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          LengthLimitingTextInputFormatter(maxDriverNameLength),
        ],
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _confirm(),
        decoration: InputDecoration(
          labelText: l10n.driverNameLabel,
          hintText: widget.fallback,
          helperText: l10n.driverNameHelper(widget.fallback),
          helperMaxLines: 3,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const ValueKey('driver-name-confirm'),
          style: compact,
          onPressed: _confirm,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
