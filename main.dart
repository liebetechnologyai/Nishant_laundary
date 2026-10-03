import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_client.dart';
import 'config.dart';
import 'push_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/order_tracker_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.isConfigured) {
    runApp(const _ConfigErrorApp());
    return;
  }

  await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
  await PushService.bootstrap();
  runApp(const LiebeApp());
}

class LiebeApp extends StatelessWidget {
  const LiebeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LIEBE Laundry',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6D28D9)),
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      initialData: AuthState(AuthChangeEvent.initialSession, auth.currentSession),
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        return session == null ? const LoginScreen() : const HomeScreen();
      },
    );
  }
}

/// Opens the live tracker for a tapped push notification.
void openOrderFromPush(String orderId) {
  navigatorKey.currentState?.push(
    MaterialPageRoute<void>(builder: (_) => OrderTrackerScreen(orderId: orderId)),
  );
}

class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Missing configuration.\nRun with --dart-define=SUPABASE_URL=… '
              '--dart-define=SUPABASE_ANON_KEY=… --dart-define=API_URL=…',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
