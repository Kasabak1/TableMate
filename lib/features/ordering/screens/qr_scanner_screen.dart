import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:str/core/database/app_database.dart';
import 'package:str/features/staff/providers/staff_provider.dart';

// Màn hình quét mã QR tại bàn
class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isScanned = false;
  bool _isTorchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Điều hướng tới thực đơn của bàn
  void _navigateToTableMenu(String restaurantName, String tableNumber) {
    if (_isScanned) return;
    setState(() => _isScanned = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã kết nối: $tableNumber - $restaurantName'),
        backgroundColor: const Color(0xFF00C853),
        duration: const Duration(seconds: 1),
      ),
    );

    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        context.pushReplacementNamed('menu', pathParameters: {
          'restaurantName': restaurantName,
          'tableId': tableNumber,
        });
      }
    });
  }

  // Xử lý dữ liệu mã QR quét được
  void _onDetect(BarcodeCapture capture) {
    if (_isScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.contains('|')) {
        final parts = rawValue.split('|');
        _navigateToTableMenu(parts[0], parts[1]);
        break;
      }
    }
  }

  // Chọn nhà hàng và bàn thủ công
  void _showManualTableSelectSheet() {
    final restaurants = ref
        .read(realRestaurantListProvider)
        .where((r) => r.status == 'APPROVED')
        .toList();
    final tables = ref.read(tableListProvider);

    if (restaurants.isEmpty || tables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Hiện chưa có nhà hàng hoặc bàn nào sẵn sàng trên hệ thống!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    String selectedRestaurant = restaurants.first.name;
    String selectedTable = tables.first.number;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.table_restaurant_rounded,
                        color: Color(0xFFFF5722), size: 26),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chọn Nhà hàng & Số bàn',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Chọn nhà hàng và số bàn hiện tại của bạn để mở thực đơn gọi món:',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6C7278)),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  value: selectedRestaurant,
                  decoration: InputDecoration(
                    labelText: 'Nhà hàng',
                    filled: true,
                    fillColor: const Color(0xFFF4F6FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: restaurants
                      .map((r) =>
                          DropdownMenuItem(value: r.name, child: Text(r.name)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setSheetState(() => selectedRestaurant = val);
                    }
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: selectedTable,
                  decoration: InputDecoration(
                    labelText: 'Số bàn đang ngồi',
                    filled: true,
                    fillColor: const Color(0xFFF4F6FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: tables
                      .map((t) => DropdownMenuItem(
                            value: t.number,
                            child: Text('${t.number} (${t.seats} chỗ ngồi)'),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setSheetState(() => selectedTable = val);
                    }
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5722),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      _navigateToTableMenu(selectedRestaurant, selectedTable);
                    },
                    icon: const Icon(Icons.restaurant_menu_rounded),
                    label: const Text(
                      'MỞ THỰC ĐƠN BÀN NÀY',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Quét mã QR tại bàn',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.amber : Colors.white,
            ),
            onPressed: () {
              _controller.toggleTorch();
              setState(() {
                _isTorchOn = !_isTorchOn;
              });
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: const Color(0xFFFF5722), width: 3),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Đưa mã QR trên bàn vào khung này',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: SafeArea(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1A1D26),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: _showManualTableSelectSheet,
                icon: const Icon(Icons.table_restaurant_rounded,
                    color: Color(0xFFFF5722)),
                label: const Text(
                  'Chọn Nhà hàng & Bàn thủ công',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
