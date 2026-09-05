enum WithdrawalStatus {
  pending('Pending'),
  completed('Completed'),
  failed('Failed'),
  cancelled('Cancelled');

  const WithdrawalStatus(this.label);
  final String label;
}

enum WithdrawalMethod {
  upi('UPI'),
  bankAccount('Bank account'),
  demoSettlement('Demo settlement');

  const WithdrawalMethod(this.label);
  final String label;
}

class WithdrawalRequest {
  const WithdrawalRequest({
    required this.id,
    required this.userId,
    required this.amountPaise,
    required this.method,
    required this.accountLabel,
    required this.status,
    required this.requestedAt,
    this.processedAt,
  });

  final String id;
  final String userId;
  final int amountPaise;
  final WithdrawalMethod method;
  final String accountLabel;
  final WithdrawalStatus status;
  final DateTime requestedAt;
  final DateTime? processedAt;

  WithdrawalRequest copyWith({
    WithdrawalStatus? status,
    DateTime? processedAt,
  }) {
    return WithdrawalRequest(
      id: id,
      userId: userId,
      amountPaise: amountPaise,
      method: method,
      accountLabel: accountLabel,
      status: status ?? this.status,
      requestedAt: requestedAt,
      processedAt: processedAt ?? this.processedAt,
    );
  }
}
