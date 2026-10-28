import 'package:flutter/material.dart';

import '../chat/chat_page.dart';
import '../home/home_page.dart';
import 'more_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.coupleId});

  final String coupleId;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(coupleId: widget.coupleId),
      const _ComingSoon(title: 'Nhật ký', icon: Icons.menu_book_rounded),
      ChatPage(coupleId: widget.coupleId),
      const _ComingSoon(title: 'Chi tiêu', icon: Icons.account_balance_wallet_rounded),
      MorePage(coupleId: widget.coupleId),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.favorite_border_rounded), selectedIcon: Icon(Icons.favorite_rounded), label: 'Trang chủ'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: 'Nhật ký'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline_rounded), selectedIcon: Icon(Icons.chat_bubble_rounded), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Chi tiêu'),
          NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps_rounded), label: 'Thêm'),
        ],
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600))),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: t.colorScheme.outline),
            const SizedBox(height: 12),
            Text('Sắp có', style: TextStyle(color: t.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}
