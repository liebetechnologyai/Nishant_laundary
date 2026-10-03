import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api_client.dart';
import '../models.dart';
import '../util.dart';
import 'receipt_screen.dart';

class OrderTrackerScreen extends StatefulWidget {
  final String orderId;
  const OrderTrackerScreen({super.key, required this.orderId});

  @override
  State<OrderTrackerScreen> createState() => _OrderTrackerScreenState();
}

class _OrderTrackerScreenState extends State<OrderTrackerScreen> {
  OrderDetail? _detail;
  String? _error;
  RealtimeChannel? _channel;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
    // Safety net in case the realtime socket drops while the screen is open.
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    final channel = _channel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    super.dispose();
  }

  // Row Level Security limits these events to the signed-in customer's own order.
  void _subscribe() {
    _channel = Supabase.instance.client
        .channel('order-${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.orderId,
          ),
          callback: (_) => _load(silent: true),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'order_status_history',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: widget.orderId,
          ),
          callback: (_) => _load(silent: true),
        )
        .subscribe();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final detail = await api.getOrder(widget.orderId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && (!silent || _detail == null)) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      appBar: AppBar(title: Text(detail?.order.orderNumber ?? 'Order')),
      body: detail == null
          ? (_error == null
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _load, child: const Text('Try again')),
                    ],
                  ),
                ))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _Timeline(order: detail.order, history: detail.history),
                  const SizedBox(height: 16),
                  _ItemsCard(order: detail.order),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('View receipt & invoice'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => ReceiptScreen(order: detail.order)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final Order order;
  final List<StatusEntry> history;
  const _Timeline({required this.order, required this.history});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cancelled = order.status == 'cancelled';
    final currentIndex = statusFlow.indexOf(order.status);

    final timestamps = <String, DateTime>{};
    for (final h in history) {
      timestamps.putIfAbsent(h.status, () => h.createdAt);
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order status', style: Theme.of(context).textTheme.titleMedium),
            if (cancelled)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.cancel, color: scheme.error),
                    const SizedBox(width: 8),
                    Text('This order was cancelled', style: TextStyle(color: scheme.error)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            for (var i = 0; i < statusFlow.length; i++)
              _TimelineTile(
                label: statusLabel(statusFlow[i]),
                time: timestamps[statusFlow[i]],
                done: !cancelled && i < currentIndex || (!cancelled && i == currentIndex && statusFlow[i] == 'delivered'),
                current: !cancelled && i == currentIndex && statusFlow[i] != 'delivered',
                isLast: i == statusFlow.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final String label;
  final DateTime? time;
  final bool done;
  final bool current;
  final bool isLast;

  const _TimelineTile({
    required this.label,
    required this.time,
    required this.done,
    required this.current,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = done || current;
    final color = active ? scheme.primary : scheme.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? color : Colors.transparent,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: done
                      ? Icon(Icons.check, size: 14, color: scheme.onPrimary)
                      : current
                          ? Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)))
                          : null,
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: done ? color : scheme.outlineVariant)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontWeight: current ? FontWeight.bold : FontWeight.normal,
                        color: active ? null : scheme.outline,
                      )),
                  if (time != null)
                    Text(formatDateTime(time!), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  final Order order;
  const _ItemsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Items', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final it in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text('${it.quantity} × ${it.itemName} @ ${formatINR(it.unitPrice)}')),
                    Text(formatINR(it.lineTotal)),
                  ],
                ),
              ),
            const Divider(),
            Row(
              children: [
                const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                Text(formatINR(order.total), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
