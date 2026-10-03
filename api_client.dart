import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  final int status;
  final String code;
  final String message;
  const ApiException(this.status, this.code, this.message);

  @override
  String toString() => message;
}

String _validationMessage(dynamic details) {
  final fields = (details is Map ? details['fieldErrors'] : null);
  if (fields is Map && fields.isNotEmpty) {
    return fields.entries
        .map((e) => '${e.key}: ${(e.value as List).isNotEmpty ? (e.value as List).first : 'invalid'}')
        .join('; ');
  }
  return 'Invalid request';
}

class ApiClient {
  final http.Client _http = http.Client();
  static const _timeout = Duration(seconds: 20);

  Future<dynamic> _request(String method, String path, {Object? body}) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    final uri = Uri.parse('${AppConfig.apiUrl}/api/v1$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final encoded = body == null ? null : jsonEncode(body);

    http.Response res;
    try {
      switch (method) {
        case 'POST':
          res = await _http.post(uri, headers: headers, body: encoded).timeout(_timeout);
        case 'PATCH':
          res = await _http.patch(uri, headers: headers, body: encoded).timeout(_timeout);
        default:
          res = await _http.get(uri, headers: headers).timeout(_timeout);
      }
    } on SocketException {
      throw const ApiException(0, 'NETWORK_ERROR', 'No internet connection. Please try again.');
    } on TimeoutException {
      throw const ApiException(0, 'TIMEOUT', 'The server took too long to respond.');
    } on http.ClientException {
      throw const ApiException(0, 'NETWORK_ERROR', 'Could not reach the server.');
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      throw ApiException(res.statusCode, 'BAD_RESPONSE', 'Unexpected server response.');
    }

    if (decoded['success'] != true) {
      final err = (decoded['error'] as Map<String, dynamic>?) ?? const {};
      final code = (err['code'] as String?) ?? 'ERROR';
      final message = code == 'VALIDATION_ERROR'
          ? _validationMessage(err['details'])
          : (err['message'] as String?) ?? 'Request failed';
      throw ApiException(res.statusCode, code, message);
    }
    return decoded['data'];
  }

  Future<List<Category>> catalog() async {
    final data = await _request('GET', '/catalog') as List;
    return data
        .map((c) => Category.fromJson(c as Map<String, dynamic>))
        .where((c) => c.services.isNotEmpty)
        .toList();
  }

  Future<Map<String, dynamic>> me() async => await _request('GET', '/me') as Map<String, dynamic>;

  Future<void> updateMe({String? fullName, String? addressLine}) async {
    final body = <String, String>{
      if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
      if (addressLine != null && addressLine.isNotEmpty) 'address_line': addressLine,
    };
    if (body.isEmpty) return;
    await _request('PATCH', '/me', body: body);
  }

  Future<void> registerDevice(String fcmToken) async {
    await _request('POST', '/me/device', body: {'fcm_token': fcmToken});
  }

  Future<Order> createOrder({
    required String pickupAddress,
    String? notes,
    required Map<String, int> items,
  }) async {
    final data = await _request('POST', '/orders', body: {
      'pickup_address': pickupAddress,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'items': items.entries.map((e) => {'service_id': e.key, 'quantity': e.value}).toList(),
    });
    return Order.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Order>> listOrders() async {
    final data = await _request('GET', '/orders?limit=100') as Map<String, dynamic>;
    return (data['items'] as List).map((o) => Order.fromJson(o as Map<String, dynamic>)).toList();
  }

  Future<OrderDetail> getOrder(String id) async =>
      OrderDetail.fromJson(await _request('GET', '/orders/$id') as Map<String, dynamic>);

  Future<Invoice> getInvoice(String orderId) async =>
      Invoice.fromJson(await _request('GET', '/orders/$orderId/invoice') as Map<String, dynamic>);
}

final ApiClient api = ApiClient();
