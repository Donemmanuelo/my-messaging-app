import 'package:flutter_bloc/flutter_bloc.dart';
import 'conversation_event.dart';
import 'conversation_state.dart';
import 'package:whatsapp_flutter_client/data/repositories/conversation_repository.dart';

class ConversationBloc extends Bloc<ConversationEvent, ConversationState> {
  final ConversationRepository conversationRepository;
  ConversationBloc({required this.conversationRepository}) : super(ConversationInitial()) {
    on<FetchConversations>((event, emit) async {
      emit(ConversationLoading());
      try {
        final conversations = await conversationRepository.getConversations();
        emit(ConversationLoadSuccess(conversations));
      } catch (e) {
        emit(ConversationFailure(e.toString()));
      }
    });
  }
} 