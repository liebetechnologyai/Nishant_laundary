double _d(dynamic v) => v is num ? v.toDouble() : double.parse(v.toString());

class Service {
  final String id;
  final String name;
  final String unit;
  final double price;

  const Service({required this.id, required this.name, required this.unit, required this.price});

  factory Service.fromJson(Map<String, dynamic> j) => Service(
        id: j['id'] as String,
        name: j['name'] as String,
        unit: (j['unit'] as String?) ?? 'piece',
        price: _d(j['price']),
      );
}

class Category {
  final String id;
  final String name;
  final String? description;
  final List<Service> services;

  const Category({required this.id, required this.name, this.description, required this.services});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        services: ((j['services'] as List?) ?? const [])
            .map((s) => Service.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class OrderItem {
  final String itemName;
  final String categoryName;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  const OrderItem({
    required this.itemName,
    required this.categoryName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        itemName: j['item_name'] as String,
        categoryName: j['category_name'] as String,
        quantity: (j['quantity'] as num).toInt(),
        unitPrice: _d(j['unit_price']),
        lineTotal: _d(j['line_total']),
      );
}

class Order {
  final String id;
  final String orderNumber;
  final String status;
  final String paymentStatus;
  final String? customerName;
  final String? customerPhone;
  final String? pickupAddress;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final DateTime createdAt;
  final List<OrderItem> items;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentStatus,
    this.customerName,
    this.customerPhone,
    this.pickupAddress,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.createdAt,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'] as String,
        orderNumber: j['order_number'] as String,
        status: j['status'] as String,
        paymentStatus: j['payment_status'] as String,
        customerName: j['customer_name'] as String?,
        customerPhone: j['customer_phone'] as String?,
        pickupAddress: j['pickup_address'] as String?,
        subtotal: _d(j['subtotal']),
        discount: _d(j['discount']),
        tax: _d(j['tax']),
        total: _d(j['total_amount']),
        createdAt: DateTime.parse(j['created_at'] as String),
        items: ((j['order_items'] as List?) ?? const [])
            .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
            .toList(),
      );
}

class StatusEntry {
  final String status;
  final String? note;
  final DateTime createdAt;

  const StatusEntry({required this.status, this.note, required this.createdAt});

  factory StatusEntry.fromJson(Map<String, dynamic> j) => StatusEntry(
        status: j['status'] as String,
        note: j['note'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class OrderDetail {
  final Order order;
  final List<StatusEntry> history;

  const OrderDetail({required this.order, required this.history});

  factory OrderDetail.fromJson(Map<String, dynamic> j) => OrderDetail(
        order: Order.fromJson(j),
        history: ((j['history'] as List?) ?? const [])
            .map((h) => StatusEntry.fromJson(h as Map<String, dynamic>))
            .toList(),
      );
}

class Invoice {
  final String invoiceNumber;
  final String? pdfUrl;
  final DateTime issuedAt;

  const Invoice({required this.invoiceNumber, this.pdfUrl, required this.issuedAt});

  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
        invoiceNumber: j['invoice_number'] as String,
        pdfUrl: j['pdf_url'] as String?,
        issuedAt: DateTime.parse(j['issued_at'] as String),
      );
}
