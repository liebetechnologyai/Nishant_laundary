import 'package:intl/intl.dart';

final NumberFormat _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

String formatINR(num value) => _inr.format(value);

String formatDateTime(DateTime d) => DateFormat('d MMM y, h:mm a').format(d.toLocal());

/// Forward-only order flow, matching the backend/database.
const List<String> statusFlow = [
  'pending',
  'pickup_done',
  'in_processing',
  'ready_for_delivery',
  'delivered',
];

const Map<String, String> statusLabels = {
  'pending': 'Pending',
  'pickup_done': 'Pickup Done',
  'in_processing': 'In Processing',
  'ready_for_delivery': 'Ready for Delivery',
  'delivered': 'Delivered',
  'cancelled': 'Cancelled',
};

String statusLabel(String status) => statusLabels[status] ?? status;

/// 10 digits -> +91XXXXXXXXXX; 11-15 digits -> +<digits>; otherwise '' (invalid).
String toE164(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 10) return '+91$digits';
  if (digits.length >= 11 && digits.length <= 15) return '+$digits';
  return '';
}
