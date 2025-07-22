import 'package:equatable/equatable.dart';

abstract class ChatEvent extends Equatable { const ChatEvent(); @override 
List<Object> get props => []; }

class ConnectWebSocket extends ChatEvent {}
class SendMessage extends ChatEvent { final String content, conversationId; const 
SendMessage({required this.content, required this.conversationId}); @override 
List<Object> get props => [content, conversationId]; }
class SendTypingIndicator extends ChatEvent { final bool isTyping; final String 
conversationId; const SendTypingIndicator({required this.isTyping, required 
this.conversationId}); @override List<Object> get props => [isTyping, 
conversationId]; }

// --- ADD NEW EVENT FOR MESSAGE HISTORY ---
class FetchMessageHistory extends ChatEvent {
  final String conversationId;
  const FetchMessageHistory(this.conversationId);
  @override List<Object> get props => [conversationId];
}
