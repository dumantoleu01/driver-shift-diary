import 'package:go_router/go_router.dart';

import '../../features/shifts/presentation/pages/day_page.dart';
import '../../features/shifts/presentation/pages/trip_form_page.dart';
import '../time/calendar_day.dart';
import '../time/service_zone.dart';

/// С чем открывается форма новой поездки.
class TripFormArgs {
  const TripFormArgs({required this.zone, required this.day});

  /// Пояс сервиса: в нём форма понимает введённое время.
  final ServiceZone zone;

  /// День, открытый на главном экране, — с него форма начинает.
  final CalendarDay day;
}

class AppRouter {
  static const home = '/';
  static const newTrip = '/trips/new';

  static final router = create();

  /// Новый роутер. В приложении он один ([router]); тестам нужен свой на каждый
  /// случай — роутер помнит, какой экран открыт.
  static GoRouter create() => GoRouter(
    initialLocation: home,
    routes: [
      GoRoute(
        path: home,
        builder: (context, state) => const DayPage(),
        routes: [
          GoRoute(
            path: 'trips/new',
            // Форме нужен пояс сервиса, а он известен только главному экрану.
            // Без него — например, после восстановления приложения системой —
            // возвращаемся на главный экран, а не открываем форму вслепую.
            redirect: (context, state) =>
                state.extra is TripFormArgs ? null : home,
            builder: (context, state) =>
                TripFormPage(args: state.extra! as TripFormArgs),
          ),
        ],
      ),
    ],
  );
}
