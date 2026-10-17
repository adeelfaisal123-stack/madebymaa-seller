import '../utils/order_number.dart';

class SellerDashboardStats {
  const SellerDashboardStats({
    required this.ordersToday,
    required this.activeOrders,
    required this.pendingOrdersCount,
    required this.deliveredOrdersCount,
    required this.completedToday,
    required this.earningsToday,
    required this.earningsWeek,
    required this.earningsTotal,
    required this.dishesCount,
    required this.dishesAvailable,
    required this.ratingAverage,
    required this.ratingCount,
  });

  final int ordersToday;
  final int activeOrders;
  final int pendingOrdersCount;
  final int deliveredOrdersCount;
  final int completedToday;
  final double earningsToday;
  final double earningsWeek;
  final double earningsTotal;
  final int dishesCount;
  final int dishesAvailable;
  final double ratingAverage;
  final int ratingCount;

  factory SellerDashboardStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return SellerDashboardStats.empty;
    double d(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    int i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

    return SellerDashboardStats(
      ordersToday: i(json['orders_today']),
      activeOrders: i(json['active_orders']),
      pendingOrdersCount: i(json['pending_orders_count']),
      deliveredOrdersCount: i(json['delivered_orders_count']),
      completedToday: i(json['completed_today']),
      earningsToday: d(json['earnings_today']),
      earningsWeek: d(json['earnings_week']),
      earningsTotal: d(json['earnings_total']),
      dishesCount: i(json['dishes_count']),
      dishesAvailable: i(json['dishes_available']),
      ratingAverage: d(json['rating_average']),
      ratingCount: i(json['rating_count']),
    );
  }

  static const empty = SellerDashboardStats(
    ordersToday: 0,
    activeOrders: 0,
    pendingOrdersCount: 0,
    deliveredOrdersCount: 0,
    completedToday: 0,
    earningsToday: 0,
    earningsWeek: 0,
    earningsTotal: 0,
    dishesCount: 0,
    dishesAvailable: 0,
    ratingAverage: 0,
    ratingCount: 0,
  );

  String get ratingLabel =>
      ratingCount > 0 ? ratingAverage.toStringAsFixed(1) : '—';
}

class SellerPendingOrder {
  const SellerPendingOrder({
    required this.id,
    required this.orderNumber,
    required this.statusLabel,
    required this.customerName,
    required this.itemCount,
    required this.kitchenTotal,
    required this.paymentLabel,
    required this.deliverySlotLabel,
    required this.placedAtHuman,
    required this.itemsPreview,
  });

  final int id;
  final String orderNumber;
  final String statusLabel;
  final String customerName;
  final int itemCount;
  final double kitchenTotal;
  final String paymentLabel;
  final String deliverySlotLabel;
  final String placedAtHuman;
  final List<String> itemsPreview;

  factory SellerPendingOrder.fromJson(Map<String, dynamic> json) {
    final preview = json['items_preview'];
    int i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    String s(dynamic v) => v == null ? '' : '$v';

    return SellerPendingOrder(
      id: i(json['id']),
      orderNumber: normalizeOrderNumber(s(json['order_number'])),
      statusLabel: s(json['status_label']).isEmpty ? 'Pending' : s(json['status_label']),
      customerName: s(json['customer_name']).isEmpty ? 'Customer' : s(json['customer_name']),
      itemCount: i(json['item_count']),
      kitchenTotal: d(json['kitchen_total']),
      paymentLabel: s(json['payment_label']),
      deliverySlotLabel: s(json['delivery_slot_label']),
      placedAtHuman: s(json['placed_at_human']),
      itemsPreview: preview is List
          ? preview.map((e) => s(e)).where((t) => t.isNotEmpty).toList()
          : const [],
    );
  }

  String get itemsSummary {
    if (itemsPreview.isEmpty) {
      return itemCount == 1 ? '1 item' : '$itemCount items';
    }
    final joined = itemsPreview.join(', ');
    if (itemCount > itemsPreview.length) {
      return '$joined +${itemCount - itemsPreview.length} more';
    }
    return joined;
  }

  String get displayNumber => formatOrderDisplayNumber(
        orderNumber: orderNumber,
        id: id,
      );
}

class SellerWeeklyEarningDay {
  const SellerWeeklyEarningDay({
    required this.label,
    required this.date,
    required this.amount,
    required this.isToday,
  });

  final String label;
  final String date;
  final double amount;
  final bool isToday;

  factory SellerWeeklyEarningDay.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

    return SellerWeeklyEarningDay(
      label: json['label']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      amount: d(json['amount']),
      isToday: json['is_today'] == true,
    );
  }
}

List<SellerWeeklyEarningDay> parseWeeklyEarnings(
  Object? raw,
  SellerDashboardStats stats,
) {
  if (raw is List && raw.isNotEmpty) {
    return raw
        .whereType<Map<String, dynamic>>()
        .map(SellerWeeklyEarningDay.fromJson)
        .toList();
  }
  return _fallbackWeeklyEarnings(stats);
}

List<SellerWeeklyEarningDay> _fallbackWeeklyEarnings(SellerDashboardStats stats) {
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - DateTime.monday));

  return List.generate(7, (index) {
    final day = monday.add(Duration(days: index));
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final date =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

    return SellerWeeklyEarningDay(
      label: labels[index],
      date: date,
      amount: isToday ? stats.earningsToday : 0,
      isToday: isToday,
    );
  });
}

class SellerDashboard {
  const SellerDashboard({
    required this.kitchenName,
    required this.stats,
    required this.pendingOrders,
    required this.weeklyEarnings,
  });

  final String kitchenName;
  final SellerDashboardStats stats;
  final List<SellerPendingOrder> pendingOrders;
  final List<SellerWeeklyEarningDay> weeklyEarnings;

  factory SellerDashboard.fromJson(Map<String, dynamic> json) {
    final kitchen = json['kitchen'];
    final stats = json['stats'];
    final pending = json['pending_orders'];
    final parsedStats = stats is Map<String, dynamic>
        ? SellerDashboardStats.fromJson(stats)
        : SellerDashboardStats.empty;

    return SellerDashboard(
      kitchenName: kitchen is Map
          ? (kitchen['name'] as String?) ?? 'Your kitchen'
          : 'Your kitchen',
      stats: parsedStats,
      pendingOrders: pending is List
          ? pending
              .whereType<Map<String, dynamic>>()
              .map(SellerPendingOrder.fromJson)
              .toList()
          : const [],
      weeklyEarnings:
          parseWeeklyEarnings(json['weekly_earnings'], parsedStats),
    );
  }

  static const empty = SellerDashboard(
    kitchenName: 'Your kitchen',
    stats: SellerDashboardStats.empty,
    pendingOrders: [],
    weeklyEarnings: [],
  );
}

String formatInr(num amount) {
  final value = amount.round();
  if (value >= 100000) {
    return '₹${(value / 100000).toStringAsFixed(1)}L';
  }
  if (value >= 1000) {
    return '₹${(value / 1000).toStringAsFixed(1)}k';
  }
  return '₹$value';
}
