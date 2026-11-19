import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:str/core/database/app_database.dart';
import 'package:str/features/staff/providers/staff_provider.dart';

// Màn hình quản lý Sơ đồ Bàn & Mã QR gọi món theo từng nhà hàng
class QrManagementScreen extends ConsumerWidget {
  const QrManagementScreen({super.key});

  // Hộp thoại quy định tổng số lượng bàn cho riêng nhà hàng
  void _showConfigureTableCountDialog(
    BuildContext context,
    WidgetRef ref,
    String myRestaurant,
    int currentCount,
  ) {
    final countCtrl = TextEditingController(
      text: currentCount > 0 ? '$currentCount' : '10',
    );
    int defaultSeats = 4;
    bool isSaving = false;
    final presets = [6, 8, 10, 12, 16, 20];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quy định số lượng bàn',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
              ),
              const SizedBox(height: 4),
              Text(
                myRestaurant,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFFF5722),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chọn nhanh hoặc nhập tổng số bàn của quán:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6C7278),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presets.map((p) {
                    final isSelected = countCtrl.text.trim() == '$p';
                    return ChoiceChip(
                      label: Text('$p bàn'),
                      selected: isSelected,
                      selectedColor: const Color(0xFFFF5722),
                      backgroundColor: const Color(0xFFF4F6FA),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF1A1D26),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onSelected: (_) {
                        setDialogState(() => countCtrl.text = '$p');
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: countCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Tổng số lượng bàn của nhà hàng',
                    hintText: 'VD: 12',
                    prefixIcon: const Icon(Icons.table_restaurant_rounded,
                        color: Color(0xFFFF5722)),
                    filled: true,
                    fillColor: const Color(0xFFF4F6FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  value: defaultSeats,
                  decoration: InputDecoration(
                    labelText: 'Số ghế tiêu chuẩn mỗi bàn',
                    prefixIcon: const Icon(Icons.event_seat_rounded,
                        color: Color(0xFFFF5722)),
                    filled: true,
                    fillColor: const Color(0xFFF4F6FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: [2, 4, 6, 8, 10, 12]
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text('$s ghế / bàn'),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => defaultSeats = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            if (!isSaving)
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      final total = int.tryParse(countCtrl.text.trim()) ?? -1;
                      if (total < 1 || total > 200) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Vui lòng nhập số lượng bàn từ 1 đến 200!'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      final ok = await ref
                          .read(tableListProvider.notifier)
                          .configureRestaurantTableCount(
                            restaurantName: myRestaurant,
                            totalTables: total,
                            defaultSeats: defaultSeats,
                          );

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Đã thiết lập $total bàn cho "$myRestaurant" trên Database!'
                                : 'Lỗi khi đồng bộ số lượng bàn lên Supabase!'),
                            backgroundColor:
                                ok ? const Color(0xFF00C853) : Colors.red,
                          ),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Áp dụng',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // Hộp thoại thêm bàn lẻ
  void _showAddTableDialog(
    BuildContext context,
    WidgetRef ref,
    String myRestaurant,
    int currentTableCount,
  ) {
    final nextNum = (currentTableCount + 1).toString().padLeft(2, '0');
    final nameCtrl = TextEditingController(text: 'Bàn $nextNum');
    int selectedSeats = 4;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Thêm bàn lẻ vào nhà hàng',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Tên / Số bàn (VD: Bàn 01, VIP 01)',
                  filled: true,
                  fillColor: const Color(0xFFF4F6FA),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: selectedSeats,
                decoration: InputDecoration(
                  labelText: 'Số lượng ghế ngồi',
                  filled: true,
                  fillColor: const Color(0xFFF4F6FA),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
                items: [2, 4, 6, 8, 10, 12]
                    .map((s) =>
                        DropdownMenuItem(value: s, child: Text('$s chỗ ngồi')))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedSeats = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final success =
                    await ref.read(tableListProvider.notifier).addTable(
                          nameCtrl.text,
                          selectedSeats,
                          restaurantName: myRestaurant,
                        );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? 'Đã thêm ${nameCtrl.text} cho $myRestaurant!'
                          : 'Bàn đã tồn tại trong nhà hàng hoặc lỗi dữ liệu!'),
                      backgroundColor:
                          success ? const Color(0xFF00C853) : Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Thêm bàn',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // Hộp thoại xem và in mã QR của bàn
  void _showQrDetailDialog(
    BuildContext context,
    WidgetRef ref,
    RestaurantTable table,
    String myRestaurant,
    String qrData,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                myRestaurant,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFFF5722),
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                table.number,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              Text(
                '${table.seats} chỗ ngồi',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade200, width: 2),
                ),
                child: SizedBox(
                  width: 210,
                  height: 210,
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 210.0,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Mã nhúng đã ký thực: $qrData',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFFFF5722),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: qrData));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép chuỗi mã QR chuẩn!'),
                            backgroundColor: Color(0xFF00C853),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      label: const Text(
                        'Sao chép chuỗi QR',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Mã QR chứa Tên nhà hàng|Số bàn kèm chữ ký số (SIG) của chủ quán để chống giả mạo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      ref.read(tableListProvider.notifier).deleteTable(
                            table.number,
                            restaurantName: myRestaurant,
                          );
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 18),
                    label: const Text('Xóa bàn',
                        style: TextStyle(color: Colors.red)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5722),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Đã xuất lệnh in mã QR cho ${table.number}!'),
                          backgroundColor: const Color(0xFF00C853),
                        ),
                      );
                    },
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('In mã QR'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myRestaurant = ref.watch(adminRestaurantNameProvider);
    final tables = ref
        .watch(tableListProvider)
        .where((t) =>
            myRestaurant.isNotEmpty &&
            isSameRestaurantName(t.restaurantName, myRestaurant))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Sơ đồ Bàn & Mã QR',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D26),
        elevation: 0.5,
        centerTitle: true,
        actions: [
          if (myRestaurant.isNotEmpty)
            IconButton(
              tooltip: 'Quy định số lượng bàn',
              icon: const Icon(Icons.tune_rounded, color: Color(0xFFFF5722)),
              onPressed: () => _showConfigureTableCountDialog(
                context,
                ref,
                myRestaurant,
                tables.length,
              ),
            ),
        ],
      ),
      floatingActionButton: myRestaurant.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: const Color(0xFFFF5722),
              foregroundColor: Colors.white,
              onPressed: () => _showAddTableDialog(
                context,
                ref,
                myRestaurant,
                tables.length,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm bàn lẻ',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
      body: myRestaurant.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.storefront_outlined,
                        size: 72, color: Colors.orange.shade300),
                    const SizedBox(height: 16),
                    const Text(
                      'Bạn chưa thiết lập Tên Nhà hàng',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Hãy vào mục Hồ sơ & Tài khoản Nhà hàng để khai báo tên quán trước khi thiết lập số lượng bàn.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6C7278)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5722),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => context.push('/admin/settings'),
                      child: const Text('Đi tới Cài đặt Nhà hàng'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              myRestaurant,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFF5722),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Hiện có ${tables.length} bàn riêng của quán trên Database',
                              style: const TextStyle(
                                color: Color(0xFF6C7278),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1D26),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        onPressed: () => _showConfigureTableCountDialog(
                          context,
                          ref,
                          myRestaurant,
                          tables.length,
                        ),
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: const Text(
                          'Quy định số bàn',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: tables.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_2_rounded,
                                    size: 80, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  'Nhà hàng "$myRestaurant" chưa có bàn nào',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1D26),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Bấm "Quy định số bàn" để tạo tự động số lượng bàn của quán (VD: 10 bàn, 15 bàn) hoặc thêm từng bàn lẻ.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Color(0xFF9A9FA5), fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF5722),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                  ),
                                  onPressed: () =>
                                      _showConfigureTableCountDialog(
                                    context,
                                    ref,
                                    myRestaurant,
                                    0,
                                  ),
                                  icon: const Icon(Icons.auto_fix_high_rounded,
                                      size: 18),
                                  label: const Text(
                                    'Thiết lập số lượng bàn ngay',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: tables.length,
                          itemBuilder: (context, index) {
                            final table = tables[index];
                            final qrData = QrSecurityHelper.generateSignedTableQr(
                              myRestaurant,
                              table.number,
                            );
                            final statusInfo = _getTableStatusBadge(table.state);

                            return GestureDetector(
                              onTap: () => _showQrDetailDialog(
                                  context, ref, table, myRestaurant, qrData),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            table.number,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF1A1D26),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: statusInfo.color
                                                .withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            statusInfo.label,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: statusInfo.color,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${table.seats} chỗ ngồi',
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.grey),
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.grey.shade200,
                                            width: 1.5),
                                      ),
                                      child: QrImageView(
                                        data: qrData,
                                        version: QrVersions.auto,
                                        size: 110.0,
                                      ),
                                    ),
                                    const Spacer(),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize:
                                            const Size(double.infinity, 34),
                                        foregroundColor:
                                            const Color(0xFFFF5722),
                                        side: const BorderSide(
                                            color: Color(0xFFFF5722)),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(
                                          Icons.qr_code_scanner_rounded,
                                          size: 15),
                                      label: const Text(
                                        'Phóng to / In mã',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11),
                                      ),
                                      onPressed: () => _showQrDetailDialog(
                                          context,
                                          ref,
                                          table,
                                          myRestaurant,
                                          qrData),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  // Nhãn trạng thái bàn ăn
  ({String label, Color color}) _getTableStatusBadge(TableState state) {
    switch (state) {
      case TableState.empty:
        return (label: 'Trống', color: const Color(0xFF00C853));
      case TableState.reserved:
        return (label: 'Đã đặt', color: const Color(0xFFFF9800));
      case TableState.occupied:
        return (label: 'Có khách', color: const Color(0xFF1E88E5));
      case TableState.needPayment:
        return (label: 'Thanh toán', color: const Color(0xFFE53935));
    }
  }
}
