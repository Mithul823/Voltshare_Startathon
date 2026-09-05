import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/config/app_config.dart';
import '../../authentication/data/auth_state.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch auth state to force re-render when initialization completes.
    ref.watch(authStateProvider);

    // Once auth initialization completes, navigate with a brief minimum
    // splash duration so the branding is visible.
    ref.listen<AuthState>(authStateProvider, (_, next) {
      if (next == AuthState.initializing) return;
      final config = ref.read(appConfigProvider);
      if (!config.isSupabaseConfigured) {
        context.go(AppRoutes.setup);
        return;
      }
      if (next == AuthState.authenticated) {
        context.go(AppRoutes.dashboard);
      } else {
        context.go(AppRoutes.login);
      }
    });

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bolt,
              color: Theme.of(context).colorScheme.primary,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text('VoltShare', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            const Text(
              'Powering communities through intelligent energy sharing',
            ),
            const SizedBox(height: 28),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
