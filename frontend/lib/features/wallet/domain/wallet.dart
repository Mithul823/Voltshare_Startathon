class Wallet {
  const Wallet({
    required this.userId,
    required this.availableBalancePaise,
    required this.pendingBalancePaise,
    required this.escrowHeldBalancePaise,
    required this.totalEarnedPaise,
    required this.totalSpentPaise,
    required this.totalWithdrawnPaise,
    required this.totalAddedPaise,
    required this.currency,
    required this.updatedAt,
  });

  final String userId;
  final int availableBalancePaise;
  final int pendingBalancePaise;
  final int escrowHeldBalancePaise;
  final int totalEarnedPaise;
  final int totalSpentPaise;
  final int totalWithdrawnPaise;
  final int totalAddedPaise;
  final String currency;
  final DateTime updatedAt;

  Wallet copyWith({
    int? availableBalancePaise,
    int? pendingBalancePaise,
    int? escrowHeldBalancePaise,
    int? totalEarnedPaise,
    int? totalSpentPaise,
    int? totalWithdrawnPaise,
    int? totalAddedPaise,
    DateTime? updatedAt,
  }) {
    return Wallet(
      userId: userId,
      availableBalancePaise:
          availableBalancePaise ?? this.availableBalancePaise,
      pendingBalancePaise: pendingBalancePaise ?? this.pendingBalancePaise,
      escrowHeldBalancePaise:
          escrowHeldBalancePaise ?? this.escrowHeldBalancePaise,
      totalEarnedPaise: totalEarnedPaise ?? this.totalEarnedPaise,
      totalSpentPaise: totalSpentPaise ?? this.totalSpentPaise,
      totalWithdrawnPaise: totalWithdrawnPaise ?? this.totalWithdrawnPaise,
      totalAddedPaise: totalAddedPaise ?? this.totalAddedPaise,
      currency: currency,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

int rupeesToPaise(double amount) => (amount * 100).round();

String formatPaise(int paise, {String currency = 'Rs'}) {
  final sign = paise < 0 ? '-' : '';
  final absolute = paise.abs();
  final rupees = absolute ~/ 100;
  final cents = absolute % 100;
  return '$sign$currency $rupees.${cents.toString().padLeft(2, '0')}';
}
