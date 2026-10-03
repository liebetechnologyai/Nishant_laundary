import 'package:flutter/material.dart';

import '../api_client.dart';
import '../models.dart';
import '../util.dart';

class NewOrderScreen extends StatefulWidget {
  final void Function(Order order) onPlaced;
  const NewOrderScreen({super.key, required this.onPlaced});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  static const _maxQty = 99;

  List<Category> _categories = [];
  final Map<String, int> _cart = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cats = await api.catalog();
      if (mounted) setState(() => _categories = cats);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, Service> get _servicesById => {
        for (final c in _categories) for (final s in c.services) s.id: s,
      };

  int get _itemCount => _cart.values.fold(0, (a, b) => a + b);

  double get _subtotal {
    final byId = _servicesById;
    return _cart.entries.fold(0.0, (sum, e) => sum + (byId[e.key]?.price ?? 0) * e.value);
  }

  void _setQty(String id, int qty) {
    setState(() {
      final q = qty.clamp(0, _maxQty);
      if (q == 0) {
        _cart.remove(id);
      } else {
        _cart[id] = q;
      }
    });
  }

  Future<void> _checkout() async {
    final order = await showModalBottomSheet<Order>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CheckoutSheet(
        lines: [
          for (final e in _cart.entries)
            if (_servicesById[e.key] != null) (_servicesById[e.key]!, e.value),
        ],
        subtotal: _subtotal,
        items: Map<String, int>.of(_cart),
      ),
    );
    if (order != null && mounted) {
      setState(_cart.clear);
      widget.onPlaced(order);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }
    if (_categories.isEmpty) {
      return const Center(child: Text('No services available right now.'));
    }

    return DefaultTabController(
      length: _categories.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final c in _categories) Tab(text: c.name)],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final c in _categories)
                  ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: c.services.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final s = c.services[i];
                      final q = _cart[s.id] ?? 0;
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          title: Text(s.name),
                          subtitle: Text('${formatINR(s.price)} / ${s.unit}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Remove one ${s.name}',
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: q == 0 ? null : () => _setQty(s.id, q - 1),
                              ),
                              SizedBox(width: 24, child: Text('$q', textAlign: TextAlign.center)),
                              IconButton(
                                tooltip: 'Add one ${s.name}',
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: q >= _maxQty ? null : () => _setQty(s.id, q + 1),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          if (_itemCount > 0)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$_itemCount item${_itemCount == 1 ? '' : 's'}'),
                          Text(formatINR(_subtotal),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    ),
                    FilledButton(onPressed: _checkout, child: const Text('Schedule pickup')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CheckoutSheet extends StatefulWidget {
  final List<(Service, int)> lines;
  final double subtotal;
  final Map<String, int> items;

  const _CheckoutSheet({required this.lines, required this.subtotal, required this.items});

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    try {
      final me = await api.me();
      if (!mounted) return;
      if (_name.text.isEmpty) _name.text = (me['full_name'] as String?) ?? '';
      if (_address.text.isEmpty) _address.text = (me['address_line'] as String?) ?? '';
    } catch (_) {
      // Prefill is a convenience only; the user can still type the details.
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final address = _address.text.trim();
    if (name.isEmpty) return setState(() => _error = 'Enter your name');
    if (address.length < 5) return setState(() => _error = 'Enter your full pickup address');

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api.updateMe(fullName: name, addressLine: address);
      final order = await api.createOrder(
        pickupAddress: address,
        notes: _notes.text.trim(),
        items: widget.items,
      );
      if (mounted) Navigator.of(context).pop(order);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Confirm pickup', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final (service, qty) in widget.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text('$qty × ${service.name} @ ${formatINR(service.price)}')),
                    Text(formatINR(service.price * qty)),
                  ],
                ),
              ),
            const Divider(),
            Row(
              children: [
                const Expanded(child: Text('Estimated total', style: TextStyle(fontWeight: FontWeight.bold))),
                Text(formatINR(widget.subtotal), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Your name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Pickup address', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Place order'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
