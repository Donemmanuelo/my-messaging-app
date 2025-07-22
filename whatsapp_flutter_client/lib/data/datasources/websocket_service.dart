import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'dart:convert';
class WebSocketService {
  final _secureStorage = const FlutterSecureStorage();
  WebSocketChannel? _channel;
  StreamController<dynamic>? _streamController;
  bool _isConnected = false;

  Stream<dynamic>? get messages => _streamController?.stream;
  
  Future<void> connect() async {
    final token = await _secureStorage.read(key: 'jwt_token');
    if (token == null) throw Exception('Auth token not found.');
    if (_isConnected) return;
    disconnect();
    final uri = Uri.parse('ws://127.0.0.1:3000/ws?token=$token');
    print("[WS] Connecting to $uri...");
    _channel = WebSocketChannel.connect(uri);
    _streamController = StreamController.broadcast();
    _isConnected = true;
    print("[WS] Connection established.");
    _channel?.stream.listen(
      (message) {
        print("[WS] <<< Received: $message");
        _streamController?.add(jsonDecode(message));
      },
      onDone: () {
        print("[WS] Connection closed.");
        _isConnected = false;
        disconnect();
      },
      onError: (error) {
        print("[WS] Stream error: $error");
        _isConnected = false;
      },
      cancelOnError: false,
    );
  }

  void send(Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      final messageString = jsonEncode(data);
      print("[WS] >>> Sending: $messageString");
      _channel!.sink.add(messageString);
    } else {
      print("[WS] Cannot send message. Not connected.");
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _streamController?.close();
    _streamController = null;
    _isConnected = false;
  }
}
