import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/app.dart';
import 'package:frontend/app/router.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/widgets/voltshare_ui.dart';
import 'package:frontend/features/analytics/presentation/analytics_screen.dart';
import 'package:frontend/features/authentication/data/auth_repository.dart';
import 'package:frontend/features/authentication/domain/user_profile.dart';
import 'package:frontend/features/authentication/domain/user_role.dart';
import 'package:frontend/features/admin_dashboard/data/admin_dashboard_models.dart';
import 'package:frontend/features/admin_dashboard/data/admin_dashboard_repository.dart';
import 'package:frontend/features/admin_dashboard/presentation/admin_dashboard_screen.dart';
import 'package:frontend/features/authentication/presentation/supabase_setup_screen.dart';
import 'package:frontend/features/dashboard/data/dashboard_api_repository.dart';
import 'package:frontend/features/dashboard/data/dashboard_mock_repository.dart';
import 'package:frontend/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:frontend/features/dashboard/presentation/dashboard_screen.dart';
import 'package:frontend/features/dashboard/providers/dashboard_provider.dart';
import 'package:frontend/features/escrow/data/energy_delivery_verification_service.dart';
import 'package:frontend/features/escrow/data/escrow_mock_repository.dart';
import 'package:frontend/features/escrow/domain/delivery_verification.dart';
import 'package:frontend/features/escrow/domain/escrow_agreement.dart';
import 'package:frontend/features/escrow/domain/escrow_operation_record.dart';
import 'package:frontend/features/escrow/domain/trade_default_case.dart';
import 'package:frontend/features/escrow/providers/escrow_provider.dart';
import 'package:frontend/features/escrow/services/escrow_funding_service.dart';
import 'package:frontend/features/escrow/services/escrow_state_machine.dart';
import 'package:frontend/features/marketplace/data/marketplace_mock_repository.dart';
import 'package:frontend/features/marketplace/data/mock_backend_store.dart';
import 'package:frontend/features/marketplace/domain/energy_listing.dart';
import 'package:frontend/features/marketplace/domain/energy_purchase.dart';
import 'package:frontend/features/marketplace/domain/marketplace_filter.dart';
import 'package:frontend/features/marketplace/domain/sell_listing_draft.dart';
import 'package:frontend/features/marketplace/presentation/create_listing_screen.dart';
import 'package:frontend/features/marketplace/presentation/marketplace_screen.dart';
import 'package:frontend/features/marketplace/presentation/purchase_confirmation_screen.dart';
import 'package:frontend/features/marketplace/providers/marketplace_provider.dart';
import 'package:frontend/features/profile/presentation/profile_screen.dart';
import 'package:frontend/features/role_access/role_navigation.dart';
import 'package:frontend/features/wallet/data/wallet_mock_repository.dart';
import 'package:frontend/features/wallet/domain/wallet_transaction.dart';
import 'package:frontend/features/wallet/domain/withdrawal_request.dart';
import 'package:frontend/features/wallet/presentation/add_funds_screen.dart';
import 'package:frontend/features/wallet/presentation/receipt_screen.dart';
import 'package:frontend/features/wallet/presentation/transaction_details_screen.dart';
import 'package:frontend/features/wallet/presentation/wallet_activity_screen.dart';
import 'package:frontend/features/wallet/presentation/wallet_screen.dart';
import 'package:frontend/features/wallet/presentation/withdraw_screen.dart';
import 'package:frontend/features/wallet/providers/wallet_provider.dart';
import 'package:frontend/features/wallet/widgets/wallet_widgets.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('backend selection', () {
    test('default app config uses live mode unless mock is explicit', () {
      const config = AppConfig(supabaseUrl: '', supabasePublishableKey: '');

      expect(config.useMockBackend, isFalse);
      expect(config.isLiveMode, isTrue);
      expect(config.isMockMode, isFalse);
    });

    test('dashboard repository selects mock or live implementation', () {
      final mockContainer = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              supabaseUrl: '',
              supabasePublishableKey: '',
              useMockBackend: true,
            ),
          ),
        ],
      );
      addTearDown(mockContainer.dispose);
      expect(
        mockContainer.read(dashboardRepositoryProvider),
        isA<DashboardMockRepository>(),
      );

      final liveContainer = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              supabaseUrl: 'https://example.supabase.co',
              supabasePublishableKey: 'publishable',
              apiBaseUrl: 'http://localhost:8000/api/v1',
              useMockBackend: false,
            ),
          ),
        ],
      );
      addTearDown(liveContainer.dispose);
      expect(
        liveContainer.read(dashboardRepositoryProvider),
        isA<DashboardApiRepository>(),
      );
    });
  });

  group('role access policy', () {
    test('navigation differs by role', () {
      expect(
        RoleAccessPolicy.navigationFor(
          UserRole.consumer,
        ).map((item) => item.label),
        containsAllInOrder([
          'Home',
          'Marketplace',
          'Purchases',
          'Wallet',
          'Profile',
        ]),
      );
      expect(
        RoleAccessPolicy.navigationFor(
          UserRole.producer,
        ).map((item) => item.label),
        containsAllInOrder([
          'Home',
          'Listings',
          'Sales',
          'Wallet',
          'Analytics',
          'Profile',
        ]),
      );
      expect(
        RoleAccessPolicy.navigationFor(
          UserRole.prosumer,
        ).map((item) => item.label),
        containsAllInOrder([
          'Home',
          'Marketplace',
          'Trade',
          'Wallet',
          'Analytics',
          'Profile',
        ]),
      );
      expect(
        RoleAccessPolicy.navigationFor(
          UserRole.technician,
        ).map((item) => item.label),
        containsAllInOrder(['Home', 'Tasks', 'Diagnostics', 'Profile']),
      );
      expect(
        RoleAccessPolicy.navigationFor(
          UserRole.gridOperator,
        ).map((item) => item.label),
        containsAllInOrder(['Home', 'Grid', 'Alerts', 'Profile']),
      );
      expect(
        RoleAccessPolicy.navigationFor(
          UserRole.admin,
        ).map((item) => item.label),
        containsAllInOrder([
          'Overview',
          'Users',
          'KYC',
          'Disputes',
          'Emergency',
          'Support',
        ]),
      );
    });

    test('route guards allow and deny role-specific routes', () {
      expect(
        RoleAccessPolicy.canAccessRoute(
          UserRole.consumer,
          AppRoutes.createListing,
        ),
        isFalse,
      );
      expect(
        RoleAccessPolicy.canAccessRoute(
          UserRole.producer,
          AppRoutes.createListing,
        ),
        isTrue,
      );
      expect(
        RoleAccessPolicy.canAccessRoute(
          UserRole.technician,
          AppRoutes.withdraw,
        ),
        isFalse,
      );
      expect(
        RoleAccessPolicy.canAccessRoute(
          UserRole.gridOperator,
          AppRoutes.marketplace,
        ),
        isFalse,
      );
      expect(
        RoleAccessPolicy.canAccessRoute(UserRole.admin, AppRoutes.adminUsers),
        isTrue,
      );
      expect(
        RoleAccessPolicy.canAccessRoute(UserRole.consumer, AppRoutes.analytics),
        isFalse,
      );
      expect(
        RoleAccessPolicy.canAccessRoute(UserRole.producer, AppRoutes.purchases),
        isFalse,
      );
      expect(
        RoleAccessPolicy.canAccessRoute(UserRole.technician, AppRoutes.wallet),
        isFalse,
      );
    });

    test('unsupported role is controlled', () {
      expect(UserRole.fromValue('owner'), UserRole.unsupported);
      expect(
        RoleAccessPolicy.canAccessRoute(
          UserRole.unsupported,
          AppRoutes.createListing,
        ),
        isFalse,
      );
    });
  });

  group('dashboard provider', () {
    test('initial loading then successful data load', () async {
      final notifier = DashboardNotifier(
        DashboardMockRepository(
          random: Random(1),
          initialTime: DateTime(2026, 7, 18, 12),
        ),
        autoStartTimer: false,
      );
      expect(notifier.state.isLoading, isTrue);

      await notifier.load();

      final snapshot = notifier.state.value;
      expect(snapshot, isNotNull);
      expect(snapshot!.solarGenerationTodayKwh, greaterThan(0));
      notifier.dispose();
    });

    test(
      'periodic mock update changes values and stops after dispose',
      () async {
        final repository = _CountingDashboardRepository();
        final notifier = DashboardNotifier(
          repository,
          updateInterval: const Duration(milliseconds: 10),
        );

        await notifier.load();
        await Future<void>.delayed(const Duration(milliseconds: 35));
        expect(repository.simulateCount, greaterThanOrEqualTo(1));

        notifier.dispose();
        final countAfterDispose = repository.simulateCount;
        await Future<void>.delayed(const Duration(milliseconds: 35));
        expect(repository.simulateCount, countAfterDispose);
      },
    );

    test('refresh keeps readings within realistic constraints', () async {
      final notifier = DashboardNotifier(
        DashboardMockRepository(
          random: Random(2),
          initialTime: DateTime(2026, 7, 18, 14),
        ),
        autoStartTimer: false,
      );
      await notifier.load();
      await notifier.refresh();

      final snapshot = notifier.state.value!;
      expect(snapshot.batteryPercentage, inInclusiveRange(0, 100));
      expect(snapshot.batteryHealthPercentage, inInclusiveRange(0, 100));
      expect(snapshot.availableToSellKwh, greaterThanOrEqualTo(0));
      expect(snapshot.co2AvoidedKg, greaterThanOrEqualTo(18.6));
      expect(snapshot.gridSavings, greaterThanOrEqualTo(214));
      notifier.dispose();
    });

    test('error recovery retries successfully', () async {
      final repository = _RecoveringDashboardRepository();
      final notifier = DashboardNotifier(repository, autoStartTimer: false);

      await notifier.load();
      expect(notifier.state.hasError, isTrue);

      repository.shouldFail = false;
      await notifier.retry();

      expect(notifier.state.hasValue, isTrue);
      expect(notifier.state.value, isNotNull);
      notifier.dispose();
    });
  });

  group('marketplace repository', () {
    test('loads, searches, filters, and sorts listings', () async {
      final store0 = MockBackendStore.fresh();

      final repository = MarketplaceMockRepository(
        currentUserId: 'test-user',
        currentUserRole: 'producer',
        store: store0,
        now: DateTime(2026, 7, 18, 12),
      );

      final all = await repository.loadListings(const MarketplaceQuery());
      expect(all, isNotEmpty);

      final search = await repository.loadListings(
        const MarketplaceQuery(search: 'ravi'),
      );
      expect(search.single.sellerName, contains('Ravi'));

      final filtered = await repository.loadListings(
        const MarketplaceQuery(
          filters: {
            MarketplaceFilter.solarOnly,
            MarketplaceFilter.batteryBacked,
          },
          sort: MarketplaceSort.rating,
        ),
      );
      expect(filtered.every((item) => item.batteryBacked), isTrue);
      expect(
        filtered.every(
          (item) =>
              item.energySource == EnergySource.solar ||
              item.energySource == EnergySource.communitySolar,
        ),
        isTrue,
      );
    });

    test('calculates quantity prices and blocks invalid inventory', () async {
      final store = MockBackendStore.fresh();
      final repository = MarketplaceMockRepository(
        currentUserId: 'test-user',
        currentUserRole: 'producer',
        store: store,
        now: DateTime(2026, 7, 18, 12),
      );
      final listing = await repository.listingById('ravi');
      final quote = repository.quote(listing, 1.5);

      expect(quote.subtotal, closeTo(12.30, 0.01));
      expect(quote.platformFee, greaterThan(0));
      expect(
        () => repository.quote(listing, listing.availableEnergyKwh + 1),
        throwsA(isA<MarketplaceException>()),
      );
    });

    test(
      'successful purchase reduces inventory and role restriction blocks buy',
      () async {
        final store = MockBackendStore.fresh();
        final repository = MarketplaceMockRepository(
          currentUserId: 'test-user',
          currentUserRole: 'prosumer',
          store: store,
          now: DateTime(2026, 7, 18, 12),
        );

        final purchase = await repository.purchase(
          listingId: 'ravi',
          buyerId: 'buyer',
          quantityKwh: 1,
          canBuy: true,
        );
        expect(purchase.status, PurchaseStatus.completed);
        expect(
          (await repository.listingById('ravi')).availableEnergyKwh,
          closeTo(99.0, 0.01),
        );

        expect(
          () => repository.purchase(
            listingId: 'ravi',
            buyerId: 'readonly',
            quantityKwh: 1,
            canBuy: false,
          ),
          throwsA(isA<MarketplaceException>()),
        );
      },
    );

    test('creates and cancels session listing', () async {
      final store = MockBackendStore.fresh();
      final repository = MarketplaceMockRepository(
        currentUserId: 'test-user',
        currentUserRole: 'producer',
        store: store,
        now: DateTime(2026, 7, 18, 12),
      );
      final listing = await repository.createListing(
        canSell: true,
        maxAvailableKwh: 8,
        draft: SellListingDraft(
          availableEnergyKwh: 2,
          pricePerKwh: 8,
          batteryReservePercentage: 30,
          availabilityStart: DateTime(2026, 7, 18, 13),
          availabilityEnd: DateTime(2026, 7, 18, 17),
          energySource: EnergySource.solar,
        ),
      );

      expect((await repository.myListings()).single.id, listing.id);
      await repository.cancelListing(listing.id);
      expect(
        (await repository.myListings()).single.listingStatus,
        ListingStatus.cancelled,
      );
    });
  });

  group('wallet repository', () {
    test('loads initial wallet and summary', () async {
      final repository = WalletMockRepository(now: DateTime(2026, 7, 18, 12));

      final wallet = await repository.loadWallet();
      final summary = repository.summary();

      expect(wallet.availableBalancePaise, 125000);
      expect(wallet.pendingBalancePaise, 32000);
      expect(summary.energyBoughtKwh, greaterThan(0));
      expect(summary.energySoldKwh, greaterThan(0));
    });

    test('successful and invalid top-up update balances safely', () async {
      final repository = WalletMockRepository(now: DateTime(2026, 7, 18, 12));

      await repository.addFunds(
        amountPaise: 25000,
        method: FundingMethod.demoBalance,
        label: 'test',
        role: UserRole.consumer,
      );
      expect((await repository.loadWallet()).availableBalancePaise, 150000);

      expect(
        () => repository.addFunds(
          amountPaise: -1,
          method: FundingMethod.demoBalance,
          label: 'bad',
          role: UserRole.consumer,
        ),
        throwsA(isA<WalletException>()),
      );
    });

    test('purchase deducts balance and blocks insufficient balance', () async {
      final walletRepository = WalletMockRepository(
        now: DateTime(2026, 7, 18, 12),
      );
      final wStore = MockBackendStore.fresh();
      final marketplaceRepository = MarketplaceMockRepository(
        currentUserId: 'test-buyer',
        currentUserRole: 'consumer',
        store: wStore,
        now: DateTime(2026, 7, 18, 12),
      );
      final listing = await marketplaceRepository.listingById('ravi');
      final purchase = await marketplaceRepository.purchase(
        listingId: 'ravi',
        buyerId: 'test-buyer',
        quantityKwh: 1,
        canBuy: true,
      );

      await walletRepository.recordPurchase(
        purchase: purchase,
        listing: listing,
        role: UserRole.consumer,
      );
      expect(
        (await walletRepository.loadWallet()).availableBalancePaise,
        lessThan(125000),
      );

      expect(
        () => walletRepository.recordPurchase(
          purchase: EnergyPurchase(
            id: 'PUR-HUGE',
            listingId: listing.id,
            buyerId: 'test-buyer',
            sellerId: listing.sellerId,
            quantityKwh: 1000,
            unitPrice: 500,
            platformFee: 0,
            totalAmount: 500000,
            estimatedSavings: 0,
            co2ImpactKg: 0,
            purchasedAt: DateTime(2026, 7, 18, 12),
            status: PurchaseStatus.completed,
          ),
          listing: listing,
          role: UserRole.consumer,
        ),
        throwsA(isA<WalletException>()),
      );
    });

    test('sale settlement moves pending to available', () async {
      final walletRepository = WalletMockRepository(
        now: DateTime(2026, 7, 18, 12),
      );
      final listing = await MarketplaceMockRepository(
        currentUserId: 'test-user',
        currentUserRole: 'producer',
        store: MockBackendStore.fresh(),
        now: DateTime(2026, 7, 18, 12),
      ).listingById('ravi');

      await walletRepository.recordSale(listing: listing, quantityKwh: 1);
      final withPending = await walletRepository.loadWallet();
      expect(withPending.pendingBalancePaise, greaterThan(32000));

      await walletRepository.settlePendingSales();
      final settled = await walletRepository.loadWallet();
      expect(
        settled.pendingBalancePaise,
        lessThanOrEqualTo(withPending.pendingBalancePaise),
      );
      expect(
        settled.availableBalancePaise,
        greaterThan(withPending.availableBalancePaise),
      );
    });

    test('withdrawal rules and refund eligibility are enforced', () async {
      final repository = WalletMockRepository(now: DateTime(2026, 7, 18, 12));

      expect(
        () => repository.withdraw(
          amountPaise: 50000,
          method: WithdrawalMethod.demoSettlement,
          accountLabel: 'demo',
          role: UserRole.consumer,
        ),
        throwsA(isA<WalletException>()),
      );

      await repository.withdraw(
        amountPaise: 25000,
        method: WithdrawalMethod.demoSettlement,
        accountLabel: 'demo',
        role: UserRole.prosumer,
      );
      expect((await repository.loadWallet()).availableBalancePaise, 100000);

      final refund = await repository.refund('TXN-SEED-2');
      expect(refund.type, WalletTransactionType.refund);
      expect(
        () => repository.refund('TXN-SEED-2'),
        throwsA(isA<WalletException>()),
      );
    });

    test('filters and sorts transaction history', () async {
      final repository = WalletMockRepository(now: DateTime(2026, 7, 18, 12));

      final purchases = await repository.transactions(
        const TransactionHistoryQuery(filter: TransactionFilter.purchases),
      );
      expect(
        purchases.every(
          (item) => item.type == WalletTransactionType.energyPurchase,
        ),
        isTrue,
      );

      final highest = await repository.transactions(
        const TransactionHistoryQuery(sort: TransactionSort.highestAmount),
      );
      expect(
        highest.first.amountPaise,
        greaterThanOrEqualTo(highest.last.amountPaise),
      );

      final search = await repository.transactions(
        const TransactionHistoryQuery(search: 'ravi'),
      );
      expect(search, isNotEmpty);
    });
  });

  group('escrow repository and settlement', () {
    test('creates funded escrow with integrity hash', () async {
      final context = await _escrowTestContext();

      final escrow = await context.escrowRepository.createFundedEscrow(
        purchase: context.purchase,
        listing: context.listing,
      );

      expect(escrow.status, EscrowStatus.energyDeliveryPending);
      expect(escrow.totalHeldPaise, greaterThan(0));
      expect(context.escrowRepository.verifyHash(escrow), isTrue);
    });

    test(
      'full delivery settlement conserves money and prevents duplicate release',
      () async {
        final context = await _escrowTestContext();
        final escrow = await context.escrowRepository.createFundedEscrow(
          purchase: context.purchase,
          listing: context.listing,
        );
        final verification = const MockEnergyDeliveryVerificationService()
            .verify(
              DeliveryVerificationInput(
                escrow: escrow,
                simulatedMeterReadingKwh: 1,
                deliveryStart: DateTime(2026, 7, 18, 12),
                deliveryEnd: DateTime(2026, 7, 18, 13),
                meterIdentifier: 'MTR-DEMO-001',
                integrityOk: true,
              ),
            );

        final first = context.escrowRepository.settle(
          escrow: escrow,
          verification: verification,
          idempotencyKey: 'settle-full',
        );
        final second = context.escrowRepository.settle(
          escrow: escrow,
          verification: verification,
          idempotencyKey: 'settle-full',
        );

        expect(first.conservesMoney, isTrue);
        expect(first.sellerReleasePaise, greaterThan(0));
        expect(first.buyerRefundPaise, 0);
        expect(second.sellerReleasePaise, first.sellerReleasePaise);
      },
    );

    test(
      'partial delivery creates proportional default case and refund',
      () async {
        final context = await _escrowTestContext();
        final escrow = await context.escrowRepository.createFundedEscrow(
          purchase: context.purchase,
          listing: context.listing,
        );
        final verification = const MockEnergyDeliveryVerificationService()
            .verify(
              DeliveryVerificationInput(
                escrow: escrow,
                simulatedMeterReadingKwh: 0.6,
                deliveryStart: DateTime(2026, 7, 18, 12),
                deliveryEnd: DateTime(2026, 7, 18, 13),
                meterIdentifier: 'MTR-DEMO-001',
                integrityOk: true,
              ),
            );

        final result = context.escrowRepository.settle(
          escrow: escrow,
          verification: verification,
          idempotencyKey: 'settle-partial',
        );

        expect(result.conservesMoney, isTrue);
        expect(result.buyerRefundPaise, greaterThan(0));
        expect(result.defaultCase?.reason, DefaultReason.partialDelivery);
      },
    );

    test('tampering freezes funds and creates default case', () async {
      final context = await _escrowTestContext();
      final escrow = await context.escrowRepository.createFundedEscrow(
        purchase: context.purchase,
        listing: context.listing,
      );
      final verification = const MockEnergyDeliveryVerificationService().verify(
        DeliveryVerificationInput(
          escrow: escrow,
          simulatedMeterReadingKwh: 1,
          deliveryStart: DateTime(2026, 7, 18, 12),
          deliveryEnd: DateTime(2026, 7, 18, 13),
          meterIdentifier: 'MTR-DEMO-001',
          integrityOk: false,
        ),
      );

      final result = context.escrowRepository.settle(
        escrow: escrow,
        verification: verification,
        idempotencyKey: 'settle-tamper',
      );

      expect(result.frozenPaise, escrow.totalHeldPaise);
      expect(result.defaultCase?.reason, DefaultReason.suspectedTampering);
      expect(result.escrow.status, EscrowStatus.frozen);
    });

    test('dispute creation marks escrow under review', () async {
      final context = await _escrowTestContext();
      final escrow = await context.escrowRepository.createFundedEscrow(
        purchase: context.purchase,
        listing: context.listing,
      );

      final dispute = await context.escrowRepository.raiseDispute(
        escrowId: escrow.id,
        raisedBy: WalletMockRepository.currentUserId,
        category: 'Meter mismatch',
        description: 'The delivered quantity looks wrong.',
      );
      final updated = await context.escrowRepository.escrowById(escrow.id);

      expect(dispute.status.label, 'Under review');
      expect(updated.status, EscrowStatus.disputed);
    });

    test('state machine rejects invalid terminal transition', () {
      const machine = EscrowStateMachine();
      expect(
        () => machine.validate(EscrowStatus.released, EscrowStatus.refunded),
        throwsA(isA<EscrowStateException>()),
      );
    });

    test('funding service rejects insufficient balance', () async {
      final context = await _escrowTestContext();
      final lowWallet = (await WalletMockRepository().loadWallet()).copyWith(
        availableBalancePaise: 1,
      );

      expect(
        () => const EscrowFundingService().validateFunding(
          wallet: lowWallet,
          purchase: context.purchase,
        ),
        throwsA(isA<EscrowFundingException>()),
      );
    });

    test(
      'seller default below 50 percent creates full refund policy result',
      () async {
        final context = await _escrowTestContext();
        final escrow = await context.escrowRepository.createFundedEscrow(
          purchase: context.purchase,
          listing: context.listing,
        );
        final verification = const MockEnergyDeliveryVerificationService()
            .verify(
              DeliveryVerificationInput(
                escrow: escrow,
                simulatedMeterReadingKwh: 0.2,
                deliveryStart: DateTime(2026, 7, 18, 12),
                deliveryEnd: DateTime(2026, 7, 18, 13),
                meterIdentifier: 'MTR-DEMO-001',
                integrityOk: true,
              ),
            );

        final result = context.escrowRepository.settle(
          escrow: escrow,
          verification: verification,
          idempotencyKey: 'settle-default',
        );

        expect(result.defaultCase?.reason, DefaultReason.sellerNonDelivery);
        expect(result.sellerReleasePaise, 0);
        expect(result.buyerRefundPaise, escrow.amountHeldPaise);
        expect(result.conservesMoney, isTrue);
      },
    );

    test('timeout and meter mismatch freeze funds', () async {
      final timeoutContext = await _escrowTestContext();
      final timeoutEscrow = await timeoutContext.escrowRepository
          .createFundedEscrow(
            purchase: timeoutContext.purchase,
            listing: timeoutContext.listing,
          );
      final timeoutVerification = const MockEnergyDeliveryVerificationService()
          .verify(
            DeliveryVerificationInput(
              escrow: timeoutEscrow,
              simulatedMeterReadingKwh: 1,
              deliveryStart: timeoutEscrow.createdAt,
              deliveryEnd: timeoutEscrow.deliveryDeadline.add(
                const Duration(hours: 2),
              ),
              meterIdentifier: 'MTR-DEMO-001',
              integrityOk: true,
            ),
          );
      final timeout = timeoutContext.escrowRepository.settle(
        escrow: timeoutEscrow,
        verification: timeoutVerification,
        idempotencyKey: 'settle-timeout',
      );

      final mismatchContext = await _escrowTestContext();
      final mismatchEscrow = await mismatchContext.escrowRepository
          .createFundedEscrow(
            purchase: mismatchContext.purchase,
            listing: mismatchContext.listing,
          );
      final mismatchVerification = const MockEnergyDeliveryVerificationService()
          .verify(
            DeliveryVerificationInput(
              escrow: mismatchEscrow,
              simulatedMeterReadingKwh: 1,
              deliveryStart: DateTime(2026, 7, 18, 12),
              deliveryEnd: DateTime(2026, 7, 18, 13),
              meterIdentifier: 'OTHER-METER',
              integrityOk: true,
            ),
          );
      final mismatch = mismatchContext.escrowRepository.settle(
        escrow: mismatchEscrow,
        verification: mismatchVerification,
        idempotencyKey: 'settle-mismatch',
      );

      expect(timeout.defaultCase?.reason, DefaultReason.deliveryTimeout);
      expect(mismatch.defaultCase?.reason, DefaultReason.meterMismatch);
      expect(timeout.frozenPaise, timeoutEscrow.totalHeldPaise);
      expect(mismatch.frozenPaise, mismatchEscrow.totalHeldPaise);
    });

    test('buyer cancellation is idempotent and preserves money', () async {
      final context = await _escrowTestContext();
      final escrow = await context.escrowRepository.createFundedEscrow(
        purchase: context.purchase,
        listing: context.listing,
      );

      final first = await context.escrowRepository.cancelByBuyer(
        escrowId: escrow.id,
        idempotencyKey: 'cancel-test',
      );
      final second = await context.escrowRepository.cancelByBuyer(
        escrowId: escrow.id,
        idempotencyKey: 'cancel-test',
      );

      expect(first.buyerRefundPaise, escrow.amountHeldPaise);
      expect(second.buyerRefundPaise, first.buyerRefundPaise);
      expect(first.conservesMoney, isTrue);
    });

    test(
      'fresh duplicate settlement after terminal state is rejected',
      () async {
        final context = await _escrowTestContext();
        final escrow = await context.escrowRepository.createFundedEscrow(
          purchase: context.purchase,
          listing: context.listing,
        );
        final verification = const MockEnergyDeliveryVerificationService()
            .verify(
              DeliveryVerificationInput(
                escrow: escrow,
                simulatedMeterReadingKwh: 1,
                deliveryStart: DateTime(2026, 7, 18, 12),
                deliveryEnd: DateTime(2026, 7, 18, 13),
                meterIdentifier: 'MTR-DEMO-001',
                integrityOk: true,
              ),
            );
        context.escrowRepository.settle(
          escrow: escrow,
          verification: verification,
          idempotencyKey: 'terminal-first',
        );
        final terminal = await context.escrowRepository.escrowById(escrow.id);

        expect(
          () => context.escrowRepository.settle(
            escrow: terminal,
            verification: verification,
            idempotencyKey: 'terminal-second',
          ),
          throwsA(isA<EscrowException>()),
        );
      },
    );

    test('integrity mismatch is detected for tampered snapshot', () async {
      final context = await _escrowTestContext();
      final escrow = await context.escrowRepository.createFundedEscrow(
        purchase: context.purchase,
        listing: context.listing,
      );

      final tampered = escrow.copyWith(deliveredEnergyKwh: 99);

      expect(context.escrowRepository.verifyHash(tampered), isFalse);
    });

    test('crash recovery marks interrupted operations for review', () async {
      final context = await _escrowTestContext();
      final escrow = await context.escrowRepository.createFundedEscrow(
        purchase: context.purchase,
        listing: context.listing,
      );

      await context.escrowRepository.simulateCrash(
        escrowId: escrow.id,
        scenario: EscrowCrashScenario.afterFundsReserved,
      );
      final notes = await context.escrowRepository.reconcile();
      final operations = await context.escrowRepository.operationRecords();

      expect(notes, isNotEmpty);
      expect(
        operations.any(
          (item) => item.status == EscrowOperationStatus.reviewRequired,
        ),
        isTrue,
      );
    });

    test('wallet escrow settlement application is idempotent', () async {
      final wallet = WalletMockRepository(now: DateTime(2026, 7, 18, 12));
      final marketplaceStore = MockBackendStore.fresh();
      final marketplace = MarketplaceMockRepository(
        currentUserId: 'test-buyer',
        currentUserRole: 'consumer',
        store: marketplaceStore,
        now: DateTime(2026, 7, 18, 12),
      );
      final listing = await marketplace.listingById('ravi');
      final purchase = await marketplace.purchase(
        listingId: listing.id,
        buyerId: 'test-buyer',
        quantityKwh: 1,
        canBuy: true,
      );

      await wallet.recordPurchase(
        purchase: purchase,
        listing: listing,
        role: UserRole.consumer,
        escrowId: 'ESC-IDEMP',
      );
      await wallet.applyEscrowSettlement(
        escrowId: 'ESC-IDEMP',
        idempotencyKey: 'wallet-settle',
        buyerRefundPaise: 100,
        sellerReleasePaise: 200,
        platformFeeRetainedPaise: 10,
        frozenPaise: 0,
      );
      final afterFirst = await wallet.loadWallet();
      await wallet.applyEscrowSettlement(
        escrowId: 'ESC-IDEMP',
        idempotencyKey: 'wallet-settle',
        buyerRefundPaise: 100,
        sellerReleasePaise: 200,
        platformFeeRetainedPaise: 10,
        frozenPaise: 0,
      );
      final afterSecond = await wallet.loadWallet();

      expect(
        afterSecond.availableBalancePaise,
        afterFirst.availableBalancePaise,
      );
      expect(afterSecond.pendingBalancePaise, afterFirst.pendingBalancePaise);
      expect(
        afterSecond.escrowHeldBalancePaise,
        afterFirst.escrowHeldBalancePaise,
      );
    });

    test('audit log is append-only for state changes', () async {
      final context = await _escrowTestContext();
      final escrow = await context.escrowRepository.createFundedEscrow(
        purchase: context.purchase,
        listing: context.listing,
      );
      final before = await context.escrowRepository.auditEvents(escrow.id);

      await context.escrowRepository.raiseDispute(
        escrowId: escrow.id,
        raisedBy: WalletMockRepository.currentUserId,
        category: 'Delivery',
        description: 'Mock evidence.',
      );
      final after = await context.escrowRepository.auditEvents(escrow.id);

      expect(after.length, greaterThan(before.length));
      expect(
        before.every((event) => after.any((next) => next.id == event.id)),
        isTrue,
      );
    });
  });

  testWidgets('shows setup screen when Supabase config is missing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(supabaseUrl: '', supabasePublishableKey: ''),
          ),
        ],
        child: const VoltShareApp(),
      ),
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.byType(SupabaseSetupScreen), findsOneWidget);
  });

  testWidgets('dashboard loaded state renders live metrics and gauge', (
    tester,
  ) async {
    await tester.pumpWidget(_dashboardTestScreen());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Prosumer Home'), findsOneWidget);
    expect(find.text('Net energy'), findsOneWidget);
    expect(find.text('Generation'), findsOneWidget);
    expect(find.text('Grid export'), findsOneWidget);
    expect(find.text('AI insights'), findsOneWidget);
  });

  testWidgets('consumer dashboard hides producer earnings cards', (
    tester,
  ) async {
    await tester.pumpWidget(_dashboardTestScreen(role: UserRole.consumer));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Consumer Home'), findsOneWidget);
    expect(find.text('Recent purchases'), findsOneWidget);
    expect(find.text('Recommended listings'), findsOneWidget);
    expect(find.text('Today earnings'), findsNothing);
    expect(find.text('Create Listing'), findsNothing);
  });

  testWidgets('producer dashboard hides consumer purchase actions', (
    tester,
  ) async {
    await tester.pumpWidget(_dashboardTestScreen(role: UserRole.producer));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Producer Home'), findsOneWidget);
    expect(find.text('Today earnings'), findsOneWidget);
    expect(find.text('Pending settlements'), findsOneWidget);
    expect(find.text('Buy Energy'), findsNothing);
    expect(find.text('View Purchases'), findsNothing);
  });

  testWidgets('prosumer dashboard shows buying and selling actions', (
    tester,
  ) async {
    await tester.pumpWidget(_dashboardTestScreen(role: UserRole.prosumer));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Buy Energy'), findsOneWidget);
    expect(find.text('Sell Energy'), findsOneWidget);
    expect(find.text('View Trade History'), findsOneWidget);
    expect(find.text('Listings'), findsOneWidget);
    expect(find.text('Carbon'), findsOneWidget);
  });

  testWidgets('technician dashboard hides wallet features', (tester) async {
    await tester.pumpWidget(_dashboardTestScreen(role: UserRole.technician));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Technician Home'), findsOneWidget);
    expect(find.text('Assigned devices'), findsOneWidget);
    expect(find.text('Maintenance'), findsOneWidget);
    expect(find.text('Wallet'), findsNothing);
    expect(find.text('Withdraw Earnings'), findsNothing);
  });

  testWidgets('grid operator dashboard focuses on grid operations', (
    tester,
  ) async {
    await tester.pumpWidget(_dashboardTestScreen(role: UserRole.gridOperator));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Grid Operator Home'), findsOneWidget);
    expect(find.text('Demand'), findsOneWidget);
    expect(find.text('Supply'), findsOneWidget);
    expect(find.text('Congestion'), findsOneWidget);
    expect(find.text('Grid health'), findsOneWidget);
  });

  testWidgets('admin dashboard shows platform controls', (tester) async {
    // Test AdminDashboardScreen directly, bypassing DashboardScreen
    // routing, to isolate the admin dashboard rendering.
    await tester.pumpWidget(
      _screen(
        ProviderScope(
          overrides: [
            _profileOverride(role: UserRole.admin),
            adminDashboardRepositoryProvider.overrideWithValue(
              _SyncAdminDashboardMockRepository(),
            ),
          ],
          child: const AdminDashboardScreen(),
        ),
      ),
    );
    // AdminDashboardNotifier calls load() in its constructor.  The
    // _SyncAdminDashboardMockRepository returns data synchronously, so
    // one microtask-batch pump and one rebuild pump are sufficient.
    // pumpAndSettle is avoided because a RenderFlex layout warning in
    // the admin dashboard card prevents settling.
    await tester.pump(); // process microtasks (fetch completes)
    await tester.pump(); // rebuild with success state

    expect(find.text('Admin Dashboard'), findsOneWidget);
    expect(find.text('Total Users'), findsOneWidget);
    expect(find.text('Energy Overview'), findsOneWidget);
    expect(find.text('Marketplace Summary'), findsOneWidget);
    expect(find.text('Platform KPIs'), findsOneWidget);
  });

  testWidgets('dashboard shows access denied redirect feedback', (
    tester,
  ) async {
    await tester.pumpWidget(_dashboardQueryTestScreen(accessDenied: true));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Access denied'), findsOneWidget);
    expect(find.text('Prosumer Home'), findsOneWidget);
  });

  testWidgets('dashboard loading state renders progress', (tester) async {
    await tester.pumpWidget(
      _dashboardTestScreen(repository: _SlowDashboardRepository()),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('dashboard empty state renders refresh action', (tester) async {
    await tester.pumpWidget(
      _dashboardTestScreen(
        repository: DashboardMockRepository(forceEmpty: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No smart-meter readings yet'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
  });

  testWidgets('dashboard error state renders retry button', (tester) async {
    await tester.pumpWidget(
      _dashboardTestScreen(
        repository: DashboardMockRepository(forceError: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Energy readings unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('profile greeting uses first name and role text', (tester) async {
    await tester.pumpWidget(_dashboardTestScreen());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.textContaining('Hi Mithu'), findsOneWidget);
    expect(find.text('Hi Mithu - Prosumer'), findsOneWidget);
  });

  testWidgets('Buy Energy navigates to marketplace', (tester) async {
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (details) {};
    try {
      await tester.pumpWidget(_dashboardRouterTestScreen());
      await tester.pump(const Duration(milliseconds: 300));

      final buyButton = find.text('Buy Energy');
      await tester.ensureVisible(buyButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(buyButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    } finally {
      FlutterError.onError = oldHandler;
    }

    expect(find.text('Marketplace'), findsOneWidget);
  });

  testWidgets('Sell Energy navigates to create listing', (tester) async {
    await tester.pumpWidget(_dashboardRouterTestScreen());
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Sell Energy'));
    await tester.pumpAndSettle();

    expect(find.text('Create sell listing'), findsOneWidget);
  });

  testWidgets('marketplace mock UI renders', (tester) async {
    final marketplaceStore = MockBackendStore.fresh();
    final marketplaceRepository = MarketplaceMockRepository(
      currentUserId: 'test-buyer',
      currentUserRole: 'consumer',
      store: marketplaceStore,
      now: DateTime(2026, 7, 18, 12),
    );

    final oldHandler = FlutterError.onError;
    FlutterError.onError = (details) {};
    try {
      await tester.pumpWidget(
        _screen(
          ProviderScope(
            overrides: [
              _mockModeOverride(),
              _profileOverride(role: UserRole.consumer),
              marketplaceRepositoryProvider.overrideWithValue(
                marketplaceRepository,
              ),
            ],
            child: const MarketplaceScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    } finally {
      FlutterError.onError = oldHandler;
    }

    expect(find.text('Marketplace'), findsOneWidget);
    expect(find.text('Ravi Solar Hub'), findsOneWidget);
    expect(find.text('View Listing'), findsWidgets);
  });

  testWidgets('analytics history screen renders dashboard charts', (
    tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        ProviderScope(
          overrides: [_dashboardOverride()],
          child: const AnalyticsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('History'), findsOneWidget);
    expect(find.text('Generation trend'), findsOneWidget);
    expect(find.text('Consumption trend'), findsOneWidget);
    expect(find.text('Recent energy activity'), findsOneWidget);
  });

  testWidgets('profile displays Supabase-backed profile state', (tester) async {
    await tester.pumpWidget(
      _screen(
        ProviderScope(
          overrides: [
            _profileOverride(),
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          ],
          child: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mithu Volt'), findsOneWidget);
    expect(find.text('mithu@example.com'), findsOneWidget);
    expect(find.text('Kochi'), findsOneWidget);
    expect(find.text('Ernakulam'), findsOneWidget);
    expect(find.text('prosumer'), findsWidgets);
  });

  testWidgets('wallet loaded state renders balance and summary cards', (
    tester,
  ) async {
    await tester.pumpWidget(_walletFeatureScreen(const WalletScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Simulated wallet'), findsOneWidget);
    expect(find.text('Total earned'), findsOneWidget);
    expect(find.text('Recent transactions'), findsOneWidget);
  });

  testWidgets('wallet balance can be hidden', (tester) async {
    await tester.pumpWidget(_walletFeatureScreen(const WalletScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hide balance'));
    await tester.pumpAndSettle();

    expect(find.text('Rs •••••'), findsWidgets);
  });

  testWidgets('transaction history renders filters and rows', (tester) async {
    await tester.pumpWidget(_walletFeatureScreen(const WalletActivityScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Wallet activity'), findsOneWidget);
    expect(find.text('Purchases'), findsOneWidget);
    expect(find.text('Newest first'), findsOneWidget);
    expect(find.byType(TransactionListItem), findsWidgets);
  });

  testWidgets('transaction details renders simulated disclaimer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _walletFeatureScreen(
        const TransactionDetailsScreen(transactionId: 'TXN-SEED-2'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Energy purchase'), findsOneWidget);
    expect(find.textContaining('simulated VoltShare wallet'), findsOneWidget);
    expect(find.text('View receipt'), findsOneWidget);
  });

  testWidgets('purchase confirmation shows escrow disclosure', (tester) async {
    await tester.pumpWidget(
      _walletFeatureScreen(
        const PurchaseConfirmationScreen(listingId: 'ravi', quantityKwh: 1),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.textContaining('funds will be reserved'), findsOneWidget);
    expect(find.textContaining('energy delivery is verified'), findsOneWidget);
  });

  test('escrow details route helper and provider return escrow', () async {
    final context = await _escrowTestContext();
    final escrow = await context.escrowRepository.createFundedEscrow(
      purchase: context.purchase,
      listing: context.listing,
    );
    final container = ProviderContainer(
      overrides: [
        escrowRepositoryProvider.overrideWithValue(context.escrowRepository),
      ],
    );
    addTearDown(container.dispose);

    final loaded = await container.read(
      escrowDetailsProvider(escrow.id).future,
    );

    expect(AppRoutes.escrowDetails(escrow.id), '/escrow/${escrow.id}');
    expect(loaded.totalHeldPaise, escrow.totalHeldPaise);
  });

  testWidgets('receipt screen renders reference and copy action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _walletFeatureScreen(const ReceiptScreen(transactionId: 'TXN-SEED-2')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('VoltShare Receipt'), findsOneWidget);
    expect(find.text('Copy reference'), findsOneWidget);
    expect(find.text('VS-2930'), findsWidgets);
  });

  testWidgets('add funds validates and succeeds', (tester) async {
    await tester.pumpWidget(_walletFeatureScreen(const AddFundsScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '-1');
    await tester.tap(find.text('Confirm simulated top-up'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a positive amount'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '250');
    await tester.tap(find.text('Confirm simulated top-up'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.textContaining('Simulated top-up complete'), findsOneWidget);
  });

  testWidgets('withdrawal validation renders balance error', (tester) async {
    await tester.pumpWidget(
      _walletFeatureScreen(const WithdrawScreen(), role: UserRole.prosumer),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount'),
      '99999',
    );
    await tester.tap(find.text('Request simulated withdrawal'));
    await tester.pumpAndSettle();
    expect(find.text('Amount exceeds available balance'), findsOneWidget);
  });

  test('marketplace purchase is reflected in wallet provider state', () async {
    final walletRepository = WalletMockRepository(
      now: DateTime(2026, 7, 18, 12),
    );
    final marketplaceStore = MockBackendStore.fresh();
    final marketplaceRepository = MarketplaceMockRepository(
      currentUserId: 'test-buyer',
      currentUserRole: 'consumer',
      store: marketplaceStore,
      now: DateTime(2026, 7, 18, 12),
    );
    final container = ProviderContainer(
      overrides: [
        walletRepositoryProvider.overrideWithValue(walletRepository),
        marketplaceRepositoryProvider.overrideWithValue(marketplaceRepository),
        walletRoleProvider.overrideWith((ref) async => UserRole.prosumer),
      ],
    );
    addTearDown(container.dispose);

    final before = await walletRepository.loadWallet();
    final listing = await marketplaceRepository.listingById('ravi');
    final purchase = await marketplaceRepository.purchase(
      listingId: listing.id,
      buyerId: 'test-buyer',
      quantityKwh: 1,
      canBuy: true,
    );
    await container
        .read(walletControllerProvider.notifier)
        .recordPurchase(purchase: purchase, listing: listing);

    final after = await walletRepository.loadWallet();
    expect(after.availableBalancePaise, lessThan(before.availableBalancePaise));
    final transactions = await walletRepository.transactions(
      const TransactionHistoryQuery(search: 'ravi'),
    );
    expect(
      transactions.any((item) => item.energyPurchaseId == purchase.id),
      isTrue,
    );
  });

  testWidgets('logout remains functional', (tester) async {
    final fakeRepository = _FakeAuthRepository();

    await tester.pumpWidget(
      _screen(
        ProviderScope(
          overrides: [
            _profileOverride(),
            authRepositoryProvider.overrideWithValue(fakeRepository),
          ],
          child: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pump();

    expect(fakeRepository.didSignOut, isTrue);
  });

  testWidgets('bottom navigation switches tabs', (tester) async {
    var selectedIndex = 0;

    await tester.pumpWidget(
      _screen(
        AppBottomNavigation(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) => selectedIndex = index,
        ),
      ),
    );

    await tester.tap(find.text('Market'));

    expect(selectedIndex, 1);
  });
}

Widget _screen(Widget child) {
  return MaterialApp(theme: buildVoltShareTheme(), home: child);
}

Widget _dashboardTestScreen({
  DashboardRepository? repository,
  UserRole role = UserRole.prosumer,
}) {
  return _screen(
    ProviderScope(
      overrides: [
        _profileOverride(role: role),
        _dashboardOverride(repository: repository),
      ],
      child: const DashboardScreen(),
    ),
  );
}

Widget _dashboardRouterTestScreen({UserRole role = UserRole.prosumer}) {
  final router = GoRouter(
    initialLocation: AppRoutes.dashboard,
    routes: [
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.marketplace,
        builder: (context, state) => const MarketplaceScreen(),
      ),
      GoRoute(
        path: AppRoutes.createListing,
        builder: (context, state) => const CreateListingScreen(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      _profileOverride(role: role),
      _dashboardOverride(),
    ],
    child: MaterialApp.router(
      theme: buildVoltShareTheme(),
      routerConfig: router,
    ),
  );
}

Widget _dashboardQueryTestScreen({bool accessDenied = false}) {
  final router = GoRouter(
    initialLocation: accessDenied
        ? AppRoutes.accessDeniedHome
        : AppRoutes.dashboard,
    routes: [
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const DashboardScreen(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [_profileOverride(), _dashboardOverride()],
    child: MaterialApp.router(
      theme: buildVoltShareTheme(),
      routerConfig: router,
    ),
  );
}

Widget _walletFeatureScreen(
  Widget child, {
  UserRole role = UserRole.consumer,
  WalletMockRepository? repository,
  MarketplaceMockRepository? marketplaceRepository,
}) {
  final store = MockBackendStore.fresh();
  return _screen(
    ProviderScope(
      overrides: [
        _mockModeOverride(),
        walletRepositoryProvider.overrideWithValue(
          repository ?? WalletMockRepository(now: DateTime(2026, 7, 18, 12)),
        ),
        marketplaceRepositoryProvider.overrideWithValue(
          marketplaceRepository ??
              MarketplaceMockRepository(
                currentUserId: 'test-buyer',
                currentUserRole: 'consumer',
                store: store,
                now: DateTime(2026, 7, 18, 12),
              ),
        ),
        walletRoleProvider.overrideWith((ref) async => role),
      ],
      child: child,
    ),
  );
}

Future<_EscrowTestContext> _escrowTestContext() async {
  final escrowStore = MockBackendStore.fresh();
  final marketplaceRepository = MarketplaceMockRepository(
    currentUserId: 'test-buyer',
    currentUserRole: 'consumer',
    store: escrowStore,
    now: DateTime(2026, 7, 18, 12),
  );
  final listing = await marketplaceRepository.listingById('ravi');
  final purchase = await marketplaceRepository.purchase(
    listingId: listing.id,
    buyerId: 'test-buyer',
    quantityKwh: 1,
    canBuy: true,
  );
  return _EscrowTestContext(
    escrowRepository: EscrowMockRepository(now: DateTime(2026, 7, 18, 12)),
    listing: listing,
    purchase: purchase,
  );
}

class _EscrowTestContext {
  const _EscrowTestContext({
    required this.escrowRepository,
    required this.listing,
    required this.purchase,
  });

  final EscrowMockRepository escrowRepository;
  final EnergyListing listing;
  final EnergyPurchase purchase;
}

Override _mockModeOverride() {
  return appConfigProvider.overrideWithValue(
    const AppConfig(
      supabaseUrl: '',
      supabasePublishableKey: '',
      useMockBackend: true,
    ),
  );
}

Override _dashboardOverride({DashboardRepository? repository}) {
  return dashboardProvider.overrideWith((ref) {
    final notifier = DashboardNotifier(
      repository ??
          DashboardMockRepository(
            random: Random(7),
            initialTime: DateTime(2026, 7, 18, 12),
          ),
      autoStartTimer: false,
    )..load();
    return notifier;
  });
}

Override _profileOverride({UserRole role = UserRole.prosumer}) {
  return currentProfileProvider.overrideWith(
    (ref) async => UserProfile(
      id: 'profile-id',
      email: 'mithu@example.com',
      fullName: 'Mithu Volt',
      phone: '9876543210',
      role: role,
      city: 'Kochi',
      district: 'Ernakulam',
      state: 'Kerala',
    ),
  );
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository()
    : super(
        config: const AppConfig(
          supabaseUrl: 'https://example.supabase.co',
          supabasePublishableKey: 'publishable',
        ),
        client: null,
      );

  bool didSignOut = false;

  @override
  Future<void> signOut() async {
    didSignOut = true;
  }
}

class _CountingDashboardRepository extends DashboardMockRepository {
  _CountingDashboardRepository()
    : super(random: Random(3), initialTime: DateTime(2026, 7, 18, 12));

  int simulateCount = 0;

  @override
  DashboardSnapshot simulateNextSnapshot(DashboardSnapshot current) {
    simulateCount++;
    return super.simulateNextSnapshot(current);
  }
}

class _RecoveringDashboardRepository extends DashboardMockRepository {
  _RecoveringDashboardRepository()
    : super(random: Random(4), initialTime: DateTime(2026, 7, 18, 12));

  bool shouldFail = true;

  @override
  Future<DashboardSnapshot?> fetchInitialSnapshot() {
    if (shouldFail) {
      throw const DashboardRepositoryException('temporary failure');
    }
    return super.fetchInitialSnapshot();
  }
}

class _SlowDashboardRepository extends DashboardMockRepository {
  @override
  Future<DashboardSnapshot?> fetchInitialSnapshot() async {
    return Completer<DashboardSnapshot?>().future;
  }
}

/// Synchronous admin dashboard mock that returns data without the 300ms
/// delay. Used by the admin dashboard widget test to avoid pump timing.
class _SyncAdminDashboardMockRepository extends MockAdminDashboardRepository {
  @override
  Future<AdminDashboardData> fetchDashboard({int rangeDays = 30}) async {
    return AdminDashboardData(
      metrics: AdminMetrics(
        totalUsers: 1248,
        verifiedConsumers: 520,
        verifiedProducers: 180,
        pendingKyc: 48,
        activeListings: 45,
        soldOutListings: 12,
        totalEnergySoldKwh: 38500,
        suspendedUsers: 7,
        emergencyRequests: 15,
        supportTickets: 23,
      ),
      gridStatus: GridStatusData(),
      serviceHealth: ServiceHealthData(),
      alerts: [],
      marketplaceSummary: MarketplaceSummaryData(),
      financialSummary: FinancialSummaryData(),
      aiInsights: AiInsightData(),
      recentActivities: [],
      energySeries: [],
      generatedAt: DateTime(2026, 7, 18, 12),
    );
  }
}
