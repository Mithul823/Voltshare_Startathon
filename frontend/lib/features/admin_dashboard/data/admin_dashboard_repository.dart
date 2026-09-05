import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'admin_dashboard_models.dart';

abstract class AdminDashboardRepository {
  Future<AdminDashboardData> fetchDashboard({int rangeDays = 30});
}

class MockAdminDashboardRepository implements AdminDashboardRepository {
  @override
  Future<AdminDashboardData> fetchDashboard({int rangeDays = 30}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return AdminDashboardData(
      metrics: AdminMetrics(
        totalUsers: 1248, totalUsersTrend: 12.5,
        energyTradedKwh: 45600, energyTradedTrend: 8.3,
        totalRevenue: 892000, revenueTrend: 15.2,
        activeListings: 45, listingsTrend: 5.1,
        pendingDisputes: 3, disputesTrend: -2.0,
        verifiedConsumers: 520, verifiedProducers: 180,
        pendingKyc: 48, soldOutListings: 12,
        totalEnergySoldKwh: 38500, suspendedUsers: 7,
        emergencyRequests: 15, supportTickets: 23,
      ),
      gridStatus: GridStatusData(gridLoadPercent: 72, renewableSharePercent: 38, batteryStoragePercent: 45, systemFrequency: 50.02, status: 'stable'),
      serviceHealth: ServiceHealthData(overall: 'healthy', services: {
        'api_gateway': ServiceStatus(status: 'healthy', healthPercent: 99.9),
        'database': ServiceStatus(status: 'healthy', healthPercent: 99.8),
        'realtime': ServiceStatus(status: 'healthy', healthPercent: 99.5),
        'ai_service': ServiceStatus(status: 'healthy', healthPercent: 98.2),
      }),
      alerts: [],
      marketplaceSummary: MarketplaceSummaryData(activeListings: 45, newListingsToday: 3, completedTrades: 128, cancelledListings: 5),
      financialSummary: FinancialSummaryData(escrowBalance: 125000, pendingSettlements: 18, platformFees: 44500),
      aiInsights: AiInsightData(pricePrediction: 8.45, demandForecastPercent: 15, generationForecastKwh: 52000, confidencePercent: 85, available: true),
      recentActivities: [
        ActivityData(id: '1', type: 'purchase', title: 'New energy purchase of 5 kWh', description: '', createdAt: DateTime.now().subtract(const Duration(minutes: 15))),
        ActivityData(id: '2', type: 'kyc', title: 'KYC approved for Priya Sharma', description: '', createdAt: DateTime.now().subtract(const Duration(hours: 1))),
        ActivityData(id: '3', type: 'listing', title: 'New listing: Solar — 50 kWh', description: '', createdAt: DateTime.now().subtract(const Duration(hours: 2))),
        ActivityData(id: '4', type: 'user', title: 'New user registered: Raj Kumar', description: '', createdAt: DateTime.now().subtract(const Duration(hours: 3))),
        ActivityData(id: '5', type: 'kyc', title: 'KYC pending review for Amit Patel', description: '', createdAt: DateTime.now().subtract(const Duration(hours: 5))),
      ],
      energySeries: [
        EnergySeriesPoint(label: 'Mon', tradedKwh: 1200, generatedKwh: 1800, consumedKwh: 1400),
        EnergySeriesPoint(label: 'Tue', tradedKwh: 1350, generatedKwh: 1650, consumedKwh: 1500),
        EnergySeriesPoint(label: 'Wed', tradedKwh: 1100, generatedKwh: 1750, consumedKwh: 1300),
        EnergySeriesPoint(label: 'Thu', tradedKwh: 1450, generatedKwh: 1900, consumedKwh: 1550),
        EnergySeriesPoint(label: 'Fri', tradedKwh: 1300, generatedKwh: 1850, consumedKwh: 1450),
        EnergySeriesPoint(label: 'Sat', tradedKwh: 980, generatedKwh: 1600, consumedKwh: 1100),
        EnergySeriesPoint(label: 'Sun', tradedKwh: 850, generatedKwh: 1500, consumedKwh: 950),
      ],
      generatedAt: DateTime.now(),
    );
  }
}

class ApiAdminDashboardRepository implements AdminDashboardRepository {
  ApiAdminDashboardRepository(this._client);
  final ApiClient _client;

  @override
  Future<AdminDashboardData> fetchDashboard({int rangeDays = 30}) async {
    final data = await _client.get('/admin/dashboard', query: {'range': rangeDays.toString()});
    return AdminDashboardData.fromJson(data as Map<String, Object?>);
  }
}

final adminDashboardRepositoryProvider = Provider<AdminDashboardRepository>((ref) {
  if (ref.watch(appConfigProvider).isLiveMode) {
    return ApiAdminDashboardRepository(ref.watch(apiClientProvider));
  }
  return MockAdminDashboardRepository();
});
