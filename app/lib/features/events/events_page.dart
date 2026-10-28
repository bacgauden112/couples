import 'package:flutter/material.dart';

import '../../main.dart';
import '../../services/reminders.dart';
import 'events_logic.dart';
import 'events_repo.dart';

IconData kindIcon(String kind) => switch (kind) {
      'birthday' => Icons.cake_rounded,
      'anniversary' => Icons.favorite_rounded,
      'holiday' => Icons.celebration_rounded,
      'milestone' => Icons.auto_awesome_rounded,
      _ => Icons.event_rounded,
    };

String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String daysLabel(int days) => switch (days) {
      0 => 'Hôm nay',
      1 => 'Ngày mai',
      _ => 'Còn $days ngày',
    };

class EventsPage extends StatefulWidget {
  const EventsPage({super.key, required this.coupleId});

  final String coupleId;

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  late Future<EventsSnapshot> _data = loadEvents(widget.coupleId);

  void _reload() {
    final next = loadEvents(widget.coupleId);
    setState(() {
      _data = next;
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _enableNotifications() async {
    final ok = await Reminders.requestPermission();
    _toast(ok ? 'Đã bật nhắc nhở' : 'Chưa cấp quyền thông báo. Bạn có thể bật trong Cài đặt của điện thoại.');
  }

  Future<void> _add() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddEventSheet(coupleId: widget.coupleId),
    );
    if (created == true) {
      await Reminders.requestPermission();
      _reload();
    }
  }

  Future<void> _delete(String id) async {
    try {
      await supabase.from('events').delete().eq('id', id);
      _reload();
    } catch (e) {
      _toast('Không xóa được: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Kỷ niệm & nhắc nhở', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: 'Bật nhắc nhở',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: _enableNotifications,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm ngày'),
      ),
      body: FutureBuilder<EventsSnapshot>(
        future: _data,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Không tải được dữ liệu:\n${snap.error}', textAlign: TextAlign.center));
          }
          final d = snap.data!;
          final today = dateOnly(DateTime.now());
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              children: [
                if (d.anniversary == null)
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.info_outline_rounded, color: t.colorScheme.primary),
                      title: const Text('Chưa đặt ngày yêu nhau'),
                      subtitle: const Text('Đặt ở Trang chủ để tự có mốc 100, 200, 365 ngày...'),
                    ),
                  ),
                if (d.upcoming.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Center(child: Text('Chưa có ngày nào sắp tới', style: TextStyle(color: t.colorScheme.outline))),
                  ),
                for (final o in d.upcoming)
                  Dismissible(
                    key: ValueKey('${o.eventId ?? o.title}-${o.date}'),
                    direction: o.eventId == null ? DismissDirection.none : DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      child: Icon(Icons.delete_outline_rounded, color: t.colorScheme.error),
                    ),
                    confirmDismiss: (_) async =>
                        await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Xóa ngày này?'),
                            content: Text(o.title),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
                            ],
                          ),
                        ) ??
                        false,
                    onDismissed: (_) => _delete(o.eventId!),
                    child: Card(
                      margin: const EdgeInsets.only(top: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                        leading: CircleAvatar(
                          backgroundColor: t.colorScheme.primary.withOpacity(0.12),
                          child: Icon(kindIcon(o.kind), color: t.colorScheme.primary),
                        ),
                        title: Text(o.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(formatDate(o.date)),
                        trailing: Text(daysLabel(o.daysFrom(today)),
                            style: TextStyle(color: t.colorScheme.primary, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AddEventSheet extends StatefulWidget {
  const _AddEventSheet({required this.coupleId});

  final String coupleId;

  @override
  State<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<_AddEventSheet> {
  final _title = TextEditingController();
  DateTime? _date;
  String _kind = 'birthday';
  bool _yearly = true;
  int _remind = 1;
  bool _busy = false;

  static const _kinds = {
    'birthday': 'Sinh nhật',
    'anniversary': 'Kỷ niệm',
    'holiday': 'Ngày lễ',
    'custom': 'Khác',
  };

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _date == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nhập tên và chọn ngày nhé')));
      return;
    }
    setState(() => _busy = true);
    try {
      final d = _date!;
      final iso = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      await supabase.from('events').insert({
        'couple_id': widget.coupleId,
        'title': title,
        'event_date': iso,
        'kind': _kind,
        'repeat_yearly': _yearly,
        'remind_days_before': _remind,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không lưu được: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Thêm ngày đặc biệt', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Tên (vd: Sinh nhật em)'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final e in _kinds.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _kind == e.key,
                    onSelected: (_) => setState(() => _kind = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
              label: Text(_date == null ? 'Chọn ngày' : formatDate(_date!)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Lặp lại hằng năm'),
              value: _yearly,
              onChanged: (v) => setState(() => _yearly = v),
            ),
            Row(
              children: [
                const Expanded(child: Text('Nhắc trước')),
                DropdownButton<int>(
                  value: _remind,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Chỉ đúng ngày')),
                    DropdownMenuItem(value: 1, child: Text('1 ngày')),
                    DropdownMenuItem(value: 3, child: Text('3 ngày')),
                    DropdownMenuItem(value: 7, child: Text('7 ngày')),
                    DropdownMenuItem(value: 14, child: Text('14 ngày')),
                  ],
                  onChanged: (v) => setState(() => _remind = v ?? 1),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
