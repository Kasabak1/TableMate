import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:str/core/database/app_database.dart';

// Màn hình quản lý Nhân sự nhà hàng
class StaffManagementScreen extends ConsumerWidget {
  const StaffManagementScreen({super.key});

  // Hộp thoại cấp mới hoặc cập nhật tài khoản nhân viên
  void _showStaffDialog(
    BuildContext context,
    WidgetRef ref,
    String myRestaurant, {
    AccountUser? existingStaff,
  }) {
    if (myRestaurant.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Vui lòng thiết lập Tên nhà hàng trong mục Cài đặt Cửa hàng trước khi thêm nhân viên!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final isEdit = existingStaff != null;
    final nameCtrl = TextEditingController(text: existingStaff?.name ?? '');
    final phoneCtrl = TextEditingController(text: existingStaff?.phone ?? '');
    final passCtrl =
        TextEditingController(text: existingStaff?.password ?? '123456');

    final roles = ['Phục vụ bàn', 'Bếp trưởng', 'Thu ngân'];
    String selectedRole =
        (existingStaff != null && roles.contains(existingStaff.subRole))
            ? existingStaff.subRole
            : 'Phục vụ bàn';
    bool isSaving = false;

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
              isEdit
                  ? 'Cập nhật tài khoản Nhân viên'
                  : 'Cấp tài khoản Nhân viên',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputLabel('Tên nhân viên'),
                  _buildTextField(
                      nameCtrl, 'Nhập họ và tên', Icons.person_outline),
                  const SizedBox(height: 12),
                  _buildInputLabel('Số điện thoại (TK Đăng nhập)'),
                  _buildTextField(
                      phoneCtrl, 'Nhập số điện thoại', Icons.phone_outlined,
                      isPhone: true),
                  const SizedBox(height: 12),
                  _buildInputLabel('Mật khẩu đăng nhập'),
                  _buildTextField(passCtrl, 'Nhập mật khẩu', Icons.lock_outline),
                  const SizedBox(height: 12),
                  _buildInputLabel('Chức vụ (Phân quyền)'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F6FA),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedRole,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFFFF5722)),
                        items: roles.map((role) {
                          return DropdownMenuItem(
                            value: role,
                            child: Text(role,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedRole = val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            actions: [
              if (!isSaving)
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
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        final phone = phoneCtrl.text.trim();
                        final pass = passCtrl.text.trim();

                        if (name.isEmpty || phone.isEmpty || pass.isEmpty) {
                          return;
                        }

                        if (ref.read(accountsDbProvider.notifier).phoneExists(
                              phone,
                              excludeId: existingStaff?.id,
                            )) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Số điện thoại đã tồn tại trên hệ thống!'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);

                        bool success;
                        if (isEdit) {
                          success = await ref
                              .read(accountsDbProvider.notifier)
                              .updateStaff(
                                id: existingStaff.id,
                                name: name,
                                phone: phone,
                                password: pass,
                                subRole: selectedRole,
                              );
                        } else {
                          success = await ref
                              .read(accountsDbProvider.notifier)
                              .registerUser(
                                name: name,
                                phone: phone,
                                password: pass,
                                role: 'STAFF',
                                subRole: selectedRole,
                                restaurantName: myRestaurant,
                              );
                        }

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? (isEdit
                                        ? 'Đã cập nhật thông tin nhân viên trên Database!'
                                        : 'Đã cấp tài khoản nhân viên thành công!')
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
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        isEdit ? 'LƯU THAY ĐỔI' : 'CẤP TÀI KHOẢN',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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
      TextEditingController controller, String hint, IconData icon,
      {bool isPhone = false}) {
    return TextField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            color: Color(0xFFB0B5B9), fontWeight: FontWeight.normal),
        prefixIcon: Icon(icon, color: Colors.grey[500]),
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
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myRestaurant = ref.watch(adminRestaurantNameProvider);
    final allUsers = ref.watch(accountsDbProvider);

    final staffList = allUsers
        .where((u) =>
            (u.role == 'STAFF' || u.role == 'WAITER' || u.role == 'CHEF') &&
            myRestaurant.isNotEmpty &&
            u.restaurantName == myRestaurant)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Quản lý Nhân sự',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            if (myRestaurant.isNotEmpty)
              Text(
                myRestaurant,
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1E88E5),
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
              colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)]),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E88E5).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showStaffDialog(context, ref, myRestaurant),
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.person_add_rounded, color: Colors.white),
          label: const Text(
            'Thêm nhân viên',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
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
                        size: 72, color: Colors.blue.shade300),
                    const SizedBox(height: 16),
                    const Text(
                      'Bạn chưa thiết lập Tên Nhà hàng',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Hãy vào mục Cài đặt Cửa hàng để khai báo tên quán trước khi cấp tài khoản cho nhân viên.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6C7278)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => context.push('/admin/settings'),
                      child: const Text('Đi tới Cài đặt Cửa hàng'),
                    ),
                  ],
                ),
              ),
            )
          : staffList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_alt_rounded,
                          size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text(
                        'Chưa có nhân viên nào trên Database',
                        style: TextStyle(
                          color: Color(0xFF9A9FA5),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Bấm "+ Thêm nhân viên" để cấp tài khoản Phục vụ hoặc Bếp.',
                        style:
                            TextStyle(color: Color(0xFF9A9FA5), fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, top: 16, bottom: 100),
                  itemCount: staffList.length,
                  itemBuilder: (context, index) {
                    final staff = staffList[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFFE3F2FD),
                          child: Text(
                            staff.name.isNotEmpty
                                ? staff.name[0].toUpperCase()
                                : 'N',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E88E5),
                              fontSize: 18,
                            ),
                          ),
                        ),
                        title: Text(staff.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F6FA),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                staff.subRole.isNotEmpty
                                    ? staff.subRole
                                    : staff.role,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6C7278),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'SĐT: ${staff.phone} • MK: ${staff.password}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9A9FA5),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Sửa thông tin / Chức vụ',
                              icon: const Icon(Icons.edit_outlined,
                                  color: Color(0xFF1E88E5)),
                              onPressed: () => _showStaffDialog(
                                context,
                                ref,
                                myRestaurant,
                                existingStaff: staff,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Xóa tài khoản',
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: Color(0xFFE53935)),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    title: const Text('Xóa tài khoản?'),
                                    content: Text(
                                        'Bạn có chắc chắn muốn xóa nhân viên "${staff.name}" khỏi Database không?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Hủy',
                                            style:
                                                TextStyle(color: Colors.grey)),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFE53935),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                        ),
                                        onPressed: () {
                                          ref
                                              .read(accountsDbProvider.notifier)
                                              .deleteStaff(staff.id);
                                          Navigator.pop(ctx);
                                        },
                                        child: const Text('Xóa',
                                            style:
                                                TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
