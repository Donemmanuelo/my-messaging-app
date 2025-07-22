import 'package:equatable/equatable.dart';
class ChatMessage extends Equatable {
  final String senderId, conversationId, content;
  const ChatMessage({required this.senderId, required this.conversationId, 
required this.content});
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
      senderId: json['sender_id'],
      conversationId: json['conversation_id'],
      content: json['content'],
    );
  @override List<Object?> get props => [senderId, conversationId, content];
}
