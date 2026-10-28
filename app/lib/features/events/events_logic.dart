class CoupleEvent {
  CoupleEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.kind,
    required this.repeatYearly,
    required this.remindDaysBefore,
  });

  factory CoupleEvent.fromMap(Map<String, dynamic> m) => CoupleEvent(
        id: m['id'] as String,
        title: m['title'] as String,
        date: DateTime.parse(m['event_date'] as String),
        kind: m['kind'] as String,
        repeatYearly: m['repeat_yearly'] as bool,
        remindDaysBefore: m['remind_days_before'] as int,
      );

  final String id;
  final String title;
  final DateTime date;
  final String kind;
  final bool repeatYearly;
  final int remindDaysBefore;
}

/// One upcoming date, either from a stored event or an auto milestone.
class Occurrence {
  Occurrence({
    required this.title,
    required this.date,
    required this.kind,
    required this.remindDaysBefore,
    this.eventId,
  });

  final String title;
  final DateTime date; // date-only (local midnight)
  final String kind; // birthday | anniversary | holiday | custom | milestone
  final int remindDaysBefore;
  final String? eventId; // null for auto milestones

  int daysFrom(DateTime today) => date.difference(today).inDays;
}

const _milestoneDays = [100, 200, 300, 365, 500, 700, 1000, 1500, 2000, 3000, 5000];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Same month/day in [year]; Feb 29 falls back to Feb 28 in non-leap years.
DateTime _inYear(DateTime d, int year) {
  final candidate = DateTime(year, d.month, d.day);
  return candidate.month == d.month ? candidate : DateTime(year, d.month, d.day - 1);
}

/// Upcoming occurrences (today or later), sorted by date, within [horizonDays].
List<Occurrence> upcomingOccurrences({
  required List<CoupleEvent> events,
  required DateTime? anniversary,
  DateTime? now,
  int horizonDays = 800,
}) {
  final today = dateOnly(now ?? DateTime.now());
  final limit = today.add(Duration(days: horizonDays));
  final out = <Occurrence>[];

  for (final e in events) {
    final base = dateOnly(e.date);
    DateTime next = base;
    if (e.repeatYearly) {
      next = _inYear(base, today.year);
      if (next.isBefore(today)) next = _inYear(base, today.year + 1);
    }
    if (next.isBefore(today)) continue;
    // Yearly events: include the following year too so reminders keep arriving.
    final dates = [next];
    if (e.repeatYearly) dates.add(_inYear(base, next.year + 1));
    for (final d in dates) {
      if (d.isAfter(limit)) continue;
      final years = d.year - base.year;
      final title = e.repeatYearly && years > 0 && e.kind != 'holiday'
          ? '${e.title} (năm thứ $years)'
          : e.title;
      out.add(Occurrence(
        title: title,
        date: d,
        kind: e.kind,
        remindDaysBefore: e.remindDaysBefore,
        eventId: e.id,
      ));
    }
  }

  if (anniversary != null) {
    final a = dateOnly(anniversary);
    // The anniversary day counts as day 1, matching the home screen counter.
    for (final n in _milestoneDays) {
      final d = a.add(Duration(days: n - 1));
      if (!d.isBefore(today) && !d.isAfter(limit)) {
        out.add(Occurrence(title: '$n ngày bên nhau', date: d, kind: 'milestone', remindDaysBefore: 1));
      }
    }
    for (var y = 1; y <= 60; y++) {
      final d = _inYear(a, a.year + y);
      if (d.isBefore(today)) continue;
      if (d.isAfter(limit)) break;
      out.add(Occurrence(title: 'Kỷ niệm $y năm yêu nhau', date: d, kind: 'milestone', remindDaysBefore: 7));
    }
  }

  out.sort((x, y) => x.date.compareTo(y.date));
  return out;
}
