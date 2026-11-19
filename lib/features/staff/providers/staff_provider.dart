import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:str/main.dart';

SupabaseClient get _supabase => Supabase.instance.client;

enum DishStatus { pending, cooking, ready, served }

// So sánh tên nhà hàng không phân biệt hoa thường và khoảng trắng thừa
bool isSameRestaurantName(String a, String b) {
  final cleanA = a.trim().toLowerCase();
  final cleanB = b.trim().toLowerCase();
  if (cleanA.isEmpty || cleanB.isEmpty) return false;
  return cleanA == cleanB;
}

// Quản lý nhật ký lỗi đồng bộ mạng (phục vụ TC35)
class SyncErrorLogNotifier extends StateNotifier<List<String>> {
  static const String _prefsKey = 'str_sync_error_logs_v1';

  SyncErrorLogNotifier() : super([]) {
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_prefsKey);
      if (saved != null && mounted) {
        state = saved;
      }
    } catch (_) {}
  }

  Future<void> logError(String contextAction, Object error) async {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final entry = '[$timeStr] $contextAction: $error';
    debugPrint(entry);
    final updated = [entry, ...state].take(50).toList();
    if (mounted) {
      state = updated;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, updated);
    } catch (_) {}
  }

  Future<void> clearLogs() async {
    state = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }
}

final syncErrorLogProvider =
    StateNotifierProvider<SyncErrorLogNotifier, List<String>>((ref) {
  return SyncErrorLogNotifier();
});

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

  Map<String, dynamic> toMap({String? restaurantName, bool isPaid = false}) {
    return {
      'id': id,
      'dish_name': dishName,
      'quantity': quantity,
      'price': price,
      'note': note,
      'status': status.name,
      if (restaurantName != null && restaurantName.trim().isNotEmpty)
        'restaurant_name': restaurantName.trim(),
      if (isPaid) 'is_paid': true,
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
  final String restaurantName;
  final String createdAt;
  final List<OrderItem> items;
  final bool isPaid;

  KitchenOrder({
    required this.orderId,
    required this.tableNumber,
    this.restaurantName = '',
    required this.createdAt,
    required this.items,
    this.isPaid = false,
  });

  KitchenOrder copyWith({
    String? orderId,
    List<OrderItem>? items,
    String? restaurantName,
    bool? isPaid,
  }) {
    return KitchenOrder(
      orderId: orderId ?? this.orderId,
      tableNumber: tableNumber,
      restaurantName: restaurantName ?? this.restaurantName,
      createdAt: createdAt,
      items: items ?? this.items,
      isPaid: isPaid ?? this.isPaid,
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    final cleanRes = restaurantName.trim();
    final cleanTable = tableNumber.trim();
    final encodedTable = isPaid
        ? 'PAID|$cleanRes|$cleanTable'
        : (cleanRes.isNotEmpty ? 'ACT|$cleanRes|$cleanTable' : cleanTable);
    return {
      'order_id': orderId,
      'table_number': encodedTable,
      'created_at': createdAt,
      'items': items
          .map((e) => e.toMap(restaurantName: cleanRes, isPaid: isPaid))
          .toList(),
    };
  }

  factory KitchenOrder.fromSupabaseMap(Map<String, dynamic> row) {
    final rawItems = row['items'] as List<dynamic>? ?? [];
    String rawTable = row['table_number']?.toString() ?? '';
    String extractedRes = row['restaurant_name']?.toString() ?? '';
    bool paidFlag = row['is_paid'] == true;

    if (rawTable.startsWith('PAID|')) {
      paidFlag = true;
      final parts = rawTable.split('|');
      if (parts.length >= 3) {
        if (extractedRes.isEmpty) {
          extractedRes = parts[1].trim();
        }
        rawTable = parts.sublist(2).join('|').trim();
      } else if (parts.length == 2) {
        rawTable = parts[1].trim();
      }
    } else if (rawTable.startsWith('ACT|')) {
      final parts = rawTable.split('|');
      if (parts.length >= 3) {
        if (extractedRes.isEmpty) {
          extractedRes = parts[1].trim();
        }
        rawTable = parts.sublist(2).join('|').trim();
      }
    } else if (rawTable.contains('|')) {
      final parts = rawTable.split('|');
      if (parts.length >= 2) {
        if (extractedRes.isEmpty) {
          extractedRes = parts.first.trim();
        }
        rawTable = parts.sublist(1).join('|').trim();
      }
    }

    if (rawItems.isNotEmpty && rawItems.first is Map) {
      final firstMap = rawItems.first as Map;
      if (extractedRes.isEmpty) {
        extractedRes = firstMap['restaurant_name']?.toString().trim() ?? '';
      }
      if (firstMap['is_paid'] == true) {
        paidFlag = true;
      }
    }

    final parsedItems = rawItems
        .map((item) =>
            OrderItem.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    final rowTotal = (row['total_amount'] as num?)?.toInt() ?? 0;
    if (parsedItems.isEmpty && rowTotal > 0) {
      parsedItems.add(
        OrderItem(
          id: 'total_${row['order_id'] ?? ''}',
          dishName: 'Hóa đơn $rawTable',
          quantity: 1,
          price: rowTotal,
          status: DishStatus.served,
        ),
      );
    }

    return KitchenOrder(
      orderId: row['order_id']?.toString() ?? '',
      tableNumber: rawTable,
      restaurantName: extractedRes,
      createdAt: row['created_at']?.toString() ?? '',
      items: parsedItems,
      isPaid: paidFlag,
    );
  }
}

// Quản lý đơn bếp và hóa đơn đã thu tiền trên Supabase + SharedPreferences
class KitchenOrderNotifier extends StateNotifier<List<KitchenOrder>> {
  static const String _prefsActiveOrdersKey = 'str_active_orders_v2';
  static const String _prefsPaidOrdersKey = 'str_paid_orders_v2';
  static const String _prefsSettledMapKey = 'str_settled_revenue_by_res_v2';

  final Ref ref;
  Timer? _syncTimer;
  bool _isMutating = false;
  List<KitchenOrder> _cachedPaidOrders = [];

  KitchenOrderNotifier(this.ref) : super([]) {
    _initOrders();
  }

  Future<void> _initOrders() async {
    await _loadLocalCache();
    if (!isSupabaseConfigured) return;
    await fetchOrders();
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_isMutating) {
        fetchOrders();
      }
    });
  }

  Future<void> _loadLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawPaid = prefs.getString(_prefsPaidOrdersKey);
      if (rawPaid != null && rawPaid.isNotEmpty) {
        final decoded = jsonDecode(rawPaid) as List<dynamic>;
        _cachedPaidOrders = decoded
            .map((e) =>
                KitchenOrder.fromSupabaseMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        ref.read(paidOrdersProvider.notifier).state = [..._cachedPaidOrders];
      }

      final rawSettledMap = prefs.getString(_prefsSettledMapKey);
      if (rawSettledMap != null && rawSettledMap.isNotEmpty) {
        final decodedMap = jsonDecode(rawSettledMap) as Map<String, dynamic>;
        final parsedMap = <String, int>{};
        decodedMap.forEach((k, v) {
          parsedMap[k] = (v as num?)?.toInt() ?? 0;
        });
        ref.read(settledRevenueByRestaurantProvider.notifier).state = parsedMap;
        final totalAll =
            parsedMap.values.fold<int>(0, (sum, element) => sum + element);
        ref.read(settledRevenueProvider.notifier).state = totalAll;
      }

      final rawActive = prefs.getString(_prefsActiveOrdersKey);
      if (rawActive != null && rawActive.isNotEmpty && state.isEmpty) {
        final decodedActive = jsonDecode(rawActive) as List<dynamic>;
        state = decodedActive
            .map((e) =>
                KitchenOrder.fromSupabaseMap(Map<String, dynamic>.from(e as Map)))
            .where((o) => !o.isPaid)
            .toList();
      }
    } catch (e) {
      debugPrint('Lỗi đọc bộ nhớ đệm đơn hàng: $e');
    }
  }

  Future<void> _saveLocalCache({
    List<KitchenOrder>? activeOrders,
    List<KitchenOrder>? paidOrders,
    Map<String, int>? revenueMap,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (activeOrders != null) {
        await prefs.setString(
          _prefsActiveOrdersKey,
          jsonEncode(activeOrders.map((e) => e.toSupabaseMap()).toList()),
        );
      }
      if (paidOrders != null) {
        _cachedPaidOrders = paidOrders;
        await prefs.setString(
          _prefsPaidOrdersKey,
          jsonEncode(paidOrders.map((e) => e.toSupabaseMap()).toList()),
        );
      }
      if (revenueMap != null) {
        await prefs.setString(_prefsSettledMapKey, jsonEncode(revenueMap));
      }
    } catch (e) {
      debugPrint('Lỗi lưu bộ nhớ đệm đơn hàng: $e');
    }
  }

  // Tải danh sách đơn bếp và đơn đã thanh toán từ Supabase
  Future<void> fetchOrders({bool force = false}) async {
    if (!isSupabaseConfigured) return;
    if (_isMutating && !force) return;
    try {
      final res = await _supabase
          .from('kitchen_orders')
          .select()
          .timeout(const Duration(seconds: 6));
      final list = (res as List<dynamic>)
          .map((row) =>
              KitchenOrder.fromSupabaseMap(Map<String, dynamic>.from(row as Map)))
          .toList();

      final Map<String, KitchenOrder> paidMap = {
        for (final o in _cachedPaidOrders) o.orderId: o,
        for (final o in list.where((o) => o.isPaid)) o.orderId: o,
      };

      try {
        final historyRes = await _supabase
            .from('payment_history')
            .select()
            .timeout(const Duration(seconds: 5));
        for (final row in (historyRes as List<dynamic>)) {
          final map = Map<String, dynamic>.from(row as Map);
          final amount = (map['amount'] as num?)?.toInt() ?? 0;
          final tableNum = map['table_number']?.toString() ?? '';
          final resName = map['restaurant_name']?.toString() ?? '';
          final idStr = map['id']?.toString() ?? '';
          if (idStr.isNotEmpty && !paidMap.containsKey(idStr) && amount > 0) {
            paidMap[idStr] = KitchenOrder(
              orderId: idStr,
              tableNumber: tableNum,
              restaurantName: resName,
              createdAt: map['paid_at']?.toString() ?? '',
              isPaid: true,
              items: [
                OrderItem(
                  id: 'hist_$idStr',
                  dishName: 'Hóa đơn $tableNum',
                  quantity: 1,
                  price: amount,
                  status: DishStatus.served,
                ),
              ],
            );
          }
        }
      } catch (_) {}

      final activeList = list.where((o) => !o.isPaid).toList();
      final combinedPaidList = paidMap.values.toList();

      if (mounted && (!_isMutating || force)) {
        state = activeList;
        ref.read(paidOrdersProvider.notifier).state = combinedPaidList;
        await _saveLocalCache(
          activeOrders: activeList,
          paidOrders: combinedPaidList,
        );
      }
    } catch (e) {
      await ref
          .read(syncErrorLogProvider.notifier)
          .logError('Tải danh sách đơn bếp', e);
    }
  }

  // Cập nhật trạng thái chế biến từng món (TC15, TC35)
  Future<bool> updateDishStatus(
    String orderId,
    String itemId,
    DishStatus newStatus,
  ) async {
    _isMutating = true;
    List<OrderItem>? updatedItemsForCloud;
    String orderResName = '';

    state = [
      for (final order in state)
        if (order.orderId == orderId)
          () {
            orderResName = order.restaurantName;
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

    await _saveLocalCache(activeOrders: state);

    if (!isSupabaseConfigured || updatedItemsForCloud == null) {
      _isMutating = false;
      return false;
    }

    try {
      await _supabase
          .from('kitchen_orders')
          .update({
            'items': updatedItemsForCloud!
                .map((e) => e.toMap(restaurantName: orderResName))
                .toList(),
          })
          .eq('order_id', orderId)
          .timeout(const Duration(seconds: 5));
      await fetchOrders(force: true);
      return true;
    } catch (e) {
      await ref
          .read(syncErrorLogProvider.notifier)
          .logError('Đổi trạng thái món ($orderId)', e);
      return false;
    } finally {
      _isMutating = false;
    }
  }

  // Đánh dấu hoàn thành toàn bộ phiếu (TC15, TC35)
  Future<bool> markAllReadyInOrder(String orderId) async {
    _isMutating = true;
    List<OrderItem>? updatedItemsForCloud;
    String orderResName = '';

    state = [
      for (final order in state)
        if (order.orderId == orderId)
          () {
            orderResName = order.restaurantName;
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

    await _saveLocalCache(activeOrders: state);

    if (!isSupabaseConfigured || updatedItemsForCloud == null) {
      _isMutating = false;
      return false;
    }

    try {
      await _supabase
          .from('kitchen_orders')
          .update({
            'items': updatedItemsForCloud!
                .map((e) => e.toMap(restaurantName: orderResName))
                .toList(),
          })
          .eq('order_id', orderId)
          .timeout(const Duration(seconds: 5));
      await fetchOrders(force: true);
      return true;
    } catch (e) {
      await ref
          .read(syncErrorLogProvider.notifier)
          .logError('Hoàn thành phiếu bếp ($orderId)', e);
      return false;
    } finally {
      _isMutating = false;
    }
  }

  // Tạo đơn gọi món mới xuống bếp (TC14, TC19, TC37)
  Future<bool> addOrderFromWaiter(
    String tableNumber,
    List<OrderItem> newItems, {
    String restaurantName = '',
  }) async {
    _isMutating = true;
    final cleanRes = restaurantName.trim();
    final cleanTable = tableNumber.trim();
    final now = TimeOfDay.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final pendingItems = newItems
        .map((item) => item.copyWith(status: DishStatus.pending))
        .toList();

    final newOrder = KitchenOrder(
      orderId:
          'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      tableNumber: cleanTable,
      restaurantName: cleanRes,
      createdAt: timeStr,
      items: pendingItems,
      isPaid: false,
    );

    state = [newOrder, ...state];
    await _saveLocalCache(activeOrders: state);

    if (!isSupabaseConfigured) {
      _isMutating = false;
      return true;
    }

    try {
      await _supabase
          .from('kitchen_orders')
          .insert(newOrder.toSupabaseMap())
          .timeout(const Duration(seconds: 6));
      await fetchOrders(force: true);
      return true;
    } catch (e) {
      await ref
          .read(syncErrorLogProvider.notifier)
          .logError('Gửi đơn gọi món mới ($cleanTable)', e);
      return false;
    } finally {
      _isMutating = false;
    }
  }

  // Chốt thanh toán hóa đơn của bàn, xóa đơn bếp đang phục vụ và lưu doanh thu ca (TC26, TC27, TC32, TC37)
  Future<void> settleOrdersForTable(
    String tableNumber, {
    String? restaurantName,
    int fallbackAmount = 0,
    String paymentMethod = 'QR',
  }) async {
    _isMutating = true;
    final cleanRes = restaurantName?.trim() ?? '';
    final cleanTable = tableNumber.trim();

    final matchingOrders = state.where((o) {
      final sameTable =
          o.tableNumber.trim().toLowerCase() == cleanTable.toLowerCase();
      if (!sameTable) return false;
      if (cleanRes.isEmpty) return true;
      return isSameRestaurantName(o.restaurantName, cleanRes);
    }).toList();

    final matchingIds = matchingOrders.map((o) => o.orderId).toList();
    state = state.where((o) => !matchingIds.contains(o.orderId)).toList();

    final List<KitchenOrder> newlyPaid = [];
    for (final o in matchingOrders) {
      final effectiveRes =
          cleanRes.isNotEmpty ? cleanRes : o.restaurantName.trim();
      final settledItems = o.items
          .map((i) => i.copyWith(status: DishStatus.served))
          .toList();
      newlyPaid.add(o.copyWith(
        orderId: o.orderId,
        restaurantName: effectiveRes,
        items: settledItems,
        isPaid: true,
      ));
    }

    if (newlyPaid.isEmpty && fallbackAmount > 0) {
      final now = TimeOfDay.now();
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      newlyPaid.add(KitchenOrder(
        orderId:
            'PAID-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        tableNumber: cleanTable,
        restaurantName: cleanRes,
        createdAt: timeStr,
        isPaid: true,
        items: [
          OrderItem(
            id: 'item_${DateTime.now().microsecondsSinceEpoch}',
            dishName: 'Hóa đơn $cleanTable',
            quantity: 1,
            price: fallbackAmount,
            status: DishStatus.served,
          ),
        ],
      ));
    }

    int totalPaidAmount = fallbackAmount;
    if (newlyPaid.isNotEmpty) {
      final currentPaid = ref.read(paidOrdersProvider);
      final existingIds = currentPaid.map((e) => e.orderId).toSet();
      final updatedPaidList = [
        ...newlyPaid.where((e) => !existingIds.contains(e.orderId)),
        ...currentPaid,
      ];
      ref.read(paidOrdersProvider.notifier).state = updatedPaidList;

      final addedRevenue = newlyPaid.fold<int>(
        0,
        (sum, ord) =>
            sum +
            ord.items.fold<int>(0, (s, i) => s + (i.price * i.quantity)),
      );
      if (addedRevenue > 0) {
        totalPaidAmount = addedRevenue;
      }

      ref.read(settledRevenueProvider.notifier).state += totalPaidAmount;

      final resKey =
          cleanRes.isNotEmpty ? cleanRes.toLowerCase() : '__default__';
      final currentMap = Map<String, int>.from(
        ref.read(settledRevenueByRestaurantProvider),
      );
      currentMap[resKey] = (currentMap[resKey] ?? 0) + totalPaidAmount;
      ref.read(settledRevenueByRestaurantProvider.notifier).state = currentMap;

      await _saveLocalCache(
        activeOrders: state,
        paidOrders: updatedPaidList,
        revenueMap: currentMap,
      );
    } else {
      await _saveLocalCache(activeOrders: state);
    }

    if (!isSupabaseConfigured) {
      _isMutating = false;
      return;
    }

    try {
      for (final id in matchingIds) {
        try {
          await _supabase
              .from('kitchen_orders')
              .delete()
              .eq('order_id', id)
              .timeout(const Duration(seconds: 5));
        } catch (_) {}
      }

      for (final paidOrder in newlyPaid) {
        final orderTotal = paidOrder.items.fold<int>(
          0,
          (s, i) => s + (i.price * i.quantity),
        );
        final effectiveAmount = orderTotal > 0 ? orderTotal : totalPaidAmount;
        if (effectiveAmount > 0) {
          try {
            await _supabase.from('payment_history').insert({
              'id': paidOrder.orderId,
              'restaurant_name': paidOrder.restaurantName,
              'table_number': paidOrder.tableNumber,
              'amount': effectiveAmount,
              'payment_method': paymentMethod,
              'items': paidOrder.items.map((e) => e.toMap()).toList(),
            });
          } catch (_) {
            try {
              await _supabase.from('payment_history').insert({
                'id': paidOrder.orderId,
                'restaurant_name': paidOrder.restaurantName,
                'table_number': paidOrder.tableNumber,
                'amount': effectiveAmount,
                'payment_method': paymentMethod,
              });
            } catch (_) {}
          }
        }
      }

      await fetchOrders(force: true);
    } catch (e) {
      await ref
          .read(syncErrorLogProvider.notifier)
          .logError('Chốt thanh toán bàn $cleanTable', e);
    } finally {
      _isMutating = false;
    }
  }

  // Xóa đơn hàng khi dọn bàn
  Future<void> clearOrdersForTable(
    String tableNumber, {
    String? restaurantName,
  }) async {
    _isMutating = true;
    final cleanRes = restaurantName?.trim() ?? '';
    final cleanTable = tableNumber.trim();
    final matchingIds = state
        .where((o) {
          final sameTable =
              o.tableNumber.trim().toLowerCase() == cleanTable.toLowerCase();
          if (!sameTable) return false;
          if (cleanRes.isEmpty) return true;
          return isSameRestaurantName(o.restaurantName, cleanRes);
        })
        .map((o) => o.orderId)
        .toList();

    state = state.where((o) => !matchingIds.contains(o.orderId)).toList();
    await _saveLocalCache(activeOrders: state);

    if (!isSupabaseConfigured) {
      _isMutating = false;
      return;
    }

    try {
      if (matchingIds.isNotEmpty) {
        for (final id in matchingIds) {
          await _supabase.from('kitchen_orders').delete().eq('order_id', id);
        }
      } else if (cleanRes.isNotEmpty) {
        await _supabase
            .from('kitchen_orders')
            .delete()
            .eq('table_number', 'ACT|$cleanRes|$cleanTable');
      }
      await fetchOrders(force: true);
    } catch (e) {
      await ref
          .read(syncErrorLogProvider.notifier)
          .logError('Xóa đơn khi dọn bàn $cleanTable', e);
    } finally {
      _isMutating = false;
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}

final paidOrdersProvider = StateProvider<List<KitchenOrder>>((ref) => []);

final settledRevenueByRestaurantProvider =
    StateProvider<Map<String, int>>((ref) => {});

final kitchenOrdersProvider =
    StateNotifierProvider<KitchenOrderNotifier, List<KitchenOrder>>((ref) {
  return KitchenOrderNotifier(ref);
});

enum TableState { empty, reserved, occupied, needPayment }

// Model bàn ăn theo từng nhà hàng (hỗ trợ cách ly tuyệt đối TC37)
class RestaurantTable {
  final String number;
  final int seats;
  final TableState state;
  final String restaurantName;
  final String rawDbKey;

  RestaurantTable({
    required this.number,
    required this.seats,
    required this.state,
    this.restaurantName = '',
    String? rawDbKey,
  }) : rawDbKey = rawDbKey ??
            (restaurantName.trim().isNotEmpty
                ? '${restaurantName.trim()}|${number.trim()}'
                : number.trim());

  RestaurantTable copyWith({
    TableState? state,
    int? seats,
    String? restaurantName,
    String? rawDbKey,
  }) {
    final nextRes = restaurantName ?? this.restaurantName;
    return RestaurantTable(
      number: number,
      seats: seats ?? this.seats,
      state: state ?? this.state,
      restaurantName: nextRes,
      rawDbKey: rawDbKey ??
          (nextRes.trim().isNotEmpty
              ? '${nextRes.trim()}|${number.trim()}'
              : number.trim()),
    );
  }

  String get compositeKey => restaurantName.trim().isNotEmpty
      ? '${restaurantName.trim()}|${number.trim()}'
      : number.trim();

  Map<String, dynamic> toSupabaseMap({bool useCompositeTableNumber = true}) {
    final cleanRes = restaurantName.trim();
    final cleanNum = number.trim();
    return {
      'restaurant_name': cleanRes,
      'table_number':
          (useCompositeTableNumber && cleanRes.isNotEmpty)
              ? '$cleanRes|$cleanNum'
              : cleanNum,
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

    final rawTableCol = row['table_number']?.toString() ?? '';
    String extractedRes = row['restaurant_name']?.toString().trim() ?? '';
    String extractedNumber = rawTableCol.trim();

    if (rawTableCol.contains('|')) {
      final parts = rawTableCol.split('|');
      if (extractedRes.isEmpty) {
        extractedRes = parts.first.trim();
      }
      extractedNumber = parts.sublist(1).join('|').trim();
    }

    return RestaurantTable(
      number: extractedNumber,
      seats: (row['seats'] as num?)?.toInt() ?? 4,
      state: parsedState,
      restaurantName: extractedRes,
      rawDbKey: rawTableCol,
    );
  }
}

// Quản lý danh sách bàn ăn theo từng nhà hàng trên Supabase + SharedPreferences
class TableListNotifier extends StateNotifier<List<RestaurantTable>> {
  static const String _prefsTablesKey = 'str_restaurant_tables_v2';
  Timer? _syncTimer;
  bool _isMutating = false;

  TableListNotifier() : super([]) {
    _initRealtimeTables();
  }

  Future<void> _initRealtimeTables() async {
    await _loadLocalTables();
    if (!isSupabaseConfigured) return;
    await fetchTables();
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_isMutating) {
        fetchTables();
      }
    });
  }

  Future<void> _loadLocalTables() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsTablesKey);
      if (raw != null && raw.isNotEmpty && state.isEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        state = decoded
            .map((e) => RestaurantTable.fromSupabaseMap(
                Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
  }

  Future<void> _saveLocalTables(List<RestaurantTable> tables) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsTablesKey,
        jsonEncode(tables.map((t) => t.toSupabaseMap()).toList()),
      );
    } catch (_) {}
  }

  // Tải danh sách bàn ăn từ Supabase
  Future<void> fetchTables({bool force = false}) async {
    if (!isSupabaseConfigured) return;
    if (_isMutating && !force) return;
    try {
      final res = await _supabase
          .from('restaurant_tables')
          .select()
          .order('table_number', ascending: true)
          .timeout(const Duration(seconds: 6));
      final list = (res as List<dynamic>)
          .map((row) => RestaurantTable.fromSupabaseMap(
              Map<String, dynamic>.from(row as Map)))
          .toList();

      final Map<String, RestaurantTable> deduped = {};
      for (final t in list) {
        final key =
            '${t.restaurantName.trim().toLowerCase()}|${t.number.trim().toLowerCase()}';
        if (!deduped.containsKey(key) || t.rawDbKey.contains('|')) {
          deduped[key] = t;
        }
      }
      final cleanList = deduped.values.toList();

      if (mounted && (!_isMutating || force)) {
        state = cleanList;
        await _saveLocalTables(cleanList);
      }
    } catch (e) {
      debugPrint('Lỗi tải danh sách bàn: $e');
    }
  }

  // Lọc danh sách bàn của một nhà hàng cụ thể (Cách ly tuyệt đối TC37)
  List<RestaurantTable> tablesForRestaurant(String restaurantName) {
    final cleanRes = restaurantName.trim();
    if (cleanRes.isEmpty) return [];
    return state
        .where((t) => isSameRestaurantName(t.restaurantName, cleanRes))
        .toList();
  }

  // Thêm bàn lẻ cho nhà hàng
  Future<bool> addTable(
    String tableNumber,
    int seats, {
    required String restaurantName,
  }) async {
    final cleanName = tableNumber.trim();
    final cleanRes = restaurantName.trim();
    if (cleanName.isEmpty || cleanRes.isEmpty) return false;

    final existsInRes = state.any((t) =>
        isSameRestaurantName(t.restaurantName, cleanRes) &&
        t.number.trim().toLowerCase() == cleanName.toLowerCase());
    if (existsInRes) return false;

    _isMutating = true;
    final newTable = RestaurantTable(
      number: cleanName,
      seats: seats,
      state: TableState.empty,
      restaurantName: cleanRes,
    );
    state = [...state, newTable];
    await _saveLocalTables(state);

    if (!isSupabaseConfigured) {
      _isMutating = false;
      return true;
    }
    try {
      try {
        await _supabase
            .from('restaurant_tables')
            .insert(newTable.toSupabaseMap(useCompositeTableNumber: true));
      } catch (_) {
        await _supabase.from('restaurant_tables').insert({
          'table_number': newTable.compositeKey,
          'seats': seats,
          'state': TableState.empty.name,
        });
      }
      await fetchTables(force: true);
      return true;
    } catch (e) {
      debugPrint('Lỗi thêm bàn mới: $e');
      return false;
    } finally {
      _isMutating = false;
    }
  }

  // Quy định và khởi tạo hàng loạt số lượng bàn cho riêng từng nhà hàng
  Future<bool> configureRestaurantTableCount({
    required String restaurantName,
    required int totalTables,
    required int defaultSeats,
  }) async {
    final cleanRes = restaurantName.trim();
    if (cleanRes.isEmpty || totalTables < 0 || totalTables > 200) return false;

    _isMutating = true;
    try {
      final existingTables = state
          .where((t) => isSameRestaurantName(t.restaurantName, cleanRes))
          .toList();

      final desiredNames = <String>[
        for (int i = 1; i <= totalTables; i++)
          'Bàn ${i.toString().padLeft(2, '0')}'
      ];

      final toInsert = <RestaurantTable>[];
      for (final name in desiredNames) {
        final alreadyExists = existingTables
            .any((t) => t.number.toLowerCase() == name.toLowerCase());
        if (!alreadyExists) {
          toInsert.add(
            RestaurantTable(
              number: name,
              seats: defaultSeats,
              state: TableState.empty,
              restaurantName: cleanRes,
            ),
          );
        }
      }

      final toDelete = existingTables
          .where((t) => !desiredNames
              .any((name) => name.toLowerCase() == t.number.toLowerCase()))
          .toList();

      final otherResTables = state
          .where((t) => !isSameRestaurantName(t.restaurantName, cleanRes))
          .toList();
      final newResTables = desiredNames.map((name) {
        final existing = existingTables
            .where((t) => t.number.toLowerCase() == name.toLowerCase())
            .firstOrNull;
        return RestaurantTable(
          number: name,
          seats: defaultSeats,
          state: existing?.state ?? TableState.empty,
          restaurantName: cleanRes,
        );
      }).toList();
      state = [...otherResTables, ...newResTables];
      await _saveLocalTables(state);

      if (isSupabaseConfigured) {
        for (final delTable in toDelete) {
          try {
            await _supabase
                .from('restaurant_tables')
                .delete()
                .eq('table_number', delTable.rawDbKey);
          } catch (_) {}
        }
        for (final insTable in toInsert) {
          try {
            await _supabase
                .from('restaurant_tables')
                .insert(insTable.toSupabaseMap(useCompositeTableNumber: true));
          } catch (_) {
            try {
              await _supabase.from('restaurant_tables').insert({
                'table_number': insTable.compositeKey,
                'seats': defaultSeats,
                'state': TableState.empty.name,
              });
            } catch (_) {}
          }
        }
        await fetchTables(force: true);
      }
      return true;
    } catch (e) {
      debugPrint('Lỗi thiết lập số lượng bàn: $e');
      return false;
    } finally {
      _isMutating = false;
    }
  }

  // Xóa bàn của nhà hàng
  Future<bool> deleteTable(
    String tableNumber, {
    String? restaurantName,
  }) async {
    final cleanRes = restaurantName?.trim() ?? '';
    final cleanTable = tableNumber.trim();
    final targetTables = state.where((t) {
      final sameNum = t.number.trim().toLowerCase() == cleanTable.toLowerCase();
      if (!sameNum) return false;
      if (cleanRes.isEmpty) return true;
      return isSameRestaurantName(t.restaurantName, cleanRes);
    }).toList();

    state = state.where((t) => !targetTables.contains(t)).toList();
    await _saveLocalTables(state);

    if (!isSupabaseConfigured) return true;
    _isMutating = true;
    try {
      for (final target in targetTables) {
        await _supabase
            .from('restaurant_tables')
            .delete()
            .eq('table_number', target.rawDbKey);
      }
      if (cleanRes.isNotEmpty) {
        await _supabase
            .from('restaurant_tables')
            .delete()
            .eq('table_number', '$cleanRes|$cleanTable');
      }
      await fetchTables(force: true);
      return true;
    } catch (e) {
      debugPrint('Lỗi xóa bàn: $e');
      return false;
    } finally {
      _isMutating = false;
    }
  }

  // Cập nhật trạng thái bàn của nhà hàng (TC14, TC26, TC35, TC37)
  Future<bool> setTableState(
    String tableNumber,
    TableState newState, {
    String? restaurantName,
  }) async {
    _isMutating = true;
    final cleanRes = restaurantName?.trim() ?? '';
    final cleanTable = tableNumber.trim();

    bool foundLocal = false;
    RestaurantTable? matchedTable;

    state = [
      for (final t in state)
        if (t.number.trim().toLowerCase() == cleanTable.toLowerCase() &&
            (cleanRes.isEmpty ||
                isSameRestaurantName(t.restaurantName, cleanRes)))
          () {
            foundLocal = true;
            final updated = t.copyWith(
              state: newState,
              restaurantName: cleanRes.isNotEmpty ? cleanRes : t.restaurantName,
            );
            matchedTable = updated;
            return updated;
          }()
        else
          t
    ];

    if (!foundLocal && cleanRes.isNotEmpty) {
      final created = RestaurantTable(
        number: cleanTable,
        seats: 4,
        state: newState,
        restaurantName: cleanRes,
      );
      matchedTable = created;
      state = [...state, created];
    }

    await _saveLocalTables(state);

    if (!isSupabaseConfigured) {
      _isMutating = false;
      return true;
    }

    try {
      bool updatedOnCloud = false;
      final compositeKey =
          cleanRes.isNotEmpty ? '$cleanRes|$cleanTable' : cleanTable;

      try {
        final res1 = await _supabase
            .from('restaurant_tables')
            .update({'state': newState.name})
            .eq('table_number', compositeKey)
            .select()
            .timeout(const Duration(seconds: 5));
        updatedOnCloud = (res1 as List).isNotEmpty;
      } catch (_) {}

      if (!updatedOnCloud && matchedTable != null) {
        try {
          final res2 = await _supabase
              .from('restaurant_tables')
              .update({'state': newState.name})
              .eq('table_number', matchedTable!.rawDbKey)
              .eq('restaurant_name', cleanRes)
              .select()
              .timeout(const Duration(seconds: 5));
          updatedOnCloud = (res2 as List).isNotEmpty;
        } catch (_) {}
      }

      if (!updatedOnCloud && cleanRes.isNotEmpty) {
        try {
          await _supabase.from('restaurant_tables').insert({
            'restaurant_name': cleanRes,
            'table_number': compositeKey,
            'seats': matchedTable?.seats ?? 4,
            'state': newState.name,
          }).timeout(const Duration(seconds: 5));
          updatedOnCloud = true;
        } catch (_) {
          try {
            await _supabase.from('restaurant_tables').insert({
              'table_number': compositeKey,
              'seats': matchedTable?.seats ?? 4,
              'state': newState.name,
            }).timeout(const Duration(seconds: 5));
            updatedOnCloud = true;
          } catch (_) {}
        }
      }

      await fetchTables(force: true);
      return true;
    } catch (e) {
      debugPrint('Lỗi cập nhật trạng thái bàn: $e');
      return false;
    } finally {
      _isMutating = false;
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
      'assigned_table': assignedTable,
    };
  }

  factory Reservation.fromSupabaseMap(Map<String, dynamic> row) {
    return Reservation(
      id: row['id']?.toString() ?? '',
      customerName: row['customer_name']?.toString() ?? 'Khách hàng',
      customerPhone: row['customer_phone']?.toString() ?? '',
      restaurantName: row['restaurant_name']?.toString() ?? '',
      address: row['address']?.toString() ?? '',
      date: row['date']?.toString() ?? '',
      time: row['time']?.toString() ?? '',
      guests: (row['guests'] as num?)?.toInt() ?? 2,
      note: row['note']?.toString() ?? '',
      status: row['status']?.toString() ?? 'PENDING',
      assignedTable: row['assigned_table']?.toString(),
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
      final res = await _supabase
          .from('reservations')
          .select()
          .order('id', ascending: false);
      final list = (res as List<dynamic>)
          .map((row) =>
              Reservation.fromSupabaseMap(Map<String, dynamic>.from(row as Map)))
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
    String note = '',
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
    String reservationId,
    String tableNumber, {
    String? restaurantName,
  }) async {
    String? resName = restaurantName;
    state = [
      for (final res in state)
        if (res.id == reservationId)
          () {
            resName ??= res.restaurantName;
            return res.copyWith(status: 'CONFIRMED', assignedTable: tableNumber);
          }()
        else
          res
    ];

    await ref.read(tableListProvider.notifier).setTableState(
          tableNumber,
          TableState.reserved,
          restaurantName: resName,
        );

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
    String? resName;
    for (final res in state) {
      if (res.id == id && res.assignedTable != null) {
        tableToRelease = res.assignedTable;
        resName = res.restaurantName;
      }
    }

    state = [
      for (final res in state)
        if (res.id == id) res.copyWith(status: 'CANCELLED') else res
    ];

    if (tableToRelease != null) {
      await ref.read(tableListProvider.notifier).setTableState(
            tableToRelease,
            TableState.empty,
            restaurantName: resName,
          );
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

  // Hoàn tất lịch đặt bàn khi khách đã thanh toán và rời bàn
  Future<void> completeReservationForTable(
    String tableNumber, {
    String? restaurantName,
  }) async {
    final cleanRes = restaurantName?.trim() ?? '';
    final matchingIds = state
        .where((r) =>
            r.status == 'CONFIRMED' &&
            r.assignedTable == tableNumber &&
            (cleanRes.isEmpty ||
                isSameRestaurantName(r.restaurantName, cleanRes)))
        .map((r) => r.id)
        .toList();

    if (matchingIds.isEmpty) return;

    state = [
      for (final res in state)
        if (matchingIds.contains(res.id))
          res.copyWith(status: 'COMPLETED')
        else
          res
    ];

    if (!isSupabaseConfigured) return;
    try {
      for (final id in matchingIds) {
        await _supabase
            .from('reservations')
            .update({'status': 'COMPLETED'}).eq('id', id);
      }
      await fetchReservations();
    } catch (e) {
      debugPrint('Lỗi hoàn tất lịch đặt bàn: $e');
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
