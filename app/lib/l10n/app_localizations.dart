import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ru')];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'Дневник смен'**
  String get appTitle;

  /// No description provided for @retry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retry;

  /// No description provided for @loadingSlow.
  ///
  /// In ru, this message translates to:
  /// **'Сервер отвечает дольше обычного. Если он спал, первый ответ придёт в течение минуты'**
  String get loadingSlow;

  /// No description provided for @dayToday.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get dayToday;

  /// No description provided for @dayYesterday.
  ///
  /// In ru, this message translates to:
  /// **'Вчера'**
  String get dayYesterday;

  /// No description provided for @dayPrevious.
  ///
  /// In ru, this message translates to:
  /// **'Предыдущий день'**
  String get dayPrevious;

  /// No description provided for @dayNext.
  ///
  /// In ru, this message translates to:
  /// **'Следующий день'**
  String get dayNext;

  /// No description provided for @dayPick.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать день'**
  String get dayPick;

  /// No description provided for @driverName.
  ///
  /// In ru, this message translates to:
  /// **'Водитель {number}'**
  String driverName(int number);

  /// No description provided for @driversTitle.
  ///
  /// In ru, this message translates to:
  /// **'Водители'**
  String get driversTitle;

  /// No description provided for @driversHint.
  ///
  /// In ru, this message translates to:
  /// **'У каждого водителя свой дневник. Пароля нет: водители разделены, но не защищены'**
  String get driversHint;

  /// No description provided for @driverSwitch.
  ///
  /// In ru, this message translates to:
  /// **'Сменить водителя'**
  String get driverSwitch;

  /// No description provided for @driverNew.
  ///
  /// In ru, this message translates to:
  /// **'Новый водитель'**
  String get driverNew;

  /// No description provided for @driverNewHint.
  ///
  /// In ru, this message translates to:
  /// **'Его дневник начнётся с образца поездок'**
  String get driverNewHint;

  /// No description provided for @summaryNet.
  ///
  /// In ru, this message translates to:
  /// **'На руки'**
  String get summaryNet;

  /// No description provided for @summaryTrips.
  ///
  /// In ru, this message translates to:
  /// **'Поездок'**
  String get summaryTrips;

  /// No description provided for @summaryRevenue.
  ///
  /// In ru, this message translates to:
  /// **'Выручка'**
  String get summaryRevenue;

  /// No description provided for @summaryCommission.
  ///
  /// In ru, this message translates to:
  /// **'Комиссия'**
  String get summaryCommission;

  /// No description provided for @paymentCash.
  ///
  /// In ru, this message translates to:
  /// **'Наличные'**
  String get paymentCash;

  /// No description provided for @paymentCard.
  ///
  /// In ru, this message translates to:
  /// **'Карта'**
  String get paymentCard;

  /// No description provided for @tripsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =0{нет поездок} one{{count} поездка} few{{count} поездки} many{{count} поездок} other{{count} поездки}}'**
  String tripsCount(int count);

  /// No description provided for @tripsHeader.
  ///
  /// In ru, this message translates to:
  /// **'Поездки'**
  String get tripsHeader;

  /// No description provided for @tripsEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'В этот день поездок нет'**
  String get tripsEmptyTitle;

  /// No description provided for @tripsEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте поездку или выберите другой день'**
  String get tripsEmptyHint;

  /// No description provided for @tripAdd.
  ///
  /// In ru, this message translates to:
  /// **'Поездка'**
  String get tripAdd;

  /// No description provided for @tripCommission.
  ///
  /// In ru, this message translates to:
  /// **'комиссия {amount}'**
  String tripCommission(String amount);

  /// No description provided for @tripNet.
  ///
  /// In ru, this message translates to:
  /// **'на руки {amount}'**
  String tripNet(String amount);

  /// No description provided for @tripEndsNextDay.
  ///
  /// In ru, this message translates to:
  /// **'след. день'**
  String get tripEndsNextDay;

  /// No description provided for @durationMinutes.
  ///
  /// In ru, this message translates to:
  /// **'{minutes} мин'**
  String durationMinutes(int minutes);

  /// No description provided for @durationHoursMinutes.
  ///
  /// In ru, this message translates to:
  /// **'{hours} ч {minutes} мин'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @formTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новая поездка'**
  String get formTitle;

  /// No description provided for @formStart.
  ///
  /// In ru, this message translates to:
  /// **'Начало'**
  String get formStart;

  /// No description provided for @formEnd.
  ///
  /// In ru, this message translates to:
  /// **'Окончание'**
  String get formEnd;

  /// No description provided for @formDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get formDate;

  /// No description provided for @formTime.
  ///
  /// In ru, this message translates to:
  /// **'Время'**
  String get formTime;

  /// No description provided for @formAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма, {currency}'**
  String formAmount(String currency);

  /// No description provided for @formPayment.
  ///
  /// In ru, this message translates to:
  /// **'Оплата'**
  String get formPayment;

  /// No description provided for @formCommission.
  ///
  /// In ru, this message translates to:
  /// **'Комиссия, {currency}'**
  String formCommission(String currency);

  /// No description provided for @formCommissionAuto.
  ///
  /// In ru, this message translates to:
  /// **'Подставлено {percent}% от суммы — можно изменить'**
  String formCommissionAuto(int percent);

  /// No description provided for @formNet.
  ///
  /// In ru, this message translates to:
  /// **'На руки: {amount}'**
  String formNet(String amount);

  /// No description provided for @formSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get formSave;

  /// No description provided for @formRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить отправку'**
  String get formRetry;

  /// No description provided for @formRetryHint.
  ///
  /// In ru, this message translates to:
  /// **'Если поездка уже дошла до сервера, дубль не появится'**
  String get formRetryHint;

  /// No description provided for @formSaved.
  ///
  /// In ru, this message translates to:
  /// **'Поездка добавлена'**
  String get formSaved;

  /// No description provided for @formAlreadySaved.
  ///
  /// In ru, this message translates to:
  /// **'Такая поездка уже записана — дубль не создан'**
  String get formAlreadySaved;

  /// No description provided for @formOutcomeUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Неизвестно, записалась ли поездка. Проверьте список, прежде чем вводить её заново'**
  String get formOutcomeUnknown;

  /// No description provided for @fieldRequired.
  ///
  /// In ru, this message translates to:
  /// **'Заполните поле'**
  String get fieldRequired;

  /// No description provided for @fieldWholeNumber.
  ///
  /// In ru, this message translates to:
  /// **'Введите целое число'**
  String get fieldWholeNumber;

  /// No description provided for @fieldAmountPositive.
  ///
  /// In ru, this message translates to:
  /// **'Сумма должна быть больше нуля'**
  String get fieldAmountPositive;

  /// No description provided for @fieldAmountTooLarge.
  ///
  /// In ru, this message translates to:
  /// **'Слишком большая сумма'**
  String get fieldAmountTooLarge;

  /// No description provided for @fieldEndAfterStart.
  ///
  /// In ru, this message translates to:
  /// **'Окончание должно быть позже начала'**
  String get fieldEndAfterStart;

  /// No description provided for @fieldTripTooLong.
  ///
  /// In ru, this message translates to:
  /// **'Поездка не может длиться дольше суток — проверьте даты'**
  String get fieldTripTooLong;

  /// No description provided for @fieldCommissionNegative.
  ///
  /// In ru, this message translates to:
  /// **'Комиссия не может быть меньше нуля'**
  String get fieldCommissionNegative;

  /// No description provided for @fieldCommissionExceeds.
  ///
  /// In ru, this message translates to:
  /// **'Комиссия не может быть больше суммы'**
  String get fieldCommissionExceeds;

  /// No description provided for @fieldOutOfRange.
  ///
  /// In ru, this message translates to:
  /// **'Дата слишком далеко от сегодняшней'**
  String get fieldOutOfRange;

  /// No description provided for @fieldInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Недопустимое значение'**
  String get fieldInvalid;

  /// No description provided for @errNoInternetTitle.
  ///
  /// In ru, this message translates to:
  /// **'Нет связи с сервером'**
  String get errNoInternetTitle;

  /// No description provided for @errNoInternetHint.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте интернет и попробуйте ещё раз'**
  String get errNoInternetHint;

  /// No description provided for @errTimeoutTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сервер долго не отвечает'**
  String get errTimeoutTitle;

  /// No description provided for @errTimeoutHint.
  ///
  /// In ru, this message translates to:
  /// **'Связь медленная — попробуйте ещё раз'**
  String get errTimeoutHint;

  /// No description provided for @errServerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сервер недоступен'**
  String get errServerTitle;

  /// No description provided for @errServerHint.
  ///
  /// In ru, this message translates to:
  /// **'Попробуйте позже'**
  String get errServerHint;

  /// No description provided for @errBadResponseTitle.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось прочитать ответ сервера'**
  String get errBadResponseTitle;

  /// No description provided for @errBadResponseHint.
  ///
  /// In ru, this message translates to:
  /// **'Обновите приложение или попробуйте позже'**
  String get errBadResponseHint;

  /// No description provided for @errTripRejectedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сервер не принял поездку'**
  String get errTripRejectedTitle;

  /// No description provided for @errTripRejectedHint.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте данные и попробуйте ещё раз'**
  String get errTripRejectedHint;

  /// No description provided for @errTripConflictTitle.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить поездку'**
  String get errTripConflictTitle;

  /// No description provided for @errTripConflictHint.
  ///
  /// In ru, this message translates to:
  /// **'Закройте форму и добавьте поездку заново'**
  String get errTripConflictHint;

  /// No description provided for @errStorageTitle.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить на телефоне'**
  String get errStorageTitle;

  /// No description provided for @errStorageHint.
  ///
  /// In ru, this message translates to:
  /// **'Освободите место на телефоне и попробуйте ещё раз'**
  String get errStorageHint;

  /// No description provided for @errUnknownTitle.
  ///
  /// In ru, this message translates to:
  /// **'Что-то пошло не так'**
  String get errUnknownTitle;

  /// No description provided for @errUnknownHint.
  ///
  /// In ru, this message translates to:
  /// **'Попробуйте ещё раз'**
  String get errUnknownHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
