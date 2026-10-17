import '../config/optica2_asset_url.dart';
import '../utils/order_number.dart';

enum SellerOrderFilter {
  all('all', 'All'),
  pending('pending', 'Pending'),
  accepted('accepted', 'Accepted'),
  readyToPickUp('ready_to_pick_up', 'Ready to be picked up'),
  pickedUp('picked_up', 'Picked up'),
  onWay('on_way', 'On the way'),
  delivered('delivered', 'Delivered'),
  cancelled('cancelled', 'Cancelled');

  const SellerOrderFilter(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class SellerOrder {
  const SellerOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.statusLabel,
    required this.customerName,
    required this.itemCount,
    required this.kitchenTotal,
    required this.paymentLabel,
    required this.paymentStatus,
    required this.deliverySlotLabel,
    required this.placedAtHuman,
    required this.itemsPreview,
  });

  final int id;
  final String orderNumber;
  final String status;
  final String statusLabel;
  final String customerName;
  final int itemCount;
  final double kitchenTotal;
  final String paymentLabel;
  final String paymentStatus;
  final String deliverySlotLabel;
  final String placedAtHuman;
  final List<String> itemsPreview;

  factory SellerOrder.fromJson(Map<String, dynamic> json) {
    final preview = json['items_preview'];
    return SellerOrder(
      id: _jsonInt(json['id']),
      orderNumber: normalizeOrderNumber(_jsonStr(json['order_number'])),
      status: _jsonStr(json['status']),
      statusLabel: _jsonStr(json['status_label']),
      customerName: _jsonStr(json['customer_name']).isEmpty
          ? 'Customer'
          : _jsonStr(json['customer_name']),
      itemCount: _jsonInt(json['item_count']),
      kitchenTotal: _jsonDouble(json['kitchen_total']),
      paymentLabel: _jsonStr(json['payment_label']),
      paymentStatus: _jsonStr(json['payment_status']),
      deliverySlotLabel: _jsonStr(json['delivery_slot_label']),
      placedAtHuman: _jsonStr(json['placed_at_human']),
      itemsPreview: preview is List
          ? preview.map((e) => _jsonStr(e)).where((s) => s.isNotEmpty).toList()
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

class SellerOrderDetail {
  const SellerOrderDetail({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.statusLabel,
    required this.statusStepIndex,
    required this.statusTimeline,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.deliverySlotLabel,
    required this.deliveryTimeLabel,
    required this.notes,
    required this.itemCount,
    required this.kitchenTotal,
    required this.paymentLabel,
    required this.paymentStatus,
    required this.placedAtHuman,
    required this.updatedAtHuman,
    required this.canAccept,
    required this.canMarkReady,
    required this.canMarkPickedUp,
    this.deliveryPartner,
    required this.items,
  });

  final int id;
  final String orderNumber;
  final String status;
  final String statusLabel;
  final int statusStepIndex;
  final List<SellerOrderTimelineStep> statusTimeline;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String deliverySlotLabel;
  final String deliveryTimeLabel;
  final String? notes;
  final int itemCount;
  final double kitchenTotal;
  final String paymentLabel;
  final String paymentStatus;
  final String placedAtHuman;
  final String updatedAtHuman;
  final bool canAccept;
  final bool canMarkReady;
  final bool canMarkPickedUp;
  final SellerDeliveryPartner? deliveryPartner;
  final List<SellerOrderLineItem> items;

  factory SellerOrderDetail.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];
    final slot = json['delivery_slot'];
    final timeline = json['status_timeline'];
    final items = json['items'];

    return SellerOrderDetail(
      id: json['id'] as int? ?? 0,
      orderNumber: normalizeOrderNumber((json['order_number'] as String?) ?? ''),
      status: (json['status'] as String?) ?? '',
      statusLabel: (json['status_label'] as String?) ?? '',
      statusStepIndex: json['status_step_index'] as int? ?? 0,
      statusTimeline: timeline is List
          ? timeline
              .whereType<Map<String, dynamic>>()
              .map(SellerOrderTimelineStep.fromJson)
              .toList()
          : const [],
      customerName: customer is Map
          ? (customer['name'] as String?) ?? 'Customer'
          : 'Customer',
      customerPhone: customer is Map
          ? (customer['phone'] as String?) ?? ''
          : '',
      deliveryAddress: (json['delivery_address'] as String?) ?? '',
      deliverySlotLabel: slot is Map
          ? (slot['label'] as String?) ?? ''
          : '',
      deliveryTimeLabel: slot is Map
          ? (slot['time_label'] as String?) ?? ''
          : '',
      notes: json['notes'] as String?,
      itemCount: json['item_count'] as int? ?? 0,
      kitchenTotal: (json['kitchen_total'] as num?)?.toDouble() ?? 0,
      paymentLabel: (json['payment_label'] as String?) ?? '',
      paymentStatus: (json['payment_status'] as String?) ?? '',
      placedAtHuman: (json['placed_at_human'] as String?) ?? '',
      updatedAtHuman: (json['updated_at_human'] as String?) ?? '',
      canAccept: json['can_accept'] == true ||
          _jsonStr(json['status']) == 'pending',
      canMarkReady: json['can_mark_ready'] == true ||
          _jsonStr(json['status']) == 'accepted',
      canMarkPickedUp: json['can_mark_picked_up'] == true ||
          _jsonStr(json['status']) == 'ready_to_pick_up',
      deliveryPartner: SellerDeliveryPartner.fromJson(json['delivery_partner']),
      items: items is List
          ? items
              .whereType<Map<String, dynamic>>()
              .map(SellerOrderLineItem.fromJson)
              .toList()
          : const [],
    );
  }

  String get displayNumber => formatOrderDisplayNumber(
        orderNumber: orderNumber,
        id: id,
      );

  bool get isCancelled => status == 'cancelled';

  bool get isPending => status == 'pending';

  bool get isAccepted => status == 'accepted';

  bool get hasDispatchFailure =>
      deliveryPartner?.hasDispatchError ?? false;

  /// When Adloggs dispatch fails, seller contacts support instead of marking picked up.
  bool get showChatWithAdminAction =>
      canMarkPickedUp && hasDispatchFailure;

  bool get hasSwipeOrderAction =>
      canAccept ||
      canMarkReady ||
      (canMarkPickedUp && !hasDispatchFailure);

  bool get hasBottomBarAction =>
      hasSwipeOrderAction || showChatWithAdminAction;

  bool get hasOrderAction => hasBottomBarAction;

  String get orderActionSwipeLabel {
    if (canAccept) return 'Swipe to accept';
    if (canMarkReady) return 'Swipe to mark ready';
    if (canMarkPickedUp) return 'Swipe to mark picked up';
    return '';
  }

  String get orderActionLoadingLabel {
    if (canAccept) return 'Accepting…';
    if (canMarkReady) return 'Updating…';
    if (canMarkPickedUp) return 'Marking picked up…';
    return 'Working…';
  }

  /// Timeline rows shown in the UI (appends Cancelled when needed).
  List<SellerOrderTimelineStep> get displayStatusTimeline {
    if (!isCancelled) return statusTimeline;
    return [
      ...statusTimeline,
      const SellerOrderTimelineStep(key: 'cancelled', label: 'Cancelled'),
    ];
  }

  /// Active step index for [displayStatusTimeline].
  int get displayStatusStepIndex {
    if (!isCancelled) return statusStepIndex;
    return statusTimeline.length;
  }
}

class SellerDeliveryPartner {
  const SellerDeliveryPartner({
    this.provider,
    this.orderUuid,
    this.status,
    this.riderName,
    this.riderPhone,
    this.assigned = false,
    this.dispatchError,
    this.pickupOtp,
    this.pickupSyncError,
    this.trackUrl,
    this.riderLatitude,
    this.riderLongitude,
    this.pickupLatitude,
    this.pickupLongitude,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.canTrack = false,
  });

  final String? provider;
  final String? orderUuid;
  final String? status;
  final String? riderName;
  final String? riderPhone;
  final bool assigned;
  final SellerDispatchError? dispatchError;
  final String? pickupOtp;
  final SellerDispatchError? pickupSyncError;
  final String? trackUrl;
  final double? riderLatitude;
  final double? riderLongitude;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final bool canTrack;

  static SellerDeliveryPartner? fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    return SellerDeliveryPartner(
      provider: _nullableStr(json['provider']),
      orderUuid: _nullableStr(json['order_uuid']),
      status: _nullableStr(json['status']),
      riderName: _nullableStr(json['rider_name']),
      riderPhone: _nullableStr(json['rider_phone']),
      assigned: json['assigned'] == true,
      dispatchError: SellerDispatchError.fromJson(json['dispatch_error']),
      pickupOtp: _nullableStr(json['pickup_otp']),
      pickupSyncError: _pickupSyncErrorFromJson(json['pickup_sync_error']),
      trackUrl: _nullableStr(json['track_url']),
      riderLatitude: _nullableDouble(json['rider_latitude']),
      riderLongitude: _nullableDouble(json['rider_longitude']),
      pickupLatitude: _nullableDouble(json['pickup_latitude']),
      pickupLongitude: _nullableDouble(json['pickup_longitude']),
      deliveryLatitude: _nullableDouble(json['delivery_latitude']),
      deliveryLongitude: _nullableDouble(json['delivery_longitude']),
      canTrack: json['can_track'] == true,
    );
  }

  bool get hasRider =>
      (riderName != null && riderName!.isNotEmpty) ||
      (riderPhone != null && riderPhone!.isNotEmpty);

  bool get hasDispatchError =>
      dispatchError != null && dispatchError!.message.isNotEmpty;

  bool get hasPickupSyncError =>
      pickupSyncError != null && pickupSyncError!.message.isNotEmpty;

  bool get hasPickupOtp => pickupOtp != null && pickupOtp!.isNotEmpty;

  bool get hasAdloggsTrack =>
      trackUrl != null && trackUrl!.isNotEmpty;

  bool get hasTrackingMap =>
      pickupLatitude != null &&
      pickupLongitude != null &&
      deliveryLatitude != null &&
      deliveryLongitude != null;
}

class SellerDispatchError {
  const SellerDispatchError({
    required this.message,
    this.code,
  });

  final String message;
  final String? code;

  static SellerDispatchError? fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final message = _nullableStr(json['message']) ?? '';
    if (message.isEmpty) return null;
    return SellerDispatchError(
      message: message,
      code: _nullableStr(json['code']),
    );
  }
}

SellerDispatchError? _pickupSyncErrorFromJson(dynamic json) {
  final error = SellerDispatchError.fromJson(json);
  if (error == null) return null;

  if (error.code == 'pickup_otp_missing') {
    return null;
  }

  if (error.message.toLowerCase().contains('pickup otp was not stored')) {
    return null;
  }

  return error;
}

class SellerOrderTimelineStep {
  const SellerOrderTimelineStep({required this.key, required this.label});

  final String key;
  final String label;

  factory SellerOrderTimelineStep.fromJson(Map<String, dynamic> json) {
    return SellerOrderTimelineStep(
      key: (json['key'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
    );
  }
}

class SellerOrderLineItem {
  const SellerOrderLineItem({
    required this.id,
    required this.dishId,
    required this.dishName,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    required this.isVeg,
    this.imageUrl,
  });

  final int id;
  final int? dishId;
  final String dishName;
  final double unitPrice;
  final int quantity;
  final double lineTotal;
  final bool isVeg;
  final String? imageUrl;

  factory SellerOrderLineItem.fromJson(Map<String, dynamic> json) {
    return SellerOrderLineItem(
      id: json['id'] as int? ?? 0,
      dishId: json['dish_id'] as int?,
      dishName: (json['dish_name'] as String?) ?? '',
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      quantity: json['quantity'] as int? ?? 0,
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0,
      isVeg: json['is_veg'] as bool? ?? false,
      imageUrl: Optica2AssetUrl.resolve(json['image_url'] as String?),
    );
  }
}

String formatOrderAmount(num amount) {
  final rounded = amount.round();
  return '₹$rounded';
}

int _jsonInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

double _jsonDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

String _jsonStr(dynamic value) {
  if (value == null) return '';
  return '$value';
}

String? _nullableStr(dynamic value) {
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}

double? _nullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}
