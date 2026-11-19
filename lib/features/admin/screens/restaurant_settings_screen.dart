import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:str/core/database/app_database.dart';

// Màn hình cài đặt Hồ sơ Nhà hàng & Tài khoản VietQR
class RestaurantSettingsScreen extends ConsumerStatefulWidget {
  const RestaurantSettingsScreen({super.key});

  @override
  ConsumerState<RestaurantSettingsScreen> createState() =>
      _RestaurantSettingsScreenState();
}

class _RestaurantSettingsScreenState
    extends ConsumerState<RestaurantSettingsScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _timeController = TextEditingController(text: '08:00 - 22:00');
  final _imageUrlController = TextEditingController();

  final _bankAccountNoController = TextEditingController();
  final _bankAccountNameController = TextEditingController();
  String _selectedBankId = 'MB';

  static const List<Map<String, String>> _vietnamBanks = [
    {'id': 'MB', 'name': 'MB Bank - Ngân hàng Quân Đội'},
    {'id': 'VCB', 'name': 'Vietcombank - Ngoại thương VN'},
    {'id': 'TCB', 'name': 'Techcombank - Kỹ thương VN'},
    {'id': 'ICB', 'name': 'VietinBank - Công thương VN'},
    {'id': 'BIDV', 'name': 'BIDV - Đầu tư & Phát triển VN'},
    {'id': 'ACB', 'name': 'ACB - Ngân hàng Á Châu'},
    {'id': 'TPB', 'name': 'TPBank - Ngân hàng Tiên Phong'},
    {'id': 'VPB', 'name': 'VPBank - Việt Nam Thịnh Vượng'},
    {'id': 'VBA', 'name': 'Agribank - NN & PT Nông thôn'},
    {'id': 'STB', 'name': 'Sacombank - Sài Gòn Thương Tín'},
    {'id': 'MSB', 'name': 'MSB - Hàng Hải Việt Nam'},
    {'id': 'OCB', 'name': 'OCB - Ngân hàng Phương Đông'},
  ];

  String _selectedCategory = 'Lẩu & Thái';
  final List<String> _categories = [
    'Lẩu & Thái',
    'Món Âu',
    'Đặc sản Việt',
    'Buffet Lẩu'
  ];

  LatLng _selectedLocation = const LatLng(21.028511, 105.804817);
  final MapController _mapController = MapController();
  bool _isInit = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _timeController.dispose();
    _imageUrlController.dispose();
    _bankAccountNoController.dispose();
    _bankAccountNameController.dispose();
    super.dispose();
  }

  String _getBankDisplayName(String bankId) {
    final found = _vietnamBanks.where((b) => b['id'] == bankId).firstOrNull;
    return found?['name'] ?? bankId;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final allRes = ref.watch(realRestaurantListProvider);
    ref.watch(restaurantBankProvider);
    final myRes =
        allRes.where((r) => r.ownerPhone == currentUser?.phone).firstOrNull;

    if (!_isInit) {
      if (myRes != null) {
        _nameController.text = myRes.name;
        _addressController.text = myRes.address;
        _timeController.text = myRes.openTime;
        _imageUrlController.text = myRes.imageUrl;
        if (_categories.contains(myRes.category)) {
          _selectedCategory = myRes.category;
        }
        _selectedLocation = LatLng(myRes.lat, myRes.lng);

        final savedBank = ref
            .read(restaurantBankProvider.notifier)
            .getBankForRestaurant(
              restaurantName: myRes.name,
              ownerPhone: currentUser?.phone,
              restaurants: allRes,
            );
        if (savedBank != null) {
          if (_vietnamBanks.any((b) => b['id'] == savedBank.bankId)) {
            _selectedBankId = savedBank.bankId;
          }
          _bankAccountNoController.text = savedBank.accountNo;
          _bankAccountNameController.text = savedBank.accountName;
        }
        _isInit = true;
      } else if (currentUser != null) {
        if (currentUser.restaurantName.trim().isNotEmpty) {
          _nameController.text = currentUser.restaurantName.trim();
        }
        final savedBank = ref
            .read(restaurantBankProvider.notifier)
            .getBankForRestaurant(
              restaurantName: currentUser.restaurantName,
              ownerPhone: currentUser.phone,
              restaurants: allRes,
            );
        if (savedBank != null && _bankAccountNoController.text.isEmpty) {
          if (_vietnamBanks.any((b) => b['id'] == savedBank.bankId)) {
            _selectedBankId = savedBank.bankId;
          }
          _bankAccountNoController.text = savedBank.accountNo;
          _bankAccountNameController.text = savedBank.accountName;
        }
        _isInit = true;
      }
    }

    final previewAccountNo = _bankAccountNoController.text.trim();
    final previewAccountName =
        _bankAccountNameController.text.trim().toUpperCase();
    final previewBankInfo = RestaurantBankInfo(
      bankId: _selectedBankId,
      bankName: _getBankDisplayName(_selectedBankId),
      accountNo: previewAccountNo,
      accountName: previewAccountName,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          'Hồ sơ & Tài khoản Nhà hàng',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D26),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (myRes != null)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: myRes.status == 'APPROVED'
                      ? const Color(0xFFE8F5E9)
                      : (myRes.status == 'REJECTED'
                          ? const Color(0xFFFFEBEE)
                          : const Color(0xFFFFF8E1)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      myRes.status == 'APPROVED'
                          ? Icons.verified_rounded
                          : (myRes.status == 'REJECTED'
                              ? Icons.cancel_rounded
                              : Icons.hourglass_top_rounded),
                      color: myRes.status == 'APPROVED'
                          ? const Color(0xFF2E7D32)
                          : (myRes.status == 'REJECTED'
                              ? const Color(0xFFC62828)
                              : const Color(0xFFF57C00)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        myRes.status == 'APPROVED'
                            ? 'Cửa hàng đã được phê duyệt hiển thị trên trang chủ'
                            : (myRes.status == 'REJECTED'
                                ? 'Hồ sơ bị từ chối • Hãy cập nhật thông tin và gửi duyệt lại'
                                : 'Hồ sơ cửa hàng đang chờ Super Admin phê duyệt'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: myRes.status == 'APPROVED'
                              ? const Color(0xFF2E7D32)
                              : (myRes.status == 'REJECTED'
                                  ? const Color(0xFFC62828)
                                  : const Color(0xFFF57C00)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Thông tin cơ bản nhà hàng
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.storefront_rounded,
                          color: Color(0xFFFF5722), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'THÔNG TIN NHÀ HÀNG TRÊN DATABASE',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: Color(0xFF1A1D26),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_imageUrlController.text.trim().isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        _imageUrlController.text.trim(),
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 100,
                          color: Colors.orange.shade50,
                          child: const Center(
                              child: Icon(Icons.broken_image_outlined,
                                  color: Colors.orange)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Tên nhà hàng / cửa hàng',
                      prefixIcon: const Icon(Icons.restaurant_rounded,
                          color: Color(0xFFFF5722)),
                      filled: true,
                      fillColor: const Color(0xFFF6F7FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Chuyên mục ẩm thực',
                      prefixIcon: const Icon(Icons.category_rounded,
                          color: Color(0xFFFF5722)),
                      filled: true,
                      fillColor: const Color(0xFFF6F7FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _timeController,
                    decoration: InputDecoration(
                      labelText: 'Giờ mở cửa (VD: 08:00 - 22:00)',
                      prefixIcon: const Icon(Icons.access_time_filled_rounded,
                          color: Color(0xFFFF5722)),
                      filled: true,
                      fillColor: const Color(0xFFF6F7FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _imageUrlController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Link ảnh bìa nhà hàng (URL)',
                      hintText: 'https://images.unsplash.com/...',
                      prefixIcon: const Icon(Icons.image_outlined,
                          color: Color(0xFFFF5722)),
                      filled: true,
                      fillColor: const Color(0xFFF6F7FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Cấu hình tài khoản ngân hàng VietQR
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.green.shade200, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.qr_code_scanner_rounded,
                            color: Colors.green.shade700, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TÀI KHOẢN NGÂN HÀNG NHẬN TIỀN (VIETQR)',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: Color(0xFF1A1D26),
                              ),
                            ),
                            Text(
                              'Tự động tạo mã QR chuyển khoản đúng số tiền trên hóa đơn cho khách quét',
                              style: TextStyle(
                                  fontSize: 11.5, color: Color(0xFF6C7278)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedBankId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Ngân hàng thụ hưởng',
                      prefixIcon: Icon(Icons.account_balance_rounded,
                          color: Colors.green.shade700),
                      filled: true,
                      fillColor: const Color(0xFFF6F7FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _vietnamBanks
                        .map((b) => DropdownMenuItem<String>(
                              value: b['id'],
                              child: Text(
                                b['name']!,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedBankId = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _bankAccountNoController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Số tài khoản ngân hàng của quán',
                      hintText: 'Để trống nếu quán chỉ thu tiền mặt',
                      prefixIcon: Icon(Icons.credit_card_rounded,
                          color: Colors.green.shade700),
                      suffixIcon: _bankAccountNoController.text.isNotEmpty
                          ? IconButton(
                              tooltip: 'Xóa tài khoản ngân hàng',
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                setState(() {
                                  _bankAccountNoController.clear();
                                  _bankAccountNameController.clear();
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF6F7FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _bankAccountNameController,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Tên chủ tài khoản (IN HOA KHÔNG DẤU)',
                      hintText: 'VD: NGUYEN VAN A',
                      prefixIcon: Icon(Icons.person_outline_rounded,
                          color: Colors.green.shade700),
                      filled: true,
                      fillColor: const Color(0xFFF6F7FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (previewBankInfo.isConfigured) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4FBF7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.verified_rounded,
                                  color: Colors.green.shade700, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Xem trước Mã QR Thanh toán của Quán',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 170,
                              height: 170,
                              child: Image.network(
                                previewBankInfo.buildVietQrUrl(
                                  amount: 0,
                                  addInfo:
                                      'Thanh toan ${_nameController.text.trim()}',
                                ),
                                width: 170,
                                height: 170,
                                fit: BoxFit.contain,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return QrImageView(
                                    data:
                                        'VIETQR|$_selectedBankId|$previewAccountNo|$previewAccountName',
                                    version: QrVersions.auto,
                                    size: 170,
                                    backgroundColor: Colors.white,
                                  );
                                },
                                errorBuilder: (_, __, ___) => QrImageView(
                                  data:
                                      'VIETQR|$_selectedBankId|$previewAccountNo|$previewAccountName',
                                  version: QrVersions.auto,
                                  size: 170,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_getBankDisplayName(_selectedBankId)}\nSTK: $previewAccountNo ${previewAccountName.isNotEmpty ? "• $previewAccountName" : ""}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1D26),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Vị trí địa lý & bản đồ
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.map_rounded,
                          color: Color(0xFF1E88E5), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'VỊ TRÍ & BẢN ĐỒ CHỈ ĐƯỜNG',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: Color(0xFF1A1D26),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: 'Địa chỉ chi tiết',
                      prefixIcon: const Icon(Icons.place_rounded,
                          color: Color(0xFF1E88E5)),
                      filled: true,
                      fillColor: const Color(0xFFF6F7FB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chạm vào bản đồ để ghim tọa độ chính xác của quán:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF6C7278)),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 240,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _selectedLocation,
                          initialZoom: 15.0,
                          onTap: (tapPosition, latLng) {
                            setState(() => _selectedLocation = latLng);
                            _mapController.move(latLng, 15.0);
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.smartorder.app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _selectedLocation,
                                width: 50,
                                height: 50,
                                alignment: Alignment.topCenter,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Color(0xFFFF5722),
                                  size: 46,
                                ),
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tọa độ đã ghim: ${_selectedLocation.latitude.toStringAsFixed(5)}, ${_selectedLocation.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF00897B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isSaving
                    ? null
                    : () async {
                        if (currentUser == null) return;
                        final newName = _nameController.text.trim();
                        final newAddress = _addressController.text.trim();
                        if (newName.isEmpty || newAddress.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Vui lòng nhập Tên nhà hàng và Địa chỉ!'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setState(() => _isSaving = true);

                        final bankInfo = RestaurantBankInfo(
                          bankId: _selectedBankId,
                          bankName: _getBankDisplayName(_selectedBankId),
                          accountNo: _bankAccountNoController.text.trim(),
                          accountName: _bankAccountNameController.text
                              .trim()
                              .toUpperCase(),
                        );

                        await ref
                            .read(restaurantBankProvider.notifier)
                            .saveBankForRestaurant(
                              restaurantName: newName,
                              ownerPhone: currentUser.phone,
                              bankInfo: bankInfo,
                            );

                        final success = await ref
                            .read(realRestaurantListProvider.notifier)
                            .submitStoreProfile(
                              currentUser.phone,
                              newName,
                              newAddress,
                              _selectedCategory,
                              _timeController.text.trim(),
                              _selectedLocation.latitude,
                              _selectedLocation.longitude,
                              imageUrl: _imageUrlController.text.trim(),
                              bankId: bankInfo.bankId,
                              bankName: bankInfo.bankName,
                              bankAccountNo: bankInfo.accountNo,
                              bankAccountName: bankInfo.accountName,
                            );

                        if (mounted) {
                          setState(() => _isSaving = false);
                        }

                        if (success && context.mounted) {
                          ref.read(currentUserProvider.notifier).state =
                              currentUser.copyWith(restaurantName: newName);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Đã lưu Hồ sơ & Tài khoản Ngân hàng VietQR của nhà hàng!'),
                              backgroundColor: Color(0xFF00C853),
                            ),
                          );
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Đã lưu Tài khoản Ngân hàng cục bộ, nhưng lỗi kết nối Supabase!'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _isSaving
                      ? 'ĐANG LƯU...'
                      : 'LƯU HỒ SƠ & TÀI KHOẢN NGÂN HÀNG',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
