import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/message_models.dart';

typedef WsEventCallback = void Function(WsEvent event);

class MessageWsService {
  MessageWsService({
    required this.baseUrl,
    required this.accessToken,
    required this.onEvent,
    required this.onDisconnected,
  });

  final String baseUrl;
  final String accessToken;
  final WsEventCallback onEvent;
  final VoidCallback onDisconnected;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  bool _disposed = false;
  int _retryCount = 0;
  Timer? _retryTimer;

  /// 建立连接
  void connect() {
    if (_disposed) return;
    _cancelRetry();
    _doConnect();
  }

  void _doConnect() {
    if (_disposed) return;
    try {
      final wsBase = baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
      final uri = Uri.parse('$wsBase/messages/ws?token=$accessToken');
      _channel = WebSocketChannel.connect(uri);
      _sub = _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
      _retryCount = 0;
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _onData(dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      final event = WsEvent.fromJson(json);
      onEvent(event);
    } catch (_) {
      // 忽略解析错误
    }
  }

  void _onError(Object _) {
    _scheduleRetry();
  }

  void _onDone() {
    if (!_disposed) {
      onDisconnected();
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _cancelRetry();
    // 指数退避：1s, 2s, 4s, 8s, 最大 30s
    final delay = Duration(seconds: _retryDelay());
    _retryCount++;
    _retryTimer = Timer(delay, _doConnect);
  }

  int _retryDelay() {
    if (_retryCount <= 0) return 1;
    final seconds = 1 << (_retryCount - 1); // 1, 2, 4, 8, 16...
    return seconds.clamp(1, 30);
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// 发送 ping
  void ping() {
    try {
      _channel?.sink.add('ping');
    } catch (_) {}
  }

  /// 断开连接（登出时调用）
  void disconnect() {
    _disposed = true;
    _cancelRetry();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  /// 重新激活（从后台恢复时调用）
  void reconnect() {
    _disposed = false;
    _retryCount = 0;
    _cancelRetry();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _doConnect();
  }
}

// 兼容 VoidCallback 类型
typedef VoidCallback = void Function();
