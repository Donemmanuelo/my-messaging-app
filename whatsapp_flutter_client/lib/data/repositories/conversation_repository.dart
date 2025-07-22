import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:whatsapp_flutter_client/data/models/conversation.dart';
import 'package:whatsapp_flutter_client/data/models/chat_message.dart';

class ConversationRepository {
  final _dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3000/api'));
  final _storage = const FlutterSecureStorage();

  ConversationRepository() {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async 
{
      options.headers['Authorization'] = 'Bearer ${await _storage.read(key: 
'jwt_token')}';
      handler.next(options);
    }));
  }

  Future<List<Conversation>> getConversations() async {
    final response = await _dio.get('/conversations');
    return (response.data as List).map((json) => 
Conversation.fromJson(json)).toList();
  }

  // --- ADD NEW METHOD FOR MESSAGE HISTORY ---
  Future<List<ChatMessage>> getMessageHistory(String conversationId) async {
    try {
      final response = await _dio.get('/conversations/$conversationId/messages');
      final data = response.data as List;
      return data.map((json) => ChatMessage.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch message history');
    }
  }
}
