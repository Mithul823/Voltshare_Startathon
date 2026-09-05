import '../domain/escrow_agreement.dart';

class EscrowStateMachine {
  const EscrowStateMachine();

  static const Map<EscrowStatus, Set<EscrowStatus>> _allowed = {
    EscrowStatus.awaitingFunding: {
      EscrowStatus.funded,
      EscrowStatus.cancelled,
      EscrowStatus.frozen,
    },
    EscrowStatus.funded: {
      EscrowStatus.energyDeliveryPending,
      EscrowStatus.cancelled,
      EscrowStatus.frozen,
    },
    EscrowStatus.energyDeliveryPending: {
      EscrowStatus.deliveryConfirmed,
      EscrowStatus.deliveryPartiallyConfirmed,
      EscrowStatus.refundPending,
      EscrowStatus.disputed,
      EscrowStatus.frozen,
      EscrowStatus.expired,
      EscrowStatus.cancelled,
    },
    EscrowStatus.deliveryPartiallyConfirmed: {
      EscrowStatus.releasePending,
      EscrowStatus.refundPending,
      EscrowStatus.disputed,
      EscrowStatus.frozen,
    },
    EscrowStatus.deliveryConfirmed: {
      EscrowStatus.releasePending,
      EscrowStatus.disputed,
      EscrowStatus.frozen,
    },
    EscrowStatus.releasePending: {EscrowStatus.released, EscrowStatus.frozen},
    EscrowStatus.refundPending: {EscrowStatus.refunded, EscrowStatus.frozen},
    EscrowStatus.disputed: {
      EscrowStatus.released,
      EscrowStatus.refunded,
      EscrowStatus.frozen,
    },
    EscrowStatus.frozen: {EscrowStatus.disputed},
    EscrowStatus.released: {},
    EscrowStatus.refunded: {},
    EscrowStatus.expired: {EscrowStatus.refundPending, EscrowStatus.frozen},
    EscrowStatus.cancelled: {EscrowStatus.refundPending},
  };

  bool canTransition(EscrowStatus from, EscrowStatus to) {
    return _allowed[from]?.contains(to) ?? false;
  }

  void validate(EscrowStatus from, EscrowStatus to) {
    if (!canTransition(from, to)) {
      throw EscrowStateException(
        'Invalid escrow transition: ${from.name} -> ${to.name}',
      );
    }
  }
}

class EscrowStateException implements Exception {
  const EscrowStateException(this.message);
  final String message;
  @override
  String toString() => message;
}
