import 'dart:math';

class IdempotencyKeyGenerator {
  IdempotencyKeyGenerator({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  String next(String operation) {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final suffix = List.generate(
      12,
      (_) => _random.nextInt(16).toRadixString(16),
    ).join();
    return '$operation-$millis-$suffix';
  }
}
