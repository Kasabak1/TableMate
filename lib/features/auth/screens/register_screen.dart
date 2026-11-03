import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:str/core/database/app_database.dart';

// Màn hình đăng ký tài khoản
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _selectedRole = 'CUSTOMER';
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // Xử lý đăng ký tài khoản mới
  Future<void> _handleRegister() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng điền đầy đủ thông tin!'),
          backgroundColor: Color(0xFFE53935),
        ),
      );
      return;
    }

    if (ref.read(accountsDbProvider.notifier).phoneExists(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Số điện thoại đã được đăng ký!'),
          backgroundColor: Color(0xFFE53935),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final success = await ref.read(accountsDbProvider.notifier).registerUser(
          name: name,
          phone: phone,
          password: pass,
          role: _selectedRole,
        );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng ký thành công! Vui lòng đăng nhập.'),
            backgroundColor: Color(0xFF00C853),
          ),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tạo tài khoản, vui lòng thử lại!'),
            backgroundColor: Color(0xFFE53935),
          ),
        );
      }
    }
  }

  // Ô nhập liệu thông tin
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    bool isPassword = false,
    bool isPhone = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1D26),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword && !_isPasswordVisible,
          keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
          style: const TextStyle(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFFB0B5B9),
              fontWeight: FontWeight.normal,
            ),
            prefixIcon: Icon(icon, color: const Color(0xFFFF5722)),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xFF9A9FA5),
                    ),
                    onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible),
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF4F5F7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1A1D26)),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tạo tài khoản mới',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1D26),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Chọn vai trò của bạn và điền thông tin bên dưới',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9A9FA5)),
                ),
                const SizedBox(height: 24),

                // Chọn vai trò đăng ký
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedRole = 'CUSTOMER'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _selectedRole == 'CUSTOMER'
                                ? const Color(0xFFFF5722)
                                : const Color(0xFFF4F6FA),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_rounded,
                                size: 18,
                                color: _selectedRole == 'CUSTOMER'
                                    ? Colors.white
                                    : const Color(0xFF6C7278),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Khách hàng',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedRole == 'CUSTOMER'
                                      ? Colors.white
                                      : const Color(0xFF6C7278),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedRole = 'ADMIN'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _selectedRole == 'ADMIN'
                                ? const Color(0xFFFF5722)
                                : const Color(0xFFF4F6FA),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.storefront_rounded,
                                size: 18,
                                color: _selectedRole == 'ADMIN'
                                    ? Colors.white
                                    : const Color(0xFF6C7278),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Chủ Nhà hàng',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedRole == 'ADMIN'
                                      ? Colors.white
                                      : const Color(0xFF6C7278),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  _nameCtrl,
                  'Họ và tên',
                  'Nhập họ và tên của bạn...',
                  Icons.person_outline_rounded,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _phoneCtrl,
                  'Số điện thoại',
                  'Nhập số điện thoại đăng nhập...',
                  Icons.phone_iphone_rounded,
                  isPhone: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _passCtrl,
                  'Mật khẩu',
                  'Tạo mật khẩu...',
                  Icons.lock_outline_rounded,
                  isPassword: true,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5722),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _handleRegister,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'ĐĂNG KÝ TÀI KHOẢN',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
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
}
