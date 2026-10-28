import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../features/events/events_logic.dart';

/// Local (on-device) reminders. No server needed; unsupported on web.
class Reminders {
  Reminders._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static const _hour = 9;
  static const _maxScheduled = 60;

  static bool get _supported => !kIsWeb;

  static Future<void> init() async {
    if (!_supported || _ready) return;
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ));
    _ready = true;
  }

  static Future<bool> requestPermission() async {
    if (!_supported) return false;
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final a = await android?.requestNotificationsPermission();
    final i = await ios?.requestPermissions(alert: true, badge: true, sound: true);
    return (a ?? i ?? false);
  }

  /// Replace every scheduled reminder with the ones for [occurrences].
  static Future<void> rescheduleAll(List<Occurrence> occurrences) async {
    if (!_supported) return;
    await init();
    await _plugin.cancelAll();

    final now = DateTime.now();
    var id = 0;
    for (final o in occurrences) {
      if (id >= _maxScheduled) break;
      final dayOf = DateTime(o.date.year, o.date.month, o.date.day, _hour);
      if (dayOf.isAfter(now)) {
        await _schedule(id++, 'Hôm nay là ngày đặc biệt 💗', o.title, dayOf);
      }
      if (o.remindDaysBefore > 0) {
        final before = dayOf.subtract(Duration(days: o.remindDaysBefore));
        if (before.isAfter(now) && id < _maxScheduled) {
          final when = o.remindDaysBefore == 1 ? 'Ngày mai' : 'Còn ${o.remindDaysBefore} ngày nữa';
          await _schedule(id++, '$when: ${o.title}', 'Đừng quên chuẩn bị nhé 🎁', before);
        }
      }
    }
  }

  static Future<void> _schedule(int id, String title, String body, DateTime local) {
    // Absolute instant: the local wall-clock time converted to UTC.
    final when = tz.TZDateTime.from(local.toUtc(), tz.UTC);
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          'Nhắc kỷ niệm',
          channelDescription: 'Nhắc các ngày kỷ niệm và sự kiện đặc biệt',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
