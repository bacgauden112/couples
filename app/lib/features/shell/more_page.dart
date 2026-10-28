import 'package:flutter/material.dart';

import '../events/events_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key, required this.coupleId});

  final String coupleId;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Thêm', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Icon(Icons.event_rounded, color: t.colorScheme.primary),
              title: const Text('Kỷ niệm & nhắc nhở'),
              subtitle: const Text('Sinh nhật, mốc ngày yêu nhau, ngày lễ'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EventsPage(coupleId: coupleId)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
