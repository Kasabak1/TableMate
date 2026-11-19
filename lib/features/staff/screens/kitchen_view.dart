import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:str/core/database/app_database.dart';
import 'package:str/features/staff/providers/staff_provider.dart';

// Màn hình điều phối chế biến món ăn (KDS - TC15, TC19, TC35, TC37)
class KitchenView extends ConsumerStatefulWidget {
  const KitchenView({super.key});

  @override
  ConsumerState<KitchenView> createState() => _KitchenViewState();
}

class _KitchenViewState extends ConsumerState<KitchenView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(kitchenOrdersProvider.notifier).fetchOrders(force: true);
    });
  }

  Future<void> _handleUpdateDishStatus(
    String orderId,
    String itemId,
    String dishName,
    DishStatus newStatus,
  ) async {
    final ok = await ref
        .read(kitchenOrdersProvider.notifier)
        .updateDishStatus(orderId, itemId, newStatus);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mất kết nối mạng khi đổi trạng thái "$dishName"! Đã lưu cục bộ và ghi nhật ký lỗi.',
          ),
          backgroundColor: Colors.orange.shade900,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Xem nhật ký',
            textColor: Colors.white,
            onPressed: _showErrorLogsDialog,
          ),
        ),
      );
    }
  }

  Future<void> _handleMarkAllReady(String orderId) async {
    final ok = await ref
        .read(kitchenOrdersProvider.notifier)
        .markAllReadyInOrder(orderId);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mất kết nối mạng khi hoàn thành phiếu #$orderId! Đã lưu cục bộ và ghi nhật ký lỗi.',
          ),
          backgroundColor: Colors.orange.shade900,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Xem nhật ký',
            textColor: Colors.white,
            onPressed: _showErrorLogsDialog,
          ),
        ),
      );
    }
  }

  void _showErrorLogsDialog() {
    final logs = ref.read(syncErrorLogProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Nhật ký lỗi kết nối & đồng bộ',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: logs.isEmpty
              ? const Text('Chưa ghi nhận lỗi kết nối nào.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (_, idx) => Text(
                    logs[idx],
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
        ),
        actions: [
          if (logs.isNotEmpty)
            TextButton(
              onPressed: () {
                ref.read(syncErrorLogProvider.notifier).clearLogs();
                Navigator.pop(ctx);
              },
              child: const Text('Xóa nhật ký',
                  style: TextStyle(color: Colors.red)),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final myRestaurant = (currentUser?.restaurantName ?? '').trim();
    final errorLogs = ref.watch(syncErrorLogProvider);
    final orders = ref
        .watch(kitchenOrdersProvider)
        .where((o) =>
            myRestaurant.isEmpty ||
            isSameRestaurantName(o.restaurantName, myRestaurant))
        .toList();

    final activeOrders = orders
        .where((o) => o.items.any((i) =>
            i.status == DishStatus.pending || i.status == DishStatus.cooking))
        .toList();
    final completedOrders = orders
        .where((o) => o.items.every((i) =>
            i.status == DishStatus.ready || i.status == DishStatus.served))
        .toList();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              labelColor: const Color(0xFFD84315),
              unselectedLabelColor: const Color(0xFF9A9FA5),
              indicatorColor: const Color(0xFFD84315),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800),
              tabs: [
                Tab(
                  icon: const Icon(Icons.local_fire_department_rounded),
                  text: 'Đang chế biến (${activeOrders.length})',
                ),
                Tab(
                  icon: const Icon(Icons.task_alt_rounded),
                  text: 'Đã hoàn thành (${completedOrders.length})',
                ),
              ],
            ),
          ),
          if (errorLogs.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFFFF8E1),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: Color(0xFFE65100), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cảnh báo mạng: ${errorLogs.first}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _showErrorLogsDialog,
                    child: const Text(
                      'Nhật ký lỗi',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Container(
              color: const Color(0xFFF6F7FB),
              child: TabBarView(
                children: [
                  _buildKitchenOrderList(context, activeOrders,
                      isHistory: false),
                  _buildKitchenOrderList(context, completedOrders,
                      isHistory: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Danh sách phiếu chế biến tại bếp
  Widget _buildKitchenOrderList(
    BuildContext context,
    List<KitchenOrder> orderList, {
    required bool isHistory,
  }) {
    if (orderList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.soup_kitchen_outlined,
                size: 80, color: Colors.grey[350]),
            const SizedBox(height: 12),
            Text(
              isHistory
                  ? 'Chưa có phiếu hoàn thành nào'
                  : 'Bếp đang trống đơn! Tất cả món đã nấu xong.',
              style: const TextStyle(
                color: Color(0xFF9A9FA5),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orderList.length,
      itemBuilder: (context, index) {
        final order = orderList[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isHistory
                        ? [const Color(0xFF546E7A), const Color(0xFF37474F)]
                        : [const Color(0xFFFF7043), const Color(0xFFD84315)],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            order.tableNumber,
                            style: const TextStyle(
                              color: Color(0xFFD84315),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '#${order.orderId}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            color: Colors.white70, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          order.createdAt,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    ...order.items.map(
                      (item) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFCCBC),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'x${item.quantity}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: Color(0xFFBF360C),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.dishName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (item.note.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Ghi chú: ${item.note}',
                                        style: const TextStyle(
                                          color: Color(0xFFE53935),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (item.status == DishStatus.pending)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFB8C00),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.outdoor_grill_rounded,
                                    size: 18),
                                label: const Text(
                                  'Nhận nấu',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                onPressed: () => _handleUpdateDishStatus(
                                  order.orderId,
                                  item.id,
                                  item.dishName,
                                  DishStatus.cooking,
                                ),
                              )
                            else if (item.status == DishStatus.cooking)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00C853),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(
                                    Icons.notifications_active_rounded,
                                    size: 18),
                                label: const Text(
                                  'Báo xong',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                onPressed: () => _handleUpdateDishStatus(
                                  order.orderId,
                                  item.id,
                                  item.dishName,
                                  DishStatus.ready,
                                ),
                              )
                            else
                              const Chip(
                                label: Text(
                                  'Đã xong',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (!isHistory)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(Icons.done_all_rounded,
                              color: Color(0xFF00C853)),
                          label: const Text(
                            'Hoàn thành toàn bộ phiếu',
                            style: TextStyle(
                              color: Color(0xFF00C853),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () => _handleMarkAllReady(order.orderId),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
