import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../features/authentication/data/auth_repository.dart';
import '../features/authentication/data/auth_state.dart';
import '../features/authentication/presentation/login_screen.dart';
import '../features/authentication/presentation/register_screen.dart';
import '../features/authentication/presentation/supabase_setup_screen.dart';
import '../features/analytics/presentation/analytics_screen.dart';
import '../features/ai/presentation/sustainability_screen.dart';
import '../features/admin_dashboard/presentation/admin_users_screen.dart';
import '../features/sales/presentation/producer_sales_screen.dart';
import '../features/admin_dashboard/presentation/admin_disputes_screen.dart';
import '../features/admin_dashboard/presentation/admin_audit_screen.dart';
import '../features/emergency/presentation/emergency_form_screen.dart';
import '../features/emergency/presentation/emergency_requests_screen.dart';
import '../features/emergency/presentation/admin_emergency_screen.dart';

import '../features/support/presentation/support_tickets_screen.dart';
import '../features/support/presentation/ticket_detail_screen.dart';
import '../features/support/presentation/admin_support_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/dashboard/presentation/dashboard_shell.dart';
import '../features/developer_debug/presentation/developer_debug_screen.dart';
import '../features/dashboard/presentation/simple_tab_screen.dart';
import '../features/kyc/presentation/kyc_form_screen.dart';
import '../features/kyc/presentation/kyc_status_screen.dart';
import '../features/kyc/presentation/admin_kyc_screen.dart';
import '../features/suspended_users/presentation/suspended_users_screen.dart';
import '../features/purchases/presentation/purchases_screen.dart';
import '../features/escrow/presentation/default_case_details_screen.dart';
import '../features/escrow/presentation/delivery_verification_screen.dart';
import '../features/escrow/presentation/escrow_debug_panel_screen.dart';
import '../features/escrow/presentation/escrow_details_screen.dart';
import '../features/escrow/presentation/raise_dispute_screen.dart';
import '../features/escrow/presentation/resolution_summary_screen.dart';
import '../features/marketplace/presentation/create_listing_screen.dart';
import '../features/marketplace/presentation/listing_details_screen.dart';
import '../features/marketplace/presentation/marketplace_screen.dart';
import '../features/marketplace/presentation/my_listings_screen.dart';
import '../features/marketplace/presentation/purchase_confirmation_screen.dart';
import '../features/marketplace/presentation/purchase_success_screen.dart';
import '../features/notifications/presentation/notification_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/role_access/role_navigation.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/wallet/presentation/wallet_screen.dart';
import '../features/wallet/presentation/add_funds_screen.dart';
import '../features/wallet/presentation/receipt_screen.dart';
import '../features/wallet/presentation/transaction_details_screen.dart';
import '../features/wallet/presentation/wallet_activity_screen.dart';
import '../features/wallet/presentation/withdraw_screen.dart';
import '../features/meter/presentation/meter_display_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final session = ref.watch(currentSessionProvider);
  final profileState = session == null
      ? null
      : ref.watch(currentProfileProvider);
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final path = state.uri.path;
      final isConfigured = ref.read(appConfigProvider).isSupabaseConfigured;
      final profile = profileState?.valueOrNull;
      final isAuthRoute = path == AppRoutes.login || path == AppRoutes.register;
      final isSetupRoute = path == AppRoutes.setup;
      final isSplashRoute = path == AppRoutes.splash;

      if (!isConfigured) {
        return isSetupRoute ? null : AppRoutes.setup;
      }

      if (isSetupRoute) {
        return AppRoutes.splash;
      }

      // Wait for auth initialization before making any redirect decisions.
      // This prevents redirecting to login while Supabase is still restoring
      // the session from local storage on app startup.
      if (authState == AuthState.initializing) {
        // Stay on splash screen until we know the auth state
        return isSplashRoute ? null : AppRoutes.splash;
      }

      if (isSplashRoute) {
        return session == null ? AppRoutes.login : AppRoutes.dashboard;
      }

      if (session == null && !isAuthRoute) {
        return AppRoutes.login;
      }

      if (session != null && isAuthRoute) {
        return AppRoutes.dashboard;
      }

      if (session != null && profile != null) {
        if (!profile.isActive &&
            path != AppRoutes.dashboard &&
            path != AppRoutes.profile) {
          return AppRoutes.dashboard;
        }
        if (!RoleAccessPolicy.canAccessRoute(profile.role, path)) {
          return AppRoutes.accessDeniedHome;
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.setup,
        builder: (context, state) => const SupabaseSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return DashboardShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.marketplace,
                builder: (context, state) => const MarketplaceScreen(),
                routes: [
                  GoRoute(
                    path: 'purchase-success/:purchaseId',
                    builder: (context, state) => const PurchaseSuccessScreen(),
                  ),
                  GoRoute(
                    path: ':listingId',
                    builder: (context, state) => ListingDetailsScreen(
                      listingId: state.pathParameters['listingId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'confirm',
                        builder: (context, state) => PurchaseConfirmationScreen(
                          listingId: state.pathParameters['listingId']!,
                          quantityKwh:
                              double.tryParse(
                                state.uri.queryParameters['qty'] ?? '0.5',
                              ) ??
                              0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: AppRoutes.myListings,
                builder: (context, state) => const MyListingsScreen(),
              ),
              GoRoute(
                path: AppRoutes.trade,
                builder: (context, state) => const SimpleTabScreen(
                  title: 'Trade',
                  icon: Icons.swap_horiz_outlined,
                  message:
                      'Trade combines buying, selling, purchases, sales, and listings for prosumers.',
                ),
              ),
              GoRoute(
                path: AppRoutes.tasks,
                builder: (context, state) => const SimpleTabScreen(
                  title: 'Tasks',
                  icon: Icons.task_alt_outlined,
                  message:
                      'Technician tasks are development data until maintenance APIs are connected.',
                ),
              ),
              GoRoute(
                path: AppRoutes.gridStatus,
                builder: (context, state) => const SimpleTabScreen(
                  title: 'Grid Status',
                  icon: Icons.grid_view_outlined,
                  message:
                      'Grid status uses derived dashboard values until aggregate grid APIs are connected.',
                ),
              ),
              GoRoute(
                path: AppRoutes.adminUsers,
                builder: (context, state) => const AdminUsersScreen(),
              ),
              GoRoute(
                path: AppRoutes.adminListings,
                builder: (context, state) => const AdminUsersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.wallet,
                builder: (context, state) => const WalletScreen(),
                routes: [
                  GoRoute(
                    path: 'activity',
                    builder: (context, state) => const WalletActivityScreen(),
                  ),
                  GoRoute(
                    path: 'add-funds',
                    builder: (context, state) => const AddFundsScreen(),
                  ),
                  GoRoute(
                    path: 'withdraw',
                    builder: (context, state) => const WithdrawScreen(),
                  ),
                  GoRoute(
                    path: 'transactions/:transactionId',
                    builder: (context, state) => TransactionDetailsScreen(
                      transactionId: state.pathParameters['transactionId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'receipt',
                        builder: (context, state) => ReceiptScreen(
                          transactionId: state.pathParameters['transactionId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: AppRoutes.purchases,
                builder: (context, state) => const PurchasesScreen(),
              ),
              GoRoute(
                path: AppRoutes.sales,
                builder: (context, state) => const ProducerSalesScreen(),
              ),
              GoRoute(
                path: AppRoutes.diagnostics,
                builder: (context, state) => const SimpleTabScreen(
                  title: 'Diagnostics',
                  icon: Icons.build_circle_outlined,
                  message:
                      'Operational diagnostics are development data until device APIs are connected.',
                ),
              ),
              GoRoute(
                path: AppRoutes.adminModeration,
                builder: (context, state) => const SimpleTabScreen(
                  title: 'Moderate Listings',
                  icon: Icons.gavel_outlined,
                  message: 'Listing moderation is a development placeholder.',
                ),
              ),
              GoRoute(
                path: AppRoutes.adminReports,
                builder: (context, state) => const SimpleTabScreen(
                  title: 'Reports',
                  icon: Icons.assessment_outlined,
                  message:
                      'Admin reports are a development placeholder until platform reporting APIs are connected.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.analytics,
                builder: (context, state) => const AnalyticsScreen(),
              ),
              GoRoute(
                path: AppRoutes.alerts,
                builder: (context, state) => const SimpleTabScreen(
                  title: 'Alerts',
                  icon: Icons.warning_amber_outlined,
                  message:
                      'Operational alerts are development data until grid operations APIs are connected.',
                ),
              ),
              GoRoute(
                path: AppRoutes.suspendedListings,
                builder: (context, state) => const SimpleTabScreen(
                  title: 'Suspended Listings',
                  icon: Icons.block_outlined,
                  message:
                      'Moderation data is a development placeholder until admin marketplace APIs are connected.',
                ),
              ),
              GoRoute(
                path: AppRoutes.adminDisputes,
                builder: (context, state) => const AdminDisputesScreen(),
              ),
              GoRoute(
                path: AppRoutes.auditLogs,
                builder: (context, state) => const AdminAuditScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
          // Emergency Assistance branch (Consumer & Admin)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.emergencyRequests,
                builder: (context, state) => const EmergencyRequestsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const EmergencyFormScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: AppRoutes.adminEmergency,
                builder: (context, state) => const AdminEmergencyScreen(),
              ),
            ],
          ),
          // Support Tickets branch (accessible from Profile)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.supportTickets,
                builder: (context, state) => const SupportTicketsScreen(),
                routes: [
                  GoRoute(
                    path: ':ticketId',
                    builder: (context, state) => TicketDetailScreen(
                      ticketId: state.pathParameters['ticketId']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: AppRoutes.adminSupport,
                builder: (context, state) => const AdminSupportScreen(),
              ),
            ],
          ),
          // Admin KYC branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.adminKyc,
                builder: (context, state) => const AdminKycScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.createListing,
        builder: (context, state) => const CreateListingScreen(),
      ),
      GoRoute(
        path: AppRoutes.kyc,
        builder: (context, state) => const KycStatusScreen(),
      ),
      GoRoute(
        path: AppRoutes.kycForm,
        builder: (context, state) => const KycFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminSuspended,
        builder: (context, state) => const SuspendedUsersScreen(),
      ),
      GoRoute(
        path: AppRoutes.reportFault,
        builder: (context, state) => const SimpleTabScreen(
          title: 'Report Fault',
          icon: Icons.report_outlined,
          message:
              'Fault reporting is a development placeholder for technician workflows.',
        ),
      ),
      GoRoute(
        path: '/escrow/:escrowId',
        builder: (context, state) =>
            EscrowDetailsScreen(escrowId: state.pathParameters['escrowId']!),
        routes: [
          GoRoute(
            path: 'verify',
            builder: (context, state) => DeliveryVerificationScreen(
              escrowId: state.pathParameters['escrowId']!,
            ),
          ),
          GoRoute(
            path: 'dispute',
            builder: (context, state) =>
                RaiseDisputeScreen(escrowId: state.pathParameters['escrowId']!),
          ),
          GoRoute(
            path: 'resolution',
            builder: (context, state) => ResolutionSummaryScreen(
              escrowId: state.pathParameters['escrowId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/default-cases/:caseId',
        builder: (context, state) =>
            DefaultCaseDetailsScreen(caseId: state.pathParameters['caseId']!),
      ),
      GoRoute(
        path: AppRoutes.escrowDebug,
        builder: (context, state) => const EscrowDebugPanelScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationScreen(),
      ),
      GoRoute(
        path: AppRoutes.sustainability,
        builder: (context, state) => const SustainabilityScreen(),
      ),
      GoRoute(
        path: AppRoutes.smartMeter,
        builder: (context, state) => const MeterDisplayPage(),
      ),
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.developerDebug,
          builder: (context, state) => const DeveloperDebugScreen(),
        ),
    ],
  );
});

class AppRoutes {
  static const splash = '/';
  static const setup = '/setup';
  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/dashboard';
  static const marketplace = '/marketplace';
  static const createListing = '/create-listing';
  static const myListings = '/my-listings';
  static const purchases = '/purchases';
  static const sales = '/sales';
  static const trade = '/trade';
  static const tasks = '/tasks';
  static const diagnostics = '/diagnostics';
  static const reportFault = '/report-fault';
  static const alerts = '/alerts';
  static const gridStatus = '/grid-status';
  static const suspendedListings = '/suspended-listings';
  static const adminUsers = '/admin/users';
  static const adminModeration = '/admin/moderation';
  static const adminDisputes = '/admin/disputes';
  static const auditLogs = '/admin/audit';
  static const adminListings = '/admin/listings';
  static const adminReports = '/admin/reports';
  static const wallet = '/wallet';
  static const walletActivity = '/wallet/activity';
  static const addFunds = '/wallet/add-funds';
  static const withdraw = '/wallet/withdraw';
  static const escrowDebug = '/escrow-debug';
  static const developerDebug = '/developer-debug';
  static const notifications = '/notifications';
  static const sustainability = '/sustainability';
  static const smartMeter = '/meter';
  static const analytics = '/analytics';
  static const profile = '/profile';
  static const emergencyForm = '/emergency/new';
  static const emergencyRequests = '/emergency';
  static const kyc = '/kyc';
  static const kycForm = '/kyc/form';
  static const adminKyc = '/admin/kyc';
  static const adminSuspended = '/admin/suspended';
  static const supportTickets = '/support';
  static const adminEmergency = '/admin/emergency';
  static const adminSupport = '/admin/support';

  static String ticketDetail(String ticketId) => '/support/$ticketId';

  static String transactionDetails(String transactionId) {
    return '/wallet/transactions/$transactionId';
  }

  static String receipt(String transactionId) {
    return '/wallet/transactions/$transactionId/receipt';
  }

  static String escrowDetails(String escrowId) => '/escrow/$escrowId';
  static String deliveryVerification(String escrowId) =>
      '/escrow/$escrowId/verify';
  static String raiseDispute(String escrowId) => '/escrow/$escrowId/dispute';
  static String resolutionSummary(String escrowId) =>
      '/escrow/$escrowId/resolution';
  static String defaultCaseDetails(String caseId) => '/default-cases/$caseId';

  static const accessDeniedHome = '/dashboard?accessDenied=1';
}
