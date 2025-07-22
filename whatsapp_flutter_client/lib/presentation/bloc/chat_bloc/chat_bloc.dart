import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:whatsapp_flutter_client/data/datasources/websocket_service.dart';
import 'package:whatsapp_flutter_client/data/models/chat_message.dart';
import 'package:whatsapp_flutter_client/data/repositories/conversation_repository.dart';
import 'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_event.dart';
import 'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_state.dart';

class _MessageReceived extends ChatEvent {
  final dynamic message;
  const _MessageReceived(this.message);
}

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final WebSocketService _wsService;
  final ConversationRepository _convoRepo;
  StreamSubscription? _subscription;
  
  ChatBloc({required WebSocketService webSocketService, required ConversationRepository conversationRepository})
      : _wsService = webSocketService,
        _convoRepo = conversationRepository,
super(const ChatState()) {
    on<ConnectWebSocket>(_onConnect);
    on<SendMessage>(_onSendMessage);
    on<SendTypingIndicator>(_onSendTyping);
    on<_MessageReceived>(_onMessageReceived);
    on<FetchMessageHistory>(_onFetchHistory);
  }

  Future<void> _onConnect(ConnectWebSocket event, Emitter<ChatState> emit) async {
    try {
      await _wsService.connect();
      _subscription?.cancel();
      _subscription = _wsService.messages?.listen((msg) => add(_MessageReceived(msg)));
      emit(state.copyWith(status: ChatStatus.connected));
    } catch (e) {
      emit(state.copyWith(status: ChatStatus.failure, error: e.toString()));
    }
  }

  void _onSendMessage(SendMessage event, Emitter<ChatState> emit) {
    _wsService.send({'event': 'message', 'data': {'conversation_id': event.conversationId, 'content': event.content}});
  }

  void _onSendTyping(SendTypingIndicator event, Emitter<ChatState> emit) {
    _wsService.send({'event': 'typing', 'data': {'conversation_id': event.conversationId, 'is_typing': event.isTyping}});
  }

  void _onMessageReceived(_MessageReceived event, Emitter<ChatState> emit) {
    if (event.message is! Map<String, dynamic>) return;
    final type = event.message['event'] as String?;
    final data = event.message['data'] as Map<String, dynamic>?;
    if (type == null || data == null) return;
    switch (type) {
      case 'new_message':
        emit(state.copyWith(messages: List.from(state.messages)..add(ChatMessage.fromJson(data)), isPeerTyping: false));
        break;
      case 'user_typing':
        emit(state.copyWith(isPeerTyping: data['is_typing'] as bool? ?? false));
        break;
    }
  }

  Future<void> _onFetchHistory(FetchMessageHistory event, Emitter<ChatState> emit) async {
    emit(state.copyWith(status: ChatStatus.loadingHistory));
    try {
      final history = await _convoRepo.getMessageHistory(event.conversationId);
      emit(state.copyWith(status: ChatStatus.success, messages: history));
    } catch (e) {
      emit(state.copyWith(status: ChatStatus.failure, error: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
