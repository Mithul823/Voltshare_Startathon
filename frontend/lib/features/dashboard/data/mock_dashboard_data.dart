class MockDashboardData {
  const MockDashboardData({
    required this.solarGenerationToday,
    required this.energyConsumptionToday,
    required this.energyAvailableToSell,
    required this.batteryPercentage,
    required this.walletBalance,
    required this.gridSavings,
    required this.co2ReducedKg,
    required this.sustainabilityScore,
  });

  final double solarGenerationToday;
  final double energyConsumptionToday;
  final double energyAvailableToSell;
  final int batteryPercentage;
  final double walletBalance;
  final double gridSavings;
  final double co2ReducedKg;
  final int sustainabilityScore;
}

const mockDashboardData = MockDashboardData(
  solarGenerationToday: 32.5,
  energyConsumptionToday: 18.2,
  energyAvailableToSell: 8.5,
  batteryPercentage: 82,
  walletBalance: 845.50,
  gridSavings: 214.00,
  co2ReducedKg: 18.6,
  sustainabilityScore: 86,
);
