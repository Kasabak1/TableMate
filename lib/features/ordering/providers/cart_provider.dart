import 'package:flutter_riverpod/flutter_riverpod.dart';

// Model món ăn trong giỏ hàng
class CartItem {
  final String name;
  final int price;
  int quantity;

  CartItem({required this.name, required this.price, this.quantity = 1});
}

// Quản lý trạng thái giỏ hàng
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  // Thêm món vào giỏ
  void addItem(String name, int price) {
    final existingIndex = state.indexWhere((item) => item.name == name);
    if (existingIndex >= 0) {
      state[existingIndex].quantity++;
      state = [...state];
    } else {
      state = [...state, CartItem(name: name, price: price)];
    }
  }

  // Giảm hoặc xóa món khỏi giỏ
  void removeItem(String name) {
    final existingIndex = state.indexWhere((item) => item.name == name);
    if (existingIndex >= 0) {
      if (state[existingIndex].quantity > 1) {
        state[existingIndex].quantity--;
        state = [...state];
      } else {
        state = [
          for (int i = 0; i < state.length; i++)
            if (i != existingIndex) state[i]
        ];
      }
    }
  }

  // Xóa toàn bộ giỏ hàng
  void clearCart() {
    state = [];
  }

  int get totalPrice =>
      state.fold(0, (sum, item) => sum + (item.price * item.quantity));
  int get totalItems => state.fold(0, (sum, item) => sum + item.quantity);
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});
