import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../error/error_presenter.dart';

/// Ошибка поверх содержимого: экран остаётся на месте, внизу — что случилось.
void showErrorSnack(BuildContext context, String? code) {
  final text = describeError(AppLocalizations.of(context), code);
  _show(context, '${text.title}. ${text.hint}');
}

/// Короткое сообщение об успехе.
void showInfoSnack(BuildContext context, String message) =>
    _show(context, message);

void _show(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
