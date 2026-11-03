import 'dart:math' show cos, sqrt, asin;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:str/core/database/app_database.dart';

// Tính khoảng cách địa lý (km)
double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  var p = 0.017453292519943295;
  var a = 0.5 -
      cos((lat2 - lat1) * p) / 2 +
      cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
  return 12742 * asin(sqrt(a));
}

// Định dạng tiền tệ VNĐ
String formatCurrency(int amount) {
  final str = amount.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(str[i]);
  }
  return '${buffer.toString()} đ';
}

// Model hồ sơ cá nhân khách hàng
class UserProfile {
  final String name, phone, email, address;
  final double lat, lng;

  UserProfile({
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    this.lat = 21.0285,
    this.lng = 105.8048,
  });

  UserProfile copyWith({
    String? name,
    String? phone,
    String? email,
    String? address,
  }) =>
      UserProfile(
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        lat: lat,
        lng: lng,
      );
}

// Quản lý trạng thái hồ sơ cá nhân
class UserProfileNotifier extends StateNotifier<UserProfile> {
  UserProfileNotifier(AccountUser? currentUser)
      : super(UserProfile(
          name: currentUser?.name ?? '',
          phone: currentUser?.phone ?? '',
          email: '',
          address: '',
        ));

  // Cập nhật thông tin hồ sơ
  void updateProfile({
    required String name,
    required String phone,
    required String email,
    required String address,
  }) {
    state = state.copyWith(
      name: name,
      phone: phone,
      email: email,
      address: address,
    );
  }
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  return UserProfileNotifier(currentUser);
});
