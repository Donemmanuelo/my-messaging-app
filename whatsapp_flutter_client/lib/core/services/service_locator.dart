import 'package:get_it/get_it.dart';
import 'package:whatsapp_flutter_client/data/datasources/auth_api_client.dart';
import 'package:whatsapp_flutter_client/data/datasources/websocket_service.dart';
import 'package:whatsapp_flutter_client/data/repositories/auth_repository.dart';
import 
'package:whatsapp_flutter_client/data/repositories/conversation_repository.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/auth_bloc/auth_bloc.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_bloc.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/conversation_bloc/conversation_bloc.dart';

final getIt = GetIt.instance;

void setupLocator() {
  getIt.registerLazySingleton<AuthApiClient>(() => AuthApiClient());
  getIt.registerLazySingleton<WebSocketService>(() => WebSocketService());

  getIt.registerLazySingleton<AuthRepository>(() => AuthRepository(apiClient: 
getIt<AuthApiClient>()));
  getIt.registerLazySingleton<ConversationRepository>(() => 
ConversationRepository());
  
  getIt.registerFactory<AuthBloc>(() => AuthBloc(authRepository: 
getIt<AuthRepository>()));
  // --- CHATBLOC NOW NEEDS THE CONVERSATION REPO ---
  getIt.registerLazySingleton<ChatBloc>(() => ChatBloc(webSocketService: 
getIt<WebSocketService>(), conversationRepository: 
getIt<ConversationRepository>()));
  getIt.registerFactory<ConversationBloc>(() => 
ConversationBloc(conversationRepository: getIt<ConversationRepository>()));
}
