import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';

const String supabaseUrl = 'https://mddalpadojitipwzdwqi.supabase.co';
const String supabaseAnonKey = 'sb_publishable_Vm5M8pjb4s9_xQqX7voaZw_LFlU8-00';

bool isSupabaseConfigured = false;

// Khởi tạo ứng dụng và kết nối Supabase
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (supabaseUrl.startsWith('https://') &&
        !supabaseUrl.contains('YOUR_PROJECT_ID') &&
        supabaseAnonKey != 'YOUR_SUPABASE_ANON_PUBLIC_KEY') {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      isSupabaseConfigured = true;
    }
  } catch (e) {
    debugPrint('Lỗi khởi tạo Supabase: $e');
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

// Cấu hình MaterialApp và điều hướng
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Smart Restaurant Order',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
