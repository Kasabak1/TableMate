import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:str/core/database/app_database.dart';
import 'package:str/features/staff/providers/staff_provider.dart';

// Màn hình quản lý Sơ đồ Bàn & Mã QR gọi món
class QrManagementScreen extends ConsumerWidget {
  const QrManagementScreen({super.key});

  // Hộp thoại thêm bàn mới
  void _showAddTableDialog(
      BuildContext context, WidgetRef ref, int currentTableCount) {
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
          title: const Text('Thêm bàn mới vào Database',
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
                final success = await ref
                    .read(tableListProvider.notifier)
                    .addTable(nameCtrl.text, selectedSeats);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? 'Đã thêm ${nameCtrl.text} lên Database!'
                          : 'Bàn đã tồn tại hoặc lỗi dữ liệu!'),
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
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
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
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            Text(
              '${table.seats} chỗ ngồi',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.shade200, width: 2),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 210.0,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Mã nhúng: $qrData',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6C7278),
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'Dùng tính năng "Quét QR tại bàn" ở tài khoản Khách hàng để quét trực tiếp mã này trên màn hình.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton.icon(
            onPressed: () {
              ref.read(tableListProvider.notifier).deleteTable(table.number);
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
            label: const Text('Xóa bàn', style: TextStyle(color: Colors.red)),
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
                  content: Text('Đã xuất lệnh in mã QR cho ${table.number}!'),
                  backgroundColor: const Color(0xFF00C853),
                ),
              );
            },
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('In mã QR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myRestaurant = ref.watch(adminRestaurantNameProvider);
    final displayRes =
        myRestaurant.isNotEmpty ? myRestaurant : 'Chưa thiết lập tên Nhà hàng';
    final tables = ref.watch(tableListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Sơ đồ Bàn & Mã QR',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D26),
        elevation: 0.5,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFF5722),
        foregroundColor: Colors.white,
        onPressed: () => _showAddTableDialog(context, ref, tables.length),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm bàn mới',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Text(
                  displayRes,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFF5722),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Chạm vào từng bàn để phóng to mã QR hoặc quản lý trạng thái bàn.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
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
                          const Text(
                            'Chưa có bàn ăn nào trên Database',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6C7278),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Nhấn nút "+ Thêm bàn mới" để tạo sơ đồ bàn và mã QR gọi món.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color(0xFF9A9FA5), fontSize: 13),
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
                      final qrData = '$displayRes|${table.number}';
                      final statusInfo = _getTableStatusBadge(table.state);

                      return GestureDetector(
                        onTap: () => _showQrDetailDialog(
                            context, ref, table, displayRes, qrData),
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
                                  Text(
                                    table.number,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1A1D26),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: statusInfo.color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
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
                                      color: Colors.grey.shade200, width: 1.5),
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
                                  minimumSize: const Size(double.infinity, 34),
                                  foregroundColor: const Color(0xFFFF5722),
                                  side: const BorderSide(
                                      color: Color(0xFFFF5722)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.qr_code_scanner_rounded,
                                    size: 15),
                                label: const Text(
                                  'Phóng to / In mã',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                                onPressed: () => _showQrDetailDialog(
                                    context, ref, table, displayRes, qrData),
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
