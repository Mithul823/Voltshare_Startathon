import 'dart:async';
import 'dart:math';

class ReconnectManager {
  ReconnectManager({
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
  });

  final Duration baseDelay;
  final Duration maxDelay;
  int _attempt = 0;
  final List<Object> _outgoingQueue = [];

  Duration nextDelay() {
    final seconds = min(
      maxDelay.inSeconds,
      baseDelay.inSeconds * (1 << _attempt),
    );
    _attempt = min(_attempt + 1, 8);
    return Duration(seconds: seconds);
  }

  void reset() {
    _attempt = 0;
  }

  void queue(Object message) {
    _outgoingQueue.add(message);
  }

  List<Object> drainQueue() {
    final messages = List<Object>.from(_outgoingQueue);
    _outgoingQueue.clear();
    return messages;
  }

  Timer schedule(void Function() callback) {
    return Timer(nextDelay(), callback);
  }
}
