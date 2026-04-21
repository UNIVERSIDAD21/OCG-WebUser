import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/providers/auth_providers.dart';
import '../shared/theme/ocg_theme.dart';
import 'router/app_router.dart';

class OcgApp extends ConsumerWidget {
  const OcgApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(fcmBootstrapProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'OCG Clínica',
      theme: OcgTheme.light,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
