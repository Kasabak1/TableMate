import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:str/core/database/app_database.dart';
import 'package:str/features/chat/chat_screen.dart';
import 'package:str/features/home/models/user_profile_provider.dart';
import 'package:str/features/home/widgets/ai_assistant_tab.dart';
import 'package:str/features/home/widgets/explore_tab.dart';
import 'package:str/features/home/widgets/history_tab.dart';
import 'package:str/features/home/widgets/profile_tab.dart';

export 'package:str/features/home/models/user_profile_provider.dart';

// Màn hình trang chủ khách hàng
class MainDashboardScreen extends ConsumerStatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  ConsumerState<MainDashboardScreen> createState() =>
      _MainDashboardScreenState();
}

class _MainDashboardScreenState extends ConsumerState<MainDashboardScreen> {
  int _currentIndex = 0;
  LatLng? _customerRealPos;
  String _currentAddress = 'Đang xác định vị trí...';

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  // Định vị GPS của khách hàng
  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _currentAddress = 'Chưa bật định vị GPS');
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() => _currentAddress = 'Chưa cấp quyền vị trí');
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _currentAddress = 'Quyền vị trí bị từ chối');
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      if (mounted) {
        setState(() {
          _customerRealPos = LatLng(position.latitude, position.longitude);
        });

        try {
          final url = Uri.parse(
              'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1');
          final response = await http.get(url, headers: {
            'User-Agent': 'com.smartorder.app',
            'Accept-Language': 'vi-VN,vi;q=0.9',
          });

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final address = data['address'];

            if (address != null && mounted) {
              final road = address['road'] ??
                  address['pedestrian'] ??
                  address['suburb'] ??
                  '';
              final city = address['city'] ??
                  address['county'] ??
                  address['state'] ??
                  '';

              setState(() {
                _currentAddress = '$road, $city'.trim();
                if (_currentAddress.startsWith(',')) {
                  _currentAddress = _currentAddress.substring(1).trim();
                }
                if (_currentAddress.isEmpty) {
                  _currentAddress = 'Vị trí GPS hiện tại';
                }
              });
            }
          }
        } catch (_) {
          if (mounted) {
            setState(() => _currentAddress = 'Vị trí GPS hiện tại');
          }
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _currentAddress = 'Không thể lấy vị trí');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final profile = ref.watch(userProfileProvider);
    final myName = (currentUser != null && currentUser.name.isNotEmpty)
        ? currentUser.name
        : (profile.name.isNotEmpty ? profile.name : 'Khách hàng');

    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final List<Widget> pages = [
      ExploreTab(
        displayName: myName,
        profile: profile,
        customerRealPos: _customerRealPos,
        currentAddress: _currentAddress,
        onRefreshLocation: _getUserLocation,
        onBookSuccess: () => setState(() => _currentIndex = 1),
      ),
      const HistoryTab(),
      const AiAssistantTab(),
      const CustomerChatListView(),
      ProfileTab(currentAddress: _currentAddress),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: pages[_currentIndex],
      floatingActionButton: (_currentIndex == 0 && !isKeyboardOpen)
          ? Container(
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
                onPressed: () => context.pushNamed('scanQR'),
                backgroundColor: Colors.transparent,
                elevation: 0,
                icon: const Icon(Icons.qr_code_scanner_rounded,
                    color: Colors.white),
                label: const Text(
                  'Quét QR tại bàn',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            )
          : null,
      bottomNavigationBar: isKeyboardOpen
          ? null
          : Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  )
                ],
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) =>
                    setState(() => _currentIndex = index),
                backgroundColor: Colors.white,
                elevation: 0,
                indicatorColor: const Color(0xFFFF5722).withOpacity(0.12),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.compass_calibration_outlined),
                    selectedIcon:
                        Icon(Icons.explore_rounded, color: Color(0xFFFF5722)),
                    label: 'Khám phá',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_today_outlined),
                    selectedIcon: Icon(Icons.calendar_month_rounded,
                        color: Color(0xFFFF5722)),
                    label: 'Lịch đặt',
                  ),
                  NavigationDestination(
                    icon:
                        Icon(Icons.auto_awesome_outlined, color: Colors.purple),
                    selectedIcon:
                        Icon(Icons.auto_awesome, color: Colors.purple),
                    label: 'Trợ lý AI',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.chat_bubble_outline),
                    selectedIcon:
                        Icon(Icons.chat_bubble, color: Color(0xFFFF5722)),
                    label: 'Hỗ trợ',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon:
                        Icon(Icons.person_rounded, color: Color(0xFFFF5722)),
                    label: 'Hồ sơ',
                  ),
                ],
              ),
            ),
    );
  }
}
