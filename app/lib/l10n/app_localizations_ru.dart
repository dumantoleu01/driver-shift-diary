// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Дневник смен';

  @override
  String get retry => 'Повторить';

  @override
  String get loadingSlow =>
      'Сервер отвечает дольше обычного. Если он спал, первый ответ придёт в течение минуты';

  @override
  String get dayToday => 'Сегодня';

  @override
  String get dayYesterday => 'Вчера';

  @override
  String get dayPrevious => 'Предыдущий день';

  @override
  String get dayNext => 'Следующий день';

  @override
  String get dayPick => 'Выбрать день';

  @override
  String get summaryNet => 'На руки';

  @override
  String get summaryTrips => 'Поездок';

  @override
  String get summaryRevenue => 'Выручка';

  @override
  String get summaryCommission => 'Комиссия';

  @override
  String get paymentCash => 'Наличные';

  @override
  String get paymentCard => 'Карта';

  @override
  String tripsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count поездки',
      many: '$count поездок',
      few: '$count поездки',
      one: '$count поездка',
      zero: 'нет поездок',
    );
    return '$_temp0';
  }

  @override
  String get tripsHeader => 'Поездки';

  @override
  String get tripsEmptyTitle => 'В этот день поездок нет';

  @override
  String get tripsEmptyHint => 'Добавьте поездку или выберите другой день';

  @override
  String get tripAdd => 'Поездка';

  @override
  String tripCommission(String amount) {
    return 'комиссия $amount';
  }

  @override
  String tripNet(String amount) {
    return 'на руки $amount';
  }

  @override
  String get tripEndsNextDay => 'след. день';

  @override
  String durationMinutes(int minutes) {
    return '$minutes мин';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours ч $minutes мин';
  }

  @override
  String get formTitle => 'Новая поездка';

  @override
  String get formStart => 'Начало';

  @override
  String get formEnd => 'Окончание';

  @override
  String get formDate => 'Дата';

  @override
  String get formTime => 'Время';

  @override
  String formAmount(String currency) {
    return 'Сумма, $currency';
  }

  @override
  String get formPayment => 'Оплата';

  @override
  String formCommission(String currency) {
    return 'Комиссия, $currency';
  }

  @override
  String formCommissionAuto(int percent) {
    return 'Подставлено $percent% от суммы — можно изменить';
  }

  @override
  String formNet(String amount) {
    return 'На руки: $amount';
  }

  @override
  String get formSave => 'Сохранить';

  @override
  String get formRetry => 'Повторить отправку';

  @override
  String get formRetryHint =>
      'Если поездка уже дошла до сервера, дубль не появится';

  @override
  String get formSaved => 'Поездка добавлена';

  @override
  String get formAlreadySaved => 'Такая поездка уже записана — дубль не создан';

  @override
  String get formOutcomeUnknown =>
      'Неизвестно, записалась ли поездка. Проверьте список, прежде чем вводить её заново';

  @override
  String get fieldRequired => 'Заполните поле';

  @override
  String get fieldWholeNumber => 'Введите целое число';

  @override
  String get fieldAmountPositive => 'Сумма должна быть больше нуля';

  @override
  String get fieldAmountTooLarge => 'Слишком большая сумма';

  @override
  String get fieldEndAfterStart => 'Окончание должно быть позже начала';

  @override
  String get fieldTripTooLong =>
      'Поездка не может длиться дольше суток — проверьте даты';

  @override
  String get fieldCommissionNegative => 'Комиссия не может быть меньше нуля';

  @override
  String get fieldCommissionExceeds => 'Комиссия не может быть больше суммы';

  @override
  String get fieldOutOfRange => 'Дата слишком далеко от сегодняшней';

  @override
  String get fieldInvalid => 'Недопустимое значение';

  @override
  String get errNoInternetTitle => 'Нет связи с сервером';

  @override
  String get errNoInternetHint => 'Проверьте интернет и попробуйте ещё раз';

  @override
  String get errTimeoutTitle => 'Сервер долго не отвечает';

  @override
  String get errTimeoutHint => 'Связь медленная — попробуйте ещё раз';

  @override
  String get errServerTitle => 'Сервер недоступен';

  @override
  String get errServerHint => 'Попробуйте позже';

  @override
  String get errBadResponseTitle => 'Не удалось прочитать ответ сервера';

  @override
  String get errBadResponseHint => 'Обновите приложение или попробуйте позже';

  @override
  String get errTripRejectedTitle => 'Сервер не принял поездку';

  @override
  String get errTripRejectedHint => 'Проверьте данные и попробуйте ещё раз';

  @override
  String get errTripConflictTitle => 'Не удалось сохранить поездку';

  @override
  String get errTripConflictHint => 'Закройте форму и добавьте поездку заново';

  @override
  String get errUnknownTitle => 'Что-то пошло не так';

  @override
  String get errUnknownHint => 'Попробуйте ещё раз';
}
