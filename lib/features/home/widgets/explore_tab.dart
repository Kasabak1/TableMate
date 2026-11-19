import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:str/core/database/app_database.dart';
import 'package:str/features/chat/chat_screen.dart';
import 'package:str/features/home/models/user_profile_provider.dart';
import 'package:str/features/home/widgets/restaurant_sheets.dart';

// Tab khám phá và tìm kiếm nhà hàng
class ExploreTab extends ConsumerStatefulWidget {
  final String displayName;
  final UserProfile profile;
  final LatLng? customerRealPos;
  final String currentAddress;
  final VoidCallback onRefreshLocation;
  final VoidCallback onBookSuccess;

  const ExploreTab({
    super.key,
    required this.displayName,
    required this.profile,
    required this.customerRealPos,
    required this.currentAddress,
    required this.onRefreshLocation,
    required this.onBookSuccess,
  });

  @override
  ConsumerState<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends ConsumerState<ExploreTab> {
  String _searchQuery = '';
  String _selectedCategory = 'Tất cả';
  final List<String> _categories = [
    'Tất cả',
    'Lẩu & Thái',
    'Món Âu',
    'Đặc sản Việt',
    'Buffet Lẩu'
  ];

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Lẩu & Thái':
        return Icons.soup_kitchen_rounded;
      case 'Món Âu':
        return Icons.dinner_dining_rounded;
      case 'Đặc sản Việt':
        return Icons.ramen_dining_rounded;
      case 'Buffet Lẩu':
        return Icons.local_fire_department_rounded;
      default:
        return Icons.grid_view_rounded;
    }
  }
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restaurants = ref.watch(realRestaurantListProvider);
    final currentUser = ref.watch(currentUserProvider);
    final rawPhone = (currentUser != null && currentUser.phone.trim().isNotEmpty)
        ? currentUser.phone.trim()
        : widget.profile.phone.trim();
    final myPhone = rawPhone.isNotEmpty ? rawPhone : 'khach';

    final filteredList = restaurants.where((r) {
      if (r.status != 'APPROVED') return false;

      final matchesSearch =
          r.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              r.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              r.address.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == 'Tất cả' || r.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          // Thông tin chào mừng và vị trí
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Xin chào,',
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF475569))),
                    const SizedBox(height: 2),
                    Text(
                      widget.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: widget.onRefreshLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.my_location_rounded,
                                  color: Color(0xFF0D9488), size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Vị trí của bạn',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF0D9488),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.currentAddress,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Thanh tìm kiếm nhà hàng
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Tìm tên quán, món ăn, địa chỉ...',
                hintStyle:
                    const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Color(0xFFFF5722)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        tooltip: 'Xóa từ khóa',
                        icon: const Icon(Icons.clear_rounded,
                            color: Color(0xFF475569), size: 20),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide:
                      const BorderSide(color: Color(0xFFFF5722), width: 1.6),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          // Bộ lọc danh mục ẩm thực
          const SizedBox(height: 18),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                return Material(
                  color: isSelected ? const Color(0xFFFF5722) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF5722)
                              : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: const Color(0xFFFF5722).withOpacity(0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _categoryIcon(cat),
                            size: 16,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFFFF5722),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 22),

          // Danh sách nhà hàng
          if (filteredList.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront_outlined,
                      size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'Không tìm thấy nhà hàng phù hợp',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1D26),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Hãy thử đổi từ khóa tìm kiếm hoặc chọn danh mục khác.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF9A9FA5)),
                  ),
                  if (_searchQuery.isNotEmpty ||
                      _selectedCategory != 'Tất cả') ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF5722),
                        side: const BorderSide(color: Color(0xFFFF5722)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _searchQuery = '';
                          _selectedCategory = 'Tất cả';
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Xóa bộ lọc',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ]
                ],
              ),
            )
          else
            ...filteredList.map((restaurant) {
              double userLat =
                  widget.customerRealPos?.latitude ?? widget.profile.lat;
              double userLng =
                  widget.customerRealPos?.longitude ?? widget.profile.lng;
              double distanceKm = calculateDistance(
                  userLat, userLng, restaurant.lat, restaurant.lng);

              return _buildRestaurantCard(
                context: context,
                restaurant: restaurant,
                distanceKm: distanceKm,
                myPhone: myPhone,
              );
            }),
        ],
      ),
    );
  }

  // Thẻ hiển thị thông tin từng nhà hàng
  Widget _buildRestaurantCard({
    required BuildContext context,
    required RestaurantModel restaurant,
    required double distanceKm,
    required String myPhone,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Image.network(
                  restaurant.imageUrl,
                  height: 175,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 175,
                      color: const Color(0xFFF1F5F9),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFFFF5722),
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    height: 175,
                    color: const Color(0xFFFFF3EE),
                    child: const Center(
                      child: Icon(Icons.restaurant,
                          size: 50, color: Color(0xFFFF5722)),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.55)
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      restaurant.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: GestureDetector(
                    onTap: () => showReviewsBottomSheet(
                        context, ref, restaurant, widget.displayName),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Consumer(builder: (context, ref, child) {
                            final resReviews = ref
                                .watch(reviewsProvider)
                                .where(
                                    (r) => r.restaurantName == restaurant.name)
                                .toList();
                            final avgRating = resReviews.isEmpty
                                ? restaurant.rating
                                : (resReviews
                                        .map((r) => r.rating)
                                        .reduce((a, b) => a + b) /
                                    resReviews.length);
                            return Text(
                              '${avgRating.toStringAsFixed(1)} (${resReviews.length})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 13),
                            );
                          })
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            color: Colors.white, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          restaurant.openTime,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  right: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00897B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_car_rounded,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${distanceKm.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1D26),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 16, color: Color(0xFFFF5722)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          restaurant.address,
                          style: const TextStyle(
                              color: Color(0xFF6C7278), fontSize: 13),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Tooltip(
                        message: 'Chat với nhà hàng',
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5722).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.chat_bubble_rounded,
                                color: Color(0xFFFF5722), size: 20),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatRoomScreen(
                                    roomId: '${myPhone}_${restaurant.name}',
                                    restaurantName: restaurant.name,
                                    customerName: widget.displayName,
                                    currentRole: 'CUSTOMER',
                                    currentSenderName: widget.displayName,
                                    title: 'Chat với ${restaurant.name}',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Xem bản đồ chỉ đường',
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.map_outlined,
                                color: Color(0xFF1E88E5), size: 20),
                            onPressed: () => showMapBottomSheet(
                              context: context,
                              restaurant: restaurant,
                              profile: widget.profile,
                              customerRealPos: widget.customerRealPos,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Xem thực đơn',
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.restaurant_menu_rounded,
                                color: Color(0xFF2E7D32), size: 20),
                            onPressed: () => showMenuPreviewBottomSheet(
                              context: context,
                              ref: ref,
                              restaurant: restaurant,
                              profile: widget.profile,
                              onBookSuccess: widget.onBookSuccess,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5722),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => showBookingBottomSheet(
                            context: context,
                            ref: ref,
                            restaurant: restaurant,
                            profile: widget.profile,
                            onBookSuccess: widget.onBookSuccess,
                          ),
                          icon: const Icon(Icons.event_seat_rounded, size: 18),
                          label: const Text('Đặt bàn',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
