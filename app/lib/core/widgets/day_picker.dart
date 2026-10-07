import 'package:flutter/material.dart';

import '../time/calendar_day.dart';

// Те же границы, что у сервера: любой день, который он может отдать, в них
// попадает. С более узкими границами календарь не открылся бы для дня за их
// пределами — он требует, чтобы начальная дата лежала внутри.
final _firstDate = DateTime(2000);
final _lastDate = DateTime(2099, 12, 31);

/// Выбрать день в календаре.
///
/// Календарю нужен `DateTime`, но смысл у него здесь — только дата: год, месяц
/// и число берутся как есть, без перевода между поясами. [today] — сегодняшний
/// день в поясе сервиса: без него календарь отметил бы «сегодня» по часам
/// телефона.
Future<CalendarDay?> pickDay(
  BuildContext context, {
  required CalendarDay initial,
  required CalendarDay today,
}) async {
  var initialDate = DateTime(initial.year, initial.month, initial.day);
  if (initialDate.isBefore(_firstDate)) initialDate = _firstDate;
  if (initialDate.isAfter(_lastDate)) initialDate = _lastDate;

  final picked = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: _firstDate,
    lastDate: _lastDate,
    currentDate: DateTime(today.year, today.month, today.day),
  );
  return picked == null
      ? null
      : CalendarDay(picked.year, picked.month, picked.day);
}
