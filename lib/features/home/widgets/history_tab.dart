import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:str/core/database/app_database.dart';
import 'package:str/features/home/models/user_profile_provider.dart';
import 'package:str/features/staff/providers/staff_provider.dart';

// Tab lịch sử đặt bàn của khách hàng
class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final profile = ref.watch(userProfileProvider);
    final myPhone = currentUser?.phone ?? profile.phone;

    final reservations = ref
        .watch(reservationProvider)
        .where((r) => myPhone.isEmpty || r.customerPhone == myPhone)
        .toList();

    final activeList = reservations
        .where((r) => r.status == 'PENDING' || r.status == 'CONFIRMED')
        .toList();
    final cancelledList =
        reservations.where((r) => r.status == 'CANCELLED').toList();

    return SafeArea(
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                'Lịch đặt bàn của bạn',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1D26),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                labelColor: const Color(0xFFFF5722),
                unselectedLabelColor: const Color(0xFF9A9FA5),
                indicatorColor: const Color(0xFFFF5722),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: [
                  Tab(text: 'Sắp tới (${activeList.length})'),
                  Tab(text: 'Đã hủy (${cancelledList.length})'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _buildReservationList(ref, activeList, isActive: true),
                  _buildReservationList(ref, cancelledList, isActive: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Danh sách phiếu đặt bàn
  Widget _buildReservationList(WidgetRef ref, List<Reservation> list,
      {required bool isActive}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive
                  ? Icons.calendar_month_outlined
                  : Icons.event_busy_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              isActive ? 'Chưa có lịch đặt bàn nào' : 'Không có đơn bị hủy',
              style: const TextStyle(
                color: Color(0xFF9A9FA5),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final isPending = item.status == 'PENDING';
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.restaurantName,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isPending
                          ? const Color(0xFFFFF8E1)
                          : (item.status == 'CONFIRMED'
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFEBEE)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isPending
                          ? '⏳ Chờ xếp bàn'
                          : (item.status == 'CONFIRMED'
                              ? '✓ Đã xếp: ${item.assignedTable}'
                              : 'Đã hủy'),
                      style: TextStyle(
                        color: isPending
                            ? const Color(0xFFF57C00)
                            : (item.status == 'CONFIRMED'
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFE53935)),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(item.address,
                  style:
                      const TextStyle(color: Color(0xFF6C7278), fontSize: 13)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: Colors.grey[200], height: 1),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.calendar_month,
                        size: 20, color: Colors.orange),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Thời gian',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 12)),
                      Text('${item.time} - ${item.date}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        const Icon(Icons.people, size: 20, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Số khách',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 12)),
                      Text('${item.guests} người',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ],
              ),
              if (item.note.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Ghi chú: ${item.note}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                    ),
                  ),
                )
              ],
              if (isActive) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE53935),
                      side: const BorderSide(color: Color(0xFFFFCDD2)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => ref
                        .read(reservationProvider.notifier)
                        .cancelReservation(item.id),
                    child: const Text('Hủy đặt bàn',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ],
          ),
        );
      },
    );
  }
}
