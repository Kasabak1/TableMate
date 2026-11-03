import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:str/core/database/app_database.dart';
import 'package:str/features/home/models/user_profile_provider.dart';

// Tab hồ sơ cá nhân khách hàng
class ProfileTab extends ConsumerWidget {
  final String currentAddress;

  const ProfileTab({
    super.key,
    required this.currentAddress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final currentUser = ref.watch(currentUserProvider);
    final displayName = (currentUser != null && currentUser.name.isNotEmpty)
        ? currentUser.name
        : (profile.name.isNotEmpty ? profile.name : 'Khách hàng');
    final displayPhone = (currentUser != null && currentUser.phone.isNotEmpty)
        ? currentUser.phone
        : (profile.phone.isNotEmpty ? profile.phone : 'Chưa cập nhật');
    final displayEmail =
        profile.email.isNotEmpty ? profile.email : 'Chưa cập nhật';

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 60, bottom: 36),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF7043), Color(0xFFFF5722)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
            ),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 46,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person_rounded,
                      size: 54, color: Color(0xFFFF5722)),
                ),
                const SizedBox(height: 14),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Khách hàng thành viên',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.phone_iphone_rounded,
                              color: Colors.blue, size: 20),
                        ),
                        title: const Text('Số điện thoại',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        subtitle: Text(
                          displayPhone,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      Divider(height: 1, color: Colors.grey[200], indent: 64),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.mail_outline_rounded,
                              color: Colors.red, size: 20),
                        ),
                        title: const Text('Email',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        subtitle: Text(
                          displayEmail,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      Divider(height: 1, color: Colors.grey[200], indent: 64),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_on_outlined,
                              color: Colors.green, size: 20),
                        ),
                        title: const Text('Địa chỉ',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        subtitle: Text(
                          profile.address.isNotEmpty
                              ? profile.address
                              : currentAddress,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1A1D26),
                      elevation: 0,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _showEditProfileDialog(
                        context, ref, displayName, displayPhone, profile),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text(
                      'Chỉnh sửa thông tin cá nhân',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE53935),
                      side: BorderSide(color: Colors.red.shade200),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      ref.read(currentUserProvider.notifier).state = null;
                      context.pushReplacement('/');
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text(
                      'Đăng xuất tài khoản',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Hộp thoại chỉnh sửa hồ sơ cá nhân
  void _showEditProfileDialog(BuildContext context, WidgetRef ref,
      String currentName, String currentPhone, UserProfile profile) {
    final nameCtrl = TextEditingController(text: currentName);
    final phoneCtrl = TextEditingController(
        text: currentPhone == 'Chưa cập nhật' ? '' : currentPhone);
    final emailCtrl = TextEditingController(text: profile.email);
    final addressCtrl = TextEditingController(text: profile.address);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Cập nhật hồ sơ',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Họ và tên',
                  filled: true,
                  fillColor: const Color(0xFFF6F7FB),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: InputDecoration(
                  labelText: 'Số điện thoại',
                  filled: true,
                  fillColor: const Color(0xFFF6F7FB),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  labelText: 'Email',
                  filled: true,
                  fillColor: const Color(0xFFF6F7FB),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                decoration: InputDecoration(
                  labelText: 'Địa chỉ',
                  filled: true,
                  fillColor: const Color(0xFFF6F7FB),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
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
            onPressed: () {
              ref.read(userProfileProvider.notifier).updateProfile(
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                  );
              final curr = ref.read(currentUserProvider);
              if (curr != null) {
                ref.read(currentUserProvider.notifier).state = curr.copyWith(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                );
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã cập nhật thông tin cá nhân!'),
                  backgroundColor: Color(0xFF00C853),
                ),
              );
            },
            child: const Text('Lưu thay đổi',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
