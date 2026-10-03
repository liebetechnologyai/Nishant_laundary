import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart' show openOrderFromPush;
import '../models.dart';
import '../push_service.dart';
import 'new_order_screen.dart';
import 'order_tracker_screen.dart';
import 'orders_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  final GlobalKey<OrdersScreenState> _ordersKey = GlobalKey<OrdersScreenState>();

  @override
  void initState() {
    super.initState();
    PushService.start(openOrderFromPush);
  }

  void _onOrderPlaced(Order order) {
    setState(() => _tab = 1);
    _ordersKey.currentState?.reload();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => OrderTrackerScreen(orderId: order.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LIEBE Laundry'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          NewOrderScreen(onPlaced: _onOrderPlaced),
          OrdersScreen(key: _ordersKey),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == 1) _ordersKey.currentState?.reload();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.local_laundry_service_outlined), label: 'Services'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'My Orders'),
        ],
      ),
    );
  }
}
