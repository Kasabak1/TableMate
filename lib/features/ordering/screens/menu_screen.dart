import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:str/core/database/app_database.dart';
import 'package:str/features/home/screens/main_dashboard_screen.dart'
    show formatCurrency;
import 'package:str/features/ordering/providers/cart_provider.dart';
import 'package:str/features/ordering/providers/gemini_provider.dart';
import 'package:str/features/staff/providers/staff_provider.dart';

// Màn hình thực đơn và gọi món tại bàn
class MenuScreen extends ConsumerStatefulWidget {
  final String restaurantName;
  final String tableId;

  const MenuScreen({
    super.key,
    required this.restaurantName,
    required this.tableId,
  });

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'Tất cả';
  bool _isSendingOrder = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index == 1) {
        ref.read(kitchenOrdersProvider.notifier).fetchOrders(force: true);
        ref.read(tableListProvider.notifier).fetchTables(force: true);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(kitchenOrdersProvider.notifier).fetchOrders(force: true);
      ref.read(tableListProvider.notifier).fetchTables(force: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Hộp thoại AI tư vấn chọn món tại bàn
  void _showAiRecommendationSheet(List<MenuItemModel> menuItems) {
    final queryCtrl = TextEditingController();
    final List<Map<String, dynamic>> quickPrompts = [
      {
        'label': 'Món đặc trưng nhất của quán',
        'icon': Icons.local_fire_department_rounded,
      },
      {
        'label': 'Đi 2 người nên gọi món gì?',
        'icon': Icons.favorite_rounded,
      },
      {
        'label': 'Món ngon không cay cho trẻ em',
        'icon': Icons.child_care_rounded,
      },
      {
        'label': 'Combo ăn no giá tiết kiệm',
        'icon': Icons.savings_rounded,
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final aiAnswer = ref.watch(geminiAssistantProvider);
          final isThinking = aiAnswer.contains('Đang suy nghĩ');

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 14,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF6A1B9A), Color(0xFFAB47BC)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.auto_awesome,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI Tư vấn Thực đơn tại bàn',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            widget.restaurantName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.purple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: quickPrompts.map((item) {
                    final prompt = item['label'] as String;
                    final iconData = item['icon'] as IconData;
                    return ActionChip(
                      avatar: Icon(
                        iconData,
                        size: 16,
                        color: const Color(0xFF6A1B9A),
                      ),
                      backgroundColor: Colors.purple.shade50,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      label: Text(
                        prompt,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6A1B9A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        ref
                            .read(geminiAssistantProvider.notifier)
                            .askForRecommendation(
                                prompt, menuItems, widget.restaurantName);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F7FB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: isThinking
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.purple, strokeWidth: 2.5),
                            ),
                            SizedBox(width: 12),
                            Text('AI đang xem thực đơn quán cho bạn...',
                                style: TextStyle(
                                    color: Colors.purple,
                                    fontWeight: FontWeight.w600)),
                          ],
                        )
                      : Text(
                          aiAnswer.isEmpty
                              ? 'Hãy chọn gợi ý phía trên hoặc nhập sở thích của bạn để AI chọn món phù hợp nhất trong thực đơn quán.'
                              : aiAnswer,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: queryCtrl,
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            ref
                                .read(geminiAssistantProvider.notifier)
                                .askForRecommendation(val.trim(), menuItems,
                                    widget.restaurantName);
                            queryCtrl.clear();
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Nhập yêu cầu (VD: Món nhậu lai rai...)',
                          filled: true,
                          fillColor: const Color(0xFFF4F6FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(12),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 20),
                      onPressed: () {
                        if (queryCtrl.text.trim().isNotEmpty) {
                          ref
                              .read(geminiAssistantProvider.notifier)
                              .askForRecommendation(queryCtrl.text.trim(),
                                  menuItems, widget.restaurantName);
                          queryCtrl.clear();
                        }
                      },
                    ),
                  ],
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
    ref.watch(realRestaurantListProvider);
    ref.watch(restaurantBankProvider);

    final allAvailableMenu =
        ref.watch(menuDbProvider).where((m) => m.isAvailable).toList();
    final matchedMenu = allAvailableMenu
        .where((m) => isSameRestaurantName(m.restaurantName, widget.restaurantName))
        .toList();
    final menuItems = matchedMenu.isNotEmpty
        ? matchedMenu
        : allAvailableMenu.where((m) => m.restaurantName.isEmpty).toList();

    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    final tableOrders = ref
        .watch(kitchenOrdersProvider)
        .where((o) =>
            o.tableNumber.trim().toLowerCase() ==
                widget.tableId.trim().toLowerCase() &&
            isSameRestaurantName(o.restaurantName, widget.restaurantName))
        .toList();
    final int totalOrderedDishes = tableOrders.fold(
        0,
        (sum, o) =>
            sum + o.items.fold(0, (itemSum, item) => itemSum + item.quantity));

    final categories = [
      'Tất cả',
      ...{for (final m in menuItems) m.category}
    ];
    final filteredMenu = _selectedCategory == 'Tất cả'
        ? menuItems
        : menuItems.where((m) => m.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D26),
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              widget.restaurantName,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            Text(
              'Đang ngồi tại: ${widget.tableId}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFFF5722),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới trạng thái món',
            onPressed: () {
              ref.read(kitchenOrdersProvider.notifier).fetchOrders(force: true);
              ref.read(tableListProvider.notifier).fetchTables(force: true);
            },
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
          IconButton(
            tooltip: 'AI tư vấn chọn món',
            onPressed: () => _showAiRecommendationSheet(menuItems),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.purple, size: 20),
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFF5722),
          unselectedLabelColor: const Color(0xFF9A9FA5),
          indicatorColor: const Color(0xFFFF5722),
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
              text: 'Thực đơn (${menuItems.length})',
            ),
            Tab(
              icon: Badge(
                isLabelVisible: totalOrderedDishes > 0,
                label: Text('$totalOrderedDishes'),
                backgroundColor: const Color(0xFF00C853),
                child: const Icon(Icons.soup_kitchen_outlined, size: 18),
              ),
              text: 'Món đã gọi ($totalOrderedDishes)',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMenuCatalogTab(
              menuItems, filteredMenu, categories, cartItems, cartNotifier),
          _buildOrderTrackingTab(tableOrders),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: cartItems.isEmpty
          ? null
          : Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D26),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A1D26).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shopping_bag_outlined,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${cartNotifier.totalItems} món đã chọn',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              formatCurrency(cartNotifier.totalPrice),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5722),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: _isSendingOrder
                          ? null
                          : () async {
                              setState(() => _isSendingOrder = true);
                              final orderItems = cartItems
                                  .map((c) => OrderItem(
                                        id: '${DateTime.now().microsecondsSinceEpoch}_${c.name}',
                                        dishName: c.name,
                                        quantity: c.quantity,
                                        price: c.price,
                                        note: 'Khách tự đặt qua QR',
                                        status: DishStatus.pending,
                                      ))
                                  .toList();

                              final orderOk = await ref
                                  .read(kitchenOrdersProvider.notifier)
                                  .addOrderFromWaiter(
                                    widget.tableId,
                                    orderItems,
                                    restaurantName: widget.restaurantName,
                                  );
                              final tableOk = await ref
                                  .read(tableListProvider.notifier)
                                  .setTableState(
                                    widget.tableId,
                                    TableState.occupied,
                                    restaurantName: widget.restaurantName,
                                  );

                              if (!mounted) return;
                              setState(() => _isSendingOrder = false);
                              cartNotifier.clearCart();
                              _tabController.animateTo(1);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    (orderOk && tableOk)
                                        ? 'Đã gửi đơn của ${widget.tableId} (trạng thái: Chờ bếp) và chuyển bàn sang Đang phục vụ!'
                                        : 'Đã ghi nhận đơn của ${widget.tableId} tại máy (đang chờ đồng bộ mạng)!',
                                  ),
                                  backgroundColor: (orderOk && tableOk)
                                      ? const Color(0xFF00C853)
                                      : Colors.orange.shade800,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                      child: _isSendingOrder
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'GỬI ĐƠN',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                    )
                  ],
                ),
              ),
            ),
    );
  }

  // Tab danh mục thực đơn
  Widget _buildMenuCatalogTab(
    List<MenuItemModel> allItems,
    List<MenuItemModel> filteredMenu,
    List<String> categories,
    List<CartItem> cartItems,
    CartNotifier cartNotifier,
  ) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _showAiRecommendationSheet(allItems),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.amber, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Chưa biết ăn gì? Bấm để AI gợi ý món ngon của quán!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
        if (categories.length > 1)
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                  selectedColor: const Color(0xFFFF5722),
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF6C7278),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: filteredMenu.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_menu_rounded,
                          size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text(
                        'Nhà hàng hiện chưa cập nhật món!',
                        style: TextStyle(
                          color: Color(0xFF9A9FA5),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, top: 12, bottom: 120),
                  itemCount: filteredMenu.length,
                  itemBuilder: (context, index) {
                    final dish = filteredMenu[index];
                    final cartItem =
                        cartItems.where((c) => c.name == dish.name).firstOrNull;
                    final currentQty = cartItem?.quantity ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F6FA),
                              borderRadius: BorderRadius.circular(16),
                              image: dish.imageUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(dish.imageUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: dish.imageUrl.isEmpty
                                ? Center(
                                    child: Text(dish.icon,
                                        style: const TextStyle(fontSize: 40)))
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4F6FA),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    dish.category,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF6C7278),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dish.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1A1D26),
                                  ),
                                ),
                                if (dish.description.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    dish.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6C7278),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      formatCurrency(dish.price),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFFFF5722),
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (currentQty == 0)
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFFF5722),
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(84, 34),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          elevation: 0,
                                        ),
                                        onPressed: () => cartNotifier.addItem(
                                            dish.name, dish.price),
                                        child: const Text('+ Thêm',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12)),
                                      )
                                    else
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF4F6FA),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            IconButton(
                                              constraints:
                                                  const BoxConstraints(),
                                              padding: const EdgeInsets.all(6),
                                              icon: const Icon(
                                                  Icons.remove_rounded,
                                                  size: 18),
                                              onPressed: () => cartNotifier
                                                  .removeItem(dish.name),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8),
                                              child: Text(
                                                '$currentQty',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              constraints:
                                                  const BoxConstraints(),
                                              padding: const EdgeInsets.all(6),
                                              icon: const Icon(
                                                Icons.add_rounded,
                                                size: 18,
                                                color: Color(0xFFFF5722),
                                              ),
                                              onPressed: () => cartNotifier
                                                  .addItem(
                                                      dish.name, dish.price),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
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

  // Tab theo dõi tiến độ món đã gọi và gọi nhân viên thanh toán
  Widget _buildOrderTrackingTab(List<KitchenOrder> tableOrders) {
    final currentTable = ref
        .watch(tableListProvider)
        .where((t) =>
            t.number.trim().toLowerCase() ==
                widget.tableId.trim().toLowerCase() &&
            isSameRestaurantName(t.restaurantName, widget.restaurantName))
        .firstOrNull;
    final bool isWaitingPayment =
        currentTable?.state == TableState.needPayment;

    int totalTableBill = 0;
    for (final o in tableOrders) {
      for (final i in o.items) {
        totalTableBill += i.price * i.quantity;
      }
    }

    if (tableOrders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 80, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const Text(
                'Bàn của bạn chưa gửi đơn gọi món nào',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1D26),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hãy chọn món ở tab Thực đơn và nhấn "GỬI ĐƠN" để theo dõi tiến độ chế biến.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9A9FA5), fontSize: 13),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF5722),
                  side: const BorderSide(color: Color(0xFFFF5722)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _tabController.animateTo(0),
                icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
                label: const Text('Quay lại Thực đơn',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (isWaitingPayment)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: const Row(
              children: [
                Icon(Icons.notifications_active_rounded,
                    color: Color(0xFFE65100), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Đã thông báo Nhân viên! Nhân viên phục vụ đang mang hóa đơn & mã QR thanh toán ra bàn cho bạn.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            itemCount: tableOrders.length,
            itemBuilder: (context, index) {
              final order = tableOrders[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
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
                        Text(
                          'Phiếu gọi món #${order.orderId}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                        Text(
                          'Lúc ${order.createdAt}',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    ...order.items.map((item) {
                      final statusInfo = _getDishStatusInfo(item.status);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5722).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'x${item.quantity}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFFF5722),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.dishName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                  Text(
                                    formatCurrency(item.price * item.quantity),
                                    style: const TextStyle(
                                        fontSize: 12, color: Color(0xFF6C7278)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: statusInfo.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                statusInfo.label,
                                style: TextStyle(
                                  color: statusInfo.color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, -4),
              )
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tổng tạm tính tại bàn:',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      formatCurrency(totalTableBill),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF5722),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF5722),
                          side: const BorderSide(color: Color(0xFFFF5722)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => _tabController.animateTo(0),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Gọi thêm món',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isWaitingPayment
                              ? const Color(0xFFE65100)
                              : const Color(0xFF00C853),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () =>
                            _notifyStaffForPayment(totalTableBill),
                        icon: const Icon(Icons.notifications_active_rounded),
                        label: Text(
                          isWaitingPayment
                              ? 'Nhắc lại Nhân viên'
                              : 'Gọi thanh toán',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Gửi thông báo gọi Nhân viên hoặc chuyển khoản VietQR tự động (TC25, TC27)
  void _notifyStaffForPayment(int totalTableBill) {
    ref.read(tableListProvider.notifier).setTableState(
          widget.tableId,
          TableState.needPayment,
          restaurantName: widget.restaurantName,
        );

    final allRestaurants = ref.read(realRestaurantListProvider);
    final bankInfo = ref
        .read(restaurantBankProvider.notifier)
        .getBankForRestaurant(
          restaurantName: widget.restaurantName,
          restaurants: allRestaurants,
        );
    final bool hasValidBank = bankInfo != null && bankInfo.isConfigured;
    final transferNote = '${widget.tableId} thanh toan';
    final qrPayload = hasValidBank
        ? 'VIETQR|${bankInfo.bankId}|${bankInfo.accountNo}|${bankInfo.accountName}|AMOUNT:$totalTableBill|NOTE:$transferNote'
        : '';

    bool isAutoConfirming = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_rounded,
                      color: Color(0xFF00C853), size: 36),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Thanh toán Hóa đơn tại bàn',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Color(0xFF1A1D26),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.restaurantName} • ${widget.tableId}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF5722),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Tổng thanh toán: ${formatCurrency(totalTableBill)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFF5722),
                  ),
                ),
                const SizedBox(height: 12),
                if (hasValidBank)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SizedBox(
                            width: 165,
                            height: 165,
                            child: Image.network(
                              bankInfo.buildVietQrUrl(
                                amount: totalTableBill,
                                addInfo: transferNote,
                              ),
                              width: 165,
                              height: 165,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => QrImageView(
                                data: qrPayload,
                                version: QrVersions.auto,
                                size: 165.0,
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
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.green.shade800,
                          ),
                        ),
                        Text(
                          'STK: ${bankInfo.accountNo} • ${bankInfo.accountName}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00C853),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: isAutoConfirming
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.verified_rounded, size: 18),
                            label: const Text(
                              'Tôi đã chuyển khoản VietQR',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            onPressed: isAutoConfirming
                                ? null
                                : () async {
                                    setDialogState(
                                        () => isAutoConfirming = true);
                                    final orderNotifier = ref.read(
                                        kitchenOrdersProvider.notifier);
                                    final tableNotifier =
                                        ref.read(tableListProvider.notifier);
                                    final resNotifier =
                                        ref.read(reservationProvider.notifier);
                                    await orderNotifier.settleOrdersForTable(
                                      widget.tableId,
                                      restaurantName: widget.restaurantName,
                                      fallbackAmount: totalTableBill,
                                      paymentMethod: 'VIETQR_AUTO',
                                    );
                                    await tableNotifier.setTableState(
                                      widget.tableId,
                                      TableState.empty,
                                      restaurantName: widget.restaurantName,
                                    );
                                    await resNotifier
                                        .completeReservationForTable(
                                      widget.tableId,
                                      restaurantName: widget.restaurantName,
                                    );
                                    if (dialogContext.mounted) {
                                      Navigator.of(dialogContext).pop();
                                    }
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Hệ thống đã tự động xác nhận giao dịch VietQR ${formatCurrency(totalTableBill)} thành công!'),
                                          backgroundColor:
                                              const Color(0xFF00C853),
                                        ),
                                      );
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.payments_outlined,
                            color: Color(0xFFE65100), size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Nhà hàng hiện chưa khai báo tài khoản ngân hàng VietQR. Vui lòng chuẩn bị TIỀN MẶT, nhân viên đang ra bàn thu tiền.',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6C7278),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'Đóng (Chờ nhân viên ra bàn)',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Nhãn trạng thái món ăn
  ({String label, Color color}) _getDishStatusInfo(DishStatus status) {
    switch (status) {
      case DishStatus.pending:
        return (label: '⏳ Chờ bếp', color: Colors.red);
      case DishStatus.cooking:
        return (label: '🔥 Đang nấu', color: Colors.orange);
      case DishStatus.ready:
        return (label: '🔔 Sắp lên món', color: Colors.blue);
      case DishStatus.served:
        return (label: '✅ Đã lên món', color: const Color(0xFF00C853));
    }
  }
}
