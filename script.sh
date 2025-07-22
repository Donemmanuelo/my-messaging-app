#!/bin/bash

# --- Start of Script ---

echo "🚀 Generating a complete, FINAL, and CORRECTED Flutter client..."
echo "-> This will create a new project folder 'whatsapp_flutter_client'."
echo "-> Please DELETE your existing project folder with the same name before 
continuing."

# 1. Create the project
flutter create whatsapp_flutter_client
cd whatsapp_flutter_client

# 2. Add dependencies
echo "-> Adding dependencies..."
flutter pub add flutter_bloc dio web_socket_channel flutter_secure_storage get_it 
equatable provider

# 3. Create directory structure
echo "-> Creating source directories..."
mkdir -p lib/core/services
mkdir -p lib/data/datasources lib/data/models lib/data/repositories
mkdir -p lib/presentation/bloc/auth_bloc lib/presentation/bloc/chat_bloc 
lib/presentation/bloc/conversation_bloc
mkdir -p lib/presentation/screens lib/presentation/widgets

# 4. Populate ALL source files with corrected code
echo "-> Writing all Dart source files..."

# --- lib/main.dart ---
cat > lib/main.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:whatsapp_flutter_client/core/services/service_locator.dart';
import 'package:whatsapp_flutter_client/data/repositories/auth_repository.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/auth_bloc/auth_bloc.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_bloc.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_event.dart';
import 
'package:whatsapp_flutter_client/presentation/screens/conversations_screen.dart';
import 
'package:whatsapp_flutter_client/presentation/screens/phone_input_screen.dart';

void main() {
  setupLocator();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GetIt.I.get<AuthBloc>(),
      child: MaterialApp(
        title: 'Flutter Chat App',
        theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: GetIt.I.get<AuthRepository>().getToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData && snapshot.data != null) {
          return BlocProvider(
            create: (context) => GetIt.I.get<ChatBloc>()..add(ConnectWebSocket()),
            child: const ConversationsScreen(),
          );
        } else {
          return const PhoneInputScreen();
        }
      },
    );
  }
}
EOF

# --- lib/core/services/service_locator.dart ---
cat > lib/core/services/service_locator.dart << 'EOF'
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
  getIt.registerLazySingleton<ChatBloc>(() => ChatBloc(webSocketService: 
getIt<WebSocketService>()));
  getIt.registerFactory<ConversationBloc>(() => 
ConversationBloc(conversationRepository: getIt<ConversationRepository>()));
}
EOF

# --- Data Layer ---
cat > lib/data/datasources/auth_api_client.dart << 'EOF'
import 'package:dio/dio.dart';
class AuthApiClient {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3000/api'));
  Future<void> sendOtp(String phoneNumber) async {
    await _dio.post('/auth/send-otp', data: {'phone_number': phoneNumber});
  }
  Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String otp) async {
    final response = await _dio.post('/auth/verify-otp', data: {'phone_number': 
phoneNumber, 'otp': otp});
    return response.data;
  }
}
EOF
cat > lib/data/datasources/websocket_service.dart << 'EOF'
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
EOF
cat > lib/data/models/chat_message.dart << 'EOF'
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
EOF
cat > lib/data/models/conversation.dart << 'EOF'
import 'package:equatable/equatable.dart';
class Conversation extends Equatable {
  final String conversationId;
  final bool isGroup;
  final String? groupName, otherUserId, otherUserName, lastMessage;
  final DateTime? lastMessageAt;
  const Conversation({required this.conversationId, required this.isGroup, 
this.groupName, this.otherUserId, this.otherUserName, this.lastMessage, 
this.lastMessageAt});
  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
      conversationId: json['conversation_id'],
      isGroup: json['is_group'],
      groupName: json['group_name'],
      otherUserId: json['other_user_id'],
      otherUserName: json['other_user_name'],
      lastMessage: json['last_message'],
      lastMessageAt: json['last_message_at'] != null ? 
DateTime.parse(json['last_message_at']) : null,
    );
  String get displayName => isGroup ? (groupName ?? 'Group') : (otherUserName ?? 
'Unknown User');
  @override List<Object?> get props => [conversationId, isGroup, groupName, 
otherUserId, otherUserName, lastMessage, lastMessageAt];
}
EOF
cat > lib/data/repositories/auth_repository.dart << 'EOF'
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:whatsapp_flutter_client/data/datasources/auth_api_client.dart';
class AuthRepository {
  final AuthApiClient _apiClient;
  final _storage = const FlutterSecureStorage();
  AuthRepository({required AuthApiClient apiClient}) : _apiClient = apiClient;
  Future<void> sendOtp(String phoneNumber) => _apiClient.sendOtp(phoneNumber);
  Future<void> verifyOtp(String phoneNumber, String otp) async {
    final data = await _apiClient.verifyOtp(phoneNumber, otp);
    await _storage.write(key: 'jwt_token', value: data['token']);
    await _storage.write(key: 'user_id', value: data['user_id']);
  }
  Future<String?> getToken() => _storage.read(key: 'jwt_token');
}
EOF
cat > lib/data/repositories/conversation_repository.dart << 'EOF'
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:whatsapp_flutter_client/data/models/conversation.dart';
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
}
EOF

# --- Presentation Layer ---
cat > lib/presentation/bloc/auth_bloc/auth_event.dart << 'EOF'
import 'package:equatable/equatable.dart';
abstract class AuthEvent extends Equatable { const AuthEvent(); @override 
List<Object> get props => []; }
class AuthSendOtpRequested extends AuthEvent { final String phoneNumber; const 
AuthSendOtpRequested(this.phoneNumber); @override List<Object> get props => 
[phoneNumber]; }
class AuthVerifyOtpRequested extends AuthEvent { final String phoneNumber, otp; 
const AuthVerifyOtpRequested({required this.phoneNumber, required this.otp}); 
@override List<Object> get props => [phoneNumber, otp]; }
EOF
cat > lib/presentation/bloc/auth_bloc/auth_state.dart << 'EOF'
import 'package:equatable/equatable.dart';
abstract class AuthState extends Equatable { const AuthState(); @override 
List<Object> get props => []; }
class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthOtpSentSuccess extends AuthState {}
class AuthSuccess extends AuthState {}
class AuthFailure extends AuthState { final String error; const 
AuthFailure(this.error); @override List<Object> get props => [error]; }
EOF
cat > lib/presentation/bloc/auth_bloc/auth_bloc.dart << 'EOF'
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:whatsapp_flutter_client/data/repositories/auth_repository.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/auth_bloc/auth_event.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/auth_bloc/auth_state.dart';
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;
  AuthBloc({required AuthRepository authRepository}) : _repo = authRepository, 
super(AuthInitial()) {
    on<AuthSendOtpRequested>((e, emit) async {
      emit(AuthLoading());
      try { await _repo.sendOtp(e.phoneNumber); emit(AuthOtpSentSuccess()); } 
catch (err) { emit(AuthFailure(err.toString())); }
    });
    on<AuthVerifyOtpRequested>((e, emit) async {
      emit(AuthLoading());
      try { await _repo.verifyOtp(e.phoneNumber, e.otp); emit(AuthSuccess()); } 
catch (err) { emit(AuthFailure(err.toString())); }
    });
  }
}
EOF
cat > lib/presentation/bloc/chat_bloc/chat_event.dart << 'EOF'
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
EOF
cat > lib/presentation/bloc/chat_bloc/chat_state.dart << 'EOF'
import 'package:equatable/equatable.dart';
import 'package:whatsapp_flutter_client/data/models/chat_message.dart';
enum ConnectionStatus { initial, connected, disconnected, error }
class ChatState extends Equatable {
  final ConnectionStatus status;
  final List<ChatMessage> messages;
  final bool isPeerTyping;
  final String? error;
  const ChatState({this.status = ConnectionStatus.initial, this.messages = const 
[], this.isPeerTyping = false, this.error});
  ChatState copyWith({ConnectionStatus? status, List<ChatMessage>? messages, bool? 
isPeerTyping, String? error}) => ChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      isPeerTyping: isPeerTyping ?? this.isPeerTyping,
      error: error ?? this.error,
    );
  @override List<Object?> get props => [status, messages, isPeerTyping, error];
}
EOF
cat > lib/presentation/bloc/chat_bloc/chat_bloc.dart << 'EOF'
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:whatsapp_flutter_client/data/datasources/websocket_service.dart';
import 'package:whatsapp_flutter_client/data/models/chat_message.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_event.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_state.dart';
class _MessageReceived extends ChatEvent { final dynamic message; const 
_MessageReceived(this.message); }
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final WebSocketService _wsService;
  StreamSubscription? _subscription;
  ChatBloc({required WebSocketService webSocketService}) : _wsService = 
webSocketService, super(const ChatState()) {
    on<ConnectWebSocket>((_, emit) async {
      try { await _wsService.connect(); _subscription?.cancel(); _subscription = 
_wsService.messages?.listen((msg) => add(_MessageReceived(msg))); 
emit(state.copyWith(status: ConnectionStatus.connected)); } catch (e) { 
emit(state.copyWith(status: ConnectionStatus.error, error: e.toString())); }
    });
    on<SendMessage>((e, _) => _wsService.send({'event': 'message', 'data': 
{'conversation_id': e.conversationId, 'content': e.content}}));
    on<SendTypingIndicator>((e, _) => _wsService.send({'event': 'typing', 'data': 
{'conversation_id': e.conversationId, 'is_typing': e.isTyping}}));
    on<_MessageReceived>((e, emit) {
      if (e.message is! Map<String, dynamic>) return;
      final type = e.message['event'] as String?;
      final data = e.message['data'] as Map<String, dynamic>?;
      if (type == null || data == null) return;
      switch (type) {
        case 'new_message': emit(state.copyWith(messages: 
List.from(state.messages)..add(ChatMessage.fromJson(data)), isPeerTyping: false)); 
break;
        case 'user_typing': emit(state.copyWith(isPeerTyping: data['is_typing'] as 
bool? ?? false)); break;
      }
    });
  }
  @override Future<void> close() { _wsService.disconnect(); 
_subscription?.cancel(); return super.close(); }
}
EOF
cat > lib/presentation/bloc/conversation_bloc/conversation_event.dart << 'EOF'
import 'package:equatable/equatable.dart';
abstract class ConversationEvent extends Equatable { const ConversationEvent(); 
@override List<Object> get props => []; }
class FetchConversations extends ConversationEvent {}
EOF
cat > lib/presentation/bloc/conversation_bloc/conversation_state.dart << 'EOF'
import 'package:equatable/equatable.dart';
import 'package:whatsapp_flutter_client/data/models/conversation.dart';
enum ConversationStatus { initial, loading, success, failure }
class ConversationState extends Equatable {
  final ConversationStatus status; final List<Conversation> conversations; final 
String? error;
  const ConversationState({this.status = ConversationStatus.initial, 
this.conversations = const [], this.error});
  ConversationState copyWith({ConversationStatus? status, List<Conversation>? 
conversations, String? error}) => ConversationState(
      status: status ?? this.status, conversations: conversations ?? 
this.conversations, error: error ?? this.error);
  @override List<Object?> get props => [status, conversations, error];
}
EOF
cat > lib/presentation/bloc/conversation_bloc/conversation_bloc.dart << 'EOF'
import 'package:flutter_bloc/flutter_bloc.dart';
import 
'package:whatsapp_flutter_client/data/repositories/conversation_repository.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/conversation_bloc/conversation_event.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/conversation_bloc/conversation_state.dart';
class ConversationBloc extends Bloc<ConversationEvent, ConversationState> {
  final ConversationRepository _repo;
  ConversationBloc({required ConversationRepository conversationRepository}) : 
_repo = conversationRepository, super(const ConversationState()) {
    on<FetchConversations>((_, emit) async {
      emit(state.copyWith(status: ConversationStatus.loading));
      try { final convos = await _repo.getConversations(); 
emit(state.copyWith(status: ConversationStatus.success, conversations: convos)); } 
catch (e) { emit(state.copyWith(status: ConversationStatus.failure, error: 
e.toString())); }
    });
  }
}
EOF

# --- Screens ---
cat > lib/presentation/screens/phone_input_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:whatsapp_flutter_client/main.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/auth_bloc/auth_bloc.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/auth_bloc/auth_event.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/auth_bloc/auth_state.dart';
import 
'package:whatsapp_flutter_client/presentation/screens/otp_verification_screen.dart';
class PhoneInputScreen extends StatefulWidget { const 
PhoneInputScreen({super.key}); @override State<PhoneInputScreen> createState() => 
_PhoneInputScreenState(); }
class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final _controller = TextEditingController(); final _formKey = 
GlobalKey<FormState>();
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Enter Phone Number')),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthOtpSentSuccess) 
Navigator.of(context).push(MaterialPageRoute(builder: (_) => 
BlocProvider.value(value: context.read<AuthBloc>(), child: 
OtpVerificationScreen(phoneNumber: _controller.text))));
          if (state is AuthFailure) 
ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: 
Text(state.error)));
        },
        child: Padding(padding: const EdgeInsets.all(20), child: Form(key: 
_formKey, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextFormField(controller: _controller, decoration: const 
InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()), 
keyboardType: TextInputType.phone, validator: (v) => v==null||v.isEmpty?'Please 
enter a phone number':null),
          const SizedBox(height: 20),
          BlocBuilder<AuthBloc, AuthState>(builder: (context, state) => state is 
AuthLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: (){ 
if(_formKey.currentState!.validate()) 
context.read<AuthBloc>().add(AuthSendOtpRequested(_controller.text)); }, child: 
const Text('Send OTP'))),
        ]))),
      ),
    );
}
EOF
cat > lib/presentation/screens/otp_verification_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:whatsapp_flutter_client/main.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/auth_bloc/auth_bloc.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/auth_bloc/auth_event.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/auth_bloc/auth_state.dart';
class OtpVerificationScreen extends StatefulWidget { final String phoneNumber; 
const OtpVerificationScreen({super.key, required this.phoneNumber}); @override 
State<OtpVerificationScreen> createState() => _OtpVerificationScreenState(); }
class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _controller = TextEditingController(); final _formKey = 
GlobalKey<FormState>();
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthSuccess) 
Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const 
AuthGate()), (route) => false);
          if (state is AuthFailure) 
ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: 
Text(state.error)));
        },
        child: Padding(padding: const EdgeInsets.all(20), child: Form(key: 
_formKey, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Enter the OTP sent to ${widget.phoneNumber}'), const 
SizedBox(height: 20),
          TextFormField(controller: _controller, decoration: const 
InputDecoration(labelText: 'OTP', border: OutlineInputBorder()), keyboardType: 
TextInputType.number, validator: (v) => v==null||v.length<6?'Enter a valid 6-digit 
OTP':null),
          const SizedBox(height: 20),
          BlocBuilder<AuthBloc, AuthState>(builder: (context, state) => state is 
AuthLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: (){ 
if(_formKey.currentState!.validate()) 
context.read<AuthBloc>().add(AuthVerifyOtpRequested(phoneNumber: 
widget.phoneNumber, otp: _controller.text)); }, child: const Text('Verify OTP'))),
        ]))),
      ),
    );
}
EOF
cat > lib/presentation/screens/conversations_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:whatsapp_flutter_client/data/models/conversation.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_bloc.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_state.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/conversation_bloc/conversation_bloc.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/conversation_bloc/conversation_event.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/conversation_bloc/conversation_state.dart';
import 'package:whatsapp_flutter_client/presentation/screens/chat_screen.dart';
class ConversationsScreen extends StatelessWidget { const 
ConversationsScreen({super.key}); @override Widget build(BuildContext context) => 
MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => 
GetIt.I.get<ConversationBloc>()..add(FetchConversations())),
        BlocProvider.value(value: BlocProvider.of<ChatBloc>(context)),
      ],
      child: const ConversationsView(),
    );
}
class ConversationsView extends StatelessWidget { const 
ConversationsView({super.key}); @override Widget build(BuildContext context) => 
Scaffold(
      appBar: AppBar(title: BlocBuilder<ChatBloc, ChatState>(builder: (context, 
state) {
        String title = "Conversations"; Color indicatorColor = Colors.grey;
        switch(state.status) {
          case ConnectionStatus.connected: title = "Connected"; indicatorColor = 
Colors.green; break;
          case ConnectionStatus.disconnected: title = "Disconnected"; 
indicatorColor = Colors.red; break;
          case ConnectionStatus.error: title = "Connection Error"; indicatorColor 
= Colors.orange; break;
          default: break;
        }
        return Row(children: [Text(title), const SizedBox(width: 8), 
CircleAvatar(backgroundColor: indicatorColor, radius: 5)]);
      })),
      body: BlocBuilder<ConversationBloc, ConversationState>(builder: (context, 
state) {
        switch (state.status) {
          case ConversationStatus.failure: return Center(child: Text('Failed to 
load conversations: ${state.error}'));
          case ConversationStatus.success:
            if (state.conversations.isEmpty) return const Center(child: Text('No 
conversations yet.'));
            return ListView.builder(itemCount: state.conversations.length, 
itemBuilder: (context, index) {
              final convo = state.conversations[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(convo.displayName),
                subtitle: Text(convo.lastMessage ?? 'No messages yet', maxLines: 
1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: 
(_) => BlocProvider.value(value: BlocProvider.of<ChatBloc>(context), child: 
ChatScreen(conversation: convo)))),
              );
            });
          default: return const Center(child: CircularProgressIndicator());
        }
      }),
    );
}
EOF
cat > lib/presentation/screens/chat_screen.dart << 'EOF'
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:whatsapp_flutter_client/data/models/conversation.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_bloc.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_event.dart';
import 
'package:whatsapp_flutter_client/presentation/bloc/chat_bloc/chat_state.dart';
import 
'package:whatsapp_flutter_client/presentation/widgets/chat_message_bubble.dart';
class ChatScreen extends StatefulWidget { final Conversation conversation; const 
ChatScreen({super.key, required this.conversation}); @override State<ChatScreen> 
createState() => _ChatScreenState(); }
class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController(); String? _currentUserId; Timer? 
_typingTimer;
  @override void initState() { super.initState(); _loadCurrentUser(); 
_controller.addListener(_onTyping); }
  Future<void> _loadCurrentUser() async { _currentUserId = await const 
FlutterSecureStorage().read(key: 'user_id'); if (mounted) setState(() {}); }
  void _onTyping() {
    _typingTimer?.cancel();
    context.read<ChatBloc>().add(SendTypingIndicator(isTyping: true, 
conversationId: widget.conversation.conversationId));
    _typingTimer = Timer(const Duration(seconds: 2), () => 
context.read<ChatBloc>().add(SendTypingIndicator(isTyping: false, conversationId: 
widget.conversation.conversationId)));
  }
  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      _typingTimer?.cancel();
      context.read<ChatBloc>().add(SendTypingIndicator(isTyping: false, 
conversationId: widget.conversation.conversationId));
      context.read<ChatBloc>().add(SendMessage(content: _controller.text, 
conversationId: widget.conversation.conversationId));
      _controller.clear();
    }
  }
  @override Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: BlocBuilder<ChatBloc, ChatState>(builder: (context, 
state) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.conversation.displayName),
        if (state.isPeerTyping) const Text('typing...', style: TextStyle(fontSize: 
12, fontStyle: FontStyle.italic)),
      ]))),
      body: Column(children: [
        Expanded(child: BlocBuilder<ChatBloc, ChatState>(builder: (context, state) 
{
          if (_currentUserId == null) return const Center(child: 
CircularProgressIndicator());
          final messages = state.messages.where((m) => m.conversationId == 
widget.conversation.conversationId).toList();
          if (messages.isEmpty) return const Center(child: Text('No messages 
yet.'));
          return ListView.builder(padding: const EdgeInsets.all(8), reverse: true, 
itemCount: messages.length, itemBuilder: (context, index) {
            final message = messages[messages.length - 1 - index];
            return ChatMessageBubble(message: message, isMe: message.senderId == 
_currentUserId);
          });
        })),
        Padding(padding: const EdgeInsets.all(8), child: Row(children: [
          Expanded(child: TextField(controller: _controller, decoration: const 
InputDecoration(hintText: 'Type a message...'), onSubmitted: (_) => 
_sendMessage())),
          IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
        ])),
      ]),
    );
  @override void dispose() { _controller.removeListener(_onTyping); 
_controller.dispose(); _typingTimer?.cancel(); super.dispose(); }
}
EOF

# --- Widgets ---
cat > lib/presentation/widgets/chat_message_bubble.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:whatsapp_flutter_client/data/models/chat_message.dart';
class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message; final bool isMe;
  const ChatMessageBubble({super.key, required this.message, required this.isMe});
  @override Widget build(BuildContext context) => Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isMe ? Colors.teal[400] : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16), topRight: const 
Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Text(message.content, style: TextStyle(color: isMe ? Colors.white : 
Colors.black87)),
      ),
    );
}
EOF

# --- End of Script ---
echo "✅ Flutter client generation complete! All known compilation errors have 
been fixed."
echo ""
echo "--- Next Steps ---"
echo "1. DELETE your old 'whatsapp_flutter_client' directory."
echo "2. Run this script in the parent directory to generate the new, corrected 
project."
echo "3. cd into the new 'whatsapp_flutter_client' directory."
echo "4. Ensure your Rust backend is running."
echo "5. Run the Flutter app: flutter run -d chrome"
echo ""
echo "The application should now compile and run without errors."
echo "------------------"
