import '../../main.dart';
import '../../services/reminders.dart';
import 'events_logic.dart';

class EventsSnapshot {
  EventsSnapshot(this.events, this.anniversary, this.upcoming);

  final List<CoupleEvent> events;
  final DateTime? anniversary;
  final List<Occurrence> upcoming;
}

/// Loads events + anniversary, computes upcoming dates and re-syncs local reminders.
Future<EventsSnapshot> loadEvents(String coupleId) async {
  final rows = await supabase.from('events').select().eq('couple_id', coupleId);
  final couple = await supabase.from('couples').select('anniversary').eq('id', coupleId).single();
  final ann = couple['anniversary'] as String?;
  final events = [for (final r in rows) CoupleEvent.fromMap(r)];
  final anniversary = ann == null ? null : DateTime.parse(ann);
  final upcoming = upcomingOccurrences(events: events, anniversary: anniversary);
  try {
    await Reminders.rescheduleAll(upcoming);
  } catch (_) {
    // Reminders are best-effort; never block the UI on a notification failure.
  }
  return EventsSnapshot(events, anniversary, upcoming);
}
