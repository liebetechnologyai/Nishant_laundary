import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';
import '../util.dart';
import 'order_tracker_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => OrdersScreenState();
}

class OrdersScreenState extends State<OrdersScreen> {
  List<Order>? _orders;
  String? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final orders = await api.listOrders();
      if (mounted) {
        setState(() {
          _orders = orders;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = _orders;
    if (orders == null && _error == null) return const Center(child: CircularProgressIndicator());
    if (orders == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: reload, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (orders.isEmpty) {
      return const Center(child: Text('No orders yet. Pick a service to get started.'));
    }

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final o = orders[i];
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              title: Text(o.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${formatDateTime(o.createdAt)}\n${formatINR(o.total)}'),
              isThreeLine: true,
              trailing: _StatusChip(status: o.status),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => OrderTrackerScreen(orderId: o.id)),
                );
                reload();
              },
            ),
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = status == 'delivered';
    final cancelled = status == 'cancelled';
    return Chip(
      label: Text(statusLabel(status), style: const TextStyle(fontSize: 12)),
      backgroundColor: cancelled
          ? scheme.errorContainer
          : done
              ? Colors.green.shade100
              : scheme.primaryContainer,
      visualDensity: VisualDensity.compact,
    );
  }
}
