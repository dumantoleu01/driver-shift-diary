import '../../../../l10n/app_localizations.dart';
import '../../domain/rules/trip_rules.dart';

/// Код причины → текст под полем формы.
///
/// Коды одни и те же, нашло ли ошибку приложение или сервер, поэтому и текст
/// один. Незнакомый код (сервер новее приложения) показывается общей фразой.
String fieldErrorText(AppLocalizations l10n, String code) => switch (code) {
  FieldCodes.required => l10n.fieldRequired,
  FieldCodes.invalidType => l10n.fieldWholeNumber,
  FieldCodes.mustBePositive => l10n.fieldAmountPositive,
  FieldCodes.tooLarge => l10n.fieldAmountTooLarge,
  FieldCodes.mustBeAfterStart => l10n.fieldEndAfterStart,
  FieldCodes.mustNotBeNegative => l10n.fieldCommissionNegative,
  FieldCodes.mustNotExceedAmount => l10n.fieldCommissionExceeds,
  FieldCodes.outOfRange => l10n.fieldOutOfRange,
  _ => l10n.fieldInvalid,
};
