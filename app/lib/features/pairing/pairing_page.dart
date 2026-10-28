import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart';

class PairingPage extends StatefulWidget {
  const PairingPage({super.key, required this.onPaired});

  final VoidCallback onPaired;

  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      widget.onPaired();
    } on PostgrestException catch (e) {
      _toast(_friendly(e.message));
    } catch (e) {
      _toast('Có lỗi xảy ra: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(String m) {
    if (m.contains('invalid invite code')) return 'Mã mời không đúng.';
    if (m.contains('couple is full')) return 'Cặp đôi này đã đủ 2 người.';
    if (m.contains('already in a couple')) return 'Bạn đã thuộc một cặp đôi.';
    return m;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(onPressed: () => supabase.auth.signOut(), child: const Text('Đăng xuất')),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Kết nối với người ấy',
                      style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('Một người tạo không gian, người còn lại nhập mã mời.',
                      style: t.textTheme.bodyLarge?.copyWith(color: t.colorScheme.outline)),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              await supabase.rpc('create_couple');
                            }),
                    child: const Text('Tạo không gian mới'),
                  ),
                  const SizedBox(height: 28),
                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('hoặc', style: TextStyle(color: t.colorScheme.outline)),
                    ),
                    const Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(hintText: 'Nhập mã mời'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              await supabase.rpc('join_couple', params: {'code': _code.text});
                            }),
                    child: const Text('Tham gia'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
