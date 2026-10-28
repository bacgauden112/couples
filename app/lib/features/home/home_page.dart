import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../main.dart';
import '../events/events_logic.dart';
import '../events/events_page.dart' show kindIcon, formatDate, daysLabel;
import '../events/events_repo.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.coupleId});

  final String coupleId;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<_HomeData> _data = _load();

  Future<_HomeData> _load() async {
    final couple = await supabase
        .from('couples')
        .select('invite_code, anniversary')
        .eq('id', widget.coupleId)
        .single();
    final members = await supabase
        .from('couple_members')
        .select('user_id')
        .eq('couple_id', widget.coupleId);
    final profiles = await supabase.from('profiles').select('id, display_name');
    final names = [
      for (final p in profiles) (p['display_name'] as String).isEmpty ? 'Bạn' : p['display_name'] as String
    ];
    final ann = couple['anniversary'] as String?;
    // Also re-syncs on-device reminders every time the home screen loads.
    List<Occurrence> upcoming = const [];
    try {
      upcoming = (await loadEvents(widget.coupleId)).upcoming;
    } catch (_) {
      // Events table may not exist yet; the rest of the home screen still works.
    }
    return _HomeData(
      inviteCode: couple['invite_code'] as String,
      anniversary: ann == null ? null : DateTime.parse(ann),
      memberCount: members.length,
      names: names,
      upcoming: upcoming,
    );
  }

  void _reload() {
    final next = _load();
    setState(() {
      _data = next;
    });
  }

  Future<void> _pickDate(DateTime? current) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(1990),
      lastDate: now,
      helpText: 'Ngày hai bạn bắt đầu yêu nhau',
    );
    if (picked == null) return;
    final iso = '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    await supabase.from('couples').update({'anniversary': iso}).eq('id', widget.coupleId);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Couples', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => supabase.auth.signOut(),
          ),
        ],
      ),
      body: FutureBuilder<_HomeData>(
        future: _data,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Không tải được dữ liệu:\n${snap.error}', textAlign: TextAlign.center));
          }
          final d = snap.data!;
          final days = d.anniversary == null
              ? null
              : DateTime.now().difference(d.anniversary!).inDays + 1;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _pickDate(d.anniversary),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                      child: Column(
                        children: [
                          Icon(Icons.favorite_rounded, color: t.colorScheme.primary),
                          const SizedBox(height: 12),
                          Text(
                            days?.toString() ?? '—',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 72,
                              height: 1.1,
                              color: t.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            days == null ? 'Chạm để đặt ngày yêu nhau' : 'ngày bên nhau',
                            style: t.textTheme.bodyLarge?.copyWith(color: t.colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (d.memberCount < 2)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mời người ấy tham gia',
                              style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Gửi mã này để người kia nhập khi mở app.',
                              style: TextStyle(color: t.colorScheme.outline)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Text(d.inviteCode,
                                    style: t.textTheme.headlineSmall
                                        ?.copyWith(letterSpacing: 4, fontWeight: FontWeight.w600)),
                              ),
                              IconButton(
                                tooltip: 'Sao chép',
                                icon: const Icon(Icons.copy_rounded),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: d.inviteCode));
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(content: Text('Đã sao chép mã mời')));
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: Icon(Icons.people_alt_rounded, color: t.colorScheme.primary),
                      title: Text(d.names.join('  ♥  ')),
                      subtitle: const Text('Đã kết nối'),
                    ),
                  ),
                if (d.upcoming.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Sắp tới', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  for (final o in d.upcoming.take(3))
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: t.colorScheme.primary.withOpacity(0.12),
                          child: Icon(kindIcon(o.kind), color: t.colorScheme.primary),
                        ),
                        title: Text(o.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(formatDate(o.date)),
                        trailing: Text(daysLabel(o.daysFrom(dateOnly(DateTime.now()))),
                            style: TextStyle(color: t.colorScheme.primary, fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HomeData {
  _HomeData({
    required this.inviteCode,
    required this.anniversary,
    required this.memberCount,
    required this.names,
    required this.upcoming,
  });

  final List<Occurrence> upcoming;
  final String inviteCode;
  final DateTime? anniversary;
  final int memberCount;
  final List<String> names;
}
