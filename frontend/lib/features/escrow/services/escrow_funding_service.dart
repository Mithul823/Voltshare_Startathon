import '../../marketplace/domain/energy_listing.dart';
import '../../marketplace/domain/energy_purchase.dart';
import '../../wallet/domain/wallet.dart';

class EscrowFundingService {
  const EscrowFundingService();

  void validateFunding({
    required Wallet wallet,
    required EnergyPurchase purchase,
  }) {
    final totalPaise = rupeesToPaise(purchase.totalAmount);
    if (totalPaise <= 0) {
      throw const EscrowFundingException('Escrow amount must be positive.');
    }
    if (wallet.availableBalancePaise < totalPaise) {
      throw const EscrowFundingException(
        'Insufficient balance for simulated escrow funding.',
      );
    }
  }

  String idempotencyKeyFor(EnergyPurchase purchase, EnergyListing listing) {
    return 'fund-${purchase.id}-${listing.id}-${purchase.buyerId}';
  }
}

class EscrowFundingException implements Exception {
  const EscrowFundingException(this.message);
  final String message;
  @override
  String toString() => message;
}
