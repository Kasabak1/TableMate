import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:str/core/database/app_database.dart';
import 'package:str/features/staff/providers/staff_provider.dart';

// Màn hình quét và xác thực mã QR tại bàn (TC11, TC31, TC38)
class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isScanned = false;
  bool _isTorchOn = false;
  DateTime? _lastRejectedAt;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Điều hướng tới thực đơn của bàn sau khi đã xác thực hợp lệ
  void _navigateToTableMenu(String restaurantName, String tableNumber) {
    if (_isScanned) return;
    setState(() => _isScanned = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Xác thực QR hợp lệ! Đã kết nối: $tableNumber - $restaurantName'),
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

  // Kiểm tra tính hợp lệ và chữ ký chủ nhà hàng của mã QR (TC31, TC38)
  ({bool isValid, String? restaurantName, String? tableNumber, String? error})
      _validateTableQrPayload(String rawValue) {
    final cleanRaw = rawValue.trim();
    if (!cleanRaw.contains('|')) {
      return (
        isValid: false,
        restaurantName: null,
        tableNumber: null,
        error: 'Định dạng mã QR không hợp lệ (thiếu thông tin Nhà hàng|Số bàn).'
      );
    }

    final parts = cleanRaw.split('|');
    if (parts.length < 2) {
      return (
        isValid: false,
        restaurantName: null,
        tableNumber: null,
        error: 'Mã QR không chứa đủ Tên nhà hàng và Số bàn.'
      );
    }

    final resName = parts[0].trim();
    final tableNum = parts[1].trim();
    if (resName.isEmpty || tableNum.isEmpty) {
      return (
        isValid: false,
        restaurantName: null,
        tableNumber: null,
        error: 'Tên nhà hàng hoặc Số bàn trong mã QR bị trống.'
      );
    }

    if (parts.length < 3 || !parts[2].trim().startsWith('SIG:')) {
      return (
        isValid: false,
        restaurantName: resName,
        tableNumber: tableNum,
        error:
            'Từ chối mã QR giả mạo! Mã "$cleanRaw" chỉ ghép theo quy ước tên|số, không có chữ ký số (SIG) do Chủ nhà hàng cấp.'
      );
    }

    final providedSig = parts[2].trim().substring(4).trim().toUpperCase();
    final expectedSig =
        QrSecurityHelper.computeSignature(resName, tableNum).toUpperCase();
    if (providedSig != expectedSig) {
      return (
        isValid: false,
        restaurantName: resName,
        tableNumber: tableNum,
        error:
            'Từ chối mã QR! Chữ ký xác thực (SIG:$providedSig) không khớp với khóa bảo mật của Chủ nhà hàng "$resName".'
      );
    }

    final allRestaurants = ref.read(realRestaurantListProvider);
    if (allRestaurants.isNotEmpty) {
      final resExists =
          allRestaurants.any((r) => isSameRestaurantName(r.name, resName));
      if (!resExists) {
        return (
          isValid: false,
          restaurantName: resName,
          tableNumber: tableNum,
          error: 'Nhà hàng "$resName" không tồn tại trên hệ thống!'
        );
      }
    }

    final allTables = ref.read(tableListProvider);
    final resTables = allTables
        .where((t) => isSameRestaurantName(t.restaurantName, resName))
        .toList();
    if (resTables.isNotEmpty) {
      final tableExists = resTables.any(
        (t) => t.number.trim().toLowerCase() == tableNum.toLowerCase(),
      );
      if (!tableExists) {
        return (
          isValid: false,
          restaurantName: resName,
          tableNumber: tableNum,
          error:
              'Từ chối mã QR! Bàn "$tableNum" chưa được Chủ nhà hàng "$resName" khởi tạo trên hệ thống.'
        );
      }
    }

    return (
      isValid: true,
      restaurantName: resName,
      tableNumber: tableNum,
      error: null,
    );
  }

  void _showQrRejectedDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.gpp_bad_rounded, color: Color(0xFFDC2626), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Từ chối Mã QR không hợp lệ',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          errorMessage,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF0F172A),
            height: 1.45,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  // Xử lý dữ liệu mã QR quét được từ Camera
  void _onDetect(BarcodeCapture capture) {
    if (_isScanned) return;
    if (_lastRejectedAt != null &&
        DateTime.now().difference(_lastRejectedAt!).inSeconds < 3) {
      return;
    }

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        final check = _validateTableQrPayload(rawValue);
        if (check.isValid) {
          _navigateToTableMenu(check.restaurantName!, check.tableNumber!);
        } else {
          _lastRejectedAt = DateTime.now();
          _showQrRejectedDialog(check.error!);
        }
        break;
      }
    }
  }

  // Hộp thoại kiểm tra mã QR bằng chuỗi (Hỗ trợ kiểm thử TC31 & TC38)
  void _showVerifyQrInputDialog({String initialValue = ''}) {
    final qrInputCtrl = TextEditingController(text: initialValue);
    String? validationError;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.verified_user_rounded,
                  color: Color(0xFFFF5722), size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Xác thực mã QR Bàn',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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
                  'Dán chuỗi mã QR do Chủ nhà hàng cấp (Tên quán|Số bàn|SIG:...) hoặc thử nhập mã giả (Tên quán|Số bàn) để kiểm tra bảo mật:',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qrInputCtrl,
                  maxLines: 2,
                  onChanged: (_) {
                    if (validationError != null) {
                      setDialogState(() => validationError = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'VD: Bếp Thái Koh Yam|Bàn 01|SIG:...',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: const Text(
                        'Thử mã giả (Thiếu SIG)',
                        style: TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
                      ),
                      backgroundColor: const Color(0xFFFEF2F2),
                      onPressed: () {
                        setDialogState(() {
                          qrInputCtrl.text = 'Bếp Thái Koh Yam|Bàn 01';
                          validationError = null;
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text(
                        'Thử mã chuẩn Chủ quán cấp',
                        style: TextStyle(fontSize: 11, color: Color(0xFF16A34A)),
                      ),
                      backgroundColor: const Color(0xFFDCFCE7),
                      onPressed: () {
                        final allRes = ref.read(realRestaurantListProvider);
                        final resName = allRes.isNotEmpty
                            ? allRes.first.name
                            : 'Bếp Thái Koh Yam';
                        setDialogState(() {
                          qrInputCtrl.text =
                              QrSecurityHelper.generateSignedTableQr(
                                  resName, 'Bàn 01');
                          validationError = null;
                        });
                      },
                    ),
                  ],
                ),
                if (validationError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.gpp_bad_rounded,
                            color: Color(0xFFDC2626), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            validationError!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Đóng'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Xác thực & Mở bàn'),
              onPressed: () {
                final check = _validateTableQrPayload(qrInputCtrl.text);
                if (!check.isValid) {
                  setDialogState(() => validationError = check.error);
                  return;
                }
                Navigator.pop(dialogCtx);
                _navigateToTableMenu(
                  check.restaurantName!,
                  check.tableNumber!,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Chọn nhà hàng và bàn đã được chủ quán phát hành kèm hiển thị mã QR chuẩn
  void _showManualTableSelectSheet() {
    final allRes = ref.read(realRestaurantListProvider);
    final approvedRes = allRes.where((r) => r.status == 'APPROVED').toList();
    final restaurants = approvedRes.isNotEmpty ? approvedRes : allRes;
    final allTables = ref.read(tableListProvider);

    if (restaurants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hiện chưa có nhà hàng nào trên hệ thống!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    List<RestaurantTable> resolveTablesForRes(String resName) {
      final matched = allTables
          .where((t) => isSameRestaurantName(t.restaurantName, resName))
          .toList();
      if (matched.isNotEmpty) return matched;
      return [
        for (int i = 1; i <= 8; i++)
          RestaurantTable(
            number: 'Bàn ${i.toString().padLeft(2, '0')}',
            seats: 4,
            state: TableState.empty,
            restaurantName: resName,
          ),
      ];
    }

    String selectedRestaurant = restaurants.first.name;
    List<RestaurantTable> filteredTables =
        resolveTablesForRes(selectedRestaurant);
    String? selectedTable =
        filteredTables.isNotEmpty ? filteredTables.first.number : 'Bàn 01';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          filteredTables = resolveTablesForRes(selectedRestaurant);
          if (selectedTable == null ||
              !filteredTables.any((t) => t.number == selectedTable)) {
            selectedTable =
                filteredTables.isNotEmpty ? filteredTables.first.number : null;
          }
          final signedQrData = QrSecurityHelper.generateSignedTableQr(
            selectedRestaurant,
            selectedTable ?? 'Bàn 01',
          );

          return Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
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
                          'Chọn Nhà hàng & Mã QR Bàn',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Chọn nhà hàng và số bàn đã được Chủ nhà hàng phát hành mã QR:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6C7278)),
                  ),
                  const SizedBox(height: 16),
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
                        .map((r) => DropdownMenuItem(
                            value: r.name, child: Text(r.name)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() {
                          selectedRestaurant = val;
                          final resTables = resolveTablesForRes(val);
                          selectedTable = resTables.isNotEmpty
                              ? resTables.first.number
                              : null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedTable,
                    decoration: InputDecoration(
                      labelText:
                          'Số bàn đang ngồi (${filteredTables.length} bàn)',
                      filled: true,
                      fillColor: const Color(0xFFF4F6FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: filteredTables
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
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F7FB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SizedBox(
                            width: 140,
                            height: 140,
                            child: QrImageView(
                              data: signedQrData,
                              version: QrVersions.auto,
                              size: 140.0,
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Mã QR định danh: $signedQrData',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1D26),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
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
                      onPressed: selectedTable == null
                          ? null
                          : () {
                              final verify =
                                  _validateTableQrPayload(signedQrData);
                              if (!verify.isValid) {
                                Navigator.pop(sheetCtx);
                                _showQrRejectedDialog(verify.error!);
                                return;
                              }
                              Navigator.pop(sheetCtx);
                              _navigateToTableMenu(
                                  verify.restaurantName!, verify.tableNumber!);
                            },
                      icon: const Icon(Icons.restaurant_menu_rounded),
                      label: const Text(
                        'XÁC THỰC QR & MỞ THỰC ĐƠN',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(realRestaurantListProvider);
    ref.watch(tableListProvider);

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
            tooltip: 'Nhập / Kiểm tra xác thực chuỗi QR',
            icon: const Icon(Icons.verified_user_outlined, color: Colors.white),
            onPressed: _showVerifyQrInputDialog,
          ),
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
                    'Đưa mã QR do Chủ nhà hàng cấp vào khung này',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _showVerifyQrInputDialog,
                      icon: const Icon(Icons.shield_outlined,
                          color: Colors.amber, size: 18),
                      label: const Text(
                        'Nhập / Kiểm tra xác thực mã QR (Chống mã giả)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1A1D26),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: _showManualTableSelectSheet,
                      icon: const Icon(Icons.table_restaurant_rounded,
                          color: Color(0xFFFF5722)),
                      label: const Text(
                        'Chọn Nhà hàng & Bàn thủ công',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
