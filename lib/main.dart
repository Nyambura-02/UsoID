import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uso_id/core/theme/app_theme.dart';
import 'package:uso_id/core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Hive for offline storage
  await Hive.initFlutter();
  await Hive.openBox('offline_scans');
  await Hive.openBox('app_cache');

  runApp(
    const ProviderScope(
      child: UsoIDApp(),
    ),
  );
}

class UsoIDApp extends ConsumerWidget {
  const UsoIDApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'UsoID - Campus Management',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
