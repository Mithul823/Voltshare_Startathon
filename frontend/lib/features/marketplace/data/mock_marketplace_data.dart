class MockEnergyListing {
  const MockEnergyListing({
    required this.sellerName,
    required this.energyAvailable,
    required this.pricePerKwh,
    required this.distance,
    required this.rating,
  });

  final String sellerName;
  final double energyAvailable;
  final double pricePerKwh;
  final double distance;
  final double rating;
}

const mockEnergyListings = [
  MockEnergyListing(
    sellerName: 'Ravi Solar Hub',
    energyAvailable: 7.5,
    pricePerKwh: 5.2,
    distance: 1.4,
    rating: 4.8,
  ),
  MockEnergyListing(
    sellerName: 'Anra Rooftop Solar',
    energyAvailable: 5.0,
    pricePerKwh: 5.6,
    distance: 2.1,
    rating: 4.7,
  ),
  MockEnergyListing(
    sellerName: 'GreenNest Power',
    energyAvailable: 9.2,
    pricePerKwh: 5.8,
    distance: 2.8,
    rating: 4.9,
  ),
  MockEnergyListing(
    sellerName: 'Kochi SunShare',
    energyAvailable: 4.6,
    pricePerKwh: 6.1,
    distance: 3.2,
    rating: 4.6,
  ),
];
