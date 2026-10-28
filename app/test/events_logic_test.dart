import 'package:couples/features/events/events_logic.dart';
import 'package:flutter_test/flutter_test.dart';

CoupleEvent ev(String title, DateTime date, {bool yearly = true, String kind = 'birthday'}) => CoupleEvent(
      id: title,
      title: title,
      date: date,
      kind: kind,
      repeatYearly: yearly,
      remindDaysBefore: 1,
    );

void main() {
  final now = DateTime(2026, 10, 28);

  test('yearly event rolls to next occurrence', () {
    final r = upcomingOccurrences(events: [ev('SN', DateTime(1995, 3, 8))], anniversary: null, now: now);
    expect(r.first.date, DateTime(2027, 3, 8));
    expect(r.first.title, 'SN (năm thứ 32)');
  });

  test('one-off past event is dropped, future one kept', () {
    final r = upcomingOccurrences(events: [
      ev('Cũ', DateTime(2026, 1, 1), yearly: false),
      ev('Mới', DateTime(2026, 12, 1), yearly: false),
    ], anniversary: null, now: now);
    expect(r.map((o) => o.title), ['Mới']);
  });

  test('event today is included', () {
    final r = upcomingOccurrences(events: [ev('Nay', DateTime(2026, 10, 28), yearly: false)], anniversary: null, now: now);
    expect(r.single.daysFrom(now), 0);
  });

  test('Feb 29 falls back to Feb 28 in non-leap years', () {
    final r = upcomingOccurrences(events: [ev('Nhuận', DateTime(2000, 2, 29))], anniversary: null, now: now);
    expect(r.first.date, DateTime(2027, 2, 28));
  });

  test('100-day milestone counts anniversary as day 1', () {
    final r = upcomingOccurrences(events: [], anniversary: DateTime(2026, 10, 1), now: now);
    final m = r.firstWhere((o) => o.title == '100 ngày bên nhau');
    expect(m.date, DateTime(2027, 1, 8)); // Oct 1 + 99 days
  });

  test('results are sorted by date', () {
    final r = upcomingOccurrences(
      events: [ev('A', DateTime(2026, 12, 25), yearly: false), ev('B', DateTime(2026, 11, 1), yearly: false)],
      anniversary: DateTime(2026, 1, 1),
      now: now,
    );
    for (var i = 1; i < r.length; i++) {
      expect(r[i].date.isBefore(r[i - 1].date), isFalse);
    }
  });
}
