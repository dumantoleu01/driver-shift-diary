import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/driver_profile.dart';

extension DriverProfileLabel on DriverProfile {
  /// Как водитель подписан на экране: своим именем, а пока его нет — номером.
  String label(AppLocalizations l10n) => name ?? l10n.driverName(number);
}
