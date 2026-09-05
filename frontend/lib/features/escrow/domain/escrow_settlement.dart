import 'escrow_agreement.dart';
import 'trade_default_case.dart';

class EscrowSettlementResult {
  const EscrowSettlementResult({
    required this.escrow,
    required this.sellerReleasePaise,
    required this.buyerRefundPaise,
    required this.platformFeeRetainedPaise,
    required this.frozenPaise,
    required this.idempotencyKey,
    this.defaultCase,
  });

  final EscrowAgreement escrow;
  final int sellerReleasePaise;
  final int buyerRefundPaise;
  final int platformFeeRetainedPaise;
  final int frozenPaise;
  final String idempotencyKey;
  final TradeDefaultCase? defaultCase;

  bool get conservesMoney {
    return escrow.totalHeldPaise ==
        sellerReleasePaise +
            buyerRefundPaise +
            platformFeeRetainedPaise +
            frozenPaise;
  }
}
