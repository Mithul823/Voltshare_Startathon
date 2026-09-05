import '../data/escrow_mock_repository.dart';
import '../domain/escrow_operation_record.dart';

class EscrowReconciliationService {
  const EscrowReconciliationService(this.repository);

  final EscrowRepository repository;

  Future<List<String>> recoverInterruptedOperations() {
    return repository.reconcile();
  }

  Future<EscrowOperationRecord?> latestOperation() async {
    final records = await repository.operationRecords();
    return records.isEmpty ? null : records.last;
  }
}
