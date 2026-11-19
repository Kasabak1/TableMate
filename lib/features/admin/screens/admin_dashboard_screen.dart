import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:str/core/database/app_database.dart';
import 'package:str/features/home/models/user_profile_provider.dart'
    show formatCurrency;
import 'package:str/features/staff/providers/staff_provider.dart';

// Màn hình tổng quan Quản trị Nhà hàng
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final myRestaurantName = ref.watch(adminRestaurantNameProvider);
    final allRestaurants = ref.watch(realRestaurantListProvider);
    ref.watch(restaurantBankProvider);
    final myBankInfo = ref
        .read(restaurantBankProvider.notifier)
        .getBankForRestaurant(
          restaurantName: myRestaurantName,
          ownerPhone: currentUser?.phone,
          restaurants: allRestaurants,
        );
    final myRes = allRestaurants
        .where((r) => r.ownerPhone == currentUser?.phone)
        .firstOrNull;

    final displayResName = myRestaurantName.isNotEmpty
        ? myRestaurantName
        : 'Chưa thiết lập tên Nhà hàng';

    final cleanMyRes = myRestaurantName.trim();
    final orders = ref
        .watch(kitchenOrdersProvider)
        .where((o) =>
            cleanMyRes.isEmpty ||
            isSameRestaurantName(o.restaurantName, cleanMyRes))
        .toList();
    final tables = ref
        .watch(tableListProvider)
        .where((t) =>
            cleanMyRes.isNotEmpty &&
            isSameRestaurantName(t.restaurantName, cleanMyRes))
        .toList();
    final occupiedTablesCount = tables
        .where((t) =>
            t.state == TableState.occupied || t.state == TableState.needPayment)
        .length;

    final paidOrders = ref
        .watch(paidOrdersProvider)
        .where((o) =>
            cleanMyRes.isEmpty ||
            isSameRestaurantName(o.restaurantName, cleanMyRes))
        .toList();
    final int paidFromDb = paidOrders.fold(
      0,
      (sumOrder, order) =>
          sumOrder +
          order.items.fold(
            0,
            (sumItem, item) => sumItem + (item.price * item.quantity),
          ),
    );
    final settledMap = ref.watch(settledRevenueByRestaurantProvider);
    final int resLocalSettled = cleanMyRes.isNotEmpty
        ? (settledMap[cleanMyRes.toLowerCase()] ?? 0)
        : ref.watch(settledRevenueProvider);
    final int settledRevenue =
        paidFromDb >= resLocalSettled ? paidFromDb : resLocalSettled;

    final int tempRevenue = orders.fold(
      0,
      (sumOrder, order) =>
          sumOrder +
          order.items.fold(
            0,
            (sumItem, item) => sumItem + (item.price * item.quantity),
          ),
    );

    final myMenuItems = ref
        .watch(menuDbProvider)
        .where((m) =>
            myRestaurantName.isNotEmpty && m.restaurantName == myRestaurantName)
        .toList();

    final staffCount = ref
        .watch(accountsDbProvider)
        .where((u) =>
            (u.role == 'STAFF' || u.role == 'WAITER' || u.role == 'CHEF') &&
            myRestaurantName.isNotEmpty &&
            u.restaurantName == myRestaurantName)
        .length;

    final myReservations = ref
        .watch(reservationProvider)
        .where((r) =>
            myRestaurantName.isNotEmpty && r.restaurantName == myRestaurantName)
        .toList();
    final pendingReservations =
        myReservations.where((r) => r.status == 'PENDING').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tổng quan Quản trị',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1D26),
                fontSize: 18,
              ),
            ),
            Text(
              displayResName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: myRestaurantName.isEmpty
                    ? Colors.red
                    : const Color(0xFFFF5722),
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
              tooltip: 'Đăng xuất',
              icon: const Icon(Icons.logout_rounded, color: Colors.red),
              onPressed: () {
                ref.read(currentUserProvider.notifier).state = null;
                context.pushReplacement('/');
              },
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStoreStatusBanner(context, myRes, myRestaurantName),
            const Text(
              'Số liệu Database thời gian thực',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1D26),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatCard(
                  title: 'Bàn & Đơn bếp',
                  value: '$occupiedTablesCount/${tables.length}',
                  subtitle: '${orders.length} đơn đang phục vụ',
                  icon: Icons.table_restaurant_rounded,
                  color: Colors.orange,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  title: 'Thực đơn quán',
                  value: '${myMenuItems.length}',
                  subtitle:
                      '${myMenuItems.where((m) => m.isAvailable).length} món đang bán',
                  icon: Icons.restaurant_menu_rounded,
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatCard(
                  title: 'Nhân sự',
                  value: '$staffCount',
                  subtitle: 'Tài khoản Phục vụ/Bếp',
                  icon: Icons.people_alt_rounded,
                  color: Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  title: 'Doanh thu đã thu',
                  value: formatCurrency(settledRevenue),
                  subtitle: 'Đang phục vụ: ${formatCurrency(tempRevenue)}',
                  icon: Icons.account_balance_wallet_rounded,
                  color: Colors.purple,
                  compactValue: true,
                  onTap: () => _showRevenueHistorySheet(
                    context,
                    paidOrders,
                    settledRevenue,
                    tempRevenue,
                  ),
                ),
              ],
            ),
            if (pendingReservations.isNotEmpty) ...[
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Khách đặt bàn chờ xếp chỗ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1D26),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${pendingReservations.length} đơn mới',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...pendingReservations
                  .map((res) => _buildReservationCard(context, ref, res, tables)),
            ],
            const SizedBox(height: 28),
            const Text(
              'Tính năng Quản trị Nhà hàng',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1D26),
              ),
            ),
            const SizedBox(height: 16),
            _buildActionTile(
              context,
              title: 'Hồ sơ Cửa hàng & Tài khoản VietQR',
              subtitle: myBankInfo != null && myBankInfo.isConfigured
                  ? 'STK nhận tiền: ${myBankInfo.bankId} - ${myBankInfo.accountNo} (${myBankInfo.accountName})'
                  : 'Cài đặt Tên quán, Bản đồ & Số tài khoản Ngân hàng nhận QR',
              icon: Icons.storefront_rounded,
              color: Colors.redAccent,
              route: '/admin/settings',
            ),
            _buildActionTile(
              context,
              title: 'Quản lý Thực đơn',
              subtitle:
                  'Thêm món, Sửa giá & thông tin, Báo hết món (${myMenuItems.length} món)',
              icon: Icons.menu_book_rounded,
              color: Colors.green,
              route: '/admin/menu',
            ),
            _buildActionTile(
              context,
              title: 'Quản lý Nhân sự',
              subtitle:
                  'Cấp tài khoản, Đổi chức vụ & mật khẩu Nhân viên ($staffCount người)',
              icon: Icons.badge_rounded,
              color: Colors.blue,
              route: '/admin/staff',
            ),
            _buildActionTile(
              context,
              title: 'Sơ đồ Bàn & Mã QR Gọi món',
              subtitle:
                  'Thêm/Xóa bàn, Đổi trạng thái bàn & Tạo mã QR (${tables.length} bàn)',
              icon: Icons.qr_code_2_rounded,
              color: Colors.purple,
              route: '/admin/qr',
            ),
            _buildActionTile(
              context,
              title: 'Hộp thư Tin nhắn Khách hàng',
              subtitle: 'Tư vấn đặt bàn & Hỗ trợ trực tuyến Real-time',
              icon: Icons.forum_rounded,
              color: const Color(0xFFFF5722),
              route: '/admin/chat',
            ),
          ],
        ),
      ),
    );
  }

  // Biểu ngữ trạng thái hồ sơ nhà hàng
  Widget _buildStoreStatusBanner(
      BuildContext context, RestaurantModel? myRes, String myRestaurantName) {
    if (myRes == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFE65100), size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chưa thiết lập Hồ sơ Nhà hàng trên Database',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE65100),
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Vui lòng cập nhật Tên quán & Vị trí để đồng bộ Thực đơn, Nhân viên và hiển thị cho Khách hàng.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6C7278)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => context.push('/admin/settings'),
              child: const Text('Thiết lập',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    final isApproved = myRes.status == 'APPROVED';
    final isRejected = myRes.status == 'REJECTED';
    final bgColor = isApproved
        ? const Color(0xFFE8F5E9)
        : (isRejected ? const Color(0xFFFFEBEE) : const Color(0xFFFFF8E1));
    final textColor = isApproved
        ? const Color(0xFF2E7D32)
        : (isRejected ? const Color(0xFFC62828) : const Color(0xFFF57C00));
    final statusLabel = isApproved
        ? 'Đã phê duyệt • Đang hiển thị trên trang chủ Khách hàng'
        : (isRejected
            ? 'Hồ sơ bị từ chối • Bấm để chỉnh sửa và gửi duyệt lại'
            : 'Đang chờ Super Admin phê duyệt hiển thị');

    return GestureDetector(
      onTap: () => context.push('/admin/settings'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              isApproved
                  ? Icons.verified_rounded
                  : (isRejected
                      ? Icons.error_outline_rounded
                      : Icons.hourglass_top_rounded),
              color: textColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textColor),
          ],
        ),
      ),
    );
  }

  // Thẻ duyệt đơn đặt bàn nhanh
  Widget _buildReservationCard(
    BuildContext context,
    WidgetRef ref,
    Reservation res,
    List<RestaurantTable> tables,
  ) {
    final emptyTables =
        tables.where((t) => t.state == TableState.empty).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
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
              Text(
                '${res.customerName} (${res.customerPhone})',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Text(
                '${res.guests} khách',
                style: const TextStyle(
                  color: Color(0xFFFF5722),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Giờ hẹn: ${res.time} - Ngày ${res.date}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6C7278)),
          ),
          if (res.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Ghi chú: ${res.note}',
              style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.black87),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => ref
                      .read(reservationProvider.notifier)
                      .cancelReservation(res.id),
                  child: const Text('Từ chối'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final availableList =
                        emptyTables.isNotEmpty ? emptyTables : tables;
                    if (availableList.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Vui lòng thêm bàn ăn trong mục Sơ đồ Bàn & Mã QR trước khi xếp bàn!'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    String selectedTable = availableList.first.number;
                    showDialog(
                      context: context,
                      builder: (ctx) => StatefulBuilder(
                        builder: (ctx, setDialogState) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          title: const Text('Xếp bàn cho khách',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          content: DropdownButtonFormField<String>(
                            value: selectedTable,
                            decoration: const InputDecoration(
                                labelText: 'Chọn bàn trống'),
                            items: availableList
                                .map((t) => DropdownMenuItem(
                                      value: t.number,
                                      child: Text('${t.number} (${t.seats} ghế)'),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedTable = val);
                              }
                            },
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Hủy'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF5722),
                                  foregroundColor: Colors.white),
                              onPressed: () {
                                ref
                                    .read(reservationProvider.notifier)
                                    .assignTableToReservation(
                                      res.id,
                                      selectedTable,
                                      restaurantName: res.restaurantName,
                                    );
                                Navigator.pop(ctx);
                              },
                              child: const Text('Xác nhận'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: const Text('Duyệt & Xếp bàn'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Thẻ thống kê chỉ số
  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool compactValue = false,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compactValue ? 20 : 26,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        const TextStyle(color: Color(0xFF475569), fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Bảng chi tiết lịch sử doanh thu đã thu
  void _showRevenueHistorySheet(
    BuildContext context,
    List<KitchenOrder> paidOrders,
    int settledRevenue,
    int tempRevenue,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.45,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chi tiết Doanh thu & Hóa đơn',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TỔNG ĐÃ THU (ĐÃ CHỐT)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatCurrency(settledRevenue),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'ĐANG PHỤC VỤ',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatCurrency(tempRevenue),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Hóa đơn đã thanh toán (${paidOrders.length})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: paidOrders.isEmpty
                    ? const Center(
                        child: Text(
                          'Chưa có hóa đơn nào được chốt thanh toán.',
                          style: TextStyle(color: Color(0xFF475569)),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: paidOrders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final ord = paidOrders[index];
                          final ordTotal = ord.items.fold<int>(
                            0,
                            (sum, item) => sum + (item.price * item.quantity),
                          );
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long_rounded,
                                    color: Color(0xFF16A34A),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${ord.tableNumber} • Mã: ${ord.orderId}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.5,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        ord.items
                                            .map((i) =>
                                                '${i.dishName} x${i.quantity}')
                                            .join(', '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatCurrency(ordTotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Mục điều hướng chức năng quản trị
  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration:
              BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () => context.push(route),
      ),
    );
  }
}
