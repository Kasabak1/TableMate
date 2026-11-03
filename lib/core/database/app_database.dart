import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:str/main.dart';

SupabaseClient get _supabase => Supabase.instance.client;

// Model tài khoản người dùng
class AccountUser {
  final String id;
  final String name;
  final String phone;
  final String password;
  final String role;
  final String subRole;
  final String restaurantName;

  AccountUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.password,
    required this.role,
    this.subRole = '',
    this.restaurantName = '',
  });

  factory AccountUser.fromSupabase(Map<String, dynamic> row) {
    return AccountUser(
      id: row['id'].toString(),
      name: row['name'] ?? '',
      phone: row['phone'] ?? '',
      password: row['password'] ?? '',
      role: row['role'] ?? 'CUSTOMER',
      subRole: row['sub_role'] ?? '',
      restaurantName: row['restaurant_name'] ?? '',
    );
  }

  AccountUser copyWith({
    String? name,
    String? phone,
    String? password,
    String? role,
    String? subRole,
    String? restaurantName,
  }) {
    return AccountUser(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      role: role ?? this.role,
      subRole: subRole ?? this.subRole,
      restaurantName: restaurantName ?? this.restaurantName,
    );
  }
}

// Quản lý dữ liệu tài khoản trên Supabase
class AccountsDatabaseNotifier extends StateNotifier<List<AccountUser>> {
  Timer? _syncTimer;

  AccountsDatabaseNotifier() : super([]) {
    _initSupabaseConnection();
  }

  void _initSupabaseConnection() {
    if (!isSupabaseConfigured) return;
    fetchAccounts();
    _syncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      fetchAccounts();
    });
  }

  // Tải danh sách tài khoản từ Supabase
  Future<void> fetchAccounts() async {
    if (!isSupabaseConfigured) return;
    try {
      final res = await _supabase.from('accounts').select();
      final list = (res as List<dynamic>)
          .map((row) =>
              AccountUser.fromSupabase(Map<String, dynamic>.from(row as Map)))
          .toList();
      if (mounted) {
        state = list;
      }
    } catch (e) {
      debugPrint('Lỗi tải danh sách tài khoản: $e');
    }
  }

  // Xác thực đăng nhập đồng bộ
  AccountUser? login(String phone, String password) {
    for (final user in state) {
      if (user.phone == phone && user.password == password) {
        return user;
      }
    }
    return null;
  }

  // Xác thực đăng nhập trực tiếp với Supabase
  Future<AccountUser?> loginAsync(String phone, String password) async {
    final cached = login(phone, password);
    if (cached != null) return cached;

    if (!isSupabaseConfigured) return null;
    try {
      final res = await _supabase
          .from('accounts')
          .select()
          .eq('phone', phone)
          .eq('password', password);
      final list = res as List<dynamic>;
      if (list.isNotEmpty) {
        final user = AccountUser.fromSupabase(
            Map<String, dynamic>.from(list.first as Map));
        await fetchAccounts();
        return user;
      }
    } catch (e) {
      debugPrint('Lỗi truy vấn đăng nhập: $e');
    }
    return null;
  }

  // Kiểm tra số điện thoại tồn tại
  bool phoneExists(String phone, {String? excludeId}) {
    return state.any((u) => u.phone == phone && u.id != excludeId);
  }

  // Đăng ký tài khoản mới
  Future<bool> registerUser({
    required String name,
    required String phone,
    required String password,
    required String role,
    String subRole = '',
    String restaurantName = '',
  }) async {
    if (!isSupabaseConfigured) return false;
    try {
      await _supabase.from('accounts').insert({
        'name': name,
        'phone': phone,
        'password': password,
        'role': role,
        'sub_role': subRole,
        'restaurant_name': restaurantName,
      });
      await fetchAccounts();
      return true;
    } catch (e) {
      debugPrint('Lỗi đăng ký: $e');
      return false;
    }
  }

  // Cập nhật thông tin nhân viên
  Future<bool> updateStaff({
    required String id,
    required String name,
    required String phone,
    required String password,
    required String subRole,
  }) async {
    if (!isSupabaseConfigured) return false;
    try {
      await _supabase.from('accounts').update({
        'name': name,
        'phone': phone,
        'password': password,
        'sub_role': subRole,
      }).eq('id', id);
      await fetchAccounts();
      return true;
    } catch (e) {
      debugPrint('Lỗi cập nhật nhân viên: $e');
      return false;
    }
  }

  // Xóa tài khoản nhân viên
  Future<bool> deleteStaff(String id) async {
    if (!isSupabaseConfigured) return false;
    try {
      await _supabase.from('accounts').delete().eq('id', id);
      await fetchAccounts();
      return true;
    } catch (e) {
      debugPrint('Lỗi xóa tài khoản: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}

final accountsDbProvider =
    StateNotifierProvider<AccountsDatabaseNotifier, List<AccountUser>>((ref) {
  return AccountsDatabaseNotifier();
});

final currentUserProvider = StateProvider<AccountUser?>((ref) => null);

// Lấy tên nhà hàng của Admin đang đăng nhập
final adminRestaurantNameProvider = Provider<String>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return '';

  final allRestaurants = ref.watch(realRestaurantListProvider);
  final ownedRes = allRestaurants
      .where((r) => r.ownerPhone == currentUser.phone)
      .firstOrNull;

  if (ownedRes != null && ownedRes.name.trim().isNotEmpty) {
    return ownedRes.name.trim();
  }
  return currentUser.restaurantName.trim();
});

// Model món ăn trong thực đơn
class MenuItemModel {
  final String id, name, category, icon, description, restaurantName, imageUrl;
  final int price;
  final bool isAvailable;

  MenuItemModel({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.icon,
    required this.description,
    this.isAvailable = true,
    required this.restaurantName,
    this.imageUrl = '',
  });

  MenuItemModel copyWith({bool? isAvailable}) => MenuItemModel(
        id: id,
        name: name,
        price: price,
        category: category,
        icon: icon,
        description: description,
        isAvailable: isAvailable ?? this.isAvailable,
        restaurantName: restaurantName,
        imageUrl: imageUrl,
      );

  factory MenuItemModel.fromSupabase(Map<String, dynamic> row) => MenuItemModel(
        id: row['id'].toString(),
        name: row['name'] ?? '',
        price: (row['price'] as num?)?.toInt() ?? 0,
        category: row['category'] ?? 'Món chính',
        icon: row['icon'] ?? '🍽️',
        description: row['description'] ?? '',
        isAvailable: row['is_available'] ?? true,
        restaurantName: row['restaurant_name'] ?? '',
        imageUrl: row['image_url'] ?? '',
      );
}

// Quản lý dữ liệu thực đơn trên Supabase
class MenuDatabaseNotifier extends StateNotifier<List<MenuItemModel>> {
  Timer? _syncTimer;

  MenuDatabaseNotifier() : super([]) {
    if (!isSupabaseConfigured) return;
    fetchMenuItems();
    _syncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      fetchMenuItems();
    });
  }

  // Tải thực đơn từ Supabase
  Future<void> fetchMenuItems() async {
    if (!isSupabaseConfigured) return;
    try {
      final res = await _supabase.from('menu_items').select();
      final list = (res as List<dynamic>)
          .map((row) =>
              MenuItemModel.fromSupabase(Map<String, dynamic>.from(row as Map)))
          .toList();
      if (mounted) {
        state = list;
      }
    } catch (e) {
      debugPrint('Lỗi tải thực đơn: $e');
    }
  }

  // Thêm món ăn mới
  Future<bool> addMenuItem({
    required String name,
    required int price,
    required String category,
    required String description,
    required String restaurantName,
    XFile? imageFile,
    String imageUrl = '',
    String icon = '🍽️',
  }) async {
    if (!isSupabaseConfigured) return false;

    String finalImageUrl = imageUrl.trim();

    try {
      if (imageFile != null) {
        try {
          final bytes = await imageFile.readAsBytes();
          final fileExt = imageFile.name.split('.').last;
          final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';

          await _supabase.storage.from('menu_images').uploadBinary(
                fileName,
                bytes,
                fileOptions: FileOptions(contentType: 'image/$fileExt'),
              );
          finalImageUrl =
              _supabase.storage.from('menu_images').getPublicUrl(fileName);
        } catch (storageErr) {
          debugPrint('Lỗi upload ảnh: $storageErr');
        }
      }

      await _supabase.from('menu_items').insert({
        'name': name,
        'price': price,
        'category': category,
        'description': description,
        'is_available': true,
        'restaurant_name': restaurantName,
        'image_url': finalImageUrl,
        'icon': icon,
      });
      await fetchMenuItems();
      return true;
    } catch (e) {
      debugPrint('Lỗi thêm món ăn: $e');
      return false;
    }
  }

  // Cập nhật thông tin món ăn
  Future<bool> updateMenuItem({
    required String id,
    required String name,
    required int price,
    required String category,
    required String description,
    XFile? imageFile,
    String? imageUrl,
    String? icon,
  }) async {
    if (!isSupabaseConfigured) return false;

    try {
      String? finalImageUrl = imageUrl?.trim();

      if (imageFile != null) {
        try {
          final bytes = await imageFile.readAsBytes();
          final fileExt = imageFile.name.split('.').last;
          final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';

          await _supabase.storage.from('menu_images').uploadBinary(
                fileName,
                bytes,
                fileOptions: FileOptions(contentType: 'image/$fileExt'),
              );
          finalImageUrl =
              _supabase.storage.from('menu_images').getPublicUrl(fileName);
        } catch (storageErr) {
          debugPrint('Lỗi upload ảnh: $storageErr');
        }
      }

      final updateData = <String, dynamic>{
        'name': name,
        'price': price,
        'category': category,
        'description': description,
      };
      if (finalImageUrl != null) {
        updateData['image_url'] = finalImageUrl;
      }
      if (icon != null && icon.isNotEmpty) {
        updateData['icon'] = icon;
      }

      await _supabase.from('menu_items').update(updateData).eq('id', id);
      await fetchMenuItems();
      return true;
    } catch (e) {
      debugPrint('Lỗi cập nhật món ăn: $e');
      return false;
    }
  }

  // Đổi trạng thái còn/hết món
  Future<void> toggleAvailability(String id) async {
    if (!isSupabaseConfigured) return;
    try {
      final item = state.firstWhere((i) => i.id == id);
      final newStatus = !item.isAvailable;
      state = [
        for (final m in state)
          if (m.id == id) m.copyWith(isAvailable: newStatus) else m
      ];
      await _supabase
          .from('menu_items')
          .update({'is_available': newStatus}).eq('id', id);
      await fetchMenuItems();
    } catch (e) {
      debugPrint('Lỗi đổi trạng thái món ăn: $e');
    }
  }

  // Xóa món ăn
  Future<void> deleteMenuItem(String id) async {
    if (!isSupabaseConfigured) return;
    try {
      state = state.where((m) => m.id != id).toList();
      await _supabase.from('menu_items').delete().eq('id', id);
      await fetchMenuItems();
    } catch (e) {
      debugPrint('Lỗi xóa món ăn: $e');
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}

final menuDbProvider =
    StateNotifierProvider<MenuDatabaseNotifier, List<MenuItemModel>>(
        (ref) => MenuDatabaseNotifier());

// Model đánh giá nhà hàng
class ReviewModel {
  final String id, restaurantName, userName, comment;
  final int rating;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.restaurantName,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromSupabase(Map<String, dynamic> row) {
    return ReviewModel(
      id: row['id'].toString(),
      restaurantName: row['restaurant_name'] ?? '',
      userName: row['user_name'] ?? 'Khách hàng',
      rating: (row['rating'] as num?)?.toInt() ?? 5,
      comment: row['comment'] ?? '',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

// Quản lý đánh giá nhà hàng trên Supabase
class ReviewsNotifier extends StateNotifier<List<ReviewModel>> {
  Timer? _syncTimer;

  ReviewsNotifier() : super([]) {
    if (!isSupabaseConfigured) return;
    fetchReviews();
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      fetchReviews();
    });
  }

  // Tải danh sách đánh giá từ Supabase
  Future<void> fetchReviews() async {
    if (!isSupabaseConfigured) return;
    try {
      final res = await _supabase
          .from('reviews')
          .select()
          .order('created_at', ascending: false);
      final list = (res as List<dynamic>)
          .map((row) =>
              ReviewModel.fromSupabase(Map<String, dynamic>.from(row as Map)))
          .toList();
      if (mounted) {
        state = list;
      }
    } catch (e) {
      debugPrint('Lỗi tải đánh giá: $e');
    }
  }

  // Thêm đánh giá mới
  Future<bool> addReview(
      String restaurantName, String userName, int rating, String comment) async {
    if (!isSupabaseConfigured) return false;
    try {
      await _supabase.from('reviews').insert({
        'restaurant_name': restaurantName,
        'user_name': userName,
        'rating': rating,
        'comment': comment,
      });
      await fetchReviews();
      return true;
    } catch (e) {
      debugPrint('Lỗi thêm đánh giá: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}

final reviewsProvider =
    StateNotifierProvider<ReviewsNotifier, List<ReviewModel>>(
        (ref) => ReviewsNotifier());

// Model thông tin ngân hàng nhận thanh toán VietQR của nhà hàng
class RestaurantBankInfo {
  final String bankId;
  final String bankName;
  final String accountNo;
  final String accountName;

  const RestaurantBankInfo({
    required this.bankId,
    required this.bankName,
    required this.accountNo,
    required this.accountName,
  });

  bool get isConfigured =>
      bankId.trim().isNotEmpty && accountNo.trim().isNotEmpty;

  // Tạo URL mã QR chuyển khoản VietQR
  String buildVietQrUrl({
    required int amount,
    required String addInfo,
  }) {
    final cleanBank = bankId.trim().isEmpty ? 'MB' : bankId.trim();
    final cleanAcc = accountNo.trim();
    final encodedInfo = Uri.encodeComponent(addInfo);
    final encodedName = Uri.encodeComponent(accountName.trim());
    if (amount > 0) {
      return 'https://img.vietqr.io/image/$cleanBank-$cleanAcc-compact2.png?amount=$amount&addInfo=$encodedInfo&accountName=$encodedName';
    }
    return 'https://img.vietqr.io/image/$cleanBank-$cleanAcc-compact2.png?addInfo=$encodedInfo&accountName=$encodedName';
  }

  Map<String, dynamic> toJson() => {
        'bankId': bankId,
        'bankName': bankName,
        'accountNo': accountNo,
        'accountName': accountName,
      };

  factory RestaurantBankInfo.fromJson(Map<String, dynamic> json) {
    return RestaurantBankInfo(
      bankId: json['bankId']?.toString() ?? 'MB',
      bankName: json['bankName']?.toString() ?? 'MB Bank',
      accountNo: json['accountNo']?.toString() ?? '',
      accountName: json['accountName']?.toString() ?? '',
    );
  }
}

// Quản lý tài khoản ngân hàng của nhà hàng
class RestaurantBankNotifier
    extends StateNotifier<Map<String, RestaurantBankInfo>> {
  static const String _prefsKey = 'restaurant_bank_accounts_v1';

  RestaurantBankNotifier() : super({}) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final loaded = <String, RestaurantBankInfo>{};
        decoded.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            loaded[key] = RestaurantBankInfo.fromJson(value);
          }
        });
        state = {...loaded, ...state};
      }
    } catch (e) {
      debugPrint('Lỗi đọc cấu hình ngân hàng: $e');
    }
  }

  // Lưu cấu hình ngân hàng cho nhà hàng
  Future<void> saveBankForRestaurant({
    required String restaurantName,
    String? ownerPhone,
    required RestaurantBankInfo bankInfo,
  }) async {
    final updated = Map<String, RestaurantBankInfo>.from(state);
    if (restaurantName.trim().isNotEmpty) {
      updated[restaurantName.trim()] = bankInfo;
    }
    if (ownerPhone != null && ownerPhone.trim().isNotEmpty) {
      updated['phone:${ownerPhone.trim()}'] = bankInfo;
    }
    state = updated;

    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = <String, dynamic>{};
      updated.forEach((key, value) {
        serialized[key] = value.toJson();
      });
      await prefs.setString(_prefsKey, jsonEncode(serialized));
    } catch (e) {
      debugPrint('Lỗi lưu cấu hình ngân hàng: $e');
    }
  }

  // Truy xuất cấu hình ngân hàng của nhà hàng
  RestaurantBankInfo? getBankForRestaurant({
    String? restaurantName,
    String? ownerPhone,
    List<RestaurantModel>? restaurants,
  }) {
    if (restaurants != null) {
      final matched = restaurants.where((r) {
        final matchName = restaurantName != null &&
            restaurantName.trim().isNotEmpty &&
            r.name.trim() == restaurantName.trim();
        final matchPhone = ownerPhone != null &&
            ownerPhone.trim().isNotEmpty &&
            r.ownerPhone.trim() == ownerPhone.trim();
        return matchName || matchPhone;
      }).firstOrNull;

      if (matched != null && matched.bankAccountNo.trim().isNotEmpty) {
        return RestaurantBankInfo(
          bankId: matched.bankId.isNotEmpty ? matched.bankId : 'MB',
          bankName:
              matched.bankName.isNotEmpty ? matched.bankName : matched.bankId,
          accountNo: matched.bankAccountNo,
          accountName: matched.bankAccountName,
        );
      }
    }

    if (restaurantName != null &&
        restaurantName.trim().isNotEmpty &&
        state.containsKey(restaurantName.trim())) {
      return state[restaurantName.trim()];
    }

    if (ownerPhone != null &&
        ownerPhone.trim().isNotEmpty &&
        state.containsKey('phone:${ownerPhone.trim()}')) {
      return state['phone:${ownerPhone.trim()}'];
    }

    if (state.isNotEmpty) {
      return state.values.first;
    }
    return null;
  }
}

final restaurantBankProvider = StateNotifierProvider<RestaurantBankNotifier,
    Map<String, RestaurantBankInfo>>((ref) {
  return RestaurantBankNotifier();
});

// Model hồ sơ nhà hàng
class RestaurantModel {
  final String id,
      ownerPhone,
      name,
      address,
      category,
      openTime,
      imageUrl,
      status,
      bankId,
      bankName,
      bankAccountNo,
      bankAccountName;
  final double lat, lng, rating;

  RestaurantModel({
    required this.id,
    required this.ownerPhone,
    required this.name,
    required this.address,
    required this.category,
    required this.openTime,
    required this.imageUrl,
    required this.lat,
    required this.lng,
    required this.rating,
    required this.status,
    this.bankId = '',
    this.bankName = '',
    this.bankAccountNo = '',
    this.bankAccountName = '',
  });

  factory RestaurantModel.fromSupabase(Map<String, dynamic> row) {
    return RestaurantModel(
      id: row['id'].toString(),
      ownerPhone: row['owner_phone'] ?? '',
      name: row['name'] ?? '',
      address: row['address'] ?? '',
      category: row['category'] ?? 'Đang cập nhật',
      openTime: row['open_time'] ?? '08:00 - 22:00',
      imageUrl: row['image_url'] ?? '',
      lat: (row['lat'] as num?)?.toDouble() ?? 21.0285,
      lng: (row['lng'] as num?)?.toDouble() ?? 105.8048,
      rating: (row['rating'] as num?)?.toDouble() ?? 5.0,
      status: row['status'] ?? 'PENDING',
      bankId: row['bank_id']?.toString() ?? '',
      bankName: row['bank_name']?.toString() ?? '',
      bankAccountNo: row['bank_account_no']?.toString() ?? '',
      bankAccountName: row['bank_account_name']?.toString() ?? '',
    );
  }
}

// Quản lý danh sách nhà hàng trên Supabase
class RestaurantListNotifier extends StateNotifier<List<RestaurantModel>> {
  Timer? _syncTimer;

  RestaurantListNotifier() : super([]) {
    if (!isSupabaseConfigured) return;
    fetchRestaurants();
    _syncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      fetchRestaurants();
    });
  }

  // Tải danh sách nhà hàng từ Supabase
  Future<void> fetchRestaurants() async {
    if (!isSupabaseConfigured) return;
    try {
      final res = await _supabase.from('restaurants').select();
      final list = (res as List<dynamic>)
          .map((row) =>
              RestaurantModel.fromSupabase(Map<String, dynamic>.from(row as Map)))
          .toList();
      if (mounted) {
        state = list;
      }
    } catch (e) {
      debugPrint('Lỗi tải danh sách nhà hàng: $e');
    }
  }

  // Lưu và gửi duyệt hồ sơ nhà hàng
  Future<bool> submitStoreProfile(
    String ownerPhone,
    String name,
    String address,
    String category,
    String openTime,
    double lat,
    double lng, {
    String? imageUrl,
    String? bankId,
    String? bankName,
    String? bankAccountNo,
    String? bankAccountName,
  }) async {
    if (!isSupabaseConfigured) return false;
    try {
      final existing = await _supabase
          .from('restaurants')
          .select()
          .eq('owner_phone', ownerPhone);

      String? oldRestaurantName;
      if (existing.isNotEmpty) {
        oldRestaurantName = existing.first['name']?.toString();
      }

      final corePayload = <String, dynamic>{
        'owner_phone': ownerPhone,
        'name': name,
        'address': address,
        'category': category,
        'open_time': openTime,
        'lat': lat,
        'lng': lng,
        'status': 'PENDING',
      };
      if (imageUrl != null && imageUrl.trim().isNotEmpty) {
        corePayload['image_url'] = imageUrl.trim();
      }

      final fullPayload = <String, dynamic>{
        ...corePayload,
        if (bankId != null) 'bank_id': bankId.trim(),
        if (bankName != null) 'bank_name': bankName.trim(),
        if (bankAccountNo != null) 'bank_account_no': bankAccountNo.trim(),
        if (bankAccountName != null)
          'bank_account_name': bankAccountName.trim().toUpperCase(),
      };

      try {
        if (existing.isEmpty) {
          await _supabase.from('restaurants').insert(fullPayload);
        } else {
          await _supabase
              .from('restaurants')
              .update(fullPayload)
              .eq('owner_phone', ownerPhone);
        }
      } catch (_) {
        if (existing.isEmpty) {
          await _supabase.from('restaurants').insert(corePayload);
        } else {
          await _supabase
              .from('restaurants')
              .update(corePayload)
              .eq('owner_phone', ownerPhone);
        }
      }

      await _supabase
          .from('accounts')
          .update({'restaurant_name': name}).eq('phone', ownerPhone);

      if (oldRestaurantName != null &&
          oldRestaurantName.isNotEmpty &&
          oldRestaurantName != name) {
        try {
          await _supabase
              .from('accounts')
              .update({'restaurant_name': name})
              .eq('restaurant_name', oldRestaurantName);
          await _supabase
              .from('menu_items')
              .update({'restaurant_name': name})
              .eq('restaurant_name', oldRestaurantName);
        } catch (syncErr) {
          debugPrint('Lỗi đồng bộ tên quán mới: $syncErr');
        }
      }

      await fetchRestaurants();
      return true;
    } catch (e) {
      debugPrint('Lỗi lưu hồ sơ quán: $e');
      return false;
    }
  }

  // Thay đổi trạng thái phê duyệt nhà hàng
  Future<bool> changeRestaurantStatus(String id, String newStatus) async {
    if (!isSupabaseConfigured) return false;
    try {
      await _supabase
          .from('restaurants')
          .update({'status': newStatus}).eq('id', id);
      await fetchRestaurants();
      return true;
    } catch (e) {
      debugPrint('Lỗi đổi trạng thái quán: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}

final realRestaurantListProvider =
    StateNotifierProvider<RestaurantListNotifier, List<RestaurantModel>>((ref) {
  return RestaurantListNotifier();
});
