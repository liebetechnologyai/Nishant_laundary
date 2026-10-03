import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api_client.dart';
import '../models.dart';
import '../util.dart';

class ReceiptScreen extends StatefulWidget {
  final Order order;
  const ReceiptScreen({super.key, required this.order});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  bool _busy = false;

  Future<void> _downloadInvoice() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final invoice = await api.getInvoice(widget.order.id);
      final url = invoice.pdfUrl;
      if (url == null) throw const ApiException(0, 'NO_PDF', 'Invoice PDF is not available yet.');
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened) throw const ApiException(0, 'LAUNCH_FAILED', 'Could not open the invoice.');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LIEBE Laundry', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _kv('Order', o.orderNumber),
                  _kv('Date', formatDateTime(o.createdAt)),
                  if (o.customerName != null && o.customerName!.isNotEmpty) _kv('Customer', o.customerName!),
                  _kv('Payment', o.paymentStatus.toUpperCase()),
                  const Divider(height: 24),
                  for (final it in o.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${it.quantity} × ${it.itemName}'),
                                Text('@ ${formatINR(it.unitPrice)} · ${it.categoryName}',
                                    style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                          Text(formatINR(it.lineTotal)),
                        ],
                      ),
                    ),
                  const Divider(height: 24),
                  _amount('Subtotal', formatINR(o.subtotal)),
                  if (o.discount > 0) _amount('Discount', '− ${formatINR(o.discount)}'),
                  if (o.tax > 0) _amount('Tax', formatINR(o.tax)),
                  const SizedBox(height: 4),
                  _amount('Total', formatINR(o.total), bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _downloadInvoice,
            icon: _busy
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download),
            label: const Text('Download invoice (PDF)'),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(width: 90, child: Text(k, style: const TextStyle(color: Colors.black54))),
            Expanded(child: Text(v)),
          ],
        ),
      );

  Widget _amount(String k, String v, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 18 : 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [Expanded(child: Text(k, style: style)), Text(v, style: style)]),
    );
  }
}
