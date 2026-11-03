import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:str/core/database/app_database.dart';
import 'package:str/features/home/models/user_profile_provider.dart';
import 'package:str/features/staff/providers/staff_provider.dart';

// Xem trước thực đơn nhà hàng
void showMenuPreviewBottomSheet({
  required BuildContext context,
  required WidgetRef ref,
  required RestaurantModel restaurant,
  required UserProfile profile,
  required VoidCallback onBookSuccess,
}) {
  final menuItems = ref
      .read(menuDbProvider)
      .where((m) => m.restaurantName == restaurant.name)
      .toList();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      height: MediaQuery.of(sheetContext).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thực đơn nhà hàng',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFFF5722),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        restaurant.name,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6FA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${menuItems.length} món',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: menuItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restaurant_menu_rounded,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        const Text(
                          'Nhà hàng đang cập nhật thực đơn',
                          style: TextStyle(
                              color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: menuItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = menuItems[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F7FB),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                image: item.imageUrl.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(item.imageUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: item.imageUrl.isEmpty
                                  ? Center(
                                      child: Text(item.icon,
                                          style: const TextStyle(fontSize: 32)))
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF1A1D26),
                                    ),
                                  ),
                                  if (item.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6C7278)),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    formatCurrency(item.price),
                                    style: const TextStyle(
                                      color: Color(0xFFFF5722),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!item.isAvailable)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Tạm hết',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
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
                    Navigator.pop(sheetContext);
                    showBookingBottomSheet(
                      context: context,
                      ref: ref,
                      restaurant: restaurant,
                      profile: profile,
                      onBookSuccess: onBookSuccess,
                    );
                  },
                  icon: const Icon(Icons.event_seat_rounded),
                  label: const Text(
                    'ĐẶT BÀN TẠI QUÁN NÀY',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// Bản đồ chỉ đường tới nhà hàng
void showMapBottomSheet({
  required BuildContext context,
  required RestaurantModel restaurant,
  required UserProfile profile,
  required LatLng? customerRealPos,
}) {
  final customerPos = customerRealPos ?? LatLng(profile.lat, profile.lng);
  final restaurantPos = LatLng(restaurant.lat, restaurant.lng);
  final centerPos = LatLng(
    (customerPos.latitude + restaurantPos.latitude) / 2,
    (customerPos.longitude + restaurantPos.longitude) / 2,
  );

  double preciseDistanceKm = calculateDistance(
    customerPos.latitude,
    customerPos.longitude,
    restaurantPos.latitude,
    restaurantPos.longitude,
  );

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chỉ đường đến nhà hàng',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        restaurant.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6C7278)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00897B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Cách bạn ${preciseDistanceKm.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      color: Color(0xFF00897B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: centerPos,
                initialZoom: 13.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.smartorder.app',
                ),
                PolylineLayer<Object>(
                  polylines: [
                    Polyline(
                      points: [customerPos, restaurantPos],
                      color: const Color(0xFF1E88E5),
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: customerPos,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.person_pin_circle_rounded,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                    Marker(
                      point: restaurantPos,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text(
                        'Đóng bản đồ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// Biểu mẫu đặt bàn giữ chỗ
void showBookingBottomSheet({
  required BuildContext context,
  required WidgetRef ref,
  required RestaurantModel restaurant,
  required UserProfile profile,
  required VoidCallback onBookSuccess,
}) {
  final currentUser = ref.read(currentUserProvider);
  final customerName = (currentUser != null && currentUser.name.isNotEmpty)
      ? currentUser.name
      : (profile.name.isNotEmpty ? profile.name : 'Khách hàng');
  final customerPhone = (currentUser != null && currentUser.phone.isNotEmpty)
      ? currentUser.phone
      : profile.phone;

  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = const TimeOfDay(hour: 19, minute: 0);
  int guests = 2;
  final noteController = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Text(
                  'Đặt bàn giữ chỗ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  restaurant.name,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900),
                ),
                Text(
                  restaurant.address,
                  style:
                      const TextStyle(color: Color(0xFF6C7278), fontSize: 13),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 30)),
                          );
                          if (picked != null) {
                            setModalState(() => selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F7FB),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded,
                                  color: Color(0xFFFF5722), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            setModalState(() => selectedTime = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F7FB),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_filled_rounded,
                                  color: Color(0xFFFF5722), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F7FB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Số lượng khách tham dự',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      Row(
                        children: [
                          IconButton(
                            onPressed: guests > 1
                                ? () => setModalState(() => guests--)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('$guests người',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w900)),
                          IconButton(
                            onPressed: () => setModalState(() => guests++),
                            icon: const Icon(Icons.add_circle_rounded,
                                color: Color(0xFFFF5722)),
                          )
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    hintText: 'Ghi chú (VD: Bàn gần cửa sổ, có trẻ em...)',
                    filled: true,
                    fillColor: const Color(0xFFF6F7FB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5722),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      ref.read(reservationProvider.notifier).addReservation(
                            customerName: customerName,
                            customerPhone: customerPhone,
                            restaurantName: restaurant.name,
                            address: restaurant.address,
                            date:
                                '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                            time:
                                '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                            guests: guests,
                            note: noteController.text.trim(),
                          );
                      Navigator.pop(sheetContext);
                      onBookSuccess();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã gửi yêu cầu đặt bàn!'),
                          backgroundColor: Color(0xFF00C853),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: const Text(
                      'XÁC NHẬN ĐẶT BÀN',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// Danh sách đánh giá của nhà hàng
void showReviewsBottomSheet(BuildContext context, WidgetRef ref,
    RestaurantModel restaurant, String myName) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Đánh giá & Nhận xét',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5722),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => showWriteReviewDialog(
                        context, ref, restaurant.name, myName),
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Viết đánh giá',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final reviews = ref
                      .watch(reviewsProvider)
                      .where((r) => r.restaurantName == restaurant.name)
                      .toList();
                  if (reviews.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.rate_review_outlined,
                              size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text(
                            'Chưa có đánh giá nào.\nHãy là người đầu tiên nhận xét!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: reviews.length,
                    itemBuilder: (context, index) {
                      final rev = reviews[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F6FA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  radius: 16,
                                  child: Text(
                                    rev.userName.isNotEmpty
                                        ? rev.userName[0].toUpperCase()
                                        : 'K',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    rev.userName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                ),
                                Row(
                                  children: List.generate(
                                    5,
                                    (i) => Icon(
                                      Icons.star_rounded,
                                      size: 16,
                                      color: i < rev.rating
                                          ? Colors.amber
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (rev.comment.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(rev.comment,
                                  style: TextStyle(
                                      color: Colors.grey.shade800,
                                      height: 1.4)),
                            ]
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

// Hộp thoại gửi đánh giá mới
void showWriteReviewDialog(BuildContext context, WidgetRef ref,
    String restaurantName, String myName) {
  int selectedStars = 5;
  final commentCtrl = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text(
            'Đánh giá trải nghiệm',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                restaurantName,
                style: const TextStyle(
                    color: Color(0xFFFF5722), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      Icons.star_rounded,
                      size: 36,
                      color: index < selectedStars
                          ? Colors.amber
                          : Colors.grey.shade300,
                    ),
                    onPressed: () =>
                        setDialogState(() => selectedStars = index + 1),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Nhà hàng phục vụ thế nào? Đồ ăn có ngon không?',
                  filled: true,
                  fillColor: const Color(0xFFF4F6FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy',
                  style: TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.bold)),
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
                    await ref.read(reviewsProvider.notifier).addReview(
                          restaurantName,
                          myName,
                          selectedStars,
                          commentCtrl.text.trim(),
                        );

                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cảm ơn bạn đã đánh giá!'),
                        backgroundColor: Color(0xFF00C853),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Không thể lưu đánh giá!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('GỬI ĐÁNH GIÁ',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    ),
  );
}
