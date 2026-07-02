import 'dart:async';
import 'dart:convert';
import 'dart:io';

class RealtimeSSEClient {
  final String url;
  final Function(Map<String, dynamic> event) onEvent;
  final Function(dynamic error)? onError;
  final Function()? onConnected;
  final Function()? onDisconnected;

  HttpClient? _client;
  HttpClientRequest? _request;
  HttpClientResponse? _response;
  StreamSubscription? _subscription;
  bool _isDisposed = false;
  Timer? _reconnectTimer;
  int _retryDelaySeconds = 2;

  RealtimeSSEClient({
    required this.url,
    required this.onEvent,
    this.onError,
    this.onConnected,
    this.onDisconnected,
  });

  void connect() async {
    if (_isDisposed) return;
    _cleanup();

    print("🔌 SSE: Connecting to $url");
    try {
      _client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);

      final uri = Uri.parse(url);
      _request = await _client!.getUrl(uri);

      // Standard headers for SSE
      _request!.headers.set('Accept', 'text/event-stream');
      _request!.headers.set('Cache-Control', 'no-cache');
      _request!.headers.set('Connection', 'keep-alive');

      _response = await _request!.close();

      if (_response!.statusCode == 200) {
        if (onConnected != null) onConnected!();
        _retryDelaySeconds = 2; // Reset reconnect timer

        _subscription = _response!
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
          (line) {
            _parseLine(line);
          },
          onError: (err) {
            _handleError(err);
          },
          onDone: () {
            _handleDisconnect();
          },
        );
      } else {
        throw HttpException("HTTP ${_response!.statusCode}: ${_response!.reasonPhrase}");
      }
    } catch (e) {
      _handleError(e);
    }
  }

  void _parseLine(String line) {
    if (line.trim().isEmpty) return;

    if (line.startsWith('data:')) {
      final dataStr = line.substring(5).trim();
      if (dataStr.isEmpty) return;

      try {
        final Map<String, dynamic> event = jsonDecode(dataStr);
        onEvent(event);
      } catch (e) {
        print("⚠️ SSE: Failed to parse line: $line - Error: $e");
      }
    }
  }

  void _handleError(dynamic err) {
    if (_isDisposed) return;
    print("❌ SSE: Connection error: $err");
    if (onError != null) onError!(err);
    _scheduleReconnect();
  }

  void _handleDisconnect() {
    if (_isDisposed) return;
    print("🔌 SSE: Connection closed");
    if (onDisconnected != null) onDisconnected!();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _retryDelaySeconds), () {
      // Exponential backoff capped at 30 seconds
      _retryDelaySeconds = (_retryDelaySeconds * 2).clamp(2, 30);
      connect();
    });
  }

  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    _request?.abort();
    _request = null;
    _client?.close(force: true);
    _client = null;
  }

  void dispose() {
    print("🧹 SSE: Disposing client");
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _cleanup();
  }
}
