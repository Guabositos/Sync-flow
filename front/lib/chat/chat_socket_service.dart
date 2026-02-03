import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;

class ChatSocketService {
  io.Socket? _socket;

  final _onNewMessage = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get newMessageStream => _onNewMessage.stream;

  bool get isConnected => _socket?.connected == true;

  /// Connect to namespace /chat
  /// Query: roomId
  /// Auth: { token: JWT }  (send RAW token, no "Bearer ")
  void connect({
    required String baseUrl,
    required int roomId,
    required String token,
  }) {
    disconnect();

    final url = '$baseUrl/chat';

    _socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'roomId': roomId.toString()})
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionAttempts(9999)
          .setReconnectionDelay(1000)
          .build(),
    );

    _socket!.on('newMessage', (data) {
      // expected: { chatId, message }
      if (data is Map) {
        _onNewMessage.add(Map<String, dynamic>.from(data));
      }
    });
  }

  /// Gateway listens @SubscribeMessage('sendMessage')
  void sendMessage({required String content}) {
    _socket?.emit('sendMessage', {'content': content});
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _onNewMessage.close();
  }
}
