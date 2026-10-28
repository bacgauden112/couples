import 'package:flutter/material.dart';

import '../../main.dart';

const _quickMessages = ['Nhớ em/anh 💗', 'Ôm cái nào 🤗', 'Ăn cơm chưa?', 'Yêu nhiều lắm'];

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.coupleId});

  final String coupleId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> _stream = supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('couple_id', widget.coupleId)
      .order('created_at', ascending: false);
  final _myId = supabase.auth.currentUser!.id;
  int _lastUnreadMarked = 0;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final body = text.trim();
    if (body.isEmpty) return;
    _input.clear();
    try {
      await supabase.from('messages').insert({'couple_id': widget.coupleId, 'body': body});
    } catch (e) {
      if (!mounted) return;
      _input.text = body;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không gửi được: $e')));
    }
  }

  /// Mark the partner's messages as read once per new unread count.
  void _markRead(List<Map<String, dynamic>> msgs) {
    final unread = msgs.where((m) => m['sender_id'] != _myId && m['read_at'] == null).length;
    if (unread > 0 && unread != _lastUnreadMarked) {
      _lastUnreadMarked = unread;
      supabase.rpc('mark_messages_read', params: {'cid': widget.coupleId}).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Trò chuyện', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Không tải được tin nhắn:\n${snap.error}', textAlign: TextAlign.center));
                }
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final msgs = snap.data!;
                WidgetsBinding.instance.addPostFrameCallback((_) => _markRead(msgs));
                if (msgs.isEmpty) {
                  return Center(
                    child: Text('Hãy gửi lời đầu tiên 💌', style: TextStyle(color: t.colorScheme.outline)),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    final mine = m['sender_id'] == _myId;
                    // Newest message is index 0; show "seen" under my latest message only.
                    final showSeen = mine && m['read_at'] != null && msgs.indexWhere((x) => x['sender_id'] == _myId) == i;
                    return _Bubble(
                      text: m['body'] as String,
                      time: DateTime.parse(m['created_at'] as String).toLocal(),
                      mine: mine,
                      seen: showSeen,
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickMessages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ActionChip(
                label: Text(_quickMessages[i]),
                onPressed: () => _send(_quickMessages[i]),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Nhắn gì đó...', counterText: ''),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => _send(_input.text),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.time, required this.mine, required this.seen});

  final String text;
  final DateTime time;
  final bool mine;
  final bool seen;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final bg = mine ? t.colorScheme.primary : t.colorScheme.surfaceContainerHighest;
    final fg = mine ? t.colorScheme.onPrimary : t.colorScheme.onSurface;
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(mine ? 20 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 20),
                ),
              ),
              child: Text(text, style: TextStyle(color: fg, fontSize: 16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
            child: Text(
              seen ? '$hh:$mm · Đã xem' : '$hh:$mm',
              style: TextStyle(fontSize: 11, color: t.colorScheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}
