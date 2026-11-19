import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:str/core/database/app_database.dart';
import 'package:str/features/home/models/user_profile_provider.dart'
    show formatCurrency;

// Màn hình quản lý Thực đơn nhà hàng
class MenuManagementScreen extends ConsumerWidget {
  const MenuManagementScreen({super.key});

  // Hộp thoại thêm hoặc chỉnh sửa món ăn
  void _showDishDialog(
    BuildContext context,
    WidgetRef ref,
    String myRestaurant, {
    MenuItemModel? existingDish,
  }) {
    if (myRestaurant.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Vui lòng thiết lập Tên nhà hàng trong mục Cài đặt Cửa hàng trước khi thêm món!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final isEdit = existingDish != null;
    final nameCtrl = TextEditingController(text: existingDish?.name ?? '');
    final priceCtrl = TextEditingController(
        text: existingDish != null ? existingDish.price.toString() : '');
    final descCtrl =
        TextEditingController(text: existingDish?.description ?? '');
    final imageUrlCtrl =
        TextEditingController(text: existingDish?.imageUrl ?? '');

    final categories = [
      'Món chính',
      'Món ăn nhẹ',
      'Lẩu',
      'Đồ uống',
      'Tráng miệng'
    ];
    String selectedCategory =
        (existingDish != null && categories.contains(existingDish.category))
            ? existingDish.category
            : 'Món chính';

    final icons = ['🍽️', '🍲', '🥩', '🍕', '🥗', '🍜', '🍹', '🍰'];
    String selectedIcon =
        (existingDish != null && icons.contains(existingDish.icon))
            ? existingDish.icon
            : '🍽️';

    XFile? selectedImage;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              isEdit ? 'Chỉnh sửa món ăn' : 'Thêm món mới',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final ImagePicker picker = ImagePicker();
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 70,
                        );
                        if (image != null) {
                          setDialogState(() => selectedImage = image);
                        }
                      },
                      child: Container(
                        height: 110,
                        width: 110,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F6FA),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            style: BorderStyle.solid,
                            width: 2,
                          ),
                          image: selectedImage != null
                              ? DecorationImage(
                                  image: kIsWeb
                                      ? NetworkImage(selectedImage!.path)
                                      : FileImage(File(selectedImage!.path))
                                          as ImageProvider,
                                  fit: BoxFit.cover,
                                )
                              : (imageUrlCtrl.text.trim().isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(
                                          imageUrlCtrl.text.trim()),
                                      fit: BoxFit.cover,
                                    )
                                  : null),
                        ),
                        child: (selectedImage == null &&
                                imageUrlCtrl.text.trim().isEmpty)
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(selectedIcon,
                                      style: const TextStyle(fontSize: 32)),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Chọn ảnh máy',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Wrap(
                      spacing: 6,
                      children: icons.map((ic) {
                        final isPicked = selectedIcon == ic;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedIcon = ic),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isPicked
                                  ? const Color(0xFFFF5722).withOpacity(0.15)
                                  : const Color(0xFFF4F6FA),
                              borderRadius: BorderRadius.circular(10),
                              border: isPicked
                                  ? Border.all(color: const Color(0xFFFF5722))
                                  : null,
                            ),
                            child:
                                Text(ic, style: const TextStyle(fontSize: 18)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildInputLabel('Tên món ăn'),
                  _buildTextField(nameCtrl, 'VD: Lẩu Thái Tomyum'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInputLabel('Giá bán (VNĐ)'),
                            _buildTextField(priceCtrl, '150000',
                                isNumber: true),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInputLabel('Danh mục'),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F6FA),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedCategory,
                                  isExpanded: true,
                                  icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Color(0xFFFF5722)),
                                  items: categories
                                      .map((c) => DropdownMenuItem(
                                            value: c,
                                            child: Text(
                                              c,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (val) => setDialogState(
                                      () => selectedCategory = val!),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInputLabel('Link ảnh món ăn (Không bắt buộc)'),
                  _buildTextField(
                    imageUrlCtrl,
                    'https://images.unsplash.com/...',
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _buildInputLabel('Mô tả ngắn'),
                  _buildTextField(descCtrl, 'Mô tả nguyên liệu, hương vị...'),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            actions: [
              if (!isUploading)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Hủy',
                    style: TextStyle(
                        color: Color(0xFF6C7278), fontWeight: FontWeight.bold),
                  ),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  elevation: 0,
                ),
                onPressed: isUploading
                    ? null
                    : () async {
                        final price = int.tryParse(priceCtrl.text.trim()) ?? 0;
                        if (nameCtrl.text.trim().isEmpty) return;

                        setDialogState(() => isUploading = true);

                        bool success;
                        if (isEdit) {
                          success = await ref
                              .read(menuDbProvider.notifier)
                              .updateMenuItem(
                                id: existingDish.id,
                                name: nameCtrl.text.trim(),
                                price: price,
                                category: selectedCategory,
                                description: descCtrl.text.trim(),
                                imageFile: selectedImage,
                                imageUrl: imageUrlCtrl.text.trim(),
                                icon: selectedIcon,
                              );
                        } else {
                          success = await ref
                              .read(menuDbProvider.notifier)
                              .addMenuItem(
                                name: nameCtrl.text.trim(),
                                price: price,
                                category: selectedCategory,
                                description: descCtrl.text.trim(),
                                restaurantName: myRestaurant,
                                imageFile: selectedImage,
                                imageUrl: imageUrlCtrl.text.trim(),
                                icon: selectedIcon,
                              );
                        }

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? (isEdit
                                        ? 'Đã cập nhật món ăn trên Database!'
                                        : 'Đã thêm món mới vào Database!')
                                    : 'Lỗi khi lưu lên Supabase Database!',
                              ),
                              backgroundColor: success
                                  ? const Color(0xFF00C853)
                                  : Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                child: isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(isEdit ? 'Lưu thay đổi' : 'Thêm món',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInputLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6C7278),
          ),
        ),
      );

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    bool isNumber = false,
    ValueChanged<String>? onChanged,
  }) =>
      TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              color: Color(0xFFB0B5B9), fontWeight: FontWeight.normal),
          filled: true,
          fillColor: const Color(0xFFF4F6FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myRestaurant = ref.watch(adminRestaurantNameProvider);
    final menuList = ref
        .watch(menuDbProvider)
        .where((m) =>
            myRestaurant.isNotEmpty && m.restaurantName == myRestaurant)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Quản lý Thực đơn',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            if (myRestaurant.isNotEmpty)
              Text(
                myRestaurant,
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFFF5722),
                    fontWeight: FontWeight.bold),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D26),
        elevation: 0.5,
        centerTitle: true,
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
              colors: [Color(0xFFFF7043), Color(0xFFFF5722)]),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5722).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showDishDialog(context, ref, myRestaurant),
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('Thêm món',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
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
                      'Hãy vào mục Cài đặt Cửa hàng để khai báo tên quán trước khi quản lý thực đơn.',
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
                      child: const Text('Đi tới Cài đặt Cửa hàng'),
                    ),
                  ],
                ),
              ),
            )
          : menuList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_menu_rounded,
                          size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text(
                        'Thực đơn trên Database đang trống',
                        style: TextStyle(
                          color: Color(0xFF9A9FA5),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Hãy nhấn nút "+ Thêm món" ở góc dưới để tạo thực đơn nhé!',
                        style:
                            TextStyle(color: Color(0xFF9A9FA5), fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, top: 16, bottom: 100),
                  itemCount: menuList.length,
                  itemBuilder: (context, index) {
                    final dish = menuList[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 75,
                            height: 75,
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
                                        style: const TextStyle(fontSize: 32)))
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dish.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: dish.isAvailable
                                        ? const Color(0xFF1A1D26)
                                        : const Color(0xFF9A9FA5),
                                    decoration: dish.isAvailable
                                        ? null
                                        : TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
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
                                if (dish.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    dish.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12, color: Color(0xFF9A9FA5)),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  formatCurrency(dish.price),
                                  style: TextStyle(
                                    color: dish.isAvailable
                                        ? const Color(0xFFFF5722)
                                        : Colors.grey,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Switch(
                                value: dish.isAvailable,
                                activeColor: Colors.white,
                                activeTrackColor: const Color(0xFF00C853),
                                inactiveThumbColor: Colors.white,
                                inactiveTrackColor: Colors.grey[300],
                                onChanged: (_) => ref
                                    .read(menuDbProvider.notifier)
                                    .toggleAvailability(dish.id),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: const Color(0xFFEFF6FF),
                                      minimumSize: const Size(40, 40),
                                    ),
                                    tooltip: 'Sửa món / Sửa giá',
                                    icon: const Icon(Icons.edit_outlined,
                                        color: Color(0xFF1E88E5), size: 19),
                                    onPressed: () => _showDishDialog(
                                      context,
                                      ref,
                                      myRestaurant,
                                      existingDish: dish,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: const Color(0xFFFEF2F2),
                                      minimumSize: const Size(40, 40),
                                    ),
                                    tooltip: 'Xóa món',
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Color(0xFFDC2626),
                                        size: 19),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20)),
                                          title: const Text('Xóa món ăn?'),
                                          content: Text(
                                              'Bạn có chắc chắn muốn xóa "${dish.name}" khỏi thực đơn trên Database không?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text('Hủy',
                                                  style: TextStyle(
                                                      color: Colors.grey)),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFFE53935),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                              ),
                                              onPressed: () {
                                                ref
                                                    .read(
                                                        menuDbProvider.notifier)
                                                    .deleteMenuItem(dish.id);
                                                Navigator.pop(ctx);
                                              },
                                              child: const Text('Xóa',
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
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
}
