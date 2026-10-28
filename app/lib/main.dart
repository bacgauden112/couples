import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'features/auth/auth_page.dart';
import 'features/pairing/pairing_page.dart';
import 'features/shell/home_shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const CouplesApp());
}

final supabase = Supabase.instance.client;

class CouplesApp extends StatelessWidget {
  const CouplesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Couples',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const AuthGate(),
    );
  }
}

/// Signed out -> AuthPage; signed in without a couple -> PairingPage; else HomePage.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, _) {
        if (supabase.auth.currentSession == null) return const AuthPage();
        return const CoupleGate();
      },
    );
  }
}

class CoupleGate extends StatefulWidget {
  const CoupleGate({super.key});

  @override
  State<CoupleGate> createState() => _CoupleGateState();
}

class _CoupleGateState extends State<CoupleGate> {
  late Future<String?> _coupleId = _load();

  Future<String?> _load() async {
    final row = await supabase
        .from('couple_members')
        .select('couple_id')
        .eq('user_id', supabase.auth.currentUser!.id)
        .maybeSingle();
    return row?['couple_id'] as String?;
  }

  void _reload() {
    final next = _load();
    setState(() {
      _coupleId = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _coupleId,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Không tải được dữ liệu:\n${snap.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _reload, child: const Text('Thử lại')),
                  ],
                ),
              ),
            ),
          );
        }
        final id = snap.data;
        if (id == null) return PairingPage(onPaired: _reload);
        return HomeShell(coupleId: id);
      },
    );
  }
}
