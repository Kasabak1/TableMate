import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:str/core/database/app_database.dart';
import 'package:str/features/home/models/user_profile_provider.dart'
    show formatCurrency;
import 'package:str/features/staff/providers/staff_provider.dart';
import 'package:str/features/chat/chat_screen.dart';

// Giao diện Nhân viên Phục vụ & Thu ngân
class WaiterView extends ConsumerWidget {
  final int readyToServeCount;
  final int pendingBookingCount;

  const WaiterView({
    super.key,
    required this.readyToServeCount,
    required this.pendingBookingCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final myRestaurant = currentUser?.restaurantName ?? '';
    final allMessages = ref.watch(chatProvider);
    ref.watch(realRestaurantListProvider);
    ref.watch(restaurantBankProvider);

    final restaurantMessages = allMessages
        .where((m) => myRestaurant.isEmpty || m.restaurantName == myRestaurant)
        .toList();
    final Map<String, ChatMessage> latestByRoom = {};
    for (final m in restaurantMessages) {
      latestByRoom[m.roomId] = m;
    }
    final int unreadChatCount =
        latestByRoom.values.where((m) => m.senderRole == 'CUSTOMER').length;

    final allTables = ref.watch(tableListProvider);
    final int needPaymentCount = allTables
        .where((t) =>
            t.state == TableState.needPayment &&
            (myRestaurant.isEmpty || t.restaurantName == myRestaurant))
        .length;

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: const Color(0xFFFF5722),
              unselectedLabelColor: const Color(0xFF9A9FA5),
              indicatorColor: const Color(0xFFFF5722),
              indicatorWeight: 3,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              tabs: [
                Tab(
                  icon: Badge(
                    isLabelVisible: needPaymentCount > 0,
                    label: Text('$needPaymentCount'),
                    backgroundColor: const Color(0xFFE65100),
                    child: const Icon(Icons.grid_view_rounded),
                  ),
                  text: needPaymentCount > 0
                      ? 'Sơ đồ bàn ($needPaymentCount gọi TT)'
                      : 'Sơ đồ bàn',
                ),
                Tab(
                  icon: Badge(
                    isLabelVisible: pendingBookingCount > 0,
                    label: Text('$pendingBookingCount'),
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.event_seat_rounded),
                  ),
                  text: 'Đặt bàn ($pendingBookingCount)',
                ),
                Tab(
                  icon: Badge(
                    isLabelVisible: readyToServeCount > 0,
                    label: Text('$readyToServeCount'),
                    child: const Icon(Icons.notifications_active_rounded),
                  ),
                  text: 'Chờ bưng ($readyToServeCount)',
                ),
                Tab(
                  icon: Badge(
                    isLabelVisible: unreadChatCount > 0,
                    label: Text('$unreadChatCount'),
                    backgroundColor: const Color(0xFFFF5722),
                    child: const Icon(Icons.chat_rounded),
                  ),
                  text: 'Tin nhắn ($unreadChatCount)',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildTableMapTab(context, ref, myRestaurant),
                _buildReservationManagementTab(context, ref, myRestaurant),
                _buildReadyToServeTab(context, ref, myRestaurant),
                const RestaurantChatListView(staffName: 'NV Phục vụ'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Sơ đồ bàn ăn
  Widget _buildTableMapTab(
      BuildContext context, WidgetRef ref, String myRestaurant) {
    final allTables = ref.watch(tableListProvider);
    final matchedTables = allTables
        .where((t) =>
            myRestaurant.isEmpty ||
            isSameRestaurantName(t.restaurantName, myRestaurant))
        .toList();
    final tables = matchedTables.isNotEmpty
        ? matchedTables
        : (myRestaurant.isEmpty
            ? allTables.where((t) => t.restaurantName.isEmpty).toList()
            : <RestaurantTable>[]);

    final orders = ref
        .watch(kitchenOrdersProvider)
        .where((o) =>
            myRestaurant.isEmpty ||
            isSameRestaurantName(o.restaurantName, myRestaurant))
        .toList();
    final reservations = ref
        .watch(reservationProvider)
        .where((r) =>
            myRestaurant.isEmpty ||
            isSameRestaurantName(r.restaurantName, myRestaurant))
        .toList();

    if (tables.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.table_restaurant_outlined,
                  size: 72, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              const Text(
                'Chưa có bàn ăn nào trên hệ thống',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6C7278),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Quản lý nhà hàng có thể thêm bàn tại mục Sơ đồ Bàn & Mã QR.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9A9FA5), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final needPaymentTables =
        tables.where((t) => t.state == TableState.needPayment).toList();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: Colors.white,
          child: Wrap(
            spacing: 16,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _buildLegendItem(const Color(0xFFE0E0E0), 'Trống'),
              _buildLegendItem(const Color(0xFFE1BEE7), 'Đã xếp lịch'),
              _buildLegendItem(const Color(0xFFC8E6C9), 'Đang phục vụ'),
              _buildLegendItem(const Color(0xFFFFECB3), 'Chờ thanh toán'),
            ],
          ),
        ),
        if (needPaymentTables.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade400, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded,
                        color: Color(0xFFE65100), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Khách đang gọi thanh toán (${needPaymentTables.length} bàn)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          color: Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...needPaymentTables.map((t) {
                  final tOrders =
                      orders.where((o) => o.tableNumber == t.number).toList();
                  final tBill = tOrders.fold<int>(
                    0,
                    (sum, ord) =>
                        sum +
                        ord.items
                            .fold<int>(0, (s, i) => s + (i.price * i.quantity)),
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '• ${t.number}: ${formatCurrency(tBill)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF1A1D26),
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5722),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(120, 32),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                          label: const Text(
                            'Đưa mã QR Thu tiền',
                            style: TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _showCheckoutInvoiceDialog(
                            context,
                            ref,
                            t,
                            tOrders,
                            tBill,
                            myRestaurant.isNotEmpty
                                ? myRestaurant
                                : t.restaurantName,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.92,
            ),
            itemCount: tables.length,
            itemBuilder: (context, index) {
              final table = tables[index];
              int readyCountForTable = 0;
              for (final o
                  in orders.where((ord) => ord.tableNumber == table.number)) {
                readyCountForTable +=
                    o.items.where((i) => i.status == DishStatus.ready).length;
              }

              final activeRes = reservations
                  .where((r) =>
                      r.status == 'CONFIRMED' &&
                      r.assignedTable == table.number)
                  .firstOrNull;

              Color cardColor = Colors.white;
              Color iconColor = const Color(0xFF6C7278);
              String statusText = 'Trống (${table.seats} ghế)';

              if (table.state == TableState.reserved) {
                cardColor = const Color(0xFFF3E5F5);
                iconColor = const Color(0xFF7B1FA2);
                statusText = activeRes != null
                    ? 'Đã đặt (${activeRes.time})'
                    : 'Đã đặt trước';
              } else if (table.state == TableState.occupied) {
                cardColor = const Color(0xFFE8F5E9);
                iconColor = const Color(0xFF2E7D32);
                statusText = 'Đang phục vụ';
              } else if (table.state == TableState.needPayment) {
                cardColor = const Color(0xFFFFF8E1);
                iconColor = const Color(0xFFE65100);
                statusText = 'Gọi thanh toán';
              }

              return InkWell(
                onTap: () => _showTableActionSheet(
                    context, ref, table, activeRes, myRestaurant),
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: iconColor.withOpacity(0.35), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.table_restaurant_rounded,
                                  color: iconColor, size: 32),
                              const SizedBox(height: 6),
                              Text(
                                table.number,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: Color(0xFF1A1D26),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                statusText,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: iconColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (activeRes != null &&
                                  table.state == TableState.reserved)
                                Text(
                                  activeRes.customerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.purple[900]),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (readyCountForTable > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            '$readyCountForTable món xong',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Chú thích trạng thái bàn
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // Quản lý & xếp bàn cho khách đặt trước
  Widget _buildReservationManagementTab(
      BuildContext context, WidgetRef ref, String myRestaurant) {
    final reservations = ref
        .watch(reservationProvider)
        .where((r) => myRestaurant.isEmpty || r.restaurantName == myRestaurant)
        .toList();
    final pendingList =
        reservations.where((r) => r.status == 'PENDING').toList();
    final confirmedList =
        reservations.where((r) => r.status == 'CONFIRMED').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(Icons.pending_actions_rounded,
                color: Color(0xFFFF5722)),
            const SizedBox(width: 8),
            Text('Yêu cầu chờ xếp bàn (${pendingList.length})',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 10),
        if (pendingList.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Hiện không có yêu cầu đặt bàn mới nào đang chờ duyệt.',
              style: TextStyle(color: Color(0xFF6C7278)),
            ),
          )
        else
          ...pendingList.map((res) =>
              _buildReservationCard(context, ref, res, isPending: true)),
        const SizedBox(height: 24),
        Row(
          children: [
            const Icon(Icons.event_available_rounded,
                color: Color(0xFF00C853)),
            const SizedBox(width: 8),
            Text('Đã xếp bàn thành công (${confirmedList.length})',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 10),
        if (confirmedList.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Chưa có bàn nào được xếp lịch.',
              style: TextStyle(color: Color(0xFF6C7278)),
            ),
          )
        else
          ...confirmedList.map((res) =>
              _buildReservationCard(context, ref, res, isPending: false)),
      ],
    );
  }

  // Thẻ thông tin đơn đặt bàn
  Widget _buildReservationCard(
      BuildContext context, WidgetRef ref, Reservation res,
      {required bool isPending}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPending
              ? Colors.orange.withOpacity(0.4)
              : Colors.green.withOpacity(0.4),
        ),
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
              Expanded(
                child: Text(
                  '${res.customerName} (${res.customerPhone})',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color:
                        isPending ? Colors.orange[50] : Colors.purple[50],
                    borderRadius: BorderRadius.circular(12)),
                child: Text(
                  isPending ? 'Chờ xếp bàn' : 'Đã xếp: ${res.assignedTable}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isPending
                          ? Colors.deepOrange[900]
                          : Colors.purple[900]),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 15, color: Colors.grey),
              const SizedBox(width: 6),
              Text('Ngày: ${res.date}'),
              const SizedBox(width: 14),
              const Icon(Icons.access_time_rounded,
                  size: 15, color: Colors.grey),
              const SizedBox(width: 6),
              Text('Giờ: ${res.time}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 14),
              const Icon(Icons.groups_rounded, size: 18, color: Colors.blue),
              const SizedBox(width: 6),
              Text('${res.guests} khách',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          if (res.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Ghi chú: ${res.note}',
                style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Từ chối'),
                onPressed: () {
                  ref
                      .read(reservationProvider.notifier)
                      .cancelReservation(res.id);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Đã hủy yêu cầu đặt bàn.'),
                      backgroundColor: Colors.redAccent));
                },
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPending
                      ? const Color(0xFF00C853)
                      : Colors.purple[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.table_bar, size: 18),
                label: Text(isPending ? 'Chọn bàn & Duyệt' : 'Đổi bàn khác'),
                onPressed: () => _showAssignTableDialog(context, ref, res),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Hộp thoại gán bàn trống cho đơn đặt trước
  void _showAssignTableDialog(
      BuildContext context, WidgetRef ref, Reservation res) {
    final allTables = ref
        .read(tableListProvider)
        .where((t) =>
            res.restaurantName.isEmpty ||
            t.restaurantName == res.restaurantName)
        .toList();
    final availableTables = allTables
        .where((t) =>
            t.state == TableState.empty || t.number == res.assignedTable)
        .toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Xếp bàn cho ${res.customerName} (${res.guests} khách)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          content: availableTables.isEmpty
              ? const Text(
                  'Hiện tại chưa có bàn trống khả dụng để xếp lịch!')
              : SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                          'Chọn 1 bàn trống bên dưới để gán cho khách:',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: availableTables.map((table) {
                          final bool isEnoughSeats = table.seats >= res.guests;
                          return ActionChip(
                            avatar: Icon(Icons.table_restaurant,
                                size: 18,
                                color: isEnoughSeats
                                    ? Colors.green[800]
                                    : Colors.orange[800]),
                            backgroundColor: isEnoughSeats
                                ? Colors.green[50]
                                : Colors.orange[50],
                            label: Text('${table.number} (${table.seats} ghế)',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            onPressed: () {
                              if (res.assignedTable != null &&
                                  res.assignedTable != table.number) {
                                ref
                                    .read(tableListProvider.notifier)
                                    .setTableState(
                                      res.assignedTable!,
                                      TableState.empty,
                                      restaurantName: res.restaurantName,
                                    );
                              }
                              ref
                                  .read(reservationProvider.notifier)
                                  .assignTableToReservation(
                                    res.id,
                                    table.number,
                                    restaurantName: res.restaurantName,
                                  );
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Đã xếp ${table.number} cho khách ${res.customerName}!'),
                                      backgroundColor: Colors.green[700]));
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng')),
          ],
        );
      },
    );
  }

  // Bảng thao tác chi tiết của bàn ăn
  void _showTableActionSheet(
    BuildContext parentContext,
    WidgetRef parentRef,
    RestaurantTable table,
    Reservation? activeRes,
    String myRestaurant,
  ) {
    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return Consumer(
          builder: (consumerContext, sheetRef, _) {
            final allOrders = sheetRef.watch(kitchenOrdersProvider);
            final tableOrders = allOrders
                .where((o) =>
                    o.tableNumber.trim().toLowerCase() ==
                        table.number.trim().toLowerCase() &&
                    (myRestaurant.isEmpty ||
                        isSameRestaurantName(o.restaurantName, myRestaurant)))
                .toList();

            int totalBill = 0;
            for (final o in tableOrders) {
              for (final i in o.items) {
                totalBill += i.price * i.quantity;
              }
            }

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${table.number} (${table.seats} ghế)',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900)),
                      Chip(
                        label: Text(table.state == TableState.empty
                            ? 'Bàn trống'
                            : table.state == TableState.reserved
                                ? 'Đã đặt trước'
                                : table.state == TableState.occupied
                                    ? 'Đang có khách'
                                    : 'Chờ thanh toán'),
                      ),
                    ],
                  ),
                  if (activeRes != null &&
                      table.state == TableState.reserved) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Khách đặt trước: ${activeRes.customerName} (${activeRes.customerPhone})',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                              'Giờ hẹn: ${activeRes.time} - Ngày ${activeRes.date} (${activeRes.guests} người)'),
                          if (activeRes.note.isNotEmpty)
                            Text('Lưu ý: ${activeRes.note}'),
                        ],
                      ),
                    ),
                  ],
                  const Divider(),
                  if (tableOrders.isEmpty)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('Bàn này hiện chưa gọi món nào.',
                            style: TextStyle(color: Colors.grey)))
                  else ...[
                    const Text('Các món đã gọi:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final order in tableOrders)
                            for (final item in order.items)
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                    '${item.dishName} (x${item.quantity})',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    '${formatCurrency(item.price * item.quantity)} ${item.note.isNotEmpty ? "• ${item.note}" : ""}'),
                                trailing: _buildStatusChip(item.status),
                              ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tạm tính:',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(formatCurrency(totalBill),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFF5722))),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E88E5),
                            foregroundColor: Colors.white),
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Gọi thêm món'),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _showWaiterOrderDialog(
                              parentContext, parentRef, table.number, myRestaurant);
                        },
                      ),
                      if (table.state == TableState.empty ||
                          table.state == TableState.reserved)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00C853),
                              foregroundColor: Colors.white),
                          icon: const Icon(Icons.people),
                          label: Text(table.state == TableState.reserved
                              ? 'Nhận bàn'
                              : 'Mở bàn'),
                          onPressed: () {
                            parentRef
                                .read(tableListProvider.notifier)
                                .setTableState(
                                  table.number,
                                  TableState.occupied,
                                  restaurantName: myRestaurant,
                                );
                            Navigator.pop(sheetContext);
                          },
                        ),
                      if (table.state == TableState.occupied ||
                          table.state == TableState.needPayment ||
                          tableOrders.isNotEmpty)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5722),
                              foregroundColor: Colors.white),
                          icon: const Icon(Icons.receipt_long_rounded),
                          label: const Text('Xuất Hóa đơn & QR Thu tiền'),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _showCheckoutInvoiceDialog(
                              parentContext,
                              parentRef,
                              table,
                              tableOrders,
                              totalBill,
                              myRestaurant,
                            );
                          },
                        ),
                      if (table.state != TableState.empty)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent),
                          icon: const Icon(Icons.cleaning_services),
                          label: const Text('Dọn bàn nhanh'),
                          onPressed: () async {
                            final effectiveRes = myRestaurant.isNotEmpty
                                ? myRestaurant
                                : table.restaurantName;
                            final orderNotifier = sheetRef
                                .read(kitchenOrdersProvider.notifier);
                            final tableNotifier =
                                sheetRef.read(tableListProvider.notifier);
                            final resNotifier =
                                sheetRef.read(reservationProvider.notifier);
                            Navigator.pop(sheetContext);
                            if (totalBill > 0) {
                              await orderNotifier.settleOrdersForTable(
                                table.number,
                                restaurantName: effectiveRes,
                                fallbackAmount: totalBill,
                              );
                            } else {
                              await orderNotifier.clearOrdersForTable(
                                table.number,
                                restaurantName: effectiveRes,
                              );
                            }
                            await tableNotifier.setTableState(
                              table.number,
                              TableState.empty,
                              restaurantName: effectiveRes,
                            );
                            await resNotifier.completeReservationForTable(
                              table.number,
                              restaurantName: effectiveRes,
                            );
                            if (parentContext.mounted) {
                              ScaffoldMessenger.of(parentContext).showSnackBar(
                                SnackBar(
                                  content: Text('Đã dọn sạch ${table.number}!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Xuất hóa đơn thanh toán, kiểm tra tài khoản ngân hàng (TC25) và tự động nhận biết giao dịch VietQR (TC26, TC27)
  void _showCheckoutInvoiceDialog(
    BuildContext parentContext,
    WidgetRef parentRef,
    RestaurantTable table,
    List<KitchenOrder> tableOrders,
    int totalBill,
    String myRestaurant,
  ) {
    final effectiveRes =
        myRestaurant.isNotEmpty ? myRestaurant : table.restaurantName;
    parentRef.read(tableListProvider.notifier).setTableState(
          table.number,
          TableState.needPayment,
          restaurantName: effectiveRes,
        );

    final allRestaurants = parentRef.read(realRestaurantListProvider);
    final bankInfo = parentRef
        .read(restaurantBankProvider.notifier)
        .getBankForRestaurant(
          restaurantName: effectiveRes,
          restaurants: allRestaurants,
        );
    final bool hasValidBank = bankInfo != null && bankInfo.isConfigured;

    String paymentMethod = hasValidBank ? 'QR' : 'CASH';
    bool isCompleting = false;
    bool isAutoDetected = false;
    Timer? autoPollTimer;

    final displayRestaurant =
        effectiveRes.isNotEmpty ? effectiveRes : 'Nhà hàng Smart Ordering';
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} - ${now.day}/${now.month}/${now.year}';

    final transferNote = '${table.number} thanh toan';
    final qrPayload = hasValidBank
        ? 'VIETQR|${bankInfo.bankId}|${bankInfo.accountNo}|${bankInfo.accountName}|AMOUNT:$totalBill|NOTE:$transferNote'
        : '';

    Future<void> completeSettlement(
      BuildContext dialogContext,
      WidgetRef dialogRef,
      StateSetter setDialogState, {
      required String methodLabel,
      bool isAutomatic = false,
    }) async {
      if (isCompleting) return;
      autoPollTimer?.cancel();
      setDialogState(() {
        isCompleting = true;
        if (isAutomatic) isAutoDetected = true;
      });
      final orderNotifier = dialogRef.read(kitchenOrdersProvider.notifier);
      final tableNotifier = dialogRef.read(tableListProvider.notifier);
      final resNotifier = dialogRef.read(reservationProvider.notifier);

      await orderNotifier.settleOrdersForTable(
        table.number,
        restaurantName: effectiveRes,
        fallbackAmount: totalBill,
        paymentMethod: methodLabel,
      );
      await tableNotifier.setTableState(
        table.number,
        TableState.empty,
        restaurantName: effectiveRes,
      );
      await resNotifier.completeReservationForTable(
        table.number,
        restaurantName: effectiveRes,
      );
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      }
      if (parentContext.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text(
              isAutomatic
                  ? 'Hệ thống tự động nhận biết giao dịch VietQR ${formatCurrency(totalBill)} thành công! Đã cộng doanh thu ca và làm trống ${table.number}.'
                  : 'Đã chốt thanh toán ${formatCurrency(totalBill)} vào Doanh thu ca và làm trống ${table.number}!',
            ),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    }

    showDialog(
      context: parentContext,
      builder: (dialogContext) => Consumer(
        builder: (consumerCtx, dialogRef, _) => StatefulBuilder(
          builder: (stateCtx, setDialogState) {
            final liveOrders = dialogRef
                .watch(kitchenOrdersProvider)
                .where((o) =>
                    o.tableNumber.trim().toLowerCase() ==
                        table.number.trim().toLowerCase() &&
                    (effectiveRes.isEmpty ||
                        isSameRestaurantName(o.restaurantName, effectiveRes)))
                .toList();

            if (tableOrders.isNotEmpty &&
                liveOrders.isEmpty &&
                !isCompleting &&
                !isAutoDetected) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (parentContext.mounted) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Hệ thống tự động nhận biết Khách tại ${table.number} đã chuyển khoản VietQR (${formatCurrency(totalBill)})!'),
                      backgroundColor: const Color(0xFF00C853),
                    ),
                  );
                }
              });
            }

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.receipt_long_rounded,
                          color: Colors.green.shade700, size: 32),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      displayRestaurant.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Color(0xFF1A1D26),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'PHIẾU THANH TOÁN • ${table.number.toUpperCase()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFFFF5722),
                      ),
                    ),
                    Text(
                      'Giờ in: $timeStr',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const Divider(height: 24, thickness: 1),
                    if (tableOrders.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Chưa có món ăn nào trong hóa đơn.'),
                      )
                    else
                      ...tableOrders.expand((o) => o.items).map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.dishName} x${item.quantity}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Text(
                                    formatCurrency(item.price * item.quantity),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    const Divider(height: 24, thickness: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TỔNG THANH TOÁN:',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                        Text(
                          formatCurrency(totalBill),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: Color(0xFFFF5722),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Quét QR Chuyển khoản'),
                            selected: paymentMethod == 'QR',
                            selectedColor: Colors.green.shade100,
                            onSelected: (_) =>
                                setDialogState(() => paymentMethod = 'QR'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Tiền mặt tại bàn'),
                            selected: paymentMethod == 'CASH',
                            selectedColor: Colors.orange.shade100,
                            onSelected: (_) =>
                                setDialogState(() => paymentMethod = 'CASH'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (!hasValidBank)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: Color(0xFFDC2626), size: 24),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Chưa khai báo Tài khoản Ngân hàng!',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Không thể tạo mã QR chuyển khoản hợp lệ do nhà hàng "$displayRestaurant" chưa nhập số tài khoản ngân hàng.\n• Hướng dẫn: Vui lòng thu ${formatCurrency(totalBill)} TIỀN MẶT trực tiếp từ khách tại ${table.number}.',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF0F172A),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (paymentMethod == 'QR')
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F7FB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: SizedBox(
                                width: 185,
                                height: 185,
                                child: Image.network(
                                  bankInfo.buildVietQrUrl(
                                    amount: totalBill,
                                    addInfo: transferNote,
                                  ),
                                  width: 185,
                                  height: 185,
                                  fit: BoxFit.contain,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) {
                                      return child;
                                    }
                                    return QrImageView(
                                      data: qrPayload,
                                      version: QrVersions.auto,
                                      size: 185.0,
                                      backgroundColor: Colors.white,
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => QrImageView(
                                    data: qrPayload,
                                    version: QrVersions.auto,
                                    size: 185.0,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              bankInfo.bankName,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.green.shade800,
                              ),
                            ),
                            Text(
                              'STK: ${bankInfo.accountNo}${bankInfo.accountName.isNotEmpty ? " • ${bankInfo.accountName}" : ""}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1D26),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Số tiền: ${formatCurrency(totalBill)} • Nội dung: $transferNote',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Đang tự động lắng nghe giao dịch VietQR...',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF16A34A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor:
                                            const Color(0xFF16A34A),
                                        side: const BorderSide(
                                            color: Color(0xFF16A34A)),
                                        minimumSize: const Size(0, 34),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                      ),
                                      icon: const Icon(
                                          Icons.bolt_rounded,
                                          size: 16),
                                      label: const Text(
                                        'Tự động xác nhận tiền về VietQR',
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      onPressed: isCompleting
                                          ? null
                                          : () => completeSettlement(
                                                dialogContext,
                                                dialogRef,
                                                setDialogState,
                                                methodLabel: 'VIETQR_AUTO',
                                                isAutomatic: true,
                                              ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.payments_outlined,
                                color: Colors.deepOrange),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Vui lòng thu ${formatCurrency(totalBill)} tiền mặt từ khách tại ${table.number}.',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6C7278),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              autoPollTimer?.cancel();
                              Navigator.of(dialogContext).pop();
                            },
                            child: const Text('Đóng'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00C853),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: isCompleting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.check_circle_rounded,
                                    size: 18),
                            label: const Text(
                              'Đã thu tiền & Dọn bàn',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: isCompleting
                                ? null
                                : () => completeSettlement(
                                      dialogContext,
                                      dialogRef,
                                      setDialogState,
                                      methodLabel:
                                          hasValidBank ? paymentMethod : 'CASH',
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Hộp thoại gọi món hộ khách tại bàn
  void _showWaiterOrderDialog(BuildContext parentContext, WidgetRef parentRef,
      String tableNumber, String myRestaurant) {
    final allAvailableMenu =
        parentRef.read(menuDbProvider).where((m) => m.isAvailable).toList();
    final filteredMenu = allAvailableMenu
        .where((m) => myRestaurant.isEmpty || m.restaurantName == myRestaurant)
        .toList();
    final effectiveMenu =
        filteredMenu.isNotEmpty ? filteredMenu : allAvailableMenu;

    final menuCatalog = effectiveMenu
        .map((m) => {'name': m.name, 'price': m.price})
        .toList();
    final Map<String, int> selectedQuantities = {};
    final noteCtrl = TextEditingController();

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return Consumer(
          builder: (consumerCtx, dialogRef, _) => StatefulBuilder(
            builder: (stateCtx, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: Text('Gọi món - $tableNumber',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (menuCatalog.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                                'Nhà hàng hiện chưa có món ăn nào trong thực đơn.'),
                          ),
                        ...menuCatalog.map((dish) {
                          final name = dish['name'] as String;
                          final price = dish['price'] as int;
                          final qty = selectedQuantities[name] ?? 0;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(formatCurrency(price)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: qty > 0
                                      ? () => setDialogState(() =>
                                          selectedQuantities[name] = qty - 1)
                                      : null,
                                ),
                                Text('$qty',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle,
                                      color: Color(0xFF00C853)),
                                  onPressed: () => setDialogState(
                                      () => selectedQuantities[name] = qty + 1),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        TextField(
                          controller: noteCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Ghi chú cho Bếp (Tùy chọn)',
                              border: OutlineInputBorder()),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Hủy')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5722),
                        foregroundColor: Colors.white),
                    onPressed: () {
                      final List<OrderItem> itemsToSend = [];
                      selectedQuantities.forEach((dishName, qty) {
                        if (qty > 0) {
                          final price = menuCatalog.firstWhere(
                              (m) => m['name'] == dishName)['price'] as int;
                          itemsToSend.add(OrderItem(
                            id: '${DateTime.now().microsecondsSinceEpoch}_$dishName',
                            dishName: dishName,
                            quantity: qty,
                            price: price,
                            note: noteCtrl.text.trim(),
                            status: DishStatus.pending,
                          ));
                        }
                      });
                      if (itemsToSend.isNotEmpty) {
                        dialogRef
                            .read(kitchenOrdersProvider.notifier)
                            .addOrderFromWaiter(
                              tableNumber,
                              itemsToSend,
                              restaurantName: myRestaurant,
                            );
                        dialogRef
                            .read(tableListProvider.notifier)
                            .setTableState(
                              tableNumber,
                              TableState.occupied,
                              restaurantName: myRestaurant,
                            );
                        Navigator.of(dialogContext).pop();
                        if (parentContext.mounted) {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Đã gửi đơn của $tableNumber xuống Nhà Bếp!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Gửi xuống Bếp'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // Danh sách món nấu xong chờ phục vụ bưng ra bàn
  Widget _buildReadyToServeTab(
      BuildContext context, WidgetRef ref, String myRestaurant) {
    final orders = ref
        .watch(kitchenOrdersProvider)
        .where((o) =>
            myRestaurant.isEmpty ||
            isSameRestaurantName(o.restaurantName, myRestaurant))
        .toList();
    final List<Map<String, dynamic>> readyItems = [];
    for (final order in orders) {
      for (final item in order.items) {
        if (item.status == DishStatus.ready) {
          readyItems.add({
            'orderId': order.orderId,
            'tableNumber': order.tableNumber,
            'item': item
          });
        }
      }
    }

    if (readyItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 70, color: Colors.grey[350]),
            const SizedBox(height: 12),
            const Text('Tất cả món nấu xong đã được bưng ra bàn!',
                style: TextStyle(color: Color(0xFF9A9FA5), fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: readyItems.length,
      itemBuilder: (context, index) {
        final data = readyItems[index];
        final String orderId = data['orderId'];
        final String tableNumber = data['tableNumber'];
        final OrderItem item = data['item'];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF00C853), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: const CircleAvatar(
                backgroundColor: Color(0xFF00C853),
                child: Icon(Icons.room_service_rounded, color: Colors.white)),
            title: Text('${item.dishName} (x${item.quantity})',
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            subtitle: Text(
                'Giao tới: $tableNumber ${item.note.isNotEmpty ? "\nLưu ý: ${item.note}" : ""}'),
            trailing: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Đã bưng ra'),
              onPressed: () {
                ref
                    .read(kitchenOrdersProvider.notifier)
                    .updateDishStatus(orderId, item.id, DishStatus.served);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        'Đã phục vụ ${item.dishName} cho $tableNumber!'),
                    duration: const Duration(milliseconds: 900)));
              },
            ),
          ),
        );
      },
    );
  }

  // Nhãn trạng thái món ăn
  Widget _buildStatusChip(DishStatus status) {
    switch (status) {
      case DishStatus.pending:
        return const Text('Chờ bếp',
            style: TextStyle(
                color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold));
      case DishStatus.cooking:
        return const Text('Đang nấu',
            style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.bold));
      case DishStatus.ready:
        return const Text('Chờ bưng',
            style: TextStyle(
                color: Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.bold));
      case DishStatus.served:
        return const Text('Đã lên món',
            style: TextStyle(color: Colors.grey, fontSize: 12));
    }
  }
}
