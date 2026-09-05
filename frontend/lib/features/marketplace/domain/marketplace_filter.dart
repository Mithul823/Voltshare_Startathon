enum EnergySource { solar, wind, hybrid, communitySolar }

enum ListingStatus { active, sold, cancelled, expired, paused }

enum PurchaseStatus {
  pending,
  confirmed,
  completed,
  cancelled,
  refunded,
  failed,
}

enum MarketplaceSort { priceLow, priceHigh, distance, rating, energyAvailable }

enum MarketplaceFilter {
  cheapest,
  nearby,
  highestRating,
  solarOnly,
  batteryBacked,
  availableNow,
  underEight,
}

extension EnergySourceLabel on EnergySource {
  String get label {
    return switch (this) {
      EnergySource.solar => 'Solar',
      EnergySource.wind => 'Wind',
      EnergySource.hybrid => 'Hybrid',
      EnergySource.communitySolar => 'Community solar',
    };
  }
}

extension MarketplaceFilterLabel on MarketplaceFilter {
  String get label {
    return switch (this) {
      MarketplaceFilter.cheapest => 'Cheapest',
      MarketplaceFilter.nearby => 'Nearby',
      MarketplaceFilter.highestRating => 'Highest rating',
      MarketplaceFilter.solarOnly => 'Solar only',
      MarketplaceFilter.batteryBacked => 'Battery-backed',
      MarketplaceFilter.availableNow => 'Available now',
      MarketplaceFilter.underEight => 'Under Rs 8',
    };
  }
}
