import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:str/core/database/app_database.dart';

// Màn hình kiểm duyệt hệ thống dành cho Super Admin
class SuperAdminDashboardScreen extends ConsumerWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allRestaurants = ref.watch(realRestaurantListProvider);

    final pendingList =
        allRestaurants.where((r) => r.status == 'PENDING').toList();
    final approvedList =
        allRestaurants.where((r) => r.status == 'APPROVED').toList();
    final rejectedList =
        allRestaurants.where((r) => r.status == 'REJECTED').toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hệ thống Quản trị (Super Admin)',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1D26),
                  fontSize: 18,
                ),
              ),
              Text(
                'Kiểm duyệt & Quản lý các Nhà hàng trên Database',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Đăng xuất',
              icon: const Icon(Icons.logout_rounded, color: Colors.red),
              onPressed: () {
                ref.read(currentUserProvider.notifier).state = null;
                context.pushReplacement('/');
              },
            )
          ],
          bottom: TabBar(
            labelColor: const Color(0xFFFF5722),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFFFF5722),
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(text: 'Chờ duyệt (${pendingList.length})'),
              Tab(text: 'Đang mở (${approvedList.length})'),
              Tab(text: 'Từ chối (${rejectedList.length})'),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildStatCard(
                        'Chờ duyệt', pendingList.length, Colors.orange),
                    const SizedBox(width: 12),
                    _buildStatCard(
                        'Đang hoạt động', approvedList.length, Colors.green),
                    const SizedBox(width: 12),
                    _buildStatCard(
                        'Đã từ chối', rejectedList.length, Colors.red),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildRestaurantList(context, ref, pendingList,
                        emptyText: 'Không có yêu cầu duyệt mới nào.'),
                    _buildRestaurantList(context, ref, approvedList,
                        emptyText: 'Chưa có nhà hàng nào được phê duyệt.'),
                    _buildRestaurantList(context, ref, rejectedList,
                        emptyText: 'Không có nhà hàng nào bị từ chối.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Danh sách nhà hàng theo trạng thái kiểm duyệt
  Widget _buildRestaurantList(
    BuildContext context,
    WidgetRef ref,
    List<RestaurantModel> list, {
    required String emptyText,
  }) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 14),
            Text(emptyText,
                style: const TextStyle(
                    color: Colors.grey, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final res = list[index];
        final isPending = res.status == 'PENDING';
        final isApproved = res.status == 'APPROVED';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5722).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.storefront_rounded,
                        color: Color(0xFFFF5722)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(res.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w900)),
                        Text(
                          'Chuyên mục: ${res.category} • Giờ mở: ${res.openTime}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF6C7278)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Địa chỉ: ${res.address}',
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
              const SizedBox(height: 4),
              Text('SĐT Chủ quán: ${res.ownerPhone}',
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                'Tọa độ: ${res.lat.toStringAsFixed(4)}, ${res.lng.toStringAsFixed(4)}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (isPending || isApproved)
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final success = await ref
                              .read(realRestaurantListProvider.notifier)
                              .changeRestaurantStatus(res.id, 'REJECTED');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success
                                    ? 'Đã chuyển "${res.name}" sang trạng thái Từ chối/Tạm ngưng!'
                                    : 'Lỗi: Không thể cập nhật trên Supabase!'),
                                backgroundColor:
                                    success ? Colors.red : Colors.orange,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.block_rounded, size: 16),
                        label: Text(isApproved ? 'TẠM KHOÁ' : 'TỪ CHỐI'),
                      ),
                    ),
                  if (isPending) const SizedBox(width: 12),
                  if (!isApproved)
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C853),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final success = await ref
                              .read(realRestaurantListProvider.notifier)
                              .changeRestaurantStatus(res.id, 'APPROVED');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success
                                    ? 'Đã phê duyệt nhà hàng "${res.name}" hiển thị trên App!'
                                    : 'Lỗi: Không thể phê duyệt trên Supabase!'),
                                backgroundColor:
                                    success ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: Text(
                            isPending ? 'PHÊ DUYỆT' : 'DUYỆT LẠI HOẠT ĐỘNG'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Thẻ thống kê số lượng nhà hàng
  Widget _buildStatCard(String title, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
