/// Shared mock backend store that persists across login/logout within the same app process.
///
/// Acts as a lightweight in-memory database for mock mode. Now supports:
/// - Real inventory tracking (remaining/sold/total)
/// - Partial purchases (multiple consumers from one listing)
/// - Sold out state management
/// - Revenue tracking per listing
class MockBackendStore {
  MockBackendStore._internal();
  static final MockBackendStore _instance = MockBackendStore._internal();
  factory MockBackendStore() => _instance;
  static MockBackendStore fresh() => MockBackendStore._internal();

  final Map<String, Map<String, dynamic>> users = {};
  final Map<String, Map<String, dynamic>> listings = {};
  final List<Map<String, dynamic>> purchases = [];

  String get _nextListingId => 'mock-listing-${listings.length + 1}';
  String get _nextPurchaseId => 'mock-purchase-${purchases.length + 1}';

  void registerUser(String id, String email, String role) {
    users[id] = {
      'id': id,
      'email': email,
      'role': role,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> addListing(Map<String, dynamic> listing) {
    final entry = Map<String, dynamic>.from(listing);
    final id = entry['id']?.toString() ?? _nextListingId;
    entry['id'] = id;
    // Ensure quantityTotalKwh is set
    if (entry['quantityTotalKwh'] == null) {
      entry['quantityTotalKwh'] = entry['availableEnergyKwh'];
    }
    entry['quantitySoldKwh'] = 0.0;
    entry['totalRevenue'] = 0.0;
    listings[id] = entry;
    return entry;
  }

  List<Map<String, dynamic>> getActiveListings({String? excludeSellerId}) {
    return listings.values.where((l) {
      final status = l['listingStatus'] ?? l['status'] ?? 'active';
      if (status != 'active') return false;
      final available = (l['availableEnergyKwh'] as num?)?.toDouble() ?? 0;
      if (available <= 0) return false;
      if (excludeSellerId != null && l['sellerId'] == excludeSellerId)
        return false;
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> getListingsByOwner(String userId) {
    return listings.values.where((l) => l['sellerId'] == userId).toList();
  }

  Map<String, dynamic>? getListing(String id) => listings[id];

  void updateListing(String id, Map<String, dynamic> updates) {
    final existing = listings[id];
    if (existing != null) {
      existing.addAll(updates);
    }
  }

  Map<String, dynamic> addPurchase(Map<String, dynamic> purchase) {
    final id = _nextPurchaseId;
    final entry = Map<String, dynamic>.from(purchase)..['id'] = id;
    purchases.add(entry);

    // Track revenue only - inventory deduction is handled by the caller (purchase method)
    final listingId = purchase['listingId']?.toString();
    if (listingId != null && listings.containsKey(listingId)) {
      final listing = listings[listingId]!;
      final qty = (purchase['quantityKwh'] as num?)?.toDouble() ?? 0;
      final totalAmount = (purchase['totalAmount'] as num?)?.toDouble() ?? 0;
      final sold = (listing['quantitySoldKwh'] as num?)?.toDouble() ?? 0;
      final revenue = (listing['totalRevenue'] as num?)?.toDouble() ?? 0;
      listing['quantitySoldKwh'] = sold + qty;
      listing['totalRevenue'] = revenue + totalAmount;
    }

    return entry;
  }

  List<Map<String, dynamic>> getPurchasesByBuyer(String userId) {
    if (userId.isEmpty) return purchases;
    return purchases.where((p) {
      final bId = p['buyerId']?.toString() ?? '';
      if (bId == userId) return true;
      if ((userId == 'mock-consumer-1' && bId == 'consumer-1') ||
          (userId == 'consumer-1' && bId == 'mock-consumer-1')) {
        return true;
      }
      if ((userId == 'mock-consumer-2' && bId == 'consumer-2') ||
          (userId == 'consumer-2' && bId == 'mock-consumer-2')) {
        return true;
      }
      return false;
    }).toList();
  }

  List<Map<String, dynamic>> getPurchasesBySeller(String userId) {
    if (userId.isEmpty) return purchases;
    return purchases.where((p) {
      final sId = p['sellerId']?.toString() ?? '';
      if (sId == userId) return true;
      if ((userId == 'mock-producer-1' && sId == 'producer-1') ||
          (userId == 'producer-1' && sId == 'mock-producer-1')) {
        return true;
      }
      if ((userId == 'mock-producer-2' && sId == 'producer-2') ||
          (userId == 'producer-2' && sId == 'mock-producer-2')) {
        return true;
      }
      return false;
    }).toList();
  }

  void seed() {
    if (listings.isNotEmpty) return;

    registerUser('producer-1', 'producer1@voltshare-demo.local', 'producer');
    registerUser('producer-2', 'producer2@voltshare-demo.local', 'producer');
    registerUser('consumer-1', 'consumer1@voltshare-demo.local', 'consumer');
    registerUser('consumer-2', 'consumer2@voltshare-demo.local', 'consumer');
    registerUser('mock-producer-1', 'ravi@voltshare-demo.local', 'producer');
    registerUser('mock-consumer-1', 'ananya@voltshare-demo.local', 'consumer');

    final now = DateTime.now();
    final listingsData = [
      {
        'id': 'ravi',
        'sellerId': 'producer-1',
        'sellerName': 'Ravi Solar Hub',
        'sellerRole': 'producer',
        'title': 'Solar Surplus — Kochi',
        'energySource': 'solar',
        'availableEnergyKwh': 100.0,
        'quantityTotalKwh': 100.0,
        'quantitySoldKwh': 0,
        'totalRevenue': 0,
        'pricePerKwh': 8.20,
        'location': 'Kochi',
        'batteryBacked': true,
        'renewableVerified': true,
        'sellerRating': 4.9,
        'reviewCount': 120,
        'distanceKm': 0.5,
        'availabilityStart': now
            .subtract(const Duration(hours: 1))
            .toIso8601String(),
        'availabilityEnd': now.add(const Duration(hours: 24)).toIso8601String(),
        'createdAt': now.subtract(const Duration(hours: 2)).toIso8601String(),
        'listingStatus': 'active',
      },
      {
        'sellerId': 'producer-1',
        'sellerName': 'Chandra Devi',
        'sellerRole': 'producer',
        'title': 'Wind Energy — Idukki',
        'energySource': 'wind',
        'availableEnergyKwh': 30.0,
        'quantityTotalKwh': 30.0,
        'quantitySoldKwh': 0,
        'totalRevenue': 0,
        'pricePerKwh': 5.20,
        'location': 'Idukki',
        'batteryBacked': false,
        'renewableVerified': true,
        'availabilityStart': now
            .subtract(const Duration(hours: 2))
            .toIso8601String(),
        'availabilityEnd': now.add(const Duration(hours: 48)).toIso8601String(),
        'createdAt': now.subtract(const Duration(days: 1)).toIso8601String(),
        'listingStatus': 'active',
      },
      {
        'sellerId': 'producer-2',
        'sellerName': 'Deepak Menon',
        'sellerRole': 'producer',
        'title': 'Hydro Power — Thrissur',
        'energySource': 'hydro',
        'availableEnergyKwh': 80.0,
        'quantityTotalKwh': 80.0,
        'quantitySoldKwh': 0,
        'totalRevenue': 0,
        'pricePerKwh': 4.50,
        'location': 'Thrissur',
        'batteryBacked': false,
        'renewableVerified': true,
        'availabilityStart': now
            .subtract(const Duration(hours: 3))
            .toIso8601String(),
        'availabilityEnd': now.add(const Duration(hours: 72)).toIso8601String(),
        'createdAt': now.subtract(const Duration(days: 2)).toIso8601String(),
        'listingStatus': 'active',
      },
      {
        'sellerId': 'producer-1',
        'sellerName': 'Chandra Devi',
        'sellerRole': 'producer',
        'title': 'Biomass — Alappuzha',
        'energySource': 'biomass',
        'availableEnergyKwh': 20.0,
        'quantityTotalKwh': 20.0,
        'quantitySoldKwh': 0,
        'totalRevenue': 0,
        'pricePerKwh': 6.20,
        'location': 'Alappuzha',
        'batteryBacked': true,
        'renewableVerified': false,
        'availabilityStart': now
            .subtract(const Duration(hours: 1))
            .toIso8601String(),
        'availabilityEnd': now.add(const Duration(hours: 12)).toIso8601String(),
        'createdAt': now.subtract(const Duration(days: 3)).toIso8601String(),
        'listingStatus': 'active',
      },
      {
        'sellerId': 'producer-2',
        'sellerName': 'Deepak Menon',
        'sellerRole': 'producer',
        'title': 'Solar — Kozhikode',
        'energySource': 'solar',
        'availableEnergyKwh': 0.0,
        'quantityTotalKwh': 15.0,
        'quantitySoldKwh': 15.0,
        'totalRevenue': 108.0,
        'pricePerKwh': 7.20,
        'location': 'Kozhikode',
        'batteryBacked': true,
        'renewableVerified': true,
        'availabilityStart': now
            .subtract(const Duration(days: 7))
            .toIso8601String(),
        'availabilityEnd': now.add(const Duration(hours: 1)).toIso8601String(),
        'createdAt': now.subtract(const Duration(days: 7)).toIso8601String(),
        'listingStatus': 'sold',
      },
    ];

    for (final listing in listingsData) {
      addListing(listing);
    }

    // Seed initial purchases
    addPurchase({
      'listingId': 'ravi',
      'buyerId': 'consumer-1',
      'buyerName': 'Ananya Sharma',
      'sellerId': 'producer-1',
      'sellerName': 'Ravi Solar Hub',
      'listingTitle': 'Solar Surplus — Kochi',
      'quantityKwh': 12.5,
      'unitPrice': 8.20,
      'platformFee': 3.08,
      'totalAmount': 105.58,
      'estimatedSavings': 22.50,
      'co2ImpactKg': 8.75,
      'purchasedAt': now.subtract(const Duration(hours: 4)).toIso8601String(),
      'status': 'completed',
    });

    addPurchase({
      'listingId': 'ravi',
      'buyerId': 'consumer-2',
      'buyerName': 'Vijay Nair',
      'sellerId': 'producer-1',
      'sellerName': 'Ravi Solar Hub',
      'listingTitle': 'Solar Surplus — Kochi',
      'quantityKwh': 8.0,
      'unitPrice': 8.20,
      'platformFee': 1.97,
      'totalAmount': 67.57,
      'estimatedSavings': 14.40,
      'co2ImpactKg': 5.60,
      'purchasedAt': now.subtract(const Duration(hours: 8)).toIso8601String(),
      'status': 'completed',
    });
  }

  void reset() {
    users.clear();
    listings.clear();
    purchases.clear();
  }
}
