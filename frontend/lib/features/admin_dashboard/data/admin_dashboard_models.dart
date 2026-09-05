int _num(Object? v) => (v is num) ? v.toInt() : 0;
double _dbl(Object? v, [double fallback = 0]) => (v is num) ? v.toDouble() : fallback;

class AdminDashboardData {
  const AdminDashboardData({
    required this.metrics,
    required this.gridStatus,
    required this.serviceHealth,
    required this.alerts,
    required this.marketplaceSummary,
    required this.financialSummary,
    required this.aiInsights,
    required this.recentActivities,
    required this.energySeries,
    required this.generatedAt,
  });

  factory AdminDashboardData.fromJson(Map<String, Object?> json) {
    return AdminDashboardData(
      metrics: AdminMetrics.fromJson((json['metrics'] as Map<String, Object?>?) ?? const {}),
      gridStatus: GridStatusData.fromJson((json['gridStatus'] as Map<String, Object?>?) ?? const {}),
      serviceHealth: ServiceHealthData.fromJson((json['serviceHealth'] as Map<String, Object?>?) ?? const {}),
      alerts: (json['alerts'] as List<Object?>?)?.map((e) => AlertData.fromJson(e as Map<String, Object?>)).toList() ?? [],
      marketplaceSummary: MarketplaceSummaryData.fromJson((json['marketplaceSummary'] as Map<String, Object?>?) ?? const {}),
      financialSummary: FinancialSummaryData.fromJson((json['financialSummary'] as Map<String, Object?>?) ?? const {}),
      aiInsights: AiInsightData.fromJson((json['aiInsights'] as Map<String, Object?>?) ?? const {}),
      recentActivities: (json['recentActivities'] as List<Object?>?)?.map((e) => ActivityData.fromJson(e as Map<String, Object?>)).toList() ?? [],
      energySeries: (json['energySeries'] as List<Object?>?)?.map((e) => EnergySeriesPoint.fromJson(e as Map<String, Object?>)).toList() ?? [],
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  final AdminMetrics metrics;
  final GridStatusData gridStatus;
  final ServiceHealthData serviceHealth;
  final List<AlertData> alerts;
  final MarketplaceSummaryData marketplaceSummary;
  final FinancialSummaryData financialSummary;
  final AiInsightData aiInsights;
  final List<ActivityData> recentActivities;
  final List<EnergySeriesPoint> energySeries;
  final DateTime generatedAt;
}

class AdminMetrics {
  const AdminMetrics({
    this.totalUsers = 0,
    this.totalUsersTrend = 0,
    this.energyTradedKwh = 0,
    this.energyTradedTrend = 0,
    this.totalRevenue = 0,
    this.revenueTrend = 0,
    this.activeListings = 0,
    this.listingsTrend = 0,
    this.pendingDisputes = 0,
    this.disputesTrend = 0,
    // New KPI fields
    this.verifiedConsumers = 0,
    this.verifiedProducers = 0,
    this.pendingKyc = 0,
    this.soldOutListings = 0,
    this.totalEnergySoldKwh = 0,
    this.suspendedUsers = 0,
    this.emergencyRequests = 0,
    this.supportTickets = 0,
  });

  factory AdminMetrics.fromJson(Map<String, Object?> json) {
    return AdminMetrics(
      totalUsers: _num(json['totalUsers']),
      totalUsersTrend: _dbl(json['totalUsersTrend']),
      energyTradedKwh: _dbl(json['energyTradedKwh']),
      energyTradedTrend: _dbl(json['energyTradedTrend']),
      totalRevenue: _dbl(json['totalRevenue']),
      revenueTrend: _dbl(json['revenueTrend']),
      activeListings: _num(json['activeListings']),
      listingsTrend: _dbl(json['listingsTrend']),
      pendingDisputes: _num(json['pendingDisputes']),
      disputesTrend: _dbl(json['disputesTrend']),
      verifiedConsumers: _num(json['verifiedConsumers']),
      verifiedProducers: _num(json['verifiedProducers']),
      pendingKyc: _num(json['pendingKyc']),
      soldOutListings: _num(json['soldOutListings']),
      totalEnergySoldKwh: _dbl(json['totalEnergySoldKwh']),
      suspendedUsers: _num(json['suspendedUsers']),
      emergencyRequests: _num(json['emergencyRequests']),
      supportTickets: _num(json['supportTickets']),
    );
  }

  final int totalUsers;
  final double totalUsersTrend;
  final double energyTradedKwh;
  final double energyTradedTrend;
  final double totalRevenue;
  final double revenueTrend;
  final int activeListings;
  final double listingsTrend;
  final int pendingDisputes;
  final double disputesTrend;
  // New KPI fields
  final int verifiedConsumers;
  final int verifiedProducers;
  final int pendingKyc;
  final int soldOutListings;
  final double totalEnergySoldKwh;
  final int suspendedUsers;
  final int emergencyRequests;
  final int supportTickets;
}

class GridStatusData {
  const GridStatusData({this.gridLoadPercent = 0, this.renewableSharePercent = 0, this.batteryStoragePercent = 0,
    this.systemFrequency = 50.0, this.status = 'unknown', this.regions = const []});

  factory GridStatusData.fromJson(Map<String, Object?> json) {
    return GridStatusData(
      gridLoadPercent: _dbl(json['gridLoadPercent']), renewableSharePercent: _dbl(json['renewableSharePercent']),
      batteryStoragePercent: _dbl(json['batteryStoragePercent']), systemFrequency: _dbl(json['systemFrequency'], 50.0),
      status: json['status']?.toString() ?? 'unknown',
      regions: (json['regions'] as List<Object?>?)?.map((e) => RegionStatus.fromJson(e as Map<String, Object?>)).toList() ?? [],
    );
  }

  final double gridLoadPercent; final double renewableSharePercent; final double batteryStoragePercent;
  final double systemFrequency; final String status; final List<RegionStatus> regions;
}

class RegionStatus {
  const RegionStatus({required this.name, required this.loadPercent, required this.status});
  factory RegionStatus.fromJson(Map<String, Object?> json) => RegionStatus(name: json['name']?.toString() ?? '', loadPercent: _dbl(json['loadPercent']), status: json['status']?.toString() ?? 'normal');
  final String name; final double loadPercent; final String status;
}

class ServiceHealthData {
  const ServiceHealthData({this.overall = 'unknown', this.services = const {}});
  factory ServiceHealthData.fromJson(Map<String, Object?> json) {
    final rawServices = json['services'] as Map<String, Object?>? ?? {};
    return ServiceHealthData(overall: json['overall']?.toString() ?? 'unknown',
      services: rawServices.map((k, v) => MapEntry(k, ServiceStatus.fromJson(v as Map<String, Object?>?))));
  }
  final String overall; final Map<String, ServiceStatus> services;
}

class ServiceStatus {
  const ServiceStatus({this.status = 'unknown', this.healthPercent = 0});
  factory ServiceStatus.fromJson(Map<String, Object?>? json) {
    if (json == null) return const ServiceStatus();
    return ServiceStatus(status: json['status']?.toString() ?? 'unknown', healthPercent: _dbl(json['healthPercent']));
  }
  final String status; final double healthPercent;
}

class AlertData {
  const AlertData({required this.id, required this.severity, required this.title, required this.description, required this.location, required this.createdAt});
  factory AlertData.fromJson(Map<String, Object?> json) => AlertData(id: json['id']?.toString() ?? '', severity: json['severity']?.toString() ?? 'warning',
    title: json['title']?.toString() ?? '', description: json['description']?.toString() ?? '', location: json['location']?.toString() ?? '',
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now());
  final String id; final String severity; final String title; final String description; final String location; final DateTime createdAt;
}

class MarketplaceSummaryData {
  const MarketplaceSummaryData({this.activeListings = 0, this.newListingsToday = 0, this.completedTrades = 0, this.cancelledListings = 0, this.flaggedListings = 0});
  factory MarketplaceSummaryData.fromJson(Map<String, Object?> json) => MarketplaceSummaryData(
    activeListings: _num(json['activeListings']), newListingsToday: _num(json['newListingsToday']),
    completedTrades: _num(json['completedTrades']), cancelledListings: _num(json['cancelledListings']), flaggedListings: _num(json['flaggedListings']));
  final int activeListings; final int newListingsToday; final int completedTrades; final int cancelledListings; final int flaggedListings;
}

class FinancialSummaryData {
  const FinancialSummaryData({this.escrowBalance = 0, this.pendingSettlements = 0, this.pendingPayouts = 0, this.refundRequests = 0, this.platformFees = 0});
  factory FinancialSummaryData.fromJson(Map<String, Object?> json) => FinancialSummaryData(
    escrowBalance: _dbl(json['escrowBalance']), pendingSettlements: _num(json['pendingSettlements']),
    pendingPayouts: _dbl(json['pendingPayouts']), refundRequests: _num(json['refundRequests']), platformFees: _dbl(json['platformFees']));
  final double escrowBalance; final int pendingSettlements; final double pendingPayouts; final int refundRequests; final double platformFees;
}

class AiInsightData {
  const AiInsightData({this.pricePrediction = 0, this.demandForecastPercent = 0, this.generationForecastKwh = 0, this.anomaliesDetected = 0, this.confidencePercent = 0, this.available = false});
  factory AiInsightData.fromJson(Map<String, Object?> json) => AiInsightData(
    pricePrediction: _dbl(json['pricePrediction']), demandForecastPercent: _dbl(json['demandForecastPercent']),
    generationForecastKwh: _dbl(json['generationForecastKwh']), anomaliesDetected: _num(json['anomaliesDetected']),
    confidencePercent: _dbl(json['confidencePercent']), available: json['available'] == true);
  final double pricePrediction; final double demandForecastPercent; final double generationForecastKwh;
  final int anomaliesDetected; final double confidencePercent; final bool available;
}

class ActivityData {
  const ActivityData({required this.id, required this.type, required this.title, required this.description, required this.createdAt, this.status});
  factory ActivityData.fromJson(Map<String, Object?> json) => ActivityData(id: json['id']?.toString() ?? '', type: json['type']?.toString() ?? 'info',
    title: json['title']?.toString() ?? '', description: json['description']?.toString() ?? '',
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(), status: json['status']?.toString());
  final String id; final String type; final String title; final String description; final DateTime createdAt; final String? status;
}

class EnergySeriesPoint {
  const EnergySeriesPoint({required this.label, this.tradedKwh = 0, this.generatedKwh = 0, this.consumedKwh = 0});
  factory EnergySeriesPoint.fromJson(Map<String, Object?> json) => EnergySeriesPoint(label: json['label']?.toString() ?? '',
    tradedKwh: _dbl(json['tradedKwh']), generatedKwh: _dbl(json['generatedKwh']), consumedKwh: _dbl(json['consumedKwh']));
  final String label; final double tradedKwh; final double generatedKwh; final double consumedKwh;
}

String formatIndianCurrency(double amount) {
  final abs = amount.abs(); final sign = amount < 0 ? '-' : '';
  if (abs >= 10000000) return '$sign₹${(abs / 10000000).toStringAsFixed(2)}Cr';
  if (abs >= 100000) return '$sign₹${(abs / 100000).toStringAsFixed(1)}L';
  if (abs >= 1000) return '$sign₹${(abs / 1000).floor()},${(abs % 1000).round().toString().padLeft(3, '0')}';
  return '$sign₹${abs.toStringAsFixed(0)}';
}

String formatEnergyCompact(double kwh) {
  if (kwh >= 1000) return '${(kwh / 1000).toStringAsFixed(2)} MWh';
  return '${kwh.toStringAsFixed(1)} kWh';
}

String formatPercent(double value) {
  final sign = value >= 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(1)}%';
}
