import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/auth_token_provider.dart';
import '../domain/realtime_event.dart';
import 'reconnect_manager.dart';

class RealtimeRepository {
  RealtimeRepository({
    required AppConfig config,
    required AuthTokenProvider tokenProvider,
    ReconnectManager? reconnectManager,
  }) : _config = config,
       _tokenProvider = tokenProvider,
       _reconnectManager = reconnectManager ?? ReconnectManager();

  final AppConfig _config;
  final AuthTokenProvider _tokenProvider;
  final ReconnectManager _reconnectManager;
  final _events = StreamController<RealtimeEvent>.broadcast();
  final List<WebSocketChannel> _sockets = [];
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Timer? _heartbeat;
  Timer? _reconnectTimer;
  bool _closed = false;

  Stream<RealtimeEvent> get events => _events.stream;

  Future<bool> connect(Iterable<String> channels) async {
    if (_config.useMockBackend || !_config.isSupabaseConfigured) {
      return false;
    }
    final token = await _tokenProvider.accessToken();
    if (token == null || token.isEmpty) {
      return false;
    }
    _closed = false;
    await disconnect(keepControllerOpen: true);
    var connected = false;
    for (final channel in channels.toSet()) {
      final socket = WebSocketChannel.connect(_webSocketUri(channel, token));
      _sockets.add(socket);
      _subscriptions.add(
        socket.stream.listen(
          _handleMessage,
          onError: (_) => _scheduleReconnect(channels),
          onDone: () => _scheduleReconnect(channels),
          cancelOnError: true,
        ),
      );
      connected = true;
    }
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 20), (_) {
      for (final socket in _sockets) {
        socket.sink.add(jsonEncode({"type": "ping"}));
      }
    });
    _reconnectManager.reset();
    return connected;
  }

  Future<void> disconnect({bool keepControllerOpen = false}) async {
    _reconnectTimer?.cancel();
    _heartbeat?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    for (final socket in _sockets) {
      await socket.sink.close();
    }
    _sockets.clear();
    if (!keepControllerOpen) {
      _closed = true;
      await _events.close();
    }
  }

  void _handleMessage(Object? raw) {
    if (raw is! String) {
      return;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['type'] != 'event') {
      return;
    }
    final eventJson = (decoded['event'] as Map?)?.cast<String, Object?>();
    if (eventJson != null) {
      _events.add(RealtimeEvent.fromJson(eventJson));
    }
  }

  void _scheduleReconnect(Iterable<String> channels) {
    if (_closed || _config.useMockBackend) {
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = _reconnectManager.schedule(() {
      unawaited(connect(channels));
    });
  }

  Uri _webSocketUri(String channel, String token) {
    final apiUri = Uri.parse(_config.apiBaseUrl);
    final scheme = apiUri.scheme == 'https' ? 'wss' : 'ws';
    return apiUri.replace(
      scheme: scheme,
      path: '/ws/$channel',
      queryParameters: {'token': token},
    );
  }
}
