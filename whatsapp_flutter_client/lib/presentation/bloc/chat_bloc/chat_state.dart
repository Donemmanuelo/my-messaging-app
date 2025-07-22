import 'package:equatable/equatable.dart';
import 'package:whatsapp_flutter_client/data/models/chat_message.dart';

// --- ADD NEW STATUS FOR LOADING HISTORY ---
enum ChatStatus { initial, loadingHistory, success, failure, connected, 
disconnected }

class ChatState extends Equatable {
  final ChatStatus status;
  final List<ChatMessage> messages;
  final bool isPeerTyping;
  final String? error;
  const ChatState({this.status = ChatStatus.initial, this.messages = const [], 
this.isPeerTyping = false, this.error});
  ChatState copyWith({ChatStatus? status, List<ChatMessage>? messages, bool? 
isPeerTyping, String? error}) => ChatState(
      status: status ?? this.status, messages: messages ?? this.messages, 
isPeerTyping: isPeerTyping ?? this.isPeerTyping, error: error ?? this.error);
  @override List<Object?> get props => [status, messages, isPeerTyping, error];
}
