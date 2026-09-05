import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/voltshare_ui.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/user_role.dart';
import '../../role_access/role_navigation.dart';

class DashboardShell extends ConsumerWidget {
  const DashboardShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(currentProfileProvider);
    final role = profileState.valueOrNull?.role ?? UserRole.consumer;
    final roleItems = RoleAccessPolicy.navigationFor(role);
    final selectedIndex = _selectedIndex(
      navigationShell.currentIndex,
      GoRouterState.of(context).uri.path,
      roleItems,
    );
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          final item = index >= roleItems.length ? null : roleItems[index];
          if (item != null) {
            context.go(item.route);
            return;
          }
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: roleItems
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }

  int _selectedIndex(
    int fallback,
    String path,
    List<RoleNavigationItem>? items,
  ) {
    if (items == null || items.isEmpty) {
      return fallback;
    }
    final index = items.indexWhere(
      (item) => path == item.route || path.startsWith('${item.route}/'),
    );
    return index < 0 ? 0 : index;
  }
}
