import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/features/metering/data/meter_repository.dart';
import 'package:frontend/features/metering/domain/meter_metrics.dart';
import 'package:frontend/features/metering/presentation/producer_smart_meter_card.dart';
import 'package:frontend/features/metering/providers/meter_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('MeterMetrics Domain Model', () {
    test('parses exact live payload from smart meter endpoint', () {
      final json = {
        'power': 2726.16,
        'energy': 493.95,
        'voltage': 230.94,
        'powerFactor': 0.93,
        'meter': 'producer',
      };

      final metrics = MeterMetrics.fromJson(json);

      expect(metrics.power, 2726.16);
      expect(metrics.energy, 493.95);
      expect(metrics.voltage, 230.94);
      expect(metrics.powerFactor, 0.93);
      expect(metrics.meterType, 'producer');
      expect(metrics.status, MeterConnectionStatus.live);
      // Computed current I = P / (V * PF) = 2726.16 / (230.94 * 0.93) = 12.693...
      expect(metrics.current, closeTo(12.69, 0.05));
    });

    test('handles missing optional fields safely without throwing', () {
      final json = <String, dynamic>{};
      final metrics = MeterMetrics.fromJson(json);

      expect(metrics.power, isNull);
      expect(metrics.energy, isNull);
      expect(metrics.voltage, isNull);
      expect(metrics.current, isNull);
      expect(metrics.powerFactor, isNull);
      expect(metrics.meterType, isNull);
      expect(metrics.status, MeterConnectionStatus.live);
    });

    test('handles string and integer numbers safely', () {
      final json = {
        'power': '2500',
        'energy': 400,
        'voltage': '230.0',
        'powerFactor': 1,
      };

      final metrics = MeterMetrics.fromJson(json);

      expect(metrics.power, 2500.0);
      expect(metrics.energy, 400.0);
      expect(metrics.voltage, 230.0);
      expect(metrics.powerFactor, 1.0);
      expect(metrics.current, closeTo(10.86, 0.05));
    });
  });

  group('ExternalMeterRepository', () {
    test('fetches and parses live meter endpoint successfully', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/meter-metrics/producer');
        return http.Response(
          jsonEncode({
            'power': 2726.16,
            'energy': 493.95,
            'voltage': 230.94,
            'powerFactor': 0.93,
            'meter': 'producer',
          }),
          200,
        );
      });

      final repository = ExternalMeterRepository(
        client: mockClient,
        baseUrl: 'https://startathon-voltshare-smartmeter.onrender.com',
        producerPath: '/meter-metrics/producer',
      );

      final metrics = await repository.getProducerMetrics();

      expect(metrics.power, 2726.16);
      expect(metrics.energy, 493.95);
      expect(metrics.voltage, 230.94);
      expect(metrics.powerFactor, 0.93);
      expect(metrics.status, MeterConnectionStatus.live);
    });

    test('throws ApiException on 500 server error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final repository = ExternalMeterRepository(
        client: mockClient,
        baseUrl: 'https://startathon-voltshare-smartmeter.onrender.com',
        producerPath: '/meter-metrics/producer',
      );

      expect(
        () => repository.getProducerMetrics(),
        throwsA(isA<ApiException>()),
      );
    });

    test('throws ApiException on invalid JSON payload', () async {
      final mockClient = MockClient((request) async {
        return http.Response('<html>Internal Server Error</html>', 200);
      });

      final repository = ExternalMeterRepository(
        client: mockClient,
        baseUrl: 'https://startathon-voltshare-smartmeter.onrender.com',
        producerPath: '/meter-metrics/producer',
      );

      expect(
        () => repository.getProducerMetrics(),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('Repository Selection Independence', () {
    test(
      'USE_MOCK_BACKEND=true still uses ExternalMeterRepository by default',
      () {
        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(
                supabaseUrl: '',
                supabasePublishableKey: '',
                useMockBackend: true,
                smartMeterBaseUrl:
                    'https://startathon-voltshare-smartmeter.onrender.com',
                smartMeterProducerPath: '/meter-metrics/producer',
                meterProvider: 'external_api',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final repo = container.read(meterRepositoryProvider);
        expect(repo, isA<ExternalMeterRepository>());
      },
    );

    test(
      'USE_MOCK_BACKEND=false also uses ExternalMeterRepository by default',
      () {
        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(
                supabaseUrl: 'https://sample.supabase.co',
                supabasePublishableKey: 'anon-key',
                useMockBackend: false,
                smartMeterBaseUrl:
                    'https://startathon-voltshare-smartmeter.onrender.com',
                smartMeterProducerPath: '/meter-metrics/producer',
                meterProvider: 'external_api',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final repo = container.read(meterRepositoryProvider);
        expect(repo, isA<ExternalMeterRepository>());
      },
    );
  });

  group('ProducerMeterNotifier & Last-Known Reading Caching', () {
    test(
      'maintains last-known reading with STALE status on temporary error',
      () async {
        int callCount = 0;
        final mockClient = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            return http.Response(
              jsonEncode({
                'power': 2726.16,
                'energy': 493.95,
                'voltage': 230.94,
                'powerFactor': 0.93,
                'meter': 'producer',
              }),
              200,
            );
          } else {
            return http.Response('Internal Error', 500);
          }
        });

        final repository = ExternalMeterRepository(
          client: mockClient,
          baseUrl: 'https://startathon-voltshare-smartmeter.onrender.com',
          producerPath: '/meter-metrics/producer',
        );

        final notifier = ProducerMeterNotifier(
          repository: repository,
          pollingInterval: const Duration(seconds: 10),
        );
        addTearDown(notifier.dispose);

        // Wait for initial fetch
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(notifier.state.value?.status, MeterConnectionStatus.live);
        expect(notifier.state.value?.power, 2726.16);

        // Trigger second fetch that fails
        await notifier.refresh();
        expect(notifier.state.value?.status, MeterConnectionStatus.stale);
        // Values are preserved from previous reading
        expect(notifier.state.value?.power, 2726.16);
        expect(notifier.state.value?.energy, 493.95);
        expect(notifier.state.value?.voltage, 230.94);
      },
    );
  });

  group('ProducerSmartMeterCard Widget Tests', () {
    testWidgets('renders live metrics from producerMeterProvider', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          producerMeterProvider.overrideWith((ref) {
            final notifier = ProducerMeterNotifier(
              repository: MockMeterRepository(
                simulatedPower: 2726.16,
                simulatedEnergy: 493.95,
                simulatedVoltage: 230.94,
                simulatedPf: 0.93,
              ),
              autoStartPolling: false,
            );
            notifier.state = AsyncValue.data(
              MeterMetrics(
                power: 2726.16,
                energy: 493.95,
                voltage: 230.94,
                powerFactor: 0.93,
                current: 12.69,
                timestamp: DateTime(2026, 9, 5, 22, 0, 0),
                status: MeterConnectionStatus.live,
              ),
            );
            return notifier;
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ProducerSmartMeterCard()),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('PRODUCER SMART METER'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('2726.2'), findsOneWidget);
      expect(find.text('493.95'), findsOneWidget);
      expect(find.text('230.9'), findsOneWidget);
      expect(find.text('0.93'), findsOneWidget);
    });

    testWidgets('renders stale banner when connection is interrupted', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          producerMeterProvider.overrideWith((ref) {
            final notifier = ProducerMeterNotifier(
              repository: MockMeterRepository(),
              autoStartPolling: false,
            );
            notifier.state = AsyncValue.data(
              MeterMetrics(
                power: 2726.16,
                energy: 493.95,
                voltage: 230.94,
                powerFactor: 0.93,
                current: 12.69,
                timestamp: DateTime(2026, 9, 5, 22, 0, 0),
                status: MeterConnectionStatus.stale,
                errorMessage: 'Connection timed out.',
              ),
            );
            return notifier;
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ProducerSmartMeterCard()),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('STALE'), findsOneWidget);
      expect(find.text('Connection timed out.'), findsOneWidget);
      expect(find.text('2726.2'), findsOneWidget);
    });

    testWidgets(
      'renders offline error card with retry button when initial fetch fails',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            producerMeterProvider.overrideWith((ref) {
              final notifier = ProducerMeterNotifier(
                repository: MockMeterRepository(),
                autoStartPolling: false,
              );
              notifier.state = AsyncValue.data(
                MeterMetrics(
                  timestamp: DateTime(2026, 9, 5, 22, 0, 0),
                  status: MeterConnectionStatus.offline,
                  errorMessage: 'Smart meter service is unreachable.',
                ),
              );
              return notifier;
            }),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: ProducerSmartMeterCard()),
            ),
          ),
        );

        await tester.pump();

        expect(find.text('OFFLINE'), findsOneWidget);
        expect(
          find.text('Smart meter service is unreachable.'),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsOneWidget);
      },
    );
  });
}
