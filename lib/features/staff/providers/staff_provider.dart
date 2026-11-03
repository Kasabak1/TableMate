import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:str/main.dart';

SupabaseClient get _supabase => Supabase.instance.client;

enum DishStatus { pending, cooking, ready, served }

// Model từng món trong phiếu gọi món
class OrderItem {
  final String id;
  final String dishName;
  final int quantity;
  final int price;
  final String note;
  final DishStatus status;

  OrderItem({
    required this.id,
    required this.dishName,
    required this.quantity,
    required this.price,
    this.note = '',
    this.status = DishStatus.pending,
  });

  OrderItem copyWith({DishStatus? status, int? quantity}) {
    return OrderItem(
      id: id,
      dishName: dishName,
      quantity: quantity ?? this.quantity,
      price: price,
      note: note,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dish_name': dishName,
      'quantity': quantity,
      'price': price,
      'note': note,
      'status': status.name,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    final statusStr = map['status']?.toString() ?? 'pending';
    final parsedStatus = DishStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => DishStatus.pending,
    );

    return OrderItem(
      id: map['id']?.toString() ?? '',
      dishName: map['dish_name']?.toString() ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      price: (map['price'] as num?)?.toInt() ?? 0,
      note: map['note']?.toString() ?? '',
      status: parsedStatus,
    );
  }
}

// Model phiếu gọi món nhà bếp
class KitchenOrder {
  final String orderId;
  final String tableNumber;
  final String createdAt;
  final List<OrderItem> items;

  KitchenOrder({
    required this.orderId,
    required this.tableNumber,
    required this.createdAt,
    required this.items,
  });

  KitchenOrder copyWith({List<OrderItem>? items}) {
    return KitchenOrder(
      orderId: orderId,
      tableNumber: tableNumber,
      createdAt: createdAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'order_id': orderId,
      'table_number': tableNumber,
      'created_at': createdAt,
      'items': items.map((e) => e.toMap()).toList(),
    };
  }

  factory KitchenOrder.fromSupabaseMap(Map<String, dynamic> row) {
    final rawItems = row['items'] as List<dynamic>? ?? [];
    final parsedItems = rawItems
        .map((item) => OrderItem.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    return KitchenOrder(
      orderId: row['order_id']?.toString() ?? '',
      tableNumber: row['table_number']?.toString() ?? '',
      createdAt: row['created_at']?.toString() ?? '',
      items: parsedItems,
    );
  }
}

// Quản lý đơn bếp thời gian thực trên Supabase
class KitchenOrderNotifier extends StateNotifier<List<KitchenOrder>> {
  Timer? _syncTimer;

  KitchenOrderNotifier() : super([]) {
    listenToRealtimeOrders();
  }

  void listenToRealtimeOrders() {
    if (!isSupabaseConfigured) return;
    fetchOrders();
    _syncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      fetchOrders();
    });
  }

  // Tải danh sách đơn bếp từ Supabase
  Future<void> fetchOrders() async {
    if (!isSupabaseConfigured) return;
    try {
      final res = await _supabase.from('kitchen_orders').select();
      final list = (res as List<dynamic>)
          .map((row) =>
              KitchenOrder.fromSupabaseMap(Map<String, dynamic>.from(row as Map)))
          .toList();
      if (mounted) {
        state = list;
      }
    } catch (e) {
      debugPrint('Lỗi tải đơn bếp: $e');
    }
  }

  // Cập nhật trạng thái chế biến từng món
  Future<void> updateDishStatus(
      String orderId, String itemId, DishStatus newStatus) async {
    List<OrderItem>? updatedItemsForCloud;

    state = [
      for (final order in state)
        if (order.orderId == orderId)
          () {
            final newItems = [
              for (final item in order.items)
                if (item.id == itemId) item.copyWith(status: newStatus) else item
            ];
            updatedItemsForCloud = newItems;
            return order.copyWith(items: newItems);
          }()
        else
          order
    ];

    if (!isSupabaseConfigured || updatedItemsForCloud == null) return;

    try {
      await _supabase.from('kitchen_orders').update({
        'items': updatedItemsForCloud!.map((e) => e.toMap()).toList(),
      }).eq('order_id', orderId);
      await fetchOrders();
    } catch (e) {
      debugPrint('Lỗi cập nhật trạng thái món: $e');
    }
  }

  // Đánh dấu hoàn thành toàn bộ phiếu
  Future<void> markAllReadyInOrder(String orderId) async {
    List<OrderItem>? updatedItemsForCloud;

    state = [
      for (final order in state)
        if (order.orderId == orderId)
          () {
            final newItems = [
              for (final item in order.items)
                if (item.status == DishStatus.pending ||
                    item.status == DishStatus.cooking)
                  item.copyWith(status: DishStatus.ready)
                else
                  item
            ];
            updatedItemsForCloud = newItems;
            return order.copyWith(items: newItems);
          }()
        else
          order
    ];

    if (!isSupabaseConfigured || updatedItemsForCloud == null) return;

    try {
      await _supabase.from('kitchen_orders').update({
        'items': updatedItemsForCloud!.map((e) => e.toMap()).toList(),
      }).eq('order_id', orderId);
      await fetchOrders();
    } catch (e) {
      debugPrint('Lỗi markAllReadyInOrder: $e');
    }
  }

  // Tạo đơn gọi món mới xuống bếp
  Future<void> addOrderFromWaiter(
      String tableNumber, List<OrderItem> newItems) async {
    final now = TimeOfDay.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final newOrder = KitchenOrder(
      orderId:
          'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      tableNumber: tableNumber,
      createdAt: timeStr,
      items: newItems,
    );

    state = [newOrder, ...state];

    if (!isSupabaseConfigured) return;

    try {
      await _supabase.from('kitchen_orders').insert(newOrder.toSupabaseMap());
      await fetchOrders();
    } catch (e) {
      debugPrint('Lỗi gửi đơn mới: $e');
    }
  }

  // Xóa đơn hàng khi dọn bàn
  Future<void> clearOrdersForTable(String tableNumber) async {
    state = state.where((o) => o.tableNumber != tableNumber).toList();
    if (!isSupabaseConfigured) return;

    try {
      await _supabase
          .from('kitchen_orders')
          .delete()
          .eq('table_number', tableNumber);
      await fetchOrders();
    } catch (e) {
      debugPrint('Lỗi xóa đơn khi dọn bàn: $e');
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}

final kitchenOrdersProvider =
    StateNotifierProvider<KitchenOrderNotifier, List<KitchenOrder>>((ref) {
  return KitchenOrderNotifier();
});

enum TableState { empty, reserved, occupied, needPayment }

// Model bàn ăn trong nhà hàng
class RestaurantTable {
  final String number;
  final int seats;
  final TableState state;

  RestaurantTable({
    required this.number,
    required this.seats,
    required this.state,
  });

  RestaurantTable copyWith({TableState? state, int? seats}) {
    return RestaurantTable(
      number: number,
      seats: seats ?? this.seats,
      state: state ?? this.state,
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'table_number': number,
      'seats': seats,
      'state': state.name,
    };
  }

  factory RestaurantTable.fromSupabaseMap(Map<String, dynamic> row) {
    final stateStr = row['state']?.toString() ?? 'empty';
    final parsedState = TableState.values.firstWhere(
      (e) => e.name == stateStr,
      orElse: () => TableState.empty,
    );

    return RestaurantTable(
      number: row['table_number']?.toString() ?? '',
      seats: (row['seats'] as num?)?.toInt() ?? 4,
      state: parsedState,
    );
  }
}

// Quản lý danh sách bàn ăn trên Supabase
class TableListNotifier extends StateNotifier<List<RestaurantTable>> {
  Timer? _syncTimer;

  TableListNotifier() : super([]) {
    _initRealtimeTables();
  }

  void _initRealtimeTables() {
    if (!isSupabaseConfigured) return;
    fetchTables();
    _syncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      fetchTables();
    });
  }

  // Tải danh sách bàn ăn từ Supabase
  Future<void> fetchTables() async {
    if (!isSupabaseConfigured) return;
    try {
      final res = await _supabase
          .from('restaurant_tables')
          .select()
          .order('table_number', ascending: true);
      final list = (res as List<dynamic>)
          .map((row) => RestaurantTable.fromSupabaseMap(
              Map<String, dynamic>.from(row as Map)))
          .toList();
      if (mounted) {
        state = list;
      }
    } catch (e) {
      debugPrint('Lỗi tải danh sách bàn: $e');
    }
  }

  // Thêm bàn mới
  Future<bool> addTable(String tableNumber, int seats) async {
    final cleanName = tableNumber.trim();
    if (cleanName.isEmpty) return false;
    if (state.any((t) => t.number.toLowerCase() == cleanName.toLowerCase())) {
      return false;
    }

    final newTable = RestaurantTable(
      number: cleanName,
      seats: seats,
      state: TableState.empty,
    );
    state = [...state, newTable];

    if (!isSupabaseConfigured) return true;
    try {
      await _supabase.from('restaurant_tables').insert(newTable.toSupabaseMap());
      await fetchTables();
      return true;
    } catch (e) {
      debugPrint('Lỗi thêm bàn mới: $e');
      return false;
    }
  }

  // Xóa bàn
  Future<bool> deleteTable(String tableNumber) async {
    state = state.where((t) => t.number != tableNumber).toList();
    if (!isSupabaseConfigured) return true;
    try {
      await _supabase
          .from('restaurant_tables')
          .delete()
          .eq('table_number', tableNumber);
      await fetchTables();
      return true;
    } catch (e) {
      debugPrint('Lỗi xóa bàn: $e');
      return false;
    }
  }

  // Cập nhật trạng thái bàn
  Future<void> setTableState(String tableNumber, TableState newState) async {
    state = [
      for (final t in state)
        if (t.number == tableNumber) t.copyWith(state: newState) else t
    ];

    if (!isSupabaseConfigured) return;

    try {
      await _supabase
          .from('restaurant_tables')
          .update({'state': newState.name}).eq('table_number', tableNumber);
      await fetchTables();
    } catch (e) {
      debugPrint('Lỗi cập nhật trạng thái bàn: $e');
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}

final tableListProvider =
    StateNotifierProvider<TableListNotifier, List<RestaurantTable>>((ref) {
  return TableListNotifier();
});

// Model đơn đặt bàn trước
class Reservation {
  final String id;
  final String customerName;
  final String customerPhone;
  final String restaurantName;
  final String address;
  final String date;
  final String time;
  final int guests;
  final String note;
  final String status;
  final String? assignedTable;

  Reservation({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.restaurantName,
    required this.address,
    required this.date,
    required this.time,
    required this.guests,
    this.note = '',
    this.status = 'PENDING',
    this.assignedTable,
  });

  Reservation copyWith({String? status, String? assignedTable}) {
    return Reservation(
      id: id,
      customerName: customerName,
      customerPhone: customerPhone,
      restaurantName: restaurantName,
      address: address,
      date: date,
      time: time,
      guests: guests,
      note: note,
      status: status ?? this.status,
      assignedTable: assignedTable ?? this.assignedTable,
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'restaurant_name': restaurantName,
      'address': address,
      'date': date,
      'time': time,
      'guests': guests,
      'note': note,
      'status': status,
      'assigned_table': assignedTable ?? '',
    };
  }

  factory Reservation.fromSupabaseMap(Map<String, dynamic> row) {
    final tableStr = row['assigned_table']?.toString() ?? '';
    return Reservation(
      id: row['id']?.toString() ?? '',
      customerName: row['customer_name']?.toString() ?? '',
      customerPhone: row['customer_phone']?.toString() ?? '',
      restaurantName: row['restaurant_name']?.toString() ?? '',
      address: row['address']?.toString() ?? '',
      date: row['date']?.toString() ?? '',
      time: row['time']?.toString() ?? '',
      guests: (row['guests'] as num?)?.toInt() ?? 2,
      note: row['note']?.toString() ?? '',
      status: row['status']?.toString() ?? 'PENDING',
      assignedTable: tableStr.isEmpty ? null : tableStr,
    );
  }
}

// Quản lý danh sách đặt bàn trên Supabase
class ReservationNotifier extends StateNotifier<List<Reservation>> {
  final Ref ref;
  Timer? _syncTimer;

  ReservationNotifier(this.ref) : super([]) {
    _initRealtimeReservations();
  }

  void _initRealtimeReservations() {
    if (!isSupabaseConfigured) return;
    fetchReservations();
    _syncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      fetchReservations();
    });
  }

  // Tải danh sách đặt bàn từ Supabase
  Future<void> fetchReservations() async {
    if (!isSupabaseConfigured) return;
    try {
      final res = await _supabase.from('reservations').select();
      final list = (res as List<dynamic>)
          .map((r) =>
              Reservation.fromSupabaseMap(Map<String, dynamic>.from(r as Map)))
          .toList();
      if (mounted) {
        state = list;
      }
    } catch (e) {
      debugPrint('Lỗi tải danh sách đặt bàn: $e');
    }
  }

  // Tạo đơn đặt bàn mới
  Future<void> addReservation({
    required String customerName,
    required String customerPhone,
    required String restaurantName,
    required String address,
    required String date,
    required String time,
    required int guests,
    required String note,
  }) async {
    final newRes = Reservation(
      id: 'RES-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      customerName: customerName,
      customerPhone: customerPhone,
      restaurantName: restaurantName,
      address: address,
      date: date,
      time: time,
      guests: guests,
      note: note,
      status: 'PENDING',
    );
    state = [newRes, ...state];

    if (!isSupabaseConfigured) return;
    try {
      await _supabase.from('reservations').insert(newRes.toSupabaseMap());
      await fetchReservations();
    } catch (e) {
      debugPrint('Lỗi thêm đặt bàn: $e');
    }
  }

  // Gán bàn cho đơn đặt trước
  Future<void> assignTableToReservation(
      String reservationId, String tableNumber) async {
    state = [
      for (final res in state)
        if (res.id == reservationId)
          res.copyWith(status: 'CONFIRMED', assignedTable: tableNumber)
        else
          res
    ];

    ref
        .read(tableListProvider.notifier)
        .setTableState(tableNumber, TableState.reserved);

    if (!isSupabaseConfigured) return;
    try {
      await _supabase.from('reservations').update({
        'status': 'CONFIRMED',
        'assigned_table': tableNumber,
      }).eq('id', reservationId);
      await fetchReservations();
    } catch (e) {
      debugPrint('Lỗi xếp bàn: $e');
    }
  }

  // Hủy đơn đặt bàn
  Future<void> cancelReservation(String id) async {
    String? tableToRelease;
    for (final res in state) {
      if (res.id == id && res.assignedTable != null) {
        tableToRelease = res.assignedTable;
      }
    }

    state = [
      for (final res in state)
        if (res.id == id) res.copyWith(status: 'CANCELLED') else res
    ];

    if (tableToRelease != null) {
      ref
          .read(tableListProvider.notifier)
          .setTableState(tableToRelease, TableState.empty);
    }

    if (!isSupabaseConfigured) return;
    try {
      await _supabase
          .from('reservations')
          .update({'status': 'CANCELLED'}).eq('id', id);
      await fetchReservations();
    } catch (e) {
      debugPrint('Lỗi hủy đặt bàn: $e');
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}

final reservationProvider =
    StateNotifierProvider<ReservationNotifier, List<Reservation>>((ref) {
  return ReservationNotifier(ref);
});

// Lưu doanh thu đã thanh toán trong ca
final settledRevenueProvider = StateProvider<int>((ref) => 0);
