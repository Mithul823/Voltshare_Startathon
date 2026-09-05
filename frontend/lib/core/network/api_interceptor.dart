typedef SafeLogSink = void Function(String message);

class ApiInterceptor {
  const ApiInterceptor({this.log});

  final SafeLogSink? log;

  void debug(String message) {
    log?.call(message.replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9._-]+'), 'Bearer [redacted]'));
  }
}
