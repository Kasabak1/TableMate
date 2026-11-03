import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:str/core/database/app_database.dart';
import 'package:str/features/staff/providers/staff_provider.dart';
import 'package:str/features/staff/screens/waiter_view.dart';
import 'package:str/features/staff/screens/kitchen_view.dart';

// Màn hình chính phân hệ Nhân viên
class StaffDashboardScreen extends ConsumerWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final orders = ref.watch(kitchenOrdersProvider);
    final reservations = ref.watch(reservationProvider);

    final subRole = (currentUser?.subRole ?? '').toLowerCase();
    final bool isKitchenStaff = subRole.contains('bếp') ||
        subRole.contains('kitchen') ||
        subRole.contains('bar');

    int readyToServeCount = 0;
    for (final o in orders) {
      for (final item in o.items) {
        if (item.status == DishStatus.ready) readyToServeCount++;
      }
    }

    final myRestaurant = currentUser?.restaurantName ?? '';
    final int pendingBookingCount = reservations
        .where((r) =>
            r.status == 'PENDING' &&
            (myRestaurant.isEmpty || r.restaurantName == myRestaurant))
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isKitchenStaff
                  ? 'Điều phối Nhà Bếp (KDS)'
                  : 'Điều phối Phục vụ & Thu ngân',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Color(0xFF1A1D26),
              ),
            ),
            if (currentUser != null)
              Text(
                '${currentUser.name} (${currentUser.subRole})${myRestaurant.isNotEmpty ? " • $myRestaurant" : ""}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isKitchenStaff
                      ? const Color(0xFFFF5722)
                      : const Color(0xFF00C853),
                ),
              ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.red),
              tooltip: 'Đăng xuất',
              onPressed: () {
                ref.read(currentUserProvider.notifier).state = null;
                context.pushReplacement('/');
              },
            ),
          )
        ],
      ),
      body: isKitchenStaff
          ? const KitchenView()
          : WaiterView(
              readyToServeCount: readyToServeCount,
              pendingBookingCount: pendingBookingCount,
            ),
    );
  }
}
