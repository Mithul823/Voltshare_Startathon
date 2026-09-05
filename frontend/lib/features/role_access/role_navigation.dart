import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../authentication/domain/user_role.dart';

class RoleNavigationItem {
  const RoleNavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}

class RoleAccessPolicy {
  const RoleAccessPolicy._();

  static List<RoleNavigationItem> navigationFor(UserRole role) {
    return switch (role) {
      UserRole.consumer => const [
        RoleNavigationItem(
          label: 'Home',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          route: AppRoutes.dashboard,
        ),
        RoleNavigationItem(
          label: 'Marketplace',
          icon: Icons.storefront_outlined,
          selectedIcon: Icons.storefront,
          route: AppRoutes.marketplace,
        ),
        RoleNavigationItem(
          label: 'Purchases',
          icon: Icons.shopping_bag_outlined,
          selectedIcon: Icons.shopping_bag,
          route: AppRoutes.purchases,
        ),
        RoleNavigationItem(
          label: 'Emergency',
          icon: Icons.emergency_outlined,
          selectedIcon: Icons.emergency,
          route: AppRoutes.emergencyRequests,
        ),
        RoleNavigationItem(
          label: 'Wallet',
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet,
          route: AppRoutes.wallet,
        ),
        RoleNavigationItem(
          label: 'Profile',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          route: AppRoutes.profile,
        ),
      ],
      UserRole.producer => const [
        RoleNavigationItem(
          label: 'Home',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          route: AppRoutes.dashboard,
        ),
        RoleNavigationItem(
          label: 'Listings',
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          route: AppRoutes.myListings,
        ),
        RoleNavigationItem(
          label: 'Sales',
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          route: AppRoutes.sales,
        ),
        RoleNavigationItem(
          label: 'Wallet',
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet,
          route: AppRoutes.wallet,
        ),
        RoleNavigationItem(
          label: 'Analytics',
          icon: Icons.analytics_outlined,
          selectedIcon: Icons.analytics,
          route: AppRoutes.analytics,
        ),
        RoleNavigationItem(
          label: 'Profile',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          route: AppRoutes.profile,
        ),
      ],
      UserRole.prosumer => const [
        RoleNavigationItem(
          label: 'Home',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          route: AppRoutes.dashboard,
        ),
        RoleNavigationItem(
          label: 'Marketplace',
          icon: Icons.storefront_outlined,
          selectedIcon: Icons.storefront,
          route: AppRoutes.marketplace,
        ),
        RoleNavigationItem(
          label: 'Trade',
          icon: Icons.swap_horiz_outlined,
          selectedIcon: Icons.swap_horiz,
          route: AppRoutes.trade,
        ),
        RoleNavigationItem(
          label: 'Wallet',
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet,
          route: AppRoutes.wallet,
        ),
        RoleNavigationItem(
          label: 'Analytics',
          icon: Icons.analytics_outlined,
          selectedIcon: Icons.analytics,
          route: AppRoutes.analytics,
        ),
        RoleNavigationItem(
          label: 'Profile',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          route: AppRoutes.profile,
        ),
      ],
      UserRole.technician => const [
        RoleNavigationItem(
          label: 'Home',
          icon: Icons.home_repair_service_outlined,
          selectedIcon: Icons.home_repair_service,
          route: AppRoutes.dashboard,
        ),
        RoleNavigationItem(
          label: 'Tasks',
          icon: Icons.task_alt_outlined,
          selectedIcon: Icons.task_alt,
          route: AppRoutes.tasks,
        ),
        RoleNavigationItem(
          label: 'Diagnostics',
          icon: Icons.build_circle_outlined,
          selectedIcon: Icons.build_circle,
          route: AppRoutes.diagnostics,
        ),
        RoleNavigationItem(
          label: 'Profile',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          route: AppRoutes.profile,
        ),
      ],
      UserRole.gridOperator => const [
        RoleNavigationItem(
          label: 'Home',
          icon: Icons.grid_view_outlined,
          selectedIcon: Icons.grid_view,
          route: AppRoutes.dashboard,
        ),
        RoleNavigationItem(
          label: 'Grid',
          icon: Icons.electrical_services_outlined,
          selectedIcon: Icons.electrical_services,
          route: AppRoutes.gridStatus,
        ),
        RoleNavigationItem(
          label: 'Alerts',
          icon: Icons.report_problem_outlined,
          selectedIcon: Icons.report_problem,
          route: AppRoutes.alerts,
        ),
        RoleNavigationItem(
          label: 'Profile',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          route: AppRoutes.profile,
        ),
      ],
      UserRole.admin => const [
        RoleNavigationItem(
          label: 'Overview',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          route: AppRoutes.dashboard,
        ),
        RoleNavigationItem(
          label: 'Users',
          icon: Icons.groups_outlined,
          selectedIcon: Icons.groups,
          route: AppRoutes.adminUsers,
        ),
        RoleNavigationItem(
          label: 'KYC',
          icon: Icons.verified_outlined,
          selectedIcon: Icons.verified,
          route: AppRoutes.adminKyc,
        ),
        RoleNavigationItem(
          label: 'Disputes',
          icon: Icons.forum_outlined,
          selectedIcon: Icons.forum,
          route: AppRoutes.adminDisputes,
        ),
        RoleNavigationItem(
          label: 'Emergency',
          icon: Icons.emergency_outlined,
          selectedIcon: Icons.emergency,
          route: AppRoutes.adminEmergency,
        ),
        RoleNavigationItem(
          label: 'Support',
          icon: Icons.support_agent_outlined,
          selectedIcon: Icons.support_agent,
          route: AppRoutes.adminSupport,
        ),
      ],
      UserRole.unsupported => const [
        RoleNavigationItem(
          label: 'Profile',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          route: AppRoutes.profile,
        ),
      ],
    };
  }

  static bool canCreateListing(UserRole role) {
    return role == UserRole.producer || role == UserRole.prosumer || role == UserRole.admin;
  }

  static bool canBuyEnergy(UserRole role) {
    return role == UserRole.consumer || role == UserRole.prosumer;
  }

  static bool canUseWalletActions(UserRole role) {
    return role == UserRole.consumer || role == UserRole.producer || role == UserRole.prosumer || role == UserRole.admin;
  }

  static bool canAccessRoute(UserRole role, String path) {
    if (role == UserRole.unsupported) {
      return path == AppRoutes.profile || path == AppRoutes.dashboard;
    }
    if (path == AppRoutes.dashboard || path == AppRoutes.profile) return true;
    if (path == AppRoutes.notifications) return true;
    if (path == AppRoutes.sustainability) return true;
    if (path == AppRoutes.smartMeter) return true;
    if (path == AppRoutes.createListing) return canCreateListing(role);
    if (path == AppRoutes.kyc || path == AppRoutes.kycForm) return true;

    if (path == AppRoutes.wallet || path.startsWith('${AppRoutes.wallet}/') ||
        path == AppRoutes.addFunds || path == AppRoutes.withdraw || path == AppRoutes.walletActivity) {
      return canUseWalletActions(role);
    }
    if (path == AppRoutes.marketplace || path.startsWith('${AppRoutes.marketplace}/')) {
      return role == UserRole.consumer || role == UserRole.prosumer || role == UserRole.admin;
    }
    if (path == AppRoutes.purchases) return role == UserRole.consumer || role == UserRole.prosumer;
    if (path == AppRoutes.sales || path == AppRoutes.myListings) return role == UserRole.producer || role == UserRole.prosumer || role == UserRole.admin;
    if (path == AppRoutes.trade) return role == UserRole.prosumer;
    if (path == AppRoutes.analytics) return role == UserRole.producer || role == UserRole.prosumer;
    if (path == AppRoutes.tasks || path == AppRoutes.diagnostics || path == AppRoutes.reportFault) return role == UserRole.technician;
    if (path == AppRoutes.gridStatus || path == AppRoutes.alerts) return role == UserRole.gridOperator;
    if (path == AppRoutes.emergencyForm || path == AppRoutes.emergencyRequests || path.startsWith('${AppRoutes.emergencyRequests}/')) {
      return role == UserRole.consumer || role == UserRole.admin;
    }
    if (path == AppRoutes.supportTickets || path.startsWith('${AppRoutes.supportTickets}/')) return role != UserRole.unsupported;
    if (path == AppRoutes.adminEmergency) return role == UserRole.admin;
    if (path == AppRoutes.adminSupport) return role == UserRole.admin;
    if (path == AppRoutes.adminKyc) return role == UserRole.admin;
    if (path == AppRoutes.adminSuspended) return role == UserRole.admin;
    if (path == AppRoutes.suspendedListings || path == AppRoutes.adminUsers ||
        path == AppRoutes.adminModeration || path == AppRoutes.adminDisputes ||
        path == AppRoutes.auditLogs || path == AppRoutes.adminListings ||
        path == AppRoutes.adminReports) return role == UserRole.admin;
    return false;
  }
}
