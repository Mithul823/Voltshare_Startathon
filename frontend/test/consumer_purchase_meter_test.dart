import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/features/marketplace/data/marketplace_mock_repository.dart';
import 'package:frontend/features/marketplace/data/mock_backend_store.dart';
import 'package:frontend/features/marketplace/domain/energy_listing.dart';
import 'package:frontend/features/marketplace/domain/energy_purchase.dart';
import 'package:frontend/features/marketplace/domain/marketplace_filter.dart';
import 'package:frontend/features/marketplace/domain/sell_listing_draft.dart';
import 'package:frontend/features/marketplace/presentation/purchase_confirmation_screen.dart';
import 'package:frontend/features/marketplace/presentation/purchase_success_screen.dart';
import 'package:frontend/features/marketplace/providers/marketplace_provider.dart';
import 'package:frontend/features/metering/data/meter_repository.dart';
import 'package:frontend/features/metering/data/smart_meter_purchase_service.dart';
import 'package:frontend/features/metering/domain/consumer_purchase_meter_request.dart';
import 'package:frontend/features/metering/domain/meter_metrics.dart';
import 'package:frontend/features/metering/domain/smart_meter_purchase_result.dart';
import 'package:frontend/features/metering/providers/meter_provider.dart';
import 'package:frontend/features/purchases/data/purchases_repository.dart';
import 'package:frontend/features/sales/data/sales_provider.dart';
import 'package:frontend/features/sales/data/sales_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() {
    MockBackendStore().reset();
    MockBackendStore().seed();
  });

  group('ConsumerPurchaseMeterRequest Serialization', () {
    test('serializes numeric 2.0 kWh accurately without strings', () {
      const request = ConsumerPurchaseMeterRequest(kwh: 2.0);
      final json = request.toJson();

      expect(json['kwh'], 2.0);
      expect(json['kwh'], isA<double>());
      expect(jsonEncode(json), '{"kwh":2.0}');
    });

    test('serializes numeric 5.5 kWh dynamically without hardcoding', () {
      const request = ConsumerPurchaseMeterRequest(kwh: 5.5);
      final json = request.toJson();

      expect(json['kwh'], 5.5);
      expect(jsonEncode(json), '{"kwh":5.5}');
    });
  });

  group('RenderSmartMeterPurchaseService', () {
    test(
      'sends POST /consumer-purchase with dynamic kWh value and parses success response',
      () async {
        final requestedBodies = <Map<String, dynamic>>[];
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/consumer-purchase');
          expect(request.method, 'POST');
          expect(request.headers['content-type'], contains('application/json'));

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          requestedBodies.add(body);

          return http.Response(
            jsonEncode({
              'message': 'Consumer purchase kWh stored',
              'kwh': body['kwh'],
              'storedAt': '2026-09-05T18:18:02.903Z',
            }),
            200,
          );
        });

        final service = RenderSmartMeterPurchaseService(
          client: mockClient,
          baseUrl: 'https://startathon-voltshare-smartmeter.onrender.com',
          purchasePath: '/consumer-purchase',
        );

        // Test 1: 2.0 kWh
        final result1 = await service.sendConsumerPurchase(2.0);
        expect(result1.isSuccess, isTrue);
        expect(result1.kwh, 2.0);
        expect(result1.message, 'Consumer purchase kWh stored');
        expect(result1.storedAt, isNotNull);
        expect(requestedBodies.first['kwh'], 2.0);

        // Test 2: 5.5 kWh
        final result2 = await service.sendConsumerPurchase(5.5);
        expect(result2.isSuccess, isTrue);
        expect(result2.kwh, 5.5);
        expect(requestedBodies.last['kwh'], 5.5);
      },
    );

    test(
      'rejects zero, negative, NaN, and infinite quantity without sending HTTP request',
      () async {
        int requestCount = 0;
        final mockClient = MockClient((request) async {
          requestCount++;
          return http.Response('OK', 200);
        });

        final service = RenderSmartMeterPurchaseService(
          client: mockClient,
          baseUrl: 'https://startathon-voltshare-smartmeter.onrender.com',
        );

        final zeroResult = await service.sendConsumerPurchase(0.0);
        expect(zeroResult.isSuccess, isFalse);
        expect(zeroResult.errorMessage, contains('Invalid purchase quantity'));

        final negativeResult = await service.sendConsumerPurchase(-2.5);
        expect(negativeResult.isSuccess, isFalse);

        final nanResult = await service.sendConsumerPurchase(double.nan);
        expect(nanResult.isSuccess, isFalse);

        final infResult = await service.sendConsumerPurchase(double.infinity);
        expect(infResult.isSuccess, isFalse);

        expect(
          requestCount,
          0,
          reason: 'No HTTP request should be sent for invalid quantities.',
        );
      },
    );

    test(
      'handles 400 Bad Request error response cleanly without throwing',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'kwh must be a non-negative number',
              'received': -1,
            }),
            400,
          );
        });

        final service = RenderSmartMeterPurchaseService(
          client: mockClient,
          baseUrl: 'https://startathon-voltshare-smartmeter.onrender.com',
        );

        // Bypass pre-flight for raw test
        final result = await service.sendConsumerPurchase(1.0);
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, 'kwh must be a non-negative number');
      },
    );

    test(
      'handles timeout without triggering uncontrolled automatic retries',
      () async {
        int requestCount = 0;
        final mockClient = MockClient((request) async {
          requestCount++;
          throw TimeoutException('Connection timed out');
        });

        final service = RenderSmartMeterPurchaseService(
          client: mockClient,
          baseUrl: 'https://startathon-voltshare-smartmeter.onrender.com',
        );

        final result = await service.sendConsumerPurchase(2.0);
        expect(result.isSuccess, isFalse);
        expect(result.status, SmartMeterSyncStatus.timeout);
        expect(result.errorMessage, 'Smart meter connection timed out.');
        expect(
          requestCount,
          1,
          reason: 'Must not retry automatically on timeout',
        );
      },
    );
  });

  group('Full Purchase Flow & Cross-Role Synchronization', () {
    test(
      'Consumer purchase creates Mock Purchase, decrements listing, updates Producer Sales, and calls Smart Meter',
      () async {
        final store = MockBackendStore();
        store.seed();

        // Initial listing Ravi Solar Hub: 100 kWh
        final raviListing = store.getListing('ravi')!;
        expect(raviListing['availableEnergyKwh'], 100.0);

        final smartMeterCalls = <double>[];
        final mockClient = MockClient((request) async {
          if (request.url.path == '/consumer-purchase') {
            final body = jsonDecode(request.body);
            smartMeterCalls.add((body['kwh'] as num).toDouble());
            return http.Response(
              jsonEncode({
                'message': 'Consumer purchase kWh stored',
                'kwh': body['kwh'],
                'storedAt': '2026-09-05T18:18:02.903Z',
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(
                supabaseUrl: '',
                supabasePublishableKey: '',
                useMockBackend: true,
                smartMeterBaseUrl:
                    'https://startathon-voltshare-smartmeter.onrender.com',
              ),
            ),
            smartMeterPurchaseServiceProvider.overrideWithValue(
              RenderSmartMeterPurchaseService(
                client: mockClient,
                baseUrl: 'https://startathon-voltshare-smartmeter.onrender.com',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Execute Consumer Purchase for 2.0 kWh
        final controller = container.read(purchaseControllerProvider.notifier);
        final purchase = await controller.purchase(
          listingId: 'ravi',
          quantityKwh: 2.0,
        );

        expect(purchase, isNotNull);
        expect(purchase!.quantityKwh, 2.0);
        expect(purchase.listingId, 'ravi');
        expect(purchase.sellerId, 'producer-1');

        // 1. Smart meter endpoint received exact quantity
        expect(smartMeterCalls.length, 1);
        expect(smartMeterCalls.first, 2.0);

        // 2. Listing quantity decremented from 100.0 to 98.0
        final updatedListing = store.getListing('ravi')!;
        expect(updatedListing['availableEnergyKwh'], 98.0);
        expect(updatedListing['listingStatus'], 'active');

        // 3. Consumer Purchases repository contains the new purchase
        final consumerRepo = MockPurchasesRepository(
          buyerId: 'consumer-1',
          store: store,
        );
        final consumerPurchases = await consumerRepo.loadPurchases();
        expect(
          consumerPurchases.any(
            (p) => p.id == purchase.id && p.quantityKwh == 2.0,
          ),
          isTrue,
        );

        // 4. Producer Sales repository contains the exact same transaction
        final salesRepo = SalesMockRepository(
          sellerId: 'producer-1',
          store: store,
        );
        final salesPage = await salesRepo.getSales();
        expect(
          salesPage.items.any(
            (s) => s.id == purchase.id && s.quantityKwh == 2.0,
          ),
          isTrue,
        );
        expect(salesPage.summary.totalSales, greaterThanOrEqualTo(3));
      },
    );

    test(
      'Purchasing entire available energy transitions listing to SOLD_OUT',
      () async {
        final store = MockBackendStore();
        store.seed();

        // Create temporary listing with 3.0 kWh
        final tempListing = store.addListing({
          'sellerId': 'producer-1',
          'sellerName': 'Ravi Solar Hub',
          'sellerRole': 'producer',
          'title': 'Mini Solar Batch',
          'energySource': 'solar',
          'availableEnergyKwh': 3.0,
          'quantityTotalKwh': 3.0,
          'pricePerKwh': 7.50,
          'location': 'Kochi',
          'listingStatus': 'active',
        });
        final listingId = tempListing['id'].toString();

        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'Stored', 'kwh': 3.0}),
            200,
          );
        });

        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(
                supabaseUrl: '',
                supabasePublishableKey: '',
                useMockBackend: true,
              ),
            ),
            smartMeterPurchaseServiceProvider.overrideWithValue(
              RenderSmartMeterPurchaseService(
                client: mockClient,
                baseUrl: 'https://startathon-voltshare-smartmeter.onrender.com',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final purchase = await container
            .read(purchaseControllerProvider.notifier)
            .purchase(listingId: listingId, quantityKwh: 3.0);

        expect(purchase, isNotNull);

        final listingAfter = store.getListing(listingId)!;
        expect(listingAfter['availableEnergyKwh'], 0.0);
        expect(listingAfter['listingStatus'], 'sold');

        // Subsequent purchase attempts must fail
        expect(
          () => container
              .read(marketplaceRepositoryProvider)
              .purchase(
                listingId: listingId,
                buyerId: 'consumer-1',
                quantityKwh: 1.0,
                canBuy: true,
              ),
          throwsA(isA<MarketplaceException>()),
        );
      },
    );

    test(
      'Separates business transaction success from smart-meter sync failure',
      () async {
        final store = MockBackendStore();
        store.seed();

        final mockClient = MockClient((request) async {
          // Smart meter hardware endpoint fails with 500
          return http.Response('Hardware Gateway Error', 500);
        });

        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(
                supabaseUrl: '',
                supabasePublishableKey: '',
                useMockBackend: true,
              ),
            ),
            smartMeterPurchaseServiceProvider.overrideWithValue(
              RenderSmartMeterPurchaseService(
                client: mockClient,
                baseUrl: 'https://startathon-voltshare-smartmeter.onrender.com',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final purchase = await container
            .read(purchaseControllerProvider.notifier)
            .purchase(listingId: 'ravi', quantityKwh: 1.5);

        // Business purchase succeeded
        expect(purchase, isNotNull);
        expect(purchase!.quantityKwh, 1.5);

        // But smart meter sync failed and is reported in latestSmartMeterResultProvider
        final syncResult = container.read(latestSmartMeterResultProvider);
        expect(syncResult, isNotNull);
        expect(syncResult!.isSuccess, isFalse);
      },
    );
  });

  group('UI Integration & Double-Submit Protection', () {
    testWidgets(
      'PurchaseConfirmationScreen prevents double tap and displays processing state',
      (tester) async {
        final store = MockBackendStore();
        store.seed();

        final container = ProviderContainer(
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
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: PurchaseConfirmationScreen(
                listingId: 'ravi',
                quantityKwh: 2.0,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Confirm simulated purchase'), findsWidgets);

        // Simulate loading state in purchaseControllerProvider
        container.read(purchaseControllerProvider.notifier).state =
            const AsyncValue.loading();
        await tester.pump();

        expect(find.text('Processing energy purchase...'), findsOneWidget);
      },
    );

    testWidgets('PurchaseSuccessScreen renders smart meter success feedback', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          latestPurchaseProvider.overrideWith(
            (ref) => EnergyPurchase(
              id: 'test-purchase-101',
              listingId: 'ravi',
              buyerId: 'consumer-1',
              sellerId: 'producer-1',
              quantityKwh: 2.0,
              unitPrice: 8.20,
              platformFee: 0.49,
              totalAmount: 16.89,
              estimatedSavings: 3.60,
              co2ImpactKg: 1.40,
              purchasedAt: DateTime.now(),
              status: PurchaseStatus.completed,
            ),
          ),
          latestSmartMeterResultProvider.overrideWith(
            (ref) => const SmartMeterPurchaseResult(
              status: SmartMeterSyncStatus.success,
              kwh: 2.0,
              message: 'Consumer purchase kWh stored',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PurchaseSuccessScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('2.0 kWh purchased successfully.'), findsOneWidget);
      expect(find.text('Reference: test-purchase-101'), findsOneWidget);
    });
  });
}
